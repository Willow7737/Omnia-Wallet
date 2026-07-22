package com.omnia.wallet

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by the local_auth
// plugin's biometric prompt on Android.
class MainActivity : FlutterFragmentActivity()
