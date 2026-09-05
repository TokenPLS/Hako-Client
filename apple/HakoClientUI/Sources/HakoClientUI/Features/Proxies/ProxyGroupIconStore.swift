import SwiftUI

import ImageIO

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public enum HakoIconDiagnostics {
    nonisolated(unsafe) public static var report: ((String) -> Void)?
}

public actor ProxyGroupIconStore {
    public static let shared = ProxyGroupIconStore()

    private var inFlight: [String: Task<CGImage?, Never>] = [:]
     
     
     
     
     
     
     
    private var memory: [String: CGImage] = [:]
     
     
     
     
     
     
     
    private var refusedUntil: [String: Date] = [:]
    static let refusalInterval: TimeInterval = 60
     
    nonisolated(unsafe) static var now: () -> Date = { Date() }

     
     
     
     
     
    private static let maximumBytes = 512 * 1024

     
     
     
     
     
     
     
    static let maximumPixelSize = 128

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static let maximumResidentBytes = 4 * 1024 * 1024
    private var residentBytes = 0
    private var recency: [String] = []

    private nonisolated static func residentCost(_ image: CGImage) -> Int {
        image.height * image.bytesPerRow
    }

     
     
     
     
     
     
    private func touch(_ address: String) {
        guard let index = recency.firstIndex(of: address) else { return }
        recency.remove(at: index)
        recency.append(address)
    }

    private func remember(_ address: String, image: CGImage) {
        if let existing = memory[address] {
            residentBytes -= Self.residentCost(existing)
            recency.removeAll { $0 == address }
        }
        memory[address] = image
        residentBytes += Self.residentCost(image)
        recency.append(address)
        while residentBytes > Self.maximumResidentBytes, let oldest = recency.first {
            recency.removeFirst()
            if let dropped = memory.removeValue(forKey: oldest) {
                residentBytes -= Self.residentCost(dropped)
            }
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private let maximumConcurrentFetches = 4
    private var activeFetches = 0
     
     
     
     
     
     
     
    public private(set) var peakConcurrentFetchesForTesting = 0
    private var inFlightRequests = 0

    private func requestBegan() {
        inFlightRequests += 1
        peakConcurrentFetchesForTesting = max(
            peakConcurrentFetchesForTesting, inFlightRequests
        )
    }

    private func requestEnded() { inFlightRequests -= 1 }

     
     
     
     
     
     
     
     
     
     
    nonisolated(unsafe) public static var fetchBytes:
        (URLRequest) async -> (Data, URLResponse)? = { request in
            guard let (bytes, response) = try? await URLSession.shared.bytes(for: request),
                  let data = await boundedRead(
                      bytes,
                      declaredLength: response.expectedContentLength,
                      limit: maximumBytes
                  )
            else { return nil }
            return (data, response)
        }
    private var waiting: [CheckedContinuation<Void, Never>] = []

    private func acquireSlot() async {
        if activeFetches < maximumConcurrentFetches {
            activeFetches += 1
            return
        }
         
         
         
         
        await withCheckedContinuation { waiting.append($0) }
    }

    private func releaseSlot() {
        if let next = waiting.first {
            waiting.removeFirst()
            next.resume()       
            return
        }
        activeFetches -= 1
    }

     
     
     
     
     
     
     
    func resetForTesting() {
        memory.removeAll()
        refusedUntil.removeAll()
        recency.removeAll()
        residentBytes = 0
        peakConcurrentFetchesForTesting = 0
        guard let directory,
              let files = try? FileManager.default.contentsOfDirectory(
                  at: directory, includingPropertiesForKeys: nil
              )
        else { return }
        for file in files { try? FileManager.default.removeItem(at: file) }
    }

    private lazy var directory: URL? = {
        guard let base = try? FileManager.default.url(
            for: .cachesDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ) else { return nil }
        let directory = base.appendingPathComponent("ProxyGroupIcons", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        return directory
    }()

    public func image(for address: String) async -> CGImage? {
        if let until = refusedUntil[address] {
            if until > Self.now() { return nil }
            refusedUntil[address] = nil
        }
        if let cached = memory[address] {
            touch(address)
            return cached
        }
        if let onDisk = readFromDisk(address),
           let decoded = Self.decodedImage(from: onDisk) {
            remember(address, image: decoded)
            return decoded
        }
        if let running = inFlight[address] { return await running.value }

         
         
         
         
         
         
         
         
         
         
        let task = Task<CGImage?, Never> {
            guard let url = URL(string: address),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "https" || scheme == "http" else { return nil }
            await self.acquireSlot()
            defer { Task { await self.releaseSlot() } }
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            request.httpShouldHandleCookies = false
            await self.requestBegan()
            let fetched = await Self.fetchBytes(request)
            await self.requestEnded()
            guard let (data, response) = fetched,
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  data.count <= Self.maximumBytes,
                  !data.isEmpty,
                  let decoded = Self.decodedImage(from: data) else { return nil }
            await self.remember(address, image: decoded)
            await self.writeToDisk(address, data: data)
            return decoded
        }
        inFlight[address] = task
        let decoded = await task.value
        inFlight[address] = nil
        if let decoded { return decoded }
         
         
         
        refusedUntil[address] = Self.now().addingTimeInterval(Self.refusalInterval)
         
         
         
         
         
         
         
         
        let host = URL(string: address)?.host ?? "?"
        HakoIconDiagnostics.report?("icon unavailable: \(host)")
        return nil
    }

     
     
     
     
     
     
     
     
     
     
    static func boundedRead<Bytes: AsyncSequence>(
        _ bytes: Bytes, declaredLength: Int64, limit: Int
    ) async -> Data? where Bytes.Element == UInt8 {
        if declaredLength > Int64(limit) { return nil }
        var data = Data()
        data.reserveCapacity(min(limit, 64 * 1024))
        do {
            for try await byte in bytes {
                if data.count >= limit { return nil }
                data.append(byte)
            }
        } catch { return nil }
        return data
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func decodedImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0
        else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
             
             
             
             
             
             
            kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary)
    }

    private func fileURL(_ address: String) -> URL? {
        guard let directory else { return nil }
         
         
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in Data(address.utf8) {
            hash = (hash ^ UInt64(byte)) &* 0x100000001b3
        }
        return directory.appendingPathComponent(String(format: "%016llx", hash))
    }

    private func readFromDisk(_ address: String) -> Data? {
        guard let url = fileURL(address),
              let data = try? Data(contentsOf: url),
              !data.isEmpty else { return nil }
        return data
    }

    private func writeToDisk(_ address: String, data: Data) {
        guard let url = fileURL(address) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

 
 
public struct ProxyGroupIconView<Placeholder: View>: View {
    let address: String?
    let size: CGFloat
    @ViewBuilder let placeholder: () -> Placeholder

    public init(
        address: String?,
        size: CGFloat,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.address = address
        self.size = size
        self.placeholder = placeholder
    }

     
     
     
     
     
    @State private var image: CGImage?
     
     
     
     
     
     
     
    @State private var resolved = false

    public enum Presentation: Equatable, Sendable { case image, placeholder, nothing }

     
    nonisolated static func presentation(hasImage: Bool, resolved: Bool) -> Presentation {
        if hasImage { return .image }
        return resolved ? .nothing : .placeholder
    }

    public var body: some View {
        Group {
            switch Self.presentation(hasImage: image != nil, resolved: resolved) {
            case .image:
                Image(image!, scale: 1, label: Text(verbatim: ""))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .accessibilityHidden(true)
            case .placeholder:
                placeholder()
            case .nothing:
                EmptyView()
            }
        }
        .task(id: address) {
            resolved = false
            guard let address, !address.isEmpty else {
                image = nil
                resolved = true
                return
            }
            image = await ProxyGroupIconStore.shared.image(for: address)
            resolved = true
        }
    }
}
