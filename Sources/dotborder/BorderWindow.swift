import AppKit
import DotborderCore

/// The border: one click-through window with a rounded outline centered on the focused window's edge (half of it over the
/// window, half outside, as JankyBorders draws it), kept above the normal windows (a window level, so there is no
/// order to keep in step with AeroSpace). A frame change is a `setFrame` and nothing else; the layer draws the outline once.
final class BorderWindow {
    private let window: NSWindow
    private let config: Config
    private var generation = 0

    init(config: Config) {
        self.config = config
        window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        // `orderOut` otherwise fades the window out over a quarter of a second: a border left in the air after its window went.
        window.animationBehavior = .none
        // Above every normal window: ordering the border relative to the focused window raced with AeroSpace and WindowServer
        // (fast workspace switches left it below the window for hundreds of milliseconds).
        window.level = .floating
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

    /// Shows the border around `frame` (CoreGraphics coordinates).
    func show(_ frame: CGRect, fade: Bool) {
        generation += 1
        place(frame)
        window.alphaValue = fade && config.fadeIn > 0 ? 0 : 1
        window.orderFrontRegardless()
        guard fade, config.fadeIn > 0 else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = config.fadeIn
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }

    func move(_ frame: CGRect) {
        generation += 1
        place(frame)
    }

    /// Hides the border. With `grace` it waits a moment: a workspace switch parks the old window before AeroSpace reports the
    /// new focus and, under load, that report can lag by hundreds of milliseconds. A `show` or `move` in the meantime
    /// cancels the hide.
    func hide(grace: Bool) {
        generation += 1
        guard grace else { return orderOut() }
        let pending = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + BorderWindow.hideGrace) { [weak self] in
            guard let self, self.generation == pending else { return }
            self.orderOut()
        }
    }

    private func orderOut() {
        // Cancels a fade that is still running: the border must not come back after it was hidden.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            window.animator().alphaValue = 0
        }
        window.orderOut(nil)
    }

    private static let hideGrace: TimeInterval = 0.25

    private func place(_ frame: CGRect) {
        let primary = NSScreen.screens.first?.frame.height ?? 0
        let outer = Geometry.appKit(Geometry.outset(frame, by: config.width / 2), primaryHeight: primary)
        window.setFrame(outer, display: false)
    }
}
