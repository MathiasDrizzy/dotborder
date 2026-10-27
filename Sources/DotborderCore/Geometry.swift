import CoreGraphics

public enum Geometry {
    /// The border surrounds the window: its frame is the window's, grown by the border's width on every side.
    public static func outset(_ frame: CGRect, by width: CGFloat) -> CGRect {
        frame.insetBy(dx: -width, dy: -width)
    }

    /// CoreGraphics (and AeroSpace) put a frame's origin at the top-left of the main display; AppKit puts it at the
    /// bottom-left.
    public static func appKit(_ frame: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
    }

    /// Whether a window is where it can be seen. AeroSpace parks the windows of the workspaces it hides in a corner of the
    /// screen with a few pixels showing: a window needs a third of its area on some screen to count.
    public static func isShown(_ frame: CGRect, on screens: [CGRect]) -> Bool {
        let area = frame.width * frame.height
        guard area > 0 else { return false }
        return screens.contains { screen in
            let visible = screen.intersection(frame)
            return !visible.isNull && visible.width * visible.height >= area / 3
        }
    }
}
