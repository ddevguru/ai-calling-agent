package com.aiagentcalling.ai_phone_assistant.telecom

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.aiagentcalling.ai_phone_assistant.MainActivity

class IncomingCallActionsReceiver : BroadcastReceiver() {

    override fun onReceive(
        context: Context,
        intent: Intent?,
    ) {
        val app = context.applicationContext
        val handle = intent?.getStringExtra(IncomingCallNotifier.EXTRA_HANDLE).orEmpty()
        when (intent?.action) {
            ACTION_ANSWER_AI -> {
                CallDirector.requestAnswerWithAi()
                LaunchIntentStore.queue(LaunchIntentStore.ACTION_START_VOICE, handle)
                app.startActivity(
                    Intent(app, MainActivity::class.java).apply {
                        flags =
                            Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                                Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra(LaunchIntentStore.EXTRA_AURA_ACTION, LaunchIntentStore.ACTION_START_VOICE)
                        putExtra(LaunchIntentStore.EXTRA_HANDLE, handle)
                    },
                )
                IncomingCallNotifier.cancel(app)
            }

            ACTION_DECLINE -> {
                CallDirector.clearPendingAnswer()
                AiInCallService.tryRejectRinging()
                IncomingCallNotifier.cancel(app)
            }
        }
    }

    companion object {
        const val ACTION_ANSWER_AI = "com.aiagentcalling.telecom.ANSWER_AI"
        const val ACTION_DECLINE = "com.aiagentcalling.telecom.DECLINE"
    }
}
