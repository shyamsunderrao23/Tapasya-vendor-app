package com.example.tapasya_vendor_app

import android.app.ActivityManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import com.google.firebase.messaging.RemoteMessage

/**
 * Intercepts FCM in background and launches the native manual job overlay (Rapido-style).
 * Flutter background handler also saves pending + notification as fallback.
 */
class TapasyaJobMessagingReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "FCM received — action=${intent.action} (TEMPORARILY DISABLED FOR V1 TESTING)")
        // TEMPORARY GUARD: Return immediately so Flutter Dart background handler can take over
        return

        val data = extractFcmData(intent)
        if (data.isEmpty()) {
            Log.d(TAG, "Empty FCM data — skipping")
            return
        }
        if (!JobPayload.isJobMessage(data)) {
            Log.d(TAG, "Not a job message — keys=${data.keys}")
            return
        }

        if (isApplicationForeground(context)) {
            Log.d(TAG, "App foreground — Flutter handles popup")
            return
        }

        if (JobPayload.isAutoJob(context, data)) {
            Log.d(TAG, "Auto job — Flutter notification handles it")
            return
        }

        Log.d(TAG, "Manual job in background — launching overlay for ${JobPayload.extractBookingId(data)}")
        JobAlertNotifier.showIncomingJob(context, data)
    }

    private fun extractFcmData(intent: Intent): Map<String, String> {
        val extras: Bundle = intent.extras ?: return emptyMap()

        // Preferred: Firebase RemoteMessage parser.
        try {
            val remoteMessage = RemoteMessage(extras)
            if (remoteMessage.data.isNotEmpty()) {
                return remoteMessage.data
            }
        } catch (e: Exception) {
            Log.w(TAG, "RemoteMessage parse failed", e)
        }

        // Fallback: read string extras directly (works on some OEMs / payload shapes).
        val data = mutableMapOf<String, String>()
        for (key in extras.keySet()) {
            if (key == "from" ||
                key == "collapse_key" ||
                key.startsWith("google.") ||
                key.startsWith("gcm.")
            ) {
                continue
            }
            val value = extras.get(key)?.toString()?.trim().orEmpty()
            if (value.isNotEmpty()) {
                data[key] = value
            }
        }
        return data
    }

    private fun isApplicationForeground(context: Context): Boolean {
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val processes = manager.runningAppProcesses ?: return false
        for (process in processes) {
            if (process.processName == context.packageName) {
                return process.importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE
            }
        }
        return false
    }

    companion object {
        private const val TAG = "TapasyaJobReceiver"
    }
}
