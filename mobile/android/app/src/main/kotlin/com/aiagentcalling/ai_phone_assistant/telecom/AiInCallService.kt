package com.aiagentcalling.ai_phone_assistant.telecom

import android.os.Handler
import android.os.Looper
import android.telecom.Call
import android.telecom.InCallService

/**
 * Observes active calls when this app is the default dialer. Pair with [AiCallScreeningService]
 * for pre-answer detection and user approval flows in Flutter.
 */
class AiInCallService : InCallService() {

    private val main = Handler(Looper.getMainLooper())

    override fun onCallAdded(call: Call) {
        emit(call, "added")
        call.registerCallback(
            object : Call.Callback() {
                override fun onStateChanged(c: Call, state: Int) {
                    emit(c, "state_changed")
                }

                override fun onDetailsChanged(c: Call, details: android.telecom.Call.Details) {
                    emit(c, "details_changed")
                }
            },
            main,
        )
    }

    override fun onCallRemoved(call: Call) {
        emit(call, "removed")
    }

    private fun emit(call: Call, reason: String) {
        val handle = call.details.handle?.schemeSpecificPart ?: ""
        TelecomBridge.emitInCallUi(
            reason,
            mapOf(
                "callState" to call.state,
                "handle" to handle,
                "isIncoming" to (call.details.callDirection == android.telecom.Call.Details.DIRECTION_INCOMING),
            ),
        )
    }
}
