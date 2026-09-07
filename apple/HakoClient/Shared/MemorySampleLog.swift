import Foundation
import Darwin

 
 
 
 
 
 
 
 
 
enum MemorySampleLog {
     
     
     
     
    static let extensionFileName = "hako-extension-memory.log"

     
     
    static let startupPhaseFileName = "hako-core-phases.log"

     
    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

     
     
     
    static func noteLine(at date: Date, text: String) -> String {
        clock.string(from: date) + "  " + text
    }

     
     
    static func line(at date: Date, footprintBytes: Int64, phase: String? = nil) -> String {
        let mebibytes = Double(footprintBytes) / 1_048_576
        var line = String(
            format: "%@  mem fp=%.1fMiB", clock.string(from: date), mebibytes
        )
        if let phase {
            line += " phase=" + phase
        }
        return line
    }

     
     
     
    static func append(_ line: String, to url: URL, maxBytes: Int) {
        let data = Data((line + "\n").utf8)
        var size = UInt64(0)
        if let handle = try? FileHandle(forWritingTo: url) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
             
             
             
            size = (try? handle.offset()) ?? UInt64(maxBytes) + 1
            try? handle.close()
        } else {
            try? data.write(to: url)
            size = UInt64(data.count)
        }
        guard size > UInt64(maxBytes) else { return }
        dropOldestHalfIfNeeded(at: url, maxBytes: maxBytes)
    }

     
     
     
    @discardableResult
    static func mirror(from source: URL, to destination: URL) -> Bool {
        guard let data = try? Data(contentsOf: source) else { return false }
        return (try? data.write(to: destination, options: .atomic)) != nil
    }

    private static func dropOldestHalfIfNeeded(at url: URL, maxBytes: Int) {
        guard let full = try? Data(contentsOf: url), full.count > maxBytes else {
            return
        }
        var keep = full.suffix(maxBytes / 2)
         
        if let newline = keep.firstIndex(of: 0x0A) {
            keep = keep[keep.index(after: newline)...]
        }
        try? keep.write(to: url, options: .atomic)
    }
}


struct MemoryLogFileIdentity: Equatable {
    let device: UInt64
    let inode: UInt64
}

protocol MemoryLogFileWitness: AnyObject {
    var identity: MemoryLogFileIdentity { get }
}

 
 
protocol MemoryLogFileIO: AnyObject {
    func open(_ url: URL, createIfMissing: Bool) throws -> any MemoryLogFileWitness
    func identity(at url: URL) throws -> MemoryLogFileIdentity?
    func size(of file: any MemoryLogFileWitness) throws -> UInt64
    func read(_ file: any MemoryLogFileWitness, at offset: UInt64, count: Int) throws -> Data
    func append(_ bytes: Data, to file: any MemoryLogFileWitness, at offset: UInt64) throws
    func truncate(_ file: any MemoryLogFileWitness, to offset: UInt64) throws
    func temporary(beside url: URL) throws -> (URL, any MemoryLogFileWitness)
    func replace(_ temporary: URL, file: any MemoryLogFileWitness, destination: URL,
                 expected: MemoryLogFileIdentity) throws
    func removeTemporary(_ url: URL, expected: MemoryLogFileIdentity) throws
}

final class MemoryLogSystemIO: MemoryLogFileIO {
    private final class Witness: MemoryLogFileWitness {
        let file: FileHandle
        let identity: MemoryLogFileIdentity
        init(_ handle: FileHandle) throws {
            file = handle
            var value = stat()
            guard fstat(handle.fileDescriptor, &value) == 0 else { throw Self.error() }
            identity = MemoryLogFileIdentity(device: UInt64(UInt32(bitPattern: value.st_dev)), inode: value.st_ino)
        }
        static func error() -> NSError { NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
    }
    private func error(_ code: Int32 = errno) -> NSError { NSError(domain: NSPOSIXErrorDomain, code: Int(code)) }
    private func witness(_ file: any MemoryLogFileWitness) throws -> Witness {
        guard let file = file as? Witness else { throw error(EINVAL) }
        return file
    }
     
     
     
