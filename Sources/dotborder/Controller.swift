import AppKit
import DotborderCore

/// Ties the events to the border: an event starts a short burst of reads of the focused window's frame (it takes a moment
/// to reach its place); each read goes through the model, which says what the border does.
final class Controller {
    private let border: BorderWindow
    private var model = BorderModel()
    private var focused: UInt32?
    private var burst: [DispatchWorkItem] = []
    private lazy var feed = AeroSpaceFeed(
        onEvent: { [weak self] event in self?.handle(event) },
        onLost: { [weak self] in self?.focused = nil; self?.refresh() })

    init(config: Config) { border = BorderWindow(config: config) }

    func start() {
        feed.start()
        // Dragging a window by hand is no AeroSpace event: follow the pointer's drags (these monitors need no permission).
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] _ in self?.refresh() }
        // A click, or an app coming to the front, can raise the focused window above the border (Ghostty does): order the
        // border above it again once the raise has landed.
        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in self?.scheduleBurst() }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in self?.scheduleBurst() }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.scheduleBurst() }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in self?.scheduleBurst() }
    }

    func stop() { feed.stop() }

    private func handle(_ event: AeroEvent) {
        if case .focus(let window) = event { focused = window }
        scheduleBurst()
    }

    private func scheduleBurst() {
        burst.forEach { $0.cancel() }
        burst = Burst.delays.dropFirst().map { delay in
            let item = DispatchWorkItem { [weak self] in self?.refresh(reassert: true) }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
            return item
        }
        refresh(reassert: true)
    }

    /// DOTBORDER_DEBUG=1 prints every decision with its time and the frame read, to see what the border did and when.
    private static let debug = ProcessInfo.processInfo.environment["DOTBORDER_DEBUG"] != nil

    private func refresh(reassert: Bool = false) {
        let frame = focused.flatMap(Controller.frame(of:))
        let command = model.update(window: focused, frame: frame, screens: Controller.screens())
        if Controller.debug, command != .none {
            FileHandle.standardError.write(Data("\(String(format: "%.3f", Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 100))) window=\(focused.map(String.init) ?? "-") frame=\(frame.map { "\($0)" } ?? "nil") -> \(command)\n".utf8))
        }
        switch command {
        case .none: break
        case .hide: border.hide()
        case .show(let frame, let fade): if let focused { border.show(frame, above: focused, fade: fade) }
        case .move(let frame): if let focused { border.move(frame, above: focused) }
        }
        if reassert, model.visible, let focused { border.reassert(above: focused) }
    }

    /// The window's frame on screen, CoreGraphics coordinates; asking for one window by id is cheap.
    private static func frame(of window: UInt32) -> CGRect? {
        guard let list = CGWindowListCopyWindowInfo([.optionIncludingWindow], CGWindowID(window)) as? [[String: Any]],
              let info = list.first, let bounds = info[kCGWindowBounds as String] as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: bounds)
    }

    private static func screens() -> [CGRect] {
        var count: UInt32 = 0
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        guard CGGetActiveDisplayList(16, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).map { CGDisplayBounds($0) }
    }
}
