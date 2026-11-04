package com.rumarasecurity.app.panic

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.net.Uri
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.rumarasecurity.app.MainActivity
import com.rumarasecurity.app.R

class PanicOverlayService : Service() {

    companion object {
        private const val TAG = "PanicOverlayService"

        const val EXTRA_TITLE = "panic_title"
        const val EXTRA_BODY = "panic_body"
        const val EXTRA_AREA = "panic_area"
        const val EXTRA_REPORTER = "panic_reporter"
        const val EXTRA_STATUS = "panic_status"

        private const val CHANNEL_ID = "guardify_panic_native"
        private const val CHANNEL_NAME = "Rumara Security Panic Overlay"
        private const val NOTIFICATION_ID = 9911

        private const val ACTION_STOP = "com.rumarasecurity.app.panic.ACTION_STOP"
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "onCreate")
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createNotificationChannel()

        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vm.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand action=${intent?.action}")
        if (intent?.action == ACTION_STOP) {
            Log.d(TAG, "ACTION_STOP received")
            stopAlerting()
            removeOverlay()
            stopSelf()
            return START_NOT_STICKY
        }

        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "PANIC"
        val body = intent?.getStringExtra(EXTRA_BODY) ?: "Ada situasi darurat"
        val area = intent?.getStringExtra(EXTRA_AREA) ?: ""
        val reporter = intent?.getStringExtra(EXTRA_REPORTER) ?: ""
        val status = intent?.getStringExtra(EXTRA_STATUS) ?: ""

        startForeground(NOTIFICATION_ID, buildForegroundNotification(title, body))

        startAlerting()

        if (!canDrawOverlays()) {
            Log.d(TAG, "No overlay permission; keeping foreground notification")
            // No overlay permission: keep only notification and stop service.
            // Keep alerting until user taps notification action.
            return START_NOT_STICKY
        }

        showOverlay(title, body, area, reporter, status)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "onDestroy")
        stopAlerting()
        removeOverlay()
    }

    private fun startAlerting() {
        Log.d(TAG, "startAlerting")
        startVibrationLoop()
        startAlarmSoundLoop()
    }

    private fun stopAlerting() {
        Log.d(TAG, "stopAlerting")
        stopVibrationLoop()
        stopAlarmSoundLoop()
    }

    private fun startVibrationLoop() {
        try {
            Log.d(TAG, "startVibrationLoop")
            val pattern = longArrayOf(
                0,
                1000, 500,
                1000, 500,
                1000, 500,
                1000, 500,
                1000, 500,
                1000, 500,
                1000, 500,
                1000
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val effect = VibrationEffect.createWaveform(pattern, 0)
                vibrator?.vibrate(effect)
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
        } catch (t: Throwable) {
            Log.e(TAG, "startVibrationLoop failed", t)
        }
    }

    private fun stopVibrationLoop() {
        try {
            Log.d(TAG, "stopVibrationLoop")
            vibrator?.cancel()
        } catch (t: Throwable) {
            Log.e(TAG, "stopVibrationLoop failed", t)
        }
    }

    private fun startAlarmSoundLoop() {
        if (mediaPlayer != null) return

        try {
            Log.d(TAG, "startAlarmSoundLoop")
            val alarmUri: Uri? = android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_ALARM)
                ?: android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_NOTIFICATION)

            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            val mp = MediaPlayer()
            mp.setAudioAttributes(attrs)
            if (alarmUri != null) {
                mp.setDataSource(this, alarmUri)
                mp.isLooping = true
                mp.prepare()
                mp.start()
                mediaPlayer = mp
            } else {
                mp.release()
            }
        } catch (t: Throwable) {
            Log.e(TAG, "startAlarmSoundLoop failed", t)
            stopAlarmSoundLoop()
        }
    }

    private fun stopAlarmSoundLoop() {
        Log.d(TAG, "stopAlarmSoundLoop")
        try {
            mediaPlayer?.stop()
        } catch (_: Throwable) {
            // ignore
        }
        try {
            mediaPlayer?.release()
        } catch (_: Throwable) {
            // ignore
        }
        mediaPlayer = null
    }

    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun showOverlay(
        title: String,
        body: String,
        area: String,
        reporter: String,
        status: String,
    ) {
        if (overlayView != null) return

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(40, 40, 40, 40)
            setBackgroundColor(0xFFFFFFFF.toInt())
        }

        val titleView = TextView(this).apply {
            text = "PANIC - $title"
            textSize = 16f
            setTextColor(0xFFE53935.toInt())
        }

        val areaView = TextView(this).apply {
            text = if (area.isNotEmpty()) area else ""
            textSize = 14f
        }

        val reporterView = TextView(this).apply {
            text = if (reporter.isNotEmpty()) "Pelapor: $reporter" else ""
            textSize = 14f
        }

        val statusView = TextView(this).apply {
            text = if (status.isNotEmpty()) "Status: $status" else ""
            textSize = 14f
        }

        val bodyView = TextView(this).apply {
            text = body
            textSize = 14f
        }

        val buttonRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
        }

        val closeBtn = Button(this).apply {
            text = "Tutup"
            setOnClickListener {
                stopAlerting()
                removeOverlay()
                stopSelf()
            }
        }

        val openBtn = Button(this).apply {
            text = "Buka App"
            setOnClickListener {
                val launchIntent = Intent(this@PanicOverlayService, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                startActivity(launchIntent)
                stopAlerting()
                removeOverlay()
                stopSelf()
            }
        }

        buttonRow.addView(openBtn)
        buttonRow.addView(closeBtn)

        container.addView(titleView)
        if (area.isNotEmpty()) container.addView(areaView)
        if (reporter.isNotEmpty()) container.addView(reporterView)
        if (status.isNotEmpty()) container.addView(statusView)
        container.addView(bodyView)
        container.addView(buttonRow)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP
        }

        overlayView = container
        windowManager?.addView(container, params)
    }

    private fun removeOverlay() {
        try {
            overlayView?.let { windowManager?.removeView(it) }
        } catch (_: Throwable) {
            // ignore
        } finally {
            overlayView = null
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH
        )
        channel.description = "Native panic overlay service notifications"
        channel.setBypassDnd(true)
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val alarmUri: Uri? = android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_ALARM)
            ?: android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_NOTIFICATION)
        if (alarmUri != null) {
            channel.setSound(alarmUri, attrs)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildForegroundNotification(title: String, body: String): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                PendingIntent.FLAG_IMMUTABLE
            else
                0
        )

        val stopIntent = Intent(this, PanicOverlayService::class.java).apply {
            action = ACTION_STOP
        }

        val stopPendingIntent = PendingIntent.getService(
            this,
            1,
            stopIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                PendingIntent.FLAG_IMMUTABLE
            else
                0
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle("PANIC - $title")
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setContentIntent(pendingIntent)
            .addAction(0, "Stop", stopPendingIntent)
            .setOngoing(true)
            .build()
    }
}