    private let temporaryLock = NSLock()
    private var unfinishedTemporary: (url: URL, handle: FileHandle)?

    private func openHandle(_ url: URL, flags: Int32) throws -> FileHandle {
        let fd = url.path.withCString { Darwin.open($0, flags | O_CLOEXEC | O_NOFOLLOW, mode_t(0o600)) }
        guard fd >= 0 else { throw error() }
        return FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    }
    private func openDescriptor(_ url: URL, flags: Int32) throws -> any MemoryLogFileWitness {
        try Witness(openHandle(url, flags: flags))
    }
    func open(_ url: URL, createIfMissing: Bool) throws -> any MemoryLogFileWitness {
        do { return try openDescriptor(url, flags: O_RDWR) }
        catch let failure as NSError where createIfMissing && failure.domain == NSPOSIXErrorDomain && failure.code == Int(ENOENT) {
            return try openDescriptor(url, flags: O_RDWR | O_CREAT | O_EXCL)
        }
    }
    func identity(at url: URL) throws -> MemoryLogFileIdentity? {
        var value = stat()
        let result = url.path.withCString { lstat($0, &value) }
        if result != 0 {
            if errno == ENOENT { return nil }
            throw error()
        }
        return MemoryLogFileIdentity(device: UInt64(UInt32(bitPattern: value.st_dev)), inode: value.st_ino)
    }
    func size(of file: any MemoryLogFileWitness) throws -> UInt64 {
        var value = stat()
        guard fstat(try witness(file).file.fileDescriptor, &value) == 0, value.st_size >= 0 else { throw error() }
        return UInt64(value.st_size)
    }
    func read(_ file: any MemoryLogFileWitness, at offset: UInt64, count: Int) throws -> Data {
        let handle = try witness(file).file
        try handle.seek(toOffset: offset)
        return try handle.read(upToCount: count) ?? Data()
    }
    func append(_ bytes: Data, to file: any MemoryLogFileWitness, at offset: UInt64) throws {
        guard try size(of: file) == offset else { throw error(ESTALE) }
        let descriptor = dup(try witness(file).file.fileDescriptor)
        guard descriptor >= 0 else { throw error() }
        var failure: (any Error)?
        do {
            guard offset <= UInt64(Int64.max), lseek(descriptor, off_t(offset), SEEK_SET) == off_t(offset) else {
                throw error(EINVAL)
            }
            try bytes.withUnsafeBytes { buffer in
                var written = 0
                while written < buffer.count {
                    let count = Darwin.write(descriptor, buffer.baseAddress!.advanced(by: written), buffer.count - written)
                    guard count > 0 else { throw error(count == 0 ? EIO : errno) }
                    written += count
                }
            }
        } catch { failure = error }
         
         
         
        let closeResult = Darwin.close(descriptor)
        let closeFailure = closeResult == 0 ? nil : error()
        if let failure { throw failure }
        if let closeFailure { throw closeFailure }
    }
    func truncate(_ file: any MemoryLogFileWitness, to offset: UInt64) throws {
        try witness(file).file.truncate(atOffset: offset)
    }
    private func recoverUnfinishedTemporary() throws {
        guard let held = unfinishedTemporary else { return }
         
         
        let file = try Witness(held.handle)
        try removeTemporary(held.url, expected: file.identity)
        unfinishedTemporary = nil
    }
    func temporary(beside url: URL) throws -> (URL, any MemoryLogFileWitness) {
        temporaryLock.lock(); defer { temporaryLock.unlock() }
        try recoverUnfinishedTemporary()
        let path = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).partial")
        let handle = try openHandle(path, flags: O_RDWR | O_CREAT | O_EXCL)
        unfinishedTemporary = (path, handle)
        do {
            let file = try Witness(handle)
            unfinishedTemporary = nil
            return (path, file)
        } catch {
             
             
            try? recoverUnfinishedTemporary()
            throw error
        }
    }
    func replace(_ temporary: URL, file: any MemoryLogFileWitness, destination: URL,
                 expected: MemoryLogFileIdentity) throws {
        guard try identity(at: temporary) == file.identity, try identity(at: destination) == expected else { throw error(ESTALE) }
        let result = temporary.path.withCString { source in destination.path.withCString { Darwin.rename(source, $0) } }
        guard result == 0 else { throw error() }
    }
    func removeTemporary(_ url: URL, expected: MemoryLogFileIdentity) throws {
        guard let current = try identity(at: url) else { return }
        guard current == expected else { throw error(ESTALE) }
        guard url.path.withCString({ unlink($0) }) == 0 else { throw error() }
    }
}

