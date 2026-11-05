package com.rumarasecurity.app

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// Import panic service
import com.rumarasecurity.app.panic.PanicOverlayService

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.rumarasecurity.app/panic"

    override fun onCreate(savedInstanceState: Bundle?) {
        // Clear corrupted SharedPreferences BEFORE Flutter engine starts
        // The shared_preferences plugin stores data in FlutterSharedPreferences.xml
        // If api_logs key grew to 231MB+, it causes OOM when the plugin tries to
        // serialize all data to send back to Dart via platform channels.
        clearCorruptedPrefsIfNeeded()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "stopPanicService" -> {
                    try {
                        val intent = Intent(this, PanicOverlayService::class.java).apply {
                            action = "com.rumarasecurity.app.panic.ACTION_STOP"
                        }
                        startService(intent)
                        Log.d("Guardify", "Stop panic service intent sent")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("Guardify", "Error stopping panic service: ${e.message}")
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun clearCorruptedPrefsIfNeeded() {
        try {
            val prefsFile = File(applicationInfo.dataDir, "shared_prefs/FlutterSharedPreferences.xml")
            if (prefsFile.exists()) {
                val fileSizeBytes = prefsFile.length()
                val fileSizeMB = fileSizeBytes / (1024 * 1024)
                Log.d("Guardify", "SharedPreferences file size: ${fileSizeMB}MB (${fileSizeBytes} bytes)")

                // If the prefs file is larger than 5MB, it's corrupted — delete it
                if (fileSizeMB > 5) {
                    Log.w("Guardify", "SharedPreferences file is too large (${fileSizeMB}MB), deleting to prevent OOM crash")
                    prefsFile.delete()
                    Log.w("Guardify", "Corrupted SharedPreferences file deleted successfully")
                }
            }
        } catch (e: Exception) {
            Log.e("Guardify", "Error checking SharedPreferences file size: ${e.message}")
        }
    }
}
