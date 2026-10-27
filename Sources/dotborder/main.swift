// dotborder: a focus border for AeroSpace. Arguments are `key=value` pairs (active_color, width, radius, fade_in).
import AppKit
import DotborderCore

/// One copy at a time: the kernel drops the lock with the process, so a crash never leaves a stale one.
func acquireLock() -> Bool {
    let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cache/dotborder")
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let descriptor = open(directory.appendingPathComponent("lock").path, O_CREAT | O_RDWR, 0o600)
    return descriptor >= 0 && flock(descriptor, LOCK_EX | LOCK_NB) == 0
}

guard acquireLock() else { exit(0) }
let application = NSApplication.shared
application.setActivationPolicy(.accessory)
let controller = Controller(config: Config(arguments: Array(CommandLine.arguments.dropFirst())))
controller.start()
signal(SIGTERM) { _ in exit(0) }
application.run()