extension MemorySampleLog {
    enum UnitOutcome: Equatable { case committed, retryableClean, uncertain }
    enum UnitIntent { case append, reconcile }
    struct UnitRequest {
        let owner: UUID
        let unitID: String
        let bytes: Data
        let intent: UnitIntent
        let isBoundary: Bool
        let maxFileBytes: Int
        let maxRecoveryBytes: Int
    }

     
     
    final class UnitWriter: @unchecked Sendable {
        private struct FileState {
            var file: any MemoryLogFileWitness
            var size: UInt64
            var ends: [UInt64]
        }
        private struct Replacement {
            let url: URL
            let file: any MemoryLogFileWitness
            let size: UInt64
            let ends: [UInt64]
        }
        private enum Stage {
            case append(UInt64)
            case cleanup(Replacement)
            case replace(Replacement)
        }
        private struct Pending {
            let request: UnitRequest
            var stage: Stage
        }
        private struct Budget {
            var remaining: Int
            mutating func take(_ bytes: Int) throws {
                guard bytes >= 0, bytes <= remaining else { throw Failure.budget }
                remaining -= bytes
            }
        }
        private enum Failure: Error { case budget, identity, size, inactive }

        private let url: URL
        private let io: any MemoryLogFileIO
        private let maxKnownUnits: Int
        private let controlLock = NSLock()
        private let ioLock = NSLock()
        private var activeOwner: UUID?
         
        private var file: FileState?
        private var boundaryOwner: UUID?
        private var pending: Pending?
        private var lastCommitted: UnitRequest?

        init(url: URL, io: any MemoryLogFileIO = MemoryLogSystemIO(), maxKnownUnits: Int = 1024) {
            precondition(maxKnownUnits >= 2 && maxKnownUnits <= 4096)
            self.url = url
            self.io = io
            self.maxKnownUnits = maxKnownUnits
        }
        func activate(_ owner: UUID) {
            controlLock.lock(); activeOwner = owner; controlLock.unlock()
        }
        func revoke(_ owner: UUID) {
            controlLock.lock()
            if activeOwner == owner { activeOwner = nil }
            controlLock.unlock()
        }
        private func active(_ owner: UUID) -> Bool {
            controlLock.lock(); defer { controlLock.unlock() }
            return activeOwner == owner
        }
        private func admit(_ owner: UUID) throws {
            guard active(owner) else { throw Failure.inactive }
        }
        private func matches(_ state: FileState) throws -> Bool {
            try io.identity(at: url) == state.file.identity
        }
        private func unchanged(_ state: FileState) throws -> Bool {
            try matches(state) && io.size(of: state.file) == state.size
        }
        private func sameUnit(_ lhs: UnitRequest, _ rhs: UnitRequest) -> Bool {
            lhs.owner == rhs.owner && lhs.unitID == rhs.unitID && lhs.bytes == rhs.bytes &&
                lhs.isBoundary == rhs.isBoundary && lhs.maxFileBytes == rhs.maxFileBytes
        }

