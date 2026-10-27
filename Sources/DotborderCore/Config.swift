import Foundation

/// How the border looks, from `key=value` arguments (the names are those of JankyBorders, so a config moves over as it is).
public struct Config: Sendable, Equatable {
    /// 0xAARRGGBB
    public var color: UInt32 = 0xccb4_8efa
    public var width: Double = 2
    /// Corner radius of the window the border follows, in points (the outline's outer edge is this plus half its width).
    public var radius: Double = 14
    /// Seconds a border takes to appear on a window that just arrived. Off by default: a fade left the window without a
    /// visible border for 270-300 ms at each fast workspace switch (measured at 60 fps).
    public var fadeIn: Double = 0

    public init(arguments: [String]) {
        for argument in arguments {
            guard let equals = argument.firstIndex(of: "=") else { continue }
            let key = String(argument[..<equals])
            let value = String(argument[argument.index(after: equals)...])
            switch key {
            case "active_color":
                let digits = value.hasPrefix("0x") ? String(value.dropFirst(2)) : value
                if let parsed = UInt32(digits, radix: 16) { color = parsed }
            case "width":
                if let parsed = Double(value), parsed > 0 { width = min(parsed, 20) }
            case "radius":
                if let parsed = Double(value), parsed >= 0 { radius = min(parsed, 60) }
            case "fade_in":
                if let parsed = Double(value), parsed >= 0 { fadeIn = min(parsed, 1000) / 1000 }
            default:
                continue
            }
        }
    }
}
