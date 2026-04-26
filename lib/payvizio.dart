/// Payvizio Flutter SDK — wraps the native Android (Kotlin) and iOS (Swift)
/// SDKs over a single MethodChannel. Card capture happens inside the
/// acquirer's iframe nested in the hosted checkout, keeping integrating apps
/// PCI-out-of-scope.
///
/// Quickstart:
/// ```dart
/// final pv = Payvizio();
/// await pv.configure(apiBaseUrl: 'https://api.payvizio.com');
///
/// final result = await pv.checkout(sessionId: 'sess_xxx');
/// switch (result.status) {
///   case PaymentStatus.captured:
///     // success
///     break;
///   case PaymentStatus.failed:
///     // retryable failure
///     break;
///   case PaymentStatus.cancelled:
///     // user closed
///     break;
///   default:
///     break;
/// }
/// ```
library payvizio;

import 'package:flutter/services.dart';

const _channel = MethodChannel('com.payvizio.flutter/sdk');

/// Final-state status delivered to the caller. Mirrors the server enum on
/// `GET /api/payments/{sessionId}` plus a synthetic `cancelled` for user-close.
enum PaymentStatus {
  authorized,
  captured,
  authFailed,
  failed,
  voided,
  expired,
  cancelled, // user dismissed the checkout
  unknown,
}

class PayvizioException implements Exception {
  final String code;
  final String message;
  PayvizioException(this.code, this.message);
  @override
  String toString() => 'PayvizioException($code): $message';
}

/// Result returned by [Payvizio.checkout].
class PaymentResult {
  final String sessionId;
  final PaymentStatus status;
  final String? acquirer;
  final String? gatewayReference;
  final String? amount;
  final String? currency;
  final String? failureReason;

  const PaymentResult({
    required this.sessionId,
    required this.status,
    this.acquirer,
    this.gatewayReference,
    this.amount,
    this.currency,
    this.failureReason,
  });

  factory PaymentResult._fromMap(Map<dynamic, dynamic> m) => PaymentResult(
        sessionId: (m['sessionId'] ?? '') as String,
        status: _parseStatus(m['status'] as String?),
        acquirer: m['acquirer'] as String?,
        gatewayReference: m['gatewayReference'] as String?,
        amount: m['amount'] as String?,
        currency: m['currency'] as String?,
        failureReason: m['failureReason'] as String?,
      );

  static PaymentStatus _parseStatus(String? raw) {
    switch (raw) {
      case 'AUTHORIZED':
        return PaymentStatus.authorized;
      case 'CAPTURED':
        return PaymentStatus.captured;
      case 'AUTH_FAILED':
        return PaymentStatus.authFailed;
      case 'FAILED':
        return PaymentStatus.failed;
      case 'VOIDED':
        return PaymentStatus.voided;
      case 'EXPIRED':
        return PaymentStatus.expired;
      case 'CANCELLED':
      case null:
      case '':
        return PaymentStatus.cancelled;
      default:
        return PaymentStatus.unknown;
    }
  }
}

class Payvizio {
  /// Configure once per app start. Subsequent calls replace the configuration.
  Future<void> configure({
    required String apiBaseUrl,
    String? checkoutUrl,
    Duration pollInterval = const Duration(milliseconds: 2500),
    bool dismissible = true,
  }) async {
    await _channel.invokeMethod('configure', {
      'apiBaseUrl': apiBaseUrl,
      'checkoutUrl': checkoutUrl,
      'pollIntervalMs': pollInterval.inMilliseconds,
      'dismissible': dismissible,
    });
  }

  /// Best-effort TLS warm-up.
  Future<void> prefetch() => _channel.invokeMethod('prefetch');

  /// Open the hosted checkout for [sessionId]. Resolves with a [PaymentResult]
  /// once the checkout reaches a terminal state or the user dismisses it.
  Future<PaymentResult> checkout({required String sessionId}) async {
    if (sessionId.isEmpty) {
      throw PayvizioException('PVZ_INVALID', 'sessionId is required');
    }
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
          'checkout', {'sessionId': sessionId});
      if (raw == null) {
        return PaymentResult(
            sessionId: sessionId, status: PaymentStatus.cancelled);
      }
      return PaymentResult._fromMap(raw);
    } on PlatformException catch (e) {
      throw PayvizioException(e.code, e.message ?? 'platform error');
    }
  }

  /// Launch a UPI Intent (`upi://pay?...`) on the device's default UPI app.
  /// Returns true when an app accepted the intent; false otherwise. Reconcile
  /// the final state with the server (no UPI app guarantees a deterministic
  /// return signal).
  Future<bool> launchUpiIntent(String intentUrl) async {
    if (!intentUrl.startsWith('upi://')) {
      throw PayvizioException('PVZ_INVALID', 'intentUrl must use upi:// scheme');
    }
    final ok = await _channel.invokeMethod<bool>('launchUpiIntent', {'url': intentUrl});
    return ok ?? false;
  }
}