        func submit(_ request: UnitRequest) -> UnitOutcome {
            ioLock.lock(); defer { ioLock.unlock() }
            guard active(request.owner), !request.bytes.isEmpty, !request.unitID.isEmpty,
                  request.unitID.utf8.count <= 256, request.maxFileBytes > 0,
                  request.bytes.count <= request.maxFileBytes, request.maxRecoveryBytes >= 0 else {
                 
                 
                return .uncertain
            }
            var budget = Budget(remaining: request.maxRecoveryBytes)
            do {
                 
                 
                if let old = pending, old.request.owner != request.owner {
                    guard request.isBoundary else { return .retryableClean }
                    if let state = file, try matches(state) {
                        return try recover(authorizedOwner: request.owner, budget: &budget) == .uncertain ? .uncertain : .retryableClean
                    }
                    try discardTemporary(from: old, authorizedOwner: request.owner)
                    pending = nil; file = nil; boundaryOwner = nil; lastCommitted = nil
                    return .retryableClean
                }
                if let current = pending {
                     
                     
                     
                     
                    if current.request.unitID != request.unitID { return .retryableClean }
                    guard sameUnit(current.request, request), request.intent == .reconcile else { return .uncertain }
                    return try recover(authorizedOwner: request.owner, budget: &budget)
                }
                if let last = lastCommitted, last.owner == request.owner, last.unitID == request.unitID {
                    guard sameUnit(last, request), let state = file, try unchanged(state),
                          state.size <= UInt64(request.maxFileBytes) else { return .uncertain }
                    return .committed
                }
                guard request.intent == .append else { return .uncertain }
                guard request.isBoundary || boundaryOwner == request.owner else { return .retryableClean }

                if let state = file, !(try unchanged(state)) {
                    guard request.isBoundary, boundaryOwner != request.owner else { return .uncertain }
                    file = nil; lastCommitted = nil
                }
                if file == nil {
                    guard request.isBoundary else { return .retryableClean }
                    try admit(request.owner)
                    let witness = try io.open(url, createIfMissing: true)
                    guard try io.identity(at: url) == witness.identity else { return .uncertain }
                    let size = try io.size(of: witness)
                    file = FileState(file: witness, size: size, ends: size == 0 ? [] : [size])
                }
                guard let state = file, try unchanged(state) else { return .uncertain }
                let cap = UInt64(request.maxFileBytes)
                if state.size > cap - UInt64(request.bytes.count) || state.ends.count >= maxKnownUnits {
                    guard try retainBeforeAppend(request, budget: &budget) else { return .uncertain }
                }
                try admit(request.owner)
                guard let current = file, try unchanged(current) else { return .uncertain }
                pending = Pending(request: request, stage: .append(current.size))
                try io.append(request.bytes, to: current.file, at: current.size)
                 
                 
                let end = current.size + UInt64(request.bytes.count)
                guard try matches(current), try io.size(of: current.file) == end else { return .uncertain }
                confirm(request, end: end)
                return .committed
            } catch {
                return pending == nil ? .retryableClean : .uncertain
            }
        }

        private func confirm(_ request: UnitRequest, end: UInt64) {
            file?.size = end
            file?.ends.append(end)
            if request.isBoundary { boundaryOwner = request.owner }
            lastCommitted = request
            pending = nil
        }

        private func discardTemporary(from transaction: Pending, authorizedOwner: UUID) throws {
            switch transaction.stage {
            case .append: return
            case let .cleanup(replacement), let .replace(replacement):
                 
                guard let identity = try io.identity(at: replacement.url) else { return }
                guard identity == replacement.file.identity else { throw Failure.identity }
                try admit(authorizedOwner)
                try io.removeTemporary(replacement.url, expected: replacement.file.identity)
            }
        }

