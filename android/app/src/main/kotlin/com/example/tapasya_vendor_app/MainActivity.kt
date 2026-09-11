package com.example.tapasya_vendor_app

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        stopNativeJobSoundIfNeeded(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "stopJobSound" -> {
                    JobSoundPlayer.stopWithContext(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        stopFlutterJobSoundIfNeeded(intent)
        deliverJobRequestToFlutter(intent)
        deliverLaunchJobActionToFlutter(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        stopNativeJobSoundIfNeeded(intent)
        stopFlutterJobSoundIfNeeded(intent)
        deliverJobRequestToFlutter(intent)
        deliverLaunchJobActionToFlutter(intent)
    }

    override fun onResume() {
        super.onResume()
        stopNativeJobSoundIfNeeded(intent)
    }

    private fun stopNativeJobSoundIfNeeded(intent: Intent?) {
        if (intent?.getBooleanExtra(IncomingJobActivity.EXTRA_OPEN_JOB, false) == true) {
            JobSoundPlayer.stopWithContext(this)
            val bookingId = intent.getStringExtra(IncomingJobActivity.EXTRA_BOOKING_ID).orEmpty()
            if (bookingId.isNotEmpty()) {
                JobAlertNotifier.cancelJobAlert(this, bookingId)
            }
        }
    }

    private fun stopFlutterJobSoundIfNeeded(intent: Intent?) {
        if (intent?.getBooleanExtra(IncomingJobActivity.EXTRA_OPEN_JOB, false) != true) return
        val bookingId = intent.getStringExtra(IncomingJobActivity.EXTRA_BOOKING_ID).orEmpty()
        val channel = methodChannel ?: return
        Handler(Looper.getMainLooper()).post {
            channel.invokeMethod("stopJobAlertSound", bookingId)
        }
    }

    private fun deliverJobRequestToFlutter(intent: Intent?) {
        if (intent?.getBooleanExtra(EXTRA_SHOW_JOB_REQUEST, false) != true) return
        val bookingId = intent.getStringExtra(EXTRA_BOOKING_ID).orEmpty()
        val jobJson = intent.getStringExtra(EXTRA_JOB_DATA).orEmpty()
        if (bookingId.isEmpty()) return

        val channel = methodChannel ?: return
        Handler(Looper.getMainLooper()).post {
            channel.invokeMethod(
                "presentJobRequest",
                mapOf(
                    "booking_id" to bookingId,
                    "job_data_json" to jobJson,
                    "native_sound_active" to true,
                ),
            )
        }
        intent.removeExtra(EXTRA_SHOW_JOB_REQUEST)
    }

    /** Accept/Decline from native overlay — run before Home re-shows the job popup. */
    private fun deliverLaunchJobActionToFlutter(intent: Intent?) {
        if (intent?.getBooleanExtra(IncomingJobActivity.EXTRA_OPEN_JOB, false) != true) return
        val channel = methodChannel ?: return
        Handler(Looper.getMainLooper()).post {
            channel.invokeMethod("processLaunchJobAction", null)
        }
    }

    private var methodChannel: MethodChannel? = null

    companion object {
        private const val CHANNEL = "com.tapasya.vendor/native_job_alert"

        const val EXTRA_SHOW_JOB_REQUEST = "show_job_request"
        const val EXTRA_OPEN_JOB = "open_job_request"
        const val EXTRA_BOOKING_ID = "booking_id"
        const val EXTRA_JOB_DATA = "job_data_json"

        fun createJobRequestIntent(
            context: Context,
            data: Map<String, String>,
            bookingId: String,
        ): Intent {
            return Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                putExtra(EXTRA_SHOW_JOB_REQUEST, true)
                putExtra(EXTRA_BOOKING_ID, bookingId)
                putExtra(EXTRA_JOB_DATA, JSONObject(data).toString())
            }
        }
    }
}
