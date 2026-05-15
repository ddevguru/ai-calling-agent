package com.aiagentcalling.ai_phone_assistant.telecom

/**
 * Queues "answer with AI" when the [Call] object is not attached yet (race with screening).
 */
object CallDirector {
    private val lock = Any()

    @Volatile
    var pendingAnswerWithAi: Boolean = false
        private set

    fun clearPendingAnswer() {
        synchronized(lock) {
            pendingAnswerWithAi = false
        }
    }

    fun markAnswerWithAiPending() {
        synchronized(lock) {
            pendingAnswerWithAi = true
        }
    }

    /**
     * Marks pending and tries an immediate answer. If the call object is not ready yet,
     * [AiInCallService] will answer on [android.telecom.InCallService.onCallAdded].
     */
    fun requestAnswerWithAi(): Boolean {
        markAnswerWithAiPending()
        val answeredNow = AiInCallService.tryAnswerRingingIncoming()
        if (answeredNow) {
            clearPendingAnswer()
        }
        return answeredNow
    }
}
