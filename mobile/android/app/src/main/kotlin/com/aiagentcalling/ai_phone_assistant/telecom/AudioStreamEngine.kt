package com.aiagentcalling.ai_phone_assistant.telecom

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.util.Base64
import androidx.core.content.ContextCompat
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 24 kHz mono PCM16 capture (VOICE_COMMUNICATION) and playback for OpenAI Realtime.
 */
class AudioStreamEngine(
    private val sampleRate: Int = 24_000,
    private val channelIn: Int = AudioFormat.CHANNEL_IN_MONO,
    private val audioFormat: Int = AudioFormat.ENCODING_PCM_16BIT,
) {
    private val capturing = AtomicBoolean(false)
    private var captureThread: Thread? = null
    private var recorder: AudioRecord? = null
    private var track: AudioTrack? = null

    fun hasRecordPermission(ctx: Context): Boolean {
        return ContextCompat.checkSelfPermission(
            ctx,
            android.Manifest.permission.RECORD_AUDIO,
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    fun startCapture(ctx: Context, onChunk: (ByteArray) -> Unit): Boolean {
        stopCapture()
        if (!hasRecordPermission(ctx)) return false
        val min = AudioRecord.getMinBufferSize(sampleRate, channelIn, audioFormat)
        if (min == AudioRecord.ERROR || min == AudioRecord.ERROR_BAD_VALUE) return false
        val bufferSize = min * 2
        val rec =
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                sampleRate,
                channelIn,
                audioFormat,
                bufferSize,
            )
        if (rec.state != AudioRecord.STATE_INITIALIZED) {
            rec.release()
            return false
        }
        recorder = rec
        capturing.set(true)
        rec.startRecording()
        captureThread =
            Thread {
                val buf = ByteArray(1920)
                while (capturing.get()) {
                    val r = rec
                    if (r == null) break
                    val n = r.read(buf, 0, buf.size)
                    if (n > 0) {
                        onChunk(buf.copyOf(n))
                    }
                }
            }.also { it.start() }
        return true
    }

    fun stopCapture() {
        capturing.set(false)
        try {
            recorder?.stop()
        } catch (_: Exception) {
        }
        recorder?.release()
        recorder = null
        try {
            captureThread?.join(800)
        } catch (_: Exception) {
        }
        captureThread = null
    }

    fun startPlayback(): Boolean {
        stopPlayback()
        val min = AudioTrack.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_OUT_MONO, audioFormat)
        if (min == AudioTrack.ERROR || min == AudioTrack.ERROR_BAD_VALUE) return false
        val t =
            AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build(),
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(audioFormat)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build(),
                )
                .setBufferSizeInBytes(min * 2)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
        if (t.state != AudioTrack.STATE_INITIALIZED) {
            t.release()
            return false
        }
        track = t
        t.play()
        return true
    }

    fun enqueuePcm(chunk: ByteArray) {
        val t = track ?: return
        var off = 0
        while (off < chunk.size) {
            val w = t.write(chunk, off, chunk.size - off)
            if (w < 0) break
            off += w
        }
    }

    fun stopPlayback() {
        try {
            track?.stop()
        } catch (_: Exception) {
        }
        track?.release()
        track = null
    }

    fun shutdown() {
        stopCapture()
        stopPlayback()
    }
}

object AudioBridge {
    private val main = Handler(Looper.getMainLooper())
    private val engine = AudioStreamEngine()

    @Volatile
    private var sink: io.flutter.plugin.common.EventChannel.EventSink? = null

    fun attachAudioSink(events: io.flutter.plugin.common.EventChannel.EventSink?) {
        sink = events
    }

    fun detachAudioSink() {
        sink = null
        engine.shutdown()
    }

    private fun emit(map: Map<String, Any?>) {
        val s = sink ?: return
        main.post { s.success(map) }
    }

    fun startMic(activity: android.app.Activity): Boolean {
        return engine.startCapture(activity) { bytes ->
            emit(
                mapOf(
                    "type" to "pcm16",
                    "base64" to Base64.encodeToString(bytes, Base64.NO_WRAP),
                ),
            )
        }
    }

    fun stopMic() {
        engine.stopCapture()
    }

    fun startSpeaker(): Boolean = engine.startPlayback()

    fun stopSpeaker() {
        engine.stopPlayback()
    }

    fun enqueueSpeakerBase64(b64: String) {
        val bytes = Base64.decode(b64, Base64.NO_WRAP)
        engine.enqueuePcm(bytes)
    }

    fun shutdownAll() {
        engine.shutdown()
    }
}
