package com.rumarasecurity.app.panic

import android.content.Intent
import android.os.Build
import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class PanicFirebaseMessagingService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "PanicFCM"
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        val type = data["type"] ?: data["Type"] ?: data["notificationType"] ?: data["notification_type"]

        val notifTitle = message.notification?.title
        val notifBody = message.notification?.body

        val looksLikePanicPayload =
            data.containsKey("IncidentName") ||
                data.containsKey("incidentName") ||
                data.containsKey("Reporter") ||
                data.containsKey("reporter") ||
                (notifTitle?.contains("panic", ignoreCase = true) == true) ||
                (notifBody?.contains("panic", ignoreCase = true) == true)

        Log.d(
            TAG,
            "onMessageReceived dataKeys=${data.keys} type=$type looksLikePanicPayload=$looksLikePanicPayload notifTitle=$notifTitle",
        )

        if (type != "panic_button" && !looksLikePanicPayload) {
            return
        }

        Log.d(TAG, "Starting PanicOverlayService (panic detected)")

        val intent = Intent(this, PanicOverlayService::class.java).apply {
            putExtra(
                PanicOverlayService.EXTRA_TITLE,
                data["IncidentName"] ?: data["incidentName"] ?: notifTitle ?: "PANIC",
            )
            putExtra(
                PanicOverlayService.EXTRA_BODY,
                data["Description"] ?: data["description"] ?: notifBody ?: "Ada situasi darurat",
            )
            putExtra(PanicOverlayService.EXTRA_AREA, data["AreasName"] ?: data["areasName"] ?: "")
            putExtra(PanicOverlayService.EXTRA_REPORTER, data["Reporter"] ?: data["reporter"] ?: "")
            putExtra(PanicOverlayService.EXTRA_STATUS, data["Status"] ?: data["status"] ?: "")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
}
