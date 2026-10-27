// The checks of DotborderCore: `swift run dotborder-tests`. Exit status is the number of failed checks.
import CoreGraphics
import DotborderCore
import Foundation

nonisolated(unsafe) var failures = 0

func check(_ name: String, _ condition: Bool, _ detail: @autoclosure () -> String = "") {
    if condition {
        print("PASS  \(name)")
    } else {
        failures += 1
        print("FAIL  \(name)\(detail().isEmpty ? "" : " (\(detail()))")")
    }
}

// MARK: configuration

let defaults = Config(arguments: [])
check("defaults: pink, 2 pt, rounded", defaults.color == 0xccb4_8efa && defaults.width == 2 && defaults.radius > 0)
check("the border appears at once by default: a fade left 270 ms gaps at fast workspace switches", defaults.fadeIn == 0)
let custom = Config(arguments: ["active_color=0xff00ff00", "width=3.5", "radius=9", "fade_in=200"])
check("arguments override the defaults", custom.color == 0xff00_ff00 && custom.width == 3.5 && custom.radius == 9 && custom.fadeIn == 0.2)
let sloppy = Config(arguments: ["width=abc", "nope", "radius=-4", "fade_in=99999", "active_color=zz"])
check("a bad value keeps the default and a wild one is clamped", sloppy.width == defaults.width && sloppy.color == defaults.color
    && sloppy.radius == defaults.radius && sloppy.fadeIn <= 1)

// MARK: geometry

let window = CGRect(x: 100, y: 200, width: 800, height: 600)
check("the border surrounds the window", Geometry.outset(window, by: 2) == CGRect(x: 98, y: 198, width: 804, height: 604))
let primaryHeight: CGFloat = 1000
check("a window's top-left frame becomes AppKit's bottom-left one",
      Geometry.appKit(window, primaryHeight: primaryHeight) == CGRect(x: 100, y: 200, width: 800, height: 600))
check("…and a window high on the screen goes up in AppKit", Geometry.appKit(CGRect(x: 0, y: 0, width: 10, height: 10), primaryHeight: primaryHeight).origin.y == 990)
let screens = [CGRect(x: 0, y: 0, width: 1440, height: 900)]
check("a window on a screen is shown", Geometry.isShown(window, on: screens))
check("a window AeroSpace parked in the corner is not", !Geometry.isShown(CGRect(x: 1430, y: 890, width: 800, height: 600), on: screens))
check("half a window on a screen still is", Geometry.isShown(CGRect(x: 1000, y: 100, width: 880, height: 600), on: screens))
check("a window on no screen is not", !Geometry.isShown(window, on: []))
check("an empty frame is not", !Geometry.isShown(.zero, on: screens))

// MARK: the border follows the window

var model = BorderModel()
check("nothing focused: nothing to do", model.update(window: nil, frame: nil, screens: screens) == .none)
check("the first window fades in", model.update(window: 7, frame: window, screens: screens) == .show(window, fade: true))
check("the same frame again does nothing", model.update(window: 7, frame: window, screens: screens) == .none)
let moved = window.offsetBy(dx: 20, dy: 0)
check("a moved window moves the border at once", model.update(window: 7, frame: moved, screens: screens) == .move(moved))
check("focus to another visible window jumps, no fade", model.update(window: 8, frame: window, screens: screens) == .move(window))
let parked = CGRect(x: 1430, y: 890, width: 800, height: 600)
check("the window leaving the screen hides the border", model.update(window: 8, frame: parked, screens: screens) == .hide)
check("another window with the very same frame is still a change: the border must go above it", { var m = BorderModel(); _ = m.update(window: 1, frame: window, screens: screens); return m.update(window: 2, frame: window, screens: screens) == .move(window) }())
check("hidden stays hidden", model.update(window: 8, frame: parked, screens: screens) == .none)
check("a window arriving after a hide fades in", model.update(window: 9, frame: window, screens: screens) == .show(window, fade: true))
check("the window vanishing hides the border", model.update(window: 9, frame: nil, screens: screens) == .hide)
check("no focused window hides it too", { var m = BorderModel(); _ = m.update(window: 1, frame: window, screens: screens); return m.update(window: nil, frame: nil, screens: screens) == .hide }())

// MARK: events from AeroSpace

check("focus-changed carries the window", AeroEvent(line: #"{"_event":"focus-changed","windowId":4538,"workspace":"1"}"#) == .focus(window: 4538))
check("a workspace change asks for a re-read", AeroEvent(line: #"{"_event":"focused-workspace-changed","prevWorkspace":"1","workspace":"2"}"#) == .refresh)
check("a key binding may have resized the window", AeroEvent(line: #"{"_event":"binding-triggered","mode":"main","binding":"alt-shift-minus"}"#) == .refresh)
check("a new window asks for a re-read", AeroEvent(line: #"{"_event":"window-detected","windowId":9}"#) == .refresh)
check("a mode change is of no interest", AeroEvent(line: #"{"_event":"mode-changed","mode":"main"}"#) == nil)
check("garbage is ignored", AeroEvent(line: "not json") == nil && AeroEvent(line: "") == nil)

// MARK: the follow-up reads

let burst = Burst.delays
check("the window's arrival is watched for a short, bounded time", burst.first == 0 && burst.count <= 8 && (burst.last ?? 0) <= 0.4 && burst == burst.sorted())

print(failures == 0 ? "\nall checks passed" : "\n\(failures) FAILED")
exit(Int32(failures))
