package com.aiagentcalling.ai_phone_assistant.telecom

import android.telecom.Call
import android.telecom.CallScreeningService

/**
 * Invoked for incoming calls when this app holds the Call Screening role.
 * [onScreenCall] must return quickly; user approval for AI pickup is coordinated in Flutter.
 */
class AiCallScreeningService : CallScreeningService() {

    override fun onScreenCall(callDetails: Call.Details) {
        val handle = callDetails.handle?.schemeSpecificPart ?: ""
        val incoming =
            callDetails.callDirection == Call.Details.DIRECTION_INCOMING
        if (incoming) {
            TelecomBridge.emitIncomingCall(handle, false)
            IncomingCallNotifier.show(this, handle)
        }

        val response =
            CallResponse.Builder()
                .setDisallowCall(false)
                .setRejectCall(false)
                .setSilenceCall(false)
                .setSkipCallLog(false)
                .setSkipNotification(false)
                .build()
        respondToCall(callDetails, response)
    }
}
