import AppKit
import DotborderCore

/// The border: one click-through window with a rounded outline centered on the focused window's edge (half of it over the
/// window, half outside, as JankyBorders draws it), placed just above that window. A frame change is a
/// `setFrame` and nothing else; the layer draws the outline once.
final class BorderWindow {
    private let window: NSWindow
    private let config: Config
    private var generation = 0
    private(set) var orderedAbove: UInt32?

    init(config: Config) {
        self.config = config
        window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.level = .normal
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        let view = NSView(frame: .zero)
        view.wantsLayer = true
        let argb = config.color
        let color = NSColor(
            srgbRed: CGFloat((argb >> 16) & 0xff) / 255, green: CGFloat((argb >> 8) & 0xff) / 255,
            blue: CGFloat(argb & 0xff) / 255, alpha: CGFloat((argb >> 24) & 0xff) / 255)
        view.layer?.borderColor = color.cgColor
        view.layer?.borderWidth = config.width
        view.layer?.cornerRadius = config.radius + config.width / 2
        window.contentView = view
    }

    /// Shows the border around `frame` (CoreGraphics coordinates), above the window with that id.
    func show(_ frame: CGRect, above windowID: UInt32, fade: Bool) {
        generation += 1
        place(frame)
        window.alphaValue = fade && config.fadeIn > 0 ? 0 : 1
        order(above: windowID)
        guard fade, config.fadeIn > 0 else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = config.fadeIn
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }

    func move(_ frame: CGRect, above windowID: UInt32) {
        place(frame)
        if orderedAbove != windowID { order(above: windowID) }
    }

    func hide() {
        generation += 1
        // Cancels a fade that is still running: the border must not come back after it was hidden.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            window.animator().alphaValue = 0
        }
        window.orderOut(nil)
        orderedAbove = nil
    }

    /// Puts the border above that window again. The first order, sent as the window arrives, can land before the window is
    /// composed and then holds nothing: the burst of reads repeats it until the window has settled.
    func reassert(above windowID: UInt32) { order(above: windowID) }

    private func place(_ frame: CGRect) {
        let primary = NSScreen.screens.first?.frame.height ?? 0
        let outer = Geometry.appKit(Geometry.outset(frame, by: config.width / 2), primaryHeight: primary)
        window.setFrame(outer, display: false)
    }

    private func order(above windowID: UInt32) {
        window.order(.above, relativeTo: Int(windowID))
        orderedAbove = windowID
    }
}
