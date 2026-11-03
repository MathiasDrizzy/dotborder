/// Spotting the system overlays the border must stay out of.
public enum Overlay {
    /// Whether Mission Control is on screen, from the owner and layer of every on-screen window. While it is up the system
    /// shrinks the windows into thumbnails and the WindowManager owns two windows at layers 14 (its "Spaces Bar") and 19 (its
    /// "ExposeShieldWindow"); its everyday windows sit at very negative layers. Window names are not used: macOS withholds
    /// them without the Screen Recording permission, which the border does not have. It sends no notification for this one
    /// either that needs no permission.
    public static func isUp(windows: [(owner: String, layer: Int)]) -> Bool {
        windows.contains { $0.owner == "WindowManager" && ($0.layer == 14 || $0.layer == 19) }
    }
}
