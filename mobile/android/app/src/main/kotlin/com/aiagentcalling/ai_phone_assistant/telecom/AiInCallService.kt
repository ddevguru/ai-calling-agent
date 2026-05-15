package com.aiagentcalling.ai_phone_assistant.telecom

import android.os.Handler
import android.os.Looper
import android.telecom.Call
import android.telecom.InCallService
import android.telecom.VideoProfile

/**
 * Observes active calls when this app is the default dialer. Used to answer/reject ringing calls.
 */
class AiInCallService : InCallService() {

    private val main = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    override fun onCallAdded(call: Call) {
        emit(call, "added")
        maybeAutoAnswerWithAi(call)
        call.registerCallback(
            object : Call.Callback() {
                override fun onStateChanged(
                    c: Call,
                    state: Int,
                ) {
                    emit(c, "state_changed")
                }

                override fun onDetailsChanged(
                    c: Call,
                    details: android.telecom.Call.Details,
                ) {
                    emit(c, "details_changed")
                }
            },
            main,
        )
    }

    override fun onCallRemoved(call: Call) {
        emit(call, "removed")
    }

    private fun maybeAutoAnswerWithAi(call: Call) {
        if (!CallDirector.pendingAnswerWithAi) return
        if (call.details.callDirection != Call.Details.DIRECTION_INCOMING) return
        if (call.state != Call.STATE_RINGING && call.state != Call.STATE_NEW) return
        CallDirector.clearPendingAnswer()
        try {
            call.answer(VideoProfile.STATE_AUDIO_ONLY)
        } catch (_: Exception) {
        }
        emitIncomingAnswered(call)
    }

    private fun emit(
        call: Call,
        reason: String,
    ) {
        val handle = call.details.handle?.schemeSpecificPart ?: ""
        TelecomBridge.emitInCallUi(
            reason,
            mapOf(
                "callState" to call.state,
                "handle" to handle,
                "isIncoming" to (call.details.callDirection == Call.Details.DIRECTION_INCOMING),
            ),
        )
    }

    private fun emitIncomingAnswered(call: Call) {
        val handle = call.details.handle?.schemeSpecificPart ?: ""
        TelecomBridge.emit(
            mapOf(
                "type" to "incoming_answered",
                "handle" to handle,
                "timestampMs" to System.currentTimeMillis(),
            ),
        )
    }

    companion object {
        @Volatile
        private var instance: AiInCallService? = null

        fun tryAnswerRingingIncoming(): Boolean {
            val svc = instance ?: return false
            for (call in svc.calls) {
                if (call.details.callDirection != Call.Details.DIRECTION_INCOMING) continue
                if (call.state != Call.STATE_RINGING && call.state != Call.STATE_NEW) continue
                try {
                    call.answer(VideoProfile.STATE_AUDIO_ONLY)
                    svc.emitIncomingAnswered(call)
                    return true
                } catch (_: Exception) {
                }
            }
            return false
        }

        fun tryRejectRinging(): Boolean {
            val svc = instance ?: return false
            for (call in svc.calls) {
                if (call.details.callDirection != Call.Details.DIRECTION_INCOMING) continue
                if (call.state != Call.STATE_RINGING && call.state != Call.STATE_NEW) continue
                try {
                    call.disconnect()
                    return true
                } catch (_: Exception) {
                }
            }
            return false
        }
    }
}
