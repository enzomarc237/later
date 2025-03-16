import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // Return false to prevent app from exiting when window is closed
    // App will continue running in the background with system tray icon
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  override func application(_ application: NSApplication, open urls: [URL]) {
    // Handle URL scheme calls
    if let url = urls.first {
      let urlString = url.absoluteString
      
      // Get the FlutterViewController
      if let controller = NSApp.windows.first?.contentViewController as? FlutterViewController {
        // Create a method channel
        let channel = FlutterMethodChannel(
          name: "com.later.app/url_scheme",
          binaryMessenger: controller.engine.binaryMessenger)
        
        // Send the URL to Flutter
        channel.invokeMethod("handleUrl", arguments: urlString)
      }
    }
    
    super.application(application, open: urls)
  }
}
