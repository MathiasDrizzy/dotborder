import CoreGraphics
import Foundation

/// What to do with the border window.
public enum BorderCommand: Equatable, Sendable {
    case none
    /// Hide the border. `grace`: the window is gone from where it was but its replacement may be about to be reported (a
    /// workspace switch parks the old window first), so the hide waits a moment. Without it there is nothing to wait for.
    case hide(grace: Bool)
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
            // A window that is still listed but parked may be about to be replaced; one that is gone from the list is not.
            return visible ? .hide(grace: newWindow != nil && newFrame != nil) : .none
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
    /// The focus went to a workspace with no window.
    case noFocus
    /// Something that may have moved or resized the focused window: read it again.
    case refresh

    public init?(line: String) {
        guard let data = line.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let name = object["_event"] as? String else { return nil }
        switch name {
        case "focus-changed":
            guard let id = object["windowId"] as? Int, id > 0 else { self = .noFocus; return }
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

    /// While a border is shown its window is read again at this interval (seconds). Why a poll at all: an app can close or
    /// hide its window (Cmd+W in an Electron app) with no AeroSpace event and no notification that needs no permission, and
    /// the border would stay on screen until something else happened. It runs only while a border is shown; each tick costs a
    /// wake-up more than the read (about 0.7 ms of CPU, measured), so the interval is what sets the idle cost.
    public static let watchInterval: TimeInterval = 0.25
}
