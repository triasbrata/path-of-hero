import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // Open at the landscape size the layout is checked at, centred. The title comes from
    // CFBundleDisplayName in Info.plist (FlutterAppDelegate overwrites anything set here).
    self.setContentSize(NSSize(width: 1266, height: 713))
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
