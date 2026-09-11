package com.example.tapasya_vendor_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONObject

object JobAlertNotifier {
    private const val TAG = "JobAlertNotifier"
    private const val CHANNEL_ID = "new_job_channel_v4"
    private const val NOTIFICATION_TAG = "tapasya_job_alert"

    fun showIncomingJob(context: Context, data: Map<String, String>) {
        val appContext = context.applicationContext
        val bookingId = JobPayload.extractBookingId(data) ?: return

        if (!JobPayload.canReceiveJobAlert(appContext)) {
            Log.d(TAG, "Blocked — vendor offline or logged out")
            return
        }

        if (JobPayload.isAutoJob(appContext, data)) {
            Log.d(TAG, "Auto job — let Flutter notification handle it")
            return
        }

        JobSoundPlayer.start(appContext)

        val activityIntent = IncomingJobActivity.createIntent(appContext, data, bookingId).apply {
            addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        }
        var activityStarted = false
        try {
            appContext.startActivity(activityIntent)
            activityStarted = true
            Log.d(TAG, "Launched IncomingJobActivity for $bookingId")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch IncomingJobActivity", e)
        }

        if (!activityStarted) {
            val flutterIntent = MainActivity.createJobRequestIntent(appContext, data, bookingId)
            try {
                appContext.startActivity(flutterIntent)
                activityStarted = true
                Log.d(TAG, "Fallback MainActivity job popup for $bookingId")
            } catch (e: Exception) {
                Log.e(TAG, "Failed fallback MainActivity launch", e)
            }
        }

        if (!activityStarted) {
            savePendingJob(appContext, bookingId, data)
            showFullScreenNotification(appContext, data, bookingId, activityIntent)
        }
    }

    /** Remove the job notification from the status bar (Accept / Decline / dismiss). */
    fun cancelJobAlert(context: Context, bookingId: String) {
        if (bookingId.isEmpty()) return
        try {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(NOTIFICATION_TAG, bookingId.hashCode())
            manager.cancel(bookingId.hashCode())
            Log.d(TAG, "Cancelled notification for $bookingId")
        } catch (e: Exception) {
            Log.e(TAG, "cancelJobAlert failed", e)
        }
    }

    private fun savePendingJob(context: Context, bookingId: String, data: Map<String, String>) {
        try {
            val payload = JSONObject()
            payload.put("booking_id", bookingId)
            payload.put("data", JSONObject(data))
            payload.put("isAuto", false)
            payload.put("savedAt", System.currentTimeMillis())
            FlutterPrefs.putString(context, "pending_job_alert", payload.toString())
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save pending job", e)
        }
    }

    private fun showFullScreenNotification(
        context: Context,
        data: Map<String, String>,
        bookingId: String,
        fullScreenIntent: Intent,
    ) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(context, manager)

        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val fullScreenPending = PendingIntent.getActivity(context, bookingId.hashCode(), fullScreenIntent, pendingFlags)
        val contentPending = PendingIntent.getActivity(context, bookingId.hashCode() + 1, fullScreenIntent, pendingFlags)

        val amount = JobPayload.amount(data)
        val title = if (amount.isNotEmpty()) "₹$amount — New Job" else "New Job Request"
        val body = "${JobPayload.serviceName(data)}\n${JobPayload.address(data)}\nTap to Accept or Decline"

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(contentPending)
            .setFullScreenIntent(fullScreenPending, true)
            .setSound(Uri.parse("android.resource://${context.packageName}/${R.raw.new_job_alert}"))
            .setVibrate(longArrayOf(0, 800, 200, 800, 200, 800))
            .build()

        manager.notify(NOTIFICATION_TAG, bookingId.hashCode(), notification)
    }

    private fun ensureChannel(context: Context, manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val soundUri = Uri.parse("android.resource://${context.packageName}/${R.raw.new_job_alert}")
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val channel = NotificationChannel(
            CHANNEL_ID,
            "New Job Alerts",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Loud alerts for new job requests."
            setSound(soundUri, attrs)
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 800, 200, 800, 200, 800)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }
}
