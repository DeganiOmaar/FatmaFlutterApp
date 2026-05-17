package com.example.pfe

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.lancy/config",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "debugLanHost" -> {
                    val h = BuildConfig.LANCY_DEBUG_LAN_HOST
                    result.success(if (h.isBlank()) "" else h)
                }
                else -> result.notImplemented()
            }
        }
    }
}
