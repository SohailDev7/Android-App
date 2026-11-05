package com.example.ai39d.classe

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "classe/restart",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "restart" -> handleRestart(result)
                "canInstallPackages" -> result.success(canInstallPackages())
                "openInstallPermissionSettings" -> {
                    openInstallPermissionSettings()
                    result.success(null)
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("BAD_ARGS", "Missing APK path.", null)
                        return@setMethodCallHandler
                    }
                    installApk(path, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun handleRestart(result: MethodChannel.Result) {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        if (intent == null) {
            result.error(
                "NO_LAUNCH_INTENT",
                "Could not find the launch activity.",
                null,
            )
            return
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

    private fun canInstallPackages(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            )
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }

    private fun installApk(path: String, result: MethodChannel.Result) {
        try {
            val file = File(path)
            if (!file.exists()) {
                result.error("NOT_FOUND", "APK file not found: $path", null)
                return
            }

            val uri: Uri = FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                file,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("INSTALL_FAILED", e.message, null)
        }
    }
}
