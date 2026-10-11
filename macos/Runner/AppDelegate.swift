import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // In place of NSApplicationDelegate's own main(), so the check runs before the window, the Flutter engine
  // or the game's save is touched.
  static func main() {
    SingleInstance.quitIfAnotherCopyRuns()
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

/// One copy of the game at a time (decisions-log 159, dev-workflow.md "One copy of the game"): two copies would
/// load and write the same save. `flutter run` starts the app itself and then runs `open` on the bundle to bring
/// it to the front; when LaunchServices doesn't know that copy yet, `open` launches a second one. The copy that
/// starts later quits.
enum SingleInstance {
  static func quitIfAnotherCopyRuns() {
    // An XCTest host (RunnerTests) may run next to the game.
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return }
    guard let bundleID = Bundle.main.bundleIdentifier, !takeLock(bundleID) else { return }
    let other = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
      .first { $0.processIdentifier != getpid() && !$0.isTerminated }
    let pid = other.map { " (pid \($0.processIdentifier))" } ?? ""
    NSLog("%@", "Path of Hero already runs\(pid): this copy (pid \(getpid())) quits.")
    if let other = other {
      // Best effort: since macOS 14 the system may decline a request from an app that isn't active.
      if #available(macOS 14, *) {
        other.activate()
      } else {
        other.activate(options: .activateIgnoringOtherApps)
      }
    }
    exit(0)
  }

  /// Takes `<Application Support>/<bundle id>/instance.lock` (in the sandbox container, which every copy with
  /// this bundle id shares). False only when another process holds it; any other failure lets the game start.
  /// The lock's descriptor is never closed: the kernel drops the lock when the process ends, crash or kill -9
  /// included, so a dead copy never blocks the next start.
  private static func takeLock(_ bundleID: String) -> Bool {
    let files = FileManager.default
    guard let support = try? files.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    else { return true }
    let dir = support.appendingPathComponent(bundleID, isDirectory: true)
    try? files.createDirectory(at: dir, withIntermediateDirectories: true)
    let fd = open(dir.appendingPathComponent("instance.lock").path, O_RDWR | O_CREAT | O_CLOEXEC, 0o644)
    guard fd >= 0 else { return true }
    if flock(fd, LOCK_EX | LOCK_NB) == 0 { return true }
    let held = errno == EWOULDBLOCK
    close(fd)
    return !held
  }
}
