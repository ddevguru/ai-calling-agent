package com.aiagentcalling.ai_phone_assistant.telecom

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Keeps the process alive while realtime mic/speaker + WebSocket run (background calls).
 */
class AssistantForegroundService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        ensureChannel()
        val notif =
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("Aura assistant active")
                .setContentText("Listening and speaking on this session.")
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        } else {
            @Suppress("DEPRECATION")
            startForeground(NOTIF_ID, notif)
        }
        return START_STICKY
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val ch =
            NotificationChannel(
                CHANNEL_ID,
                "Assistant session",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Keeps Aura voice assistant running during a call"
            }
        mgr.createNotificationChannel(ch)
    }

    companion object {
        private const val CHANNEL_ID = "aura_assistant_session"
        private const val NOTIF_ID = 71043

        fun start(ctx: Context) {
            val intent = Intent(ctx, AssistantForegroundService::class.java)
            ContextCompat.startForegroundService(ctx, intent)
        }

        fun stop(ctx: Context) {
            ctx.stopService(Intent(ctx, AssistantForegroundService::class.java))
        }
    }
}
