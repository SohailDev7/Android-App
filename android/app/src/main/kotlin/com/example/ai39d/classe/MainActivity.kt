package com.example.ai39d.classe

import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "classe/restart",
        ).setMethodCallHandler { call, result ->
            if (call.method != "restart") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent == null) {
                result.error(
                    "NO_LAUNCH_INTENT",
                    "Could not find the launch activity.",
                    null,
                )
                return@setMethodCallHandler
            }

            intent.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK,
            )

            // Reply first so the Dart side has a chance to receive the result,
            // then relaunch and kill this process for a true cold start. A cold
            // start is required for Shorebird to load the downloaded patch.
            result.success(null)
            Handler(Looper.getMainLooper()).postDelayed({
                startActivity(intent)
                Runtime.getRuntime().exit(0)
            }, 300)
        }
    }
}
