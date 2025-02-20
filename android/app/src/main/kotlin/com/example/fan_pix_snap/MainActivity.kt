package com.example.fan_pix_snap

import android.os.Bundle
import android.content.Intent
import android.net.Uri
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.fan_pix_snap/media_store"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "scanFile") {
                val path = call.argument<String>("path")
                if (path != null) {
                    scanMediaFile(path)
                    result.success(null)
                } else {
                    result.error("INVALID_PATH", "No path provided", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun scanMediaFile(path: String) {
        val uri = Uri.fromFile(java.io.File(path))
        val scanIntent = Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE, uri)
        sendBroadcast(scanIntent)
    }
}
