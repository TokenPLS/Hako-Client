import Foundation
import OSLog
import SwiftUI

#if canImport(UIKit)
 
 
 
 
 
 
import QuartzCore
#endif

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public enum HakoFrameCensus {
     
     
     
     
     
     
     
    public static func isObservationGap(
        elapsed: CFTimeInterval,
        window: CFTimeInterval
    ) -> Bool {
        elapsed > window
    }
}

public enum HakoPerf {
    public static let subsystem = "org.example.hako"
    public static let log = Logger(subsystem: subsystem, category: "perf")
    public static let signposter = OSSignposter(
        subsystem: subsystem, category: .pointsOfInterest
    )

     
     
     
     
     
     
    @MainActor
    public static var sink: ((String) -> Void)?

    @MainActor
    public static func emit(_ line: String) {
        sink?(line)
    }

     
     
     
     
     
     
     
     
     
    @MainActor
    public static func span(
        _ name: String,
        milliseconds: Double,
        detail: @autoclosure () -> String = ""
    ) {
        tally(name, milliseconds: milliseconds)
        guard milliseconds >= 8 else { return }
        let line = String(
            format: "span %@ %.1fms %@", name, milliseconds, detail()
        )
        log.notice("\(line, privacy: .public)")
        emit(line)
    }

     
     
     
     
     
     
     
     
    public enum Reason {
        public static let readerTappedApply = "reader tapped Apply"
        public static let editSettled = "edit settled (debounced restage)"
        public static let profileSelected = "select"
        public static let clientRuntimeSetting = "restageForClientRuntimeSetting"
        public static let globalConfiguration = "updateGlobalConfiguration"
        public static let profileSync = "sync"
         
        public static let bridgeOnMain = "bridge.main "
    }

     
     
     
     
     
     
     
    @MainActor
    public static func note(_ line: String) {
        log.notice("\(line, privacy: .public)")
        emit(line)
    }

     
     
     
     
     
     
     
     
    @MainActor
    private static var tallies: [String: (count: Int, milliseconds: Double)] = [:]

    @MainActor
    static func tally(_ name: String, milliseconds: Double) {
        var entry = tallies[name] ?? (0, 0)
        entry.count += 1
        entry.milliseconds += milliseconds
        tallies[name] = entry
    }

     
     
     
     
    @MainActor
    static func discardTallies() {
        tallies.removeAll()
    }

     
    @MainActor
    static func drainTallies() -> String? {
        guard !tallies.isEmpty else { return nil }
        let parts = tallies
            .sorted { $0.value.milliseconds > $1.value.milliseconds }
            .map { name, value in
                String(format: "%@=%d/%.0fms", name, value.count, value.milliseconds)
            }
        tallies.removeAll()
        return parts.joined(separator: " ")
    }

     
     
     
     
     
     
     
     
     
    public static func count(_ name: String) {
        guard Thread.isMainThread else { return }
        MainActor.assumeIsolated { tally(name, milliseconds: 0) }
    }

     
     
     
     
     
     
     
     
     
     
    public static func markFoldAll(collapsing: Bool) {
        mark(collapsing ? "proxies fold-all begins" : "proxies unfold-all begins")
    }

    public static func markGroupFold(wasOpen: Bool) {
        mark(wasOpen ? "proxies group folds" : "proxies group unfolds")
    }

    public static func markDisplayPreferencesChange() {
        mark("proxies display preferences change")
    }

     
     
     
     
     
     
    public static func markProxiesRailTaskFires(stamp: String = "") {
        mark(
            stamp.isEmpty
                ? "proxies rail task fires"
                : "proxies rail task fires rail=\(stamp)"
        )
    }

     
     
     
     
     
    public static func markShellRootChange(to name: String) {
        mark("shell root -> \(name)")
    }

    public static func markProxiesRailConsumesStagedGroup() {
        mark("proxies rail consumes staged group")
    }

    public static func mark(_ line: String) {
        guard Thread.isMainThread else { return }
        MainActor.assumeIsolated {
            log.notice("mark \(line, privacy: .public)")
            emit("mark " + line)
        }
    }

     
     
     
     
     
     
     
     
     
     
    static func frameLine(
        screen: String,
        frames: Int,
        late: Int,
        worst: Double,
        seconds: Double,
        totals: String?
    ) -> String {
        let ran = max(seconds, 0.001)
        var line = String(
            format: "frames %@ drawn=%d late=%d worst=%.1fms fps≈%.0f over=%.2fs",
            screen, frames, late, worst, Double(frames) / ran, ran
        )
         
         
         
        if let totals {
            line += "  [\(totals)]"
        }
        return line
    }

     
     
     
    @MainActor
    public static func armed() {
        emit("frames watch armed")
    }

     
     
    @discardableResult
    public static func measure<T>(
        _ name: StaticString,
        detail: @autoclosure () -> String = "",
        _ body: () throws -> T
    ) rethrows -> T {
        let state = signposter.beginInterval(name, id: signposter.makeSignpostID())
        let began = DispatchTime.now().uptimeNanoseconds
        defer {
            signposter.endInterval(name, state)
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - began) / 1_000_000
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    tally(String(describing: name), milliseconds: elapsed)
                }
            }
             
             
            if elapsed >= 8 {
                let extra = detail()
                let line = String(
                    format: "span %@ %.1fms %@",
                    String(describing: name), elapsed, extra
                )
                log.notice("\(line, privacy: .public)")
                if Thread.isMainThread {
                    MainActor.assumeIsolated { emit(line) }
                }
            }
        }
        return try body()
    }
}

 
 
