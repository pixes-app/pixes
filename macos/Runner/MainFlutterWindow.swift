import Cocoa
import FlutterMacOS
import IOKit.ps

class MainFlutterWindow: NSWindow {
  private static let downloadPathBookmarkKey = "pixes.download.path.bookmark"
  private static var scopedDownloadDirectoryURL: URL?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    let proxyChannel = FlutterMethodChannel(
      name: "pixes/proxy",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
      proxyChannel.setMethodCallHandler { (call, result) in
      // 获取代理设置
        if let proxySettings = CFNetworkCopySystemProxySettings()?.takeUnretainedValue() as NSDictionary?,
          let dict = proxySettings.object(forKey: kCFNetworkProxiesHTTPProxy) as? NSDictionary,
          let host = dict.object(forKey: kCFNetworkProxiesHTTPProxy) as? String,
          let port = dict.object(forKey: kCFNetworkProxiesHTTPPort) as? Int {
          let proxyConfig = "\(host):\(port)"
          result(proxyConfig)
        } else {
          result("No proxy")
        }
    }

    let downloadPathChannel = FlutterMethodChannel(
      name: "pixes/macos/download_path",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    downloadPathChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "window_deallocated", message: nil, details: nil))
        return
      }
      switch call.method {
      case "selectDownloadDirectory":
        self.handleSelectDownloadDirectory(call: call, result: result)
      case "restoreDownloadDirectoryAccess":
        self.handleRestoreDownloadDirectoryAccess(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }

  private func handleSelectDownloadDirectory(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let initialPath = args?["initialPath"] as? String

    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = true
    panel.prompt = "Select"
    if let initialPath {
      panel.directoryURL = URL(fileURLWithPath: (initialPath as NSString).expandingTildeInPath)
    }

    if panel.runModal() != .OK {
      result(nil)
      return
    }

    guard let url = panel.url else {
      result(nil)
      return
    }

    do {
      try persistScopedDirectoryAccess(url: url)
      result(url.path)
    } catch {
      result(FlutterError(
        code: "persist_directory_access_failed",
        message: "Failed to persist selected directory access.",
        details: "\(error)"
      ))
    }
  }

  private func handleRestoreDownloadDirectoryAccess(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let expectedPath = args?["path"] as? String
    do {
      let restoredPath = try restoreScopedDirectoryAccess(expectedPath: expectedPath)
      result(restoredPath)
    } catch {
      result(FlutterError(
        code: "restore_directory_access_failed",
        message: "Failed to restore persisted directory access.",
        details: "\(error)"
      ))
    }
  }

  private func persistScopedDirectoryAccess(url: URL) throws {
    if let previousURL = MainFlutterWindow.scopedDownloadDirectoryURL {
      previousURL.stopAccessingSecurityScopedResource()
      MainFlutterWindow.scopedDownloadDirectoryURL = nil
    }

    guard url.startAccessingSecurityScopedResource() else {
      throw NSError(
        domain: "pixes.macos.download_path",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Unable to access selected directory."]
      )
    }

    let bookmark = try url.bookmarkData(
      options: [.withSecurityScope],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
    UserDefaults.standard.set(bookmark, forKey: MainFlutterWindow.downloadPathBookmarkKey)
    MainFlutterWindow.scopedDownloadDirectoryURL = url
  }

  private func restoreScopedDirectoryAccess(expectedPath: String?) throws -> String? {
    guard let bookmark = UserDefaults.standard.data(forKey: MainFlutterWindow.downloadPathBookmarkKey) else {
      return nil
    }

    var stale = false
    var url = try URL(
      resolvingBookmarkData: bookmark,
      options: [.withSecurityScope],
      relativeTo: nil,
      bookmarkDataIsStale: &stale
    )

    if stale {
      let refreshedBookmark = try url.bookmarkData(
        options: [.withSecurityScope],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
      UserDefaults.standard.set(refreshedBookmark, forKey: MainFlutterWindow.downloadPathBookmarkKey)
    }

    if let expectedPath {
      let normalizedExpectedPath = URL(fileURLWithPath: (expectedPath as NSString).expandingTildeInPath)
        .standardizedFileURL.path
      let normalizedRestoredPath = url.standardizedFileURL.path
      if normalizedExpectedPath != normalizedRestoredPath {
        return nil
      }
    }

    if let previousURL = MainFlutterWindow.scopedDownloadDirectoryURL,
       previousURL.standardizedFileURL.path != url.standardizedFileURL.path {
      previousURL.stopAccessingSecurityScopedResource()
      MainFlutterWindow.scopedDownloadDirectoryURL = nil
    }

    guard url.startAccessingSecurityScopedResource() else {
      throw NSError(
        domain: "pixes.macos.download_path",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Unable to restore directory access."]
      )
    }
    MainFlutterWindow.scopedDownloadDirectoryURL = url
    return url.path
  }
}
