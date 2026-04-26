# Payvizio Flutter SDK

Wraps the native [Android](../android-sdk/) and [iOS](../ios-sdk/) SDKs.
Card capture happens inside the acquirer's iframe inside our hosted checkout —
integrating apps stay **PCI-out-of-scope**.

## Install

```yaml
dependencies:
  payvizio: ^0.1.0
```

## Usage

```dart
import 'package:payvizio/payvizio.dart';

final pv = Payvizio();

@override
void initState() {
  super.initState();
  pv.configure(apiBaseUrl: 'https://api.payvizio.com');
  pv.prefetch();
}

Future<void> _pay(String sessionId) async {
  final r = await pv.checkout(sessionId: sessionId);
  switch (r.status) {
    case PaymentStatus.captured:
    case PaymentStatus.authorized:
      // success
      break;
    case PaymentStatus.cancelled:
      // user dismissed
      break;
    default:
      // failure / expired / voided
  }
}
```

## Native UPI Intent

```dart
final ok = await pv.launchUpiIntent('upi://pay?pa=acme@hdfcbank&am=100');
```

## What this SDK doesn't include

- A native card form (acquirer's drop-in handles card capture)
- 3DS challenge UI (acquirer hosts the ACS page)
- Saved-card management — render via your own UI before opening checkout

Pre-1.0; pin a specific version in production.
