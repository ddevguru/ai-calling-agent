package com.aiagentcalling.ai_phone_assistant.telecom

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Bridges native telephony events (incoming screening, in-call state) to Flutter via [EventChannel].
 */
object TelecomBridge {
    private val main = Handler(Looper.getMainLooper())
    @Volatile
    private var sink: EventChannel.EventSink? = null

    fun attachSink(events: EventChannel.EventSink?) {
        sink = events
    }

    fun detachSink() {
        sink = null
    }

    fun emit(map: Map<String, Any?>) {
        val s = sink ?: return
        main.post { s.success(map) }
    }

    fun emitIncomingCall(handle: String, isBlocked: Boolean) {
        emit(
            mapOf(
                "type" to "incoming",
                "handle" to handle,
                "timestampMs" to System.currentTimeMillis(),
                "isBlocked" to isBlocked,
            ),
        )
    }

    fun emitInCallUi(state: String, extras: Map<String, Any?> = emptyMap()) {
        val payload = LinkedHashMap<String, Any?>()
        payload["type"] = "incall"
        payload["state"] = state
        payload.putAll(extras)
        emit(payload)
    }
}
