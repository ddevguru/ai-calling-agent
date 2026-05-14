package com.aiagentcalling.ai_phone_assistant

import com.aiagentcalling.ai_phone_assistant.telecom.AudioBridge
import com.aiagentcalling.ai_phone_assistant.telecom.TelecomBridge
import com.aiagentcalling.ai_phone_assistant.telecom.TelecomMethodHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val METHODS = "com.aiagentcalling.telecom/methods"
        private const val EVENTS = "com.aiagentcalling.telecom/events"
        private const val AUDIO_EVENTS = "com.aiagentcalling.telecom/audio"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHODS)
            .setMethodCallHandler(TelecomMethodHandler(this))

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENTS)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        TelecomBridge.attachSink(events)
                    }

                    override fun onCancel(arguments: Any?) {
                        TelecomBridge.detachSink()
                    }
                },
            )

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_EVENTS)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        AudioBridge.attachAudioSink(events)
                    }

                    override fun onCancel(arguments: Any?) {
                        AudioBridge.detachAudioSink()
                    }
                },
            )
    }
}
