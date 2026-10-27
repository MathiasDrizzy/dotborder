import CoreGraphics
import Foundation

/// What to do with the border window.
public enum BorderCommand: Equatable, Sendable {
    case none
    case hide
    /// Put the border on the frame and show it, fading in when it was not visible.
    case show(CGRect, fade: Bool)
    /// The border is visible already: follow the window with no animation.
    case move(CGRect)
}

/// Decides, from where the focused window is, what the border does. Pure: the shell reads the window and applies the
/// command. A border that was visible follows the window at once; one that was not (a workspace came in) fades in, so a
/// switch reads as an animation and not as a flicker.
public struct BorderModel: Sendable {
    public private(set) var visible = false
    private var frame: CGRect = .zero
    private var window: UInt32?

    public init() {}

    public mutating func update(window newWindow: UInt32?, frame newFrame: CGRect?, screens: [CGRect]) -> BorderCommand {
        guard newWindow != nil, let newFrame, Geometry.isShown(newFrame, on: screens) else {
            defer { visible = false; window = nil }
            return visible ? .hide : .none
        }
        defer { visible = true; frame = newFrame; window = newWindow }
        if !visible { return .show(newFrame, fade: true) }
        // Another window with the very same frame is a change too: the border goes above that one.
        return newFrame == frame && newWindow == window ? .none : .move(newFrame)
    }
}

/// An event of `aerospace subscribe` that matters to the border.
public enum AeroEvent: Equatable, Sendable {
    /// The focused window changed (its CoreGraphics window id).
    case focus(window: UInt32)
    /// Something that may have moved or resized the focused window: read it again.
    case refresh

    public init?(line: String) {
        guard let data = line.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let name = object["_event"] as? String else { return nil }
        switch name {
        case "focus-changed":
            guard let id = object["windowId"] as? Int, id > 0 else { self = .refresh; return }
            self = .focus(window: UInt32(id))
        case "focused-workspace-changed", "binding-triggered", "window-detected", "focused-monitor-changed":
            self = .refresh
        default:
            return nil
        }
    }
}

public enum Burst {
    /// A window takes a moment to reach its place after the event that moved it: it is read again after these delays
    /// (seconds), then left alone. Nothing runs while nothing happens.
    public static let delays: [TimeInterval] = [0, 0.008, 0.02, 0.045, 0.09, 0.16, 0.3]
}
