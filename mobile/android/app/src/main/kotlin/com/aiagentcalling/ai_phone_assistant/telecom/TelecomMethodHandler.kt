package com.aiagentcalling.ai_phone_assistant.telecom

import android.app.Activity
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.telecom.TelecomManager
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class TelecomMethodHandler(
    private val activity: Activity,
) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "placeCall" -> {
                val raw = call.argument<String>("number") ?: ""
                val uri = Uri.parse("tel:" + Uri.encode(raw))
                val intent = Intent(Intent.ACTION_CALL, uri)
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                try {
                    activity.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("CALL_FAILED", e.message, null)
                }
            }

            "openDialer" -> {
                val raw = call.argument<String>("number") ?: ""
                val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:" + Uri.encode(raw)))
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                activity.startActivity(intent)
                result.success(true)
            }

            "getDefaultDialerPackage" -> {
                val mgr = activity.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
                result.success(mgr.defaultDialerPackage)
            }

            "requestDefaultDialerRole" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val intent = (activity.getSystemService(Context.ROLE_SERVICE) as RoleManager)
                        .createRequestRoleIntent(RoleManager.ROLE_DIALER)
                    activity.startActivity(intent)
                    result.success(true)
                } else {
                    result.success(false)
                }
            }

            "requestCallScreeningRole" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val rm = activity.getSystemService(Context.ROLE_SERVICE) as RoleManager
                    val intent = rm.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING)
                    activity.startActivity(intent)
                    result.success(true)
                } else {
                    result.success(false)
                }
            }

            "isCallScreeningRoleHeld" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val rm = activity.getSystemService(Context.ROLE_SERVICE) as RoleManager
                    result.success(rm.isRoleHeld(RoleManager.ROLE_CALL_SCREENING))
                } else {
                    result.success(false)
                }
            }

            "isDefaultDialer" -> {
                val mgr = activity.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
                result.success(activity.packageName == mgr.defaultDialerPackage)
            }

            "getSimLineNumber" -> {
                result.success(readLineNumber())
            }

            "openAppSettings" -> {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", activity.packageName, null)
                }
                activity.startActivity(intent)
                result.success(true)
            }

            "startMicStream" -> {
                val ok = AudioBridge.startMic(activity)
                result.success(ok)
            }

            "stopMicStream" -> {
                AudioBridge.stopMic()
                result.success(true)
            }

            "startSpeaker" -> {
                val ok = AudioBridge.startSpeaker()
                result.success(ok)
            }

            "stopSpeaker" -> {
                AudioBridge.stopSpeaker()
                result.success(true)
            }

            "enqueueSpeakerPcm64" -> {
                val b64 = call.argument<String>("base64") ?: ""
                if (b64.isNotEmpty()) {
                    AudioBridge.enqueueSpeakerBase64(b64)
                }
                result.success(true)
            }

            "shutdownAudio" -> {
                AudioBridge.shutdownAll()
                result.success(true)
            }

            "requestAnswerWithAi" -> {
                val ok = CallDirector.requestAnswerWithAi()
                result.success(ok)
            }

            "rejectRingingCall" -> {
                CallDirector.clearPendingAnswer()
                val ok = AiInCallService.tryRejectRinging()
                result.success(ok)
            }

            "consumePendingLaunch" -> {
                result.success(LaunchIntentStore.consume())
            }

            "startAssistantForeground" -> {
                AssistantForegroundService.start(activity.applicationContext)
                result.success(true)
            }

            "stopAssistantForeground" -> {
                AssistantForegroundService.stop(activity.applicationContext)
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    private fun readLineNumber(): String? {
        val telephony =
            activity.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        val sm =
            activity.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
        val list = sm.activeSubscriptionInfoList
        if (!list.isNullOrEmpty()) {
            val subId = list[0].subscriptionId
            return telephony.createForSubscriptionId(subId).line1Number
        }
        return telephony.line1Number
    }
}
