import DotborderCore
import Foundation

/// Follows `aerospace subscribe`: AeroSpace pushes an event the instant the focus or the workspace changes, so nothing is
/// polled. If AeroSpace goes away (or restarts) the feed starts again, waiting longer each time it fails at once.
final class AeroSpaceFeed {
    private let onEvent: (AeroEvent) -> Void
    private let onLost: () -> Void
    private var process: Process?
    private var failures = 0

    init(onEvent: @escaping (AeroEvent) -> Void, onLost: @escaping () -> Void) {
        self.onEvent = onEvent
        self.onLost = onLost
    }

    func start() {
        guard let binary = AeroSpaceFeed.binary() else { return retry(after: 10) }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: binary)
        task.arguments = ["subscribe", "focus-changed", "focused-workspace-changed", "focused-monitor-changed", "window-detected", "binding-triggered"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        var pending = Data()
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            pending.append(chunk)
            while let newline = pending.firstIndex(of: 0x0a) {
                let line = String(decoding: pending[..<newline], as: UTF8.self)
                pending.removeSubrange(...newline)
                if let event = AeroEvent(line: line) {
                    DispatchQueue.main.async { self?.onEvent(event) }
                }
            }
        }
        let started = Date()
        task.terminationHandler = { [weak self] _ in
            pipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                guard let self else { return }
                self.onLost()
                self.failures = Date().timeIntervalSince(started) > 10 ? 0 : self.failures + 1
                self.retry(after: min(2 * pow(2, Double(self.failures)), 30))
            }
        }
        do {
            try task.run()
            process = task
        } catch {
            retry(after: 10)
        }
    }

    func stop() {
        process?.terminationHandler = nil
        process?.terminate()
    }

    private func retry(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.start() }
    }

    private static func binary() -> String? {
        let fromPath = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { "\($0)/aerospace" }
        return (fromPath + ["/opt/homebrew/bin/aerospace", "/usr/local/bin/aerospace"])
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
