import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let methodChannel = FlutterMethodChannel(name: "pixes/proxy", binaryMessenger: controller.binaryMessenger)
    methodChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        if let proxySettings = CFNetworkCopySystemProxySettings()?.takeUnretainedValue() as NSDictionary?,
           let dict = proxySettings.object(forKey: kCFNetworkProxiesHTTPProxy) as? NSDictionary,
           let host = dict.object(forKey: kCFNetworkProxiesHTTPProxy) as? String,
           let port = dict.object(forKey: kCFNetworkProxiesHTTPPort) as? Int {
            let proxyConfig = "\(host):\(port)"
            result(proxyConfig)
        } else {
            result("no proxy")
        }
    }

    let screenAwakeChannel = FlutterMethodChannel(name: "pixes/screen_awake", binaryMessenger: controller.binaryMessenger)
    screenAwakeChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        guard call.method == "setKeepScreenOn", let enabled = call.arguments as? Bool else {
            result(FlutterMethodNotImplemented)
            return
        }
        UIApplication.shared.isIdleTimerDisabled = enabled
        result(nil)
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
