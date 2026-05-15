package com.aiagentcalling.ai_phone_assistant.telecom

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.aiagentcalling.ai_phone_assistant.MainActivity

object IncomingCallNotifier {
    const val CHANNEL_ID = "aura_incoming_calls"
    private const val NOTIF_ID = 71042

    private const val RC_ANSWER = 9101
    private const val RC_DECLINE = 9102
    private const val RC_OPEN = 9103

    const val EXTRA_HANDLE = LaunchIntentStore.EXTRA_HANDLE

    fun ensureChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val ch =
            NotificationChannel(
                CHANNEL_ID,
                "Incoming calls",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Aura incoming call actions"
                setBypassDnd(false)
            }
        mgr.createNotificationChannel(ch)
    }

    fun show(
        ctx: Context,
        handle: String,
    ) {
        ensureChannel(ctx)
        val appCtx = ctx.applicationContext

        val answerIntent =
            Intent(appCtx, IncomingCallActionsReceiver::class.java).apply {
                putExtra(EXTRA_HANDLE, handle)
                action = IncomingCallActionsReceiver.ACTION_ANSWER_AI
            }
        val answerPi =
            PendingIntent.getBroadcast(
                appCtx,
                RC_ANSWER,
                answerIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        val declineIntent =
            Intent(appCtx, IncomingCallActionsReceiver::class.java).apply {
                putExtra(EXTRA_HANDLE, handle)
                action = IncomingCallActionsReceiver.ACTION_DECLINE
            }
        val declinePi =
            PendingIntent.getBroadcast(
                appCtx,
                RC_DECLINE,
                declineIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        val openIntent =
            Intent(appCtx, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(LaunchIntentStore.EXTRA_AURA_ACTION, LaunchIntentStore.ACTION_PROMPT_INCOMING)
                putExtra(EXTRA_HANDLE, handle)
            }
        val openPi =
            PendingIntent.getActivity(
                appCtx,
                RC_OPEN,
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        val nb =
            NotificationCompat.Builder(appCtx, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.sym_call_incoming)
                .setContentTitle("Incoming call")
                .setContentText(handle.ifEmpty { "Unknown number" })
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setContentIntent(openPi)
                .setAutoCancel(true)
                .addAction(android.R.drawable.stat_sys_phone_call, "Answer with AI", answerPi)
                .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Decline", declinePi)

        NotificationManagerCompat.from(appCtx).notify(NOTIF_ID, nb.build())
    }

    fun cancel(ctx: Context) {
        NotificationManagerCompat.from(ctx.applicationContext).cancel(NOTIF_ID)
    }
}