        private func recover(authorizedOwner: UUID, budget: inout Budget) throws -> UnitOutcome {
            guard let transaction = pending, let state = file else { return .uncertain }
            switch transaction.stage {
            case let .append(start):
                guard try matches(state) else { return .uncertain }
                let end = start + UInt64(transaction.request.bytes.count)
                let actual = try io.size(of: state.file)
                guard actual >= start, actual <= end else { return .uncertain }
                let length = Int(actual - start)
                if length > 0 {
                    try budget.take(length)
                    let bytes = try io.read(state.file, at: start, count: length)
                    guard bytes.count == length, bytes == transaction.request.bytes.prefix(length),
                          try matches(state), try io.size(of: state.file) == actual else { return .uncertain }
                }
                if actual == end {
                    confirm(transaction.request, end: end)
                    return .committed
                }
                if actual != start {
                    try budget.take(length)
                    try admit(authorizedOwner)
                    guard try matches(state), try io.size(of: state.file) == actual else { return .uncertain }
                    try io.truncate(state.file, to: start)
                    guard try matches(state), try io.size(of: state.file) == start else { return .uncertain }
                }
                pending = nil
                return .retryableClean
            case let .cleanup(replacement):
                guard try unchanged(state) else { return .uncertain }
                try admit(authorizedOwner)
                try io.removeTemporary(replacement.url, expected: replacement.file.identity)
                pending = nil
                return .retryableClean
            case let .replace(replacement):
                let current = try io.identity(at: url)
                if current == replacement.file.identity {
                    guard try io.size(of: replacement.file) == replacement.size else { return .uncertain }
                    file = FileState(file: replacement.file, size: replacement.size, ends: replacement.ends)
                    pending = nil
                    return .retryableClean
                }
                guard current == state.file.identity, try unchanged(state) else { return .uncertain }
                try admit(authorizedOwner)
                try io.removeTemporary(replacement.url, expected: replacement.file.identity)
                pending = nil
                return .retryableClean
            }
        }

        private func retainBeforeAppend(_ request: UnitRequest, budget: inout Budget) throws -> Bool {
            guard let state = file, try unchanged(state) else { return false }
            let keepLimit = min(UInt64(request.maxFileBytes / 2),
                                UInt64(request.maxFileBytes - request.bytes.count), UInt64(budget.remaining / 2))
            var start = state.size
            var first = state.ends.count
            let keepUnitLimit = maxKnownUnits / 2
            for index in state.ends.indices.reversed() {
                let candidate = index == 0 ? 0 : state.ends[index - 1]
                if state.size - candidate > keepLimit || state.ends.count - index > keepUnitLimit { break }
                start = candidate; first = index
            }
            let kept = Int(state.size - start)
            let bytes: Data
            if kept > 0 {
                try budget.take(kept)
                bytes = try io.read(state.file, at: start, count: kept)
                guard bytes.count == kept, try unchanged(state) else { return false }
            } else { bytes = Data() }
            try admit(request.owner)
            let (path, witness) = try io.temporary(beside: url)
            let replacement = Replacement(url: path, file: witness, size: UInt64(kept),
                ends: state.ends.dropFirst(first).map { $0 - start })
            pending = Pending(request: request, stage: .cleanup(replacement))
            if !bytes.isEmpty {
                try budget.take(bytes.count)
                try admit(request.owner)
                try io.append(bytes, to: witness, at: 0)
            }
            guard try io.identity(at: path) == witness.identity,
                  try io.size(of: witness) == UInt64(kept), try unchanged(state) else { return false }
            pending?.stage = .replace(replacement)
            try admit(request.owner)
            try io.replace(path, file: witness, destination: url, expected: state.file.identity)
            guard try io.identity(at: url) == witness.identity, try io.size(of: witness) == UInt64(kept) else { return false }
            file = FileState(file: witness, size: UInt64(kept), ends: replacement.ends)
            pending = nil
            return true
        }
    }
}
