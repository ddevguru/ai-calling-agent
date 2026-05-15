package com.aiagentcalling.ai_phone_assistant.telecom

import android.content.Intent

/**
 * Pending actions from notifications / cold start, consumed once by Flutter on resume.
 */
object LaunchIntentStore {
    private val lock = Any()
    private var action: String? = null
    private var handle: String? = null

    fun ingest(intent: Intent?) {
        if (intent == null) return
        val a = intent.getStringExtra(EXTRA_AURA_ACTION) ?: return
        val h = intent.getStringExtra(EXTRA_HANDLE).orEmpty()
        synchronized(lock) {
            action = a
            handle = h
        }
    }

    fun queue(action: String, handle: String) {
        synchronized(lock) {
            this.action = action
            this.handle = handle
        }
    }

    fun consume(): Map<String, String?> {
        synchronized(lock) {
            val out =
                mapOf(
                    "action" to action,
                    "handle" to handle,
                )
            action = null
            handle = null
            return out
        }
    }

    const val EXTRA_AURA_ACTION = "aura_action"
    const val EXTRA_HANDLE = "handle"

    const val ACTION_START_VOICE = "start_voice"
    const val ACTION_PROMPT_INCOMING = "prompt_incoming"
}
