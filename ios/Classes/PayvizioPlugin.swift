import Flutter
import UIKit
import Payvizio

/**
 MethodChannel bridge from Dart to the Payvizio iOS SDK. Resolves the
 top-most view controller at checkout-time so the hosted checkout sheet has a
 presenter regardless of how the host app's navigation stack is built.
 */
public class PayvizioPlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.payvizio.flutter/sdk",
            binaryMessenger: registrar.messenger())
        let instance = PayvizioPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "configure":       handleConfigure(call, result: result)
        case "prefetch":        Payvizio.shared.prefetch(); result(nil)
        case "checkout":        handleCheckout(call, result: result)
        case "launchUpiIntent": handleUpi(call, result: result)
        default:                result(FlutterMethodNotImplemented)
        }
    }

    private func handleConfigure(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let baseUrlString = args["apiBaseUrl"] as? String,
              let baseUrl = URL(string: baseUrlString) else {
            result(FlutterError(code: "PVZ_INVALID", message: "apiBaseUrl is required", details: nil)); return
        }
        let checkoutUrl = (args["checkoutUrl"] as? String).flatMap(URL.init(string:))
        let pollMs = (args["pollIntervalMs"] as? Int) ?? 2500
        let dismissible = (args["dismissible"] as? Bool) ?? true
        Payvizio.shared.configure(PayvizioConfig(
            apiBaseUrl: baseUrl,
            checkoutUrl: checkoutUrl,
            pollInterval: TimeInterval(pollMs) / 1000.0,
            dismissible: dismissible))
        result(nil)
    }

    @MainActor
    private func handleCheckout(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let sessionId = args["sessionId"] as? String, !sessionId.isEmpty else {
            result(FlutterError(code: "PVZ_INVALID", message: "sessionId is required", details: nil)); return
        }
        guard let presenter = topViewController() else {
            result(FlutterError(code: "PVZ_NO_VC", message: "No top view controller", details: nil)); return
        }
        let cb = BridgeCallback(sessionId: sessionId, result: result)
        _ = Payvizio.shared.checkout(presenting: presenter, sessionId: sessionId, callback: cb)
    }

    @MainActor
    private func handleUpi(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let url = args["url"] as? String else {
            result(FlutterError(code: "PVZ_INVALID", message: "url is required", details: nil)); return
        }
        UpiIntent.launch(url) { ok in result(ok) }
    }

    @MainActor
    private func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

/// Boxes the Flutter result so the lifecycle-bound callback can hand back a
/// single map and translate close-without-terminal into a synthetic CANCELLED.
private final class BridgeCallback: PaymentCallback {

    let sessionId: String
    var result: FlutterResult?

    init(sessionId: String, result: @escaping FlutterResult) {
        self.sessionId = sessionId
        self.result = result
    }

    func onSuccess(_ r: PaymentResult) { deliver(r) }
    func onFailure(_ r: PaymentResult) { deliver(r) }
    func onClose() {
        guard let r = result else { return }
        r(["sessionId": sessionId, "status": "CANCELLED"])
        result = nil
    }

    private func deliver(_ r: PaymentResult) {
        guard let cb = result else { return }
        cb([
            "sessionId":        r.sessionId,
            "status":           r.status.rawValue,
            "acquirer":         r.acquirer ?? NSNull(),
            "gatewayReference": r.gatewayReference ?? NSNull(),
            "amount":           r.amount ?? NSNull(),
            "currency":         r.currency ?? NSNull(),
            "failureReason":    r.failureReason ?? NSNull(),
        ])
        result = nil
    }
}
