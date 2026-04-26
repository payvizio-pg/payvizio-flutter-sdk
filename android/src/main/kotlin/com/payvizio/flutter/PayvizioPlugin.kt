package com.payvizio.flutter

import android.app.Activity
import com.payvizio.sdk.PaymentCallback
import com.payvizio.sdk.PaymentResult
import com.payvizio.sdk.Payvizio
import com.payvizio.sdk.PayvizioConfig
import com.payvizio.sdk.UpiIntent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel bridge from Dart to the Payvizio Android SDK. Holds the
 * current Activity binding so [com.payvizio.sdk.Payvizio.checkout] has a
 * launcher to open CheckoutActivity from.
 */
class PayvizioPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.payvizio.flutter/sdk")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity()                              { activity = null }
    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) { activity = b.activity }
    override fun onDetachedFromActivityForConfigChanges()              { activity = null }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "configure"        -> handleConfigure(call, result)
            "prefetch"         -> { Payvizio.prefetch(); result.success(null) }
            "checkout"         -> handleCheckout(call, result)
            "launchUpiIntent"  -> handleUpiIntent(call, result)
            else               -> result.notImplemented()
        }
    }

    private fun handleConfigure(call: MethodCall, result: MethodChannel.Result) {
        val baseUrl = call.argument<String>("apiBaseUrl") ?: run {
            result.error("PVZ_INVALID", "apiBaseUrl is required", null); return
        }
        val checkoutUrl = call.argument<String?>("checkoutUrl")
        val pollMs = (call.argument<Number>("pollIntervalMs") ?: 2500).toLong()
        val dismissible = call.argument<Boolean>("dismissible") ?: true
        Payvizio.init(PayvizioConfig(
            apiBaseUrl = baseUrl,
            checkoutUrl = checkoutUrl,
            pollIntervalMs = pollMs,
            backButtonDismissible = dismissible))
        result.success(null)
    }

    private fun handleCheckout(call: MethodCall, result: MethodChannel.Result) {
        val sessionId = call.argument<String>("sessionId") ?: run {
            result.error("PVZ_INVALID", "sessionId is required", null); return
        }
        val act = activity ?: run {
            result.error("PVZ_NO_ACTIVITY", "No foreground Activity", null); return
        }
        Payvizio.checkout(act, sessionId, object : PaymentCallback {
            override fun onSuccess(r: PaymentResult) { result.success(toMap(r)) }
            override fun onFailure(r: PaymentResult) { result.success(toMap(r)) }
            override fun onClose() {
                // synthetic CANCELLED so Dart sees a single completion path
                result.success(mapOf("sessionId" to sessionId, "status" to "CANCELLED"))
            }
        })
    }

    private fun handleUpiIntent(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url") ?: run {
            result.error("PVZ_INVALID", "url is required", null); return
        }
        val act = activity ?: run {
            result.error("PVZ_NO_ACTIVITY", "No foreground Activity", null); return
        }
        result.success(UpiIntent.launch(act, url))
    }

    private fun toMap(r: PaymentResult): Map<String, Any?> = mapOf(
        "sessionId"        to r.sessionId,
        "status"           to r.status.name,
        "acquirer"         to r.acquirer,
        "gatewayReference" to r.gatewayReference,
        "amount"           to r.amount,
        "currency"         to r.currency,
        "failureReason"    to r.failureReason,
    )
}