@MainActor
public protocol HakoDisplayLinkDriving: AnyObject {
    func invalidate()
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
@MainActor
public enum HakoDisplayLinkHooks {
    public static var make: (
        (@escaping (CFTimeInterval, CFTimeInterval) -> Void)
            -> HakoDisplayLinkDriving?
    )?
}

 
@MainActor
public final class HakoFrameWatch {
    public static let shared = HakoFrameWatch()

    private var link: HakoDisplayLinkDriving?
    private var saidLinkState = false
    private var labels: [String] = []
    private var lastTimestamp: CFTimeInterval = 0
    private var windowBegan: CFTimeInterval = 0
    private var frames = 0
    private var late = 0
    private var worst: Double = 0
    private var worstAt: CFTimeInterval = 0

     
     
    private let windowSeconds: CFTimeInterval = 1.5

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private static let isUnderUITest: Bool = {

        return false

    }()

    public func begin(_ label: String) {
        guard !Self.isUnderUITest else { return }
         
         
         
         
         
         
         
        labels.removeAll { $0 == label }
        labels.append(label)
        guard link == nil else { return }
        reset()
        link = Self.makeLink { [weak self] now, target in
            self?.tick(timestamp: now, target: target)
        }
         
         
         
         
         
         
         
        if !saidLinkState {
            saidLinkState = true
            HakoPerf.emit(
                link == nil
                    ? "frames watch has no display link on this platform"
                        + " — no frame census will follow"
                    : "frames watch counting — a quiet window still writes"
                        + " nothing, but silence now means smooth"
            )
        }
    }

    private static func makeLink(
        _ onTick: @escaping (CFTimeInterval, CFTimeInterval) -> Void
    ) -> HakoDisplayLinkDriving? {
        #if canImport(UIKit)
        return HakoQuartzDisplayLink(onTick)
        #else
        return HakoDisplayLinkHooks.make?(onTick)
        #endif
    }

    public func end(_ label: String) {
         
         
         
        guard !Self.isUnderUITest else { return }
        labels.removeAll { $0 == label }
        guard labels.isEmpty else { return }
         
         
        flush(at: lastTimestamp, force: true)
        link?.invalidate()
        link = nil
    }

    private func reset() {
        lastTimestamp = 0
        windowBegan = 0
        frames = 0
        late = 0
        worst = 0
         
         
         
         
         
         
         
        HakoPerf.discardTallies()
    }

    private func tick(timestamp now: CFTimeInterval, target: CFTimeInterval) {
        defer { lastTimestamp = now }
        guard lastTimestamp > 0 else {
            windowBegan = now
            return
        }
         
         
         
         
        let expected = max(target - now, 1.0 / 120.0)
        let elapsed = now - lastTimestamp
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        if HakoFrameCensus.isObservationGap(elapsed: elapsed, window: windowSeconds) {
            let line = String(
                format: "gap %@ %.1fs — not counted as a frame",
                labels.last ?? "?", elapsed
            )
            HakoPerf.log.warning("\(line, privacy: .public)")
            HakoPerf.emit(line)
            reset()
            windowBegan = now
            return
        }
        frames += 1
        if elapsed > expected * 1.75 {
            late += 1
            let milliseconds = elapsed * 1000
            if milliseconds > worst {
                worst = milliseconds
                worstAt = now
            }
            if milliseconds >= 100 {
                let screen = labels.last ?? "?"
                let line = String(format: "hitch %@ %.1fms", screen, milliseconds)
                HakoPerf.log.warning("\(line, privacy: .public)")
                HakoPerf.emit(line)
            }
        }
        if now - windowBegan >= windowSeconds {
            if !flush(at: now, force: false) {
                 
                 
                HakoPerf.discardTallies()
            }
            windowBegan = now
            frames = 0
            late = 0
            worst = 0
        }
    }

    @discardableResult
    private func flush(at now: CFTimeInterval, force: Bool) -> Bool {
        guard frames > 0, late > 0 || force else { return false }
         
         
         
         
         
        let line = HakoPerf.frameLine(
            screen: labels.last ?? "?",
            frames: frames,
            late: late,
            worst: worst,
            seconds: now - windowBegan,
            totals: HakoPerf.drainTallies()
        )
        HakoPerf.log.notice("\(line, privacy: .public)")
        HakoPerf.emit(line)
        return true
    }
}

#if canImport(UIKit)
 
@MainActor
private final class HakoQuartzDisplayLink: HakoDisplayLinkDriving {
    private var link: CADisplayLink?
    private let onTick: (CFTimeInterval, CFTimeInterval) -> Void

    init(_ onTick: @escaping (CFTimeInterval, CFTimeInterval) -> Void) {
        self.onTick = onTick
        let link = CADisplayLink(target: self, selector: #selector(fire(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    @objc private func fire(_ link: CADisplayLink) {
        onTick(link.timestamp, link.targetTimestamp)
    }

    func invalidate() {
        link?.invalidate()
        link = nil
    }
}
#endif

private struct HakoFrameWatchModifier: ViewModifier {
    let label: String

    func body(content: Content) -> some View {
        content
            .onAppear { HakoFrameWatch.shared.begin(label) }
            .onDisappear { HakoFrameWatch.shared.end(label) }
    }
}

public extension View {
     
     
     
     
     
    func hakoFrameWatch(_ label: String) -> some View {
        modifier(HakoFrameWatchModifier(label: label))
    }
}


