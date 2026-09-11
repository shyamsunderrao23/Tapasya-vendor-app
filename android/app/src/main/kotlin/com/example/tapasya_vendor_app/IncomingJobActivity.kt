package com.example.tapasya_vendor_app

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.CountDownTimer
import android.os.Vibrator
import android.os.VibratorManager
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject

/**
 * Rapido-style overlay shown when a manual job arrives while the app is in the background.
 * Matches the in-app Flutter JobRequestScreen UI and loads full booking details from API.
 */
class IncomingJobActivity : Activity() {
    private var timer: CountDownTimer? = null
    private lateinit var bookingId: String
    private lateinit var jobData: Map<String, String>

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setupWindowFlags()
        setContentView(R.layout.activity_incoming_job)

        bookingId = intent.getStringExtra(EXTRA_BOOKING_ID).orEmpty()
        jobData = readJobData(intent)
        if (bookingId.isEmpty()) {
            finish()
            return
        }

        bindUiFromPayload()
        JobSoundPlayer.start(this)
        startTimer()
        cancelTrayNotification()
        fetchFullDetails()

        findViewById<Button>(R.id.btnAccept).setOnClickListener {
            stopAlertImmediately()
            clearPendingOnly()
            openFlutterJob(action = "accept")
        }
        findViewById<Button>(R.id.btnDecline).setOnClickListener {
            stopAlertImmediately()
            markJobHandled()
            openFlutterJob(action = "decline")
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val newId = intent.getStringExtra(EXTRA_BOOKING_ID).orEmpty()
        if (newId.isEmpty() || newId == bookingId) return
        bookingId = newId
        jobData = readJobData(intent)
        bindUiFromPayload()
        timer?.cancel()
        startTimer()
        JobSoundPlayer.start(this)
        cancelTrayNotification()
        fetchFullDetails()
        findViewById<Button>(R.id.btnAccept).isEnabled = true
        findViewById<Button>(R.id.btnDecline).isEnabled = true
    }

    private fun fetchFullDetails() {
        val fallback = BookingApiClient.BookingDetails(
            amount = JobPayload.amount(jobData),
            serviceName = JobPayload.serviceName(jobData),
            subService = "",
            customerName = JobPayload.customerName(jobData),
            address = JobPayload.address(jobData),
            timeSlot = JobPayload.timeSlot(jobData),
            distance = JobPayload.distance(jobData),
        )
        BookingApiClient.fetchBookingDetails(this, bookingId, fallback) { details ->
            if (isFinishing) return@fetchBookingDetails
            applyDetails(details)
        }
    }

    private fun bindUiFromPayload() {
        applyDetails(
            BookingApiClient.BookingDetails(
                amount = JobPayload.amount(jobData),
                serviceName = JobPayload.serviceName(jobData),
                subService = "",
                customerName = JobPayload.customerName(jobData),
                address = JobPayload.address(jobData),
                timeSlot = JobPayload.timeSlot(jobData),
                distance = JobPayload.distance(jobData),
            ),
        )
    }

    private fun applyDetails(details: BookingApiClient.BookingDetails) {
        val amountView = findViewById<TextView>(R.id.tvAmount)
        if (details.amount.isNotEmpty()) {
            amountView.text = "₹${details.amount}"
        } else {
            amountView.text = details.serviceName
        }

        val serviceView = findViewById<TextView>(R.id.tvService)
        val serviceLine = when {
            details.subService.isNotEmpty() -> details.subService
            details.amount.isNotEmpty() -> details.serviceName
            else -> ""
        }
        if (serviceLine.isNotEmpty()) {
            serviceView.visibility = View.VISIBLE
            serviceView.text = serviceLine
        } else {
            serviceView.visibility = View.GONE
        }

        findViewById<TextView>(R.id.tvCustomer).text = details.customerName
        findViewById<TextView>(R.id.tvLocation).text = details.address

        val distanceLabel = findViewById<TextView>(R.id.tvDistanceLabel)
        val distanceView = findViewById<TextView>(R.id.tvDistance)
        if (details.distance.isNotEmpty()) {
            distanceLabel.visibility = View.VISIBLE
            distanceView.visibility = View.VISIBLE
            distanceView.text = details.distance
        } else {
            distanceLabel.visibility = View.GONE
            distanceView.visibility = View.GONE
        }

        val slotLabel = findViewById<TextView>(R.id.tvTimeSlotLabel)
        val slotView = findViewById<TextView>(R.id.tvTimeSlot)
        if (details.timeSlot.isNotEmpty()) {
            slotLabel.visibility = View.VISIBLE
            slotView.visibility = View.VISIBLE
            slotView.text = details.timeSlot
        } else {
            slotLabel.visibility = View.GONE
            slotView.visibility = View.GONE
        }
    }

    private fun stopAlertImmediately() {
        findViewById<Button>(R.id.btnAccept).isEnabled = false
        findViewById<Button>(R.id.btnDecline).isEnabled = false
        timer?.cancel()
        timer = null
        JobSoundPlayer.stopWithContext(this)
        cancelVibration()
        cancelTrayNotification()
    }

    private fun cancelVibration() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(VibratorManager::class.java)
                vm?.defaultVibrator?.cancel()
            } else {
                @Suppress("DEPRECATION")
                (getSystemService(VIBRATOR_SERVICE) as? Vibrator)?.cancel()
            }
        } catch (_: Exception) {}
    }

    private fun setupWindowFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguard = getSystemService(KEYGUARD_SERVICE) as KeyguardManager
            keyguard.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun startTimer() {
        val timerView = findViewById<TextView>(R.id.tvTimer)
        timer = object : CountDownTimer(TIMER_SECONDS * 1000L, 1000L) {
            override fun onTick(millisUntilFinished: Long) {
                val seconds = (millisUntilFinished / 1000L).toInt()
                timerView.text = "${seconds}s"
                timerView.setTextColor(
                    if (seconds <= 3) 0xFFDC2626.toInt() else 0xFF15803D.toInt(),
                )
            }

            override fun onFinish() {
                JobSoundPlayer.stop()
                finish()
            }
        }.start()
    }

    private fun cancelTrayNotification() {
        JobAlertNotifier.cancelJobAlert(this, bookingId)
    }

    private fun markJobHandled() {
        FlutterPrefs.addHandledJobId(this, bookingId)
        clearPendingOnly()
    }

    private fun clearPendingOnly() {
        getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            .edit()
            .remove("flutter.pending_job_alert")
            .apply()
    }

    private fun openFlutterJob(action: String) {
        stopAlertImmediately()
        clearPendingOnly()

        val payload = JSONObject()
        payload.put("type", "manual")
        payload.put("booking_id", bookingId)
        payload.put("data", JSONObject(jobData))

        val wrapper = JSONObject()
        wrapper.put("payload", payload.toString())
        wrapper.put("actionId", action)
        FlutterPrefs.putString(this, "launch_job_payload", wrapper.toString())

        val mainIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(EXTRA_OPEN_JOB, true)
            putExtra(EXTRA_BOOKING_ID, bookingId)
        }
        startActivity(mainIntent)
        finish()
    }

    override fun onDestroy() {
        timer?.cancel()
        JobSoundPlayer.stopWithContext(this)
        cancelVibration()
        cancelTrayNotification()
        super.onDestroy()
    }

    companion object {
        const val EXTRA_BOOKING_ID = "booking_id"
        const val EXTRA_JOB_DATA = "job_data_json"
        const val EXTRA_OPEN_JOB = "open_job_request"
        private const val TIMER_SECONDS = 10

        fun createIntent(context: Context, data: Map<String, String>, bookingId: String): Intent {
            return Intent(context, IncomingJobActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
                putExtra(EXTRA_BOOKING_ID, bookingId)
                putExtra(EXTRA_JOB_DATA, JSONObject(data).toString())
            }
        }

        private fun readJobData(intent: Intent): Map<String, String> {
            val json = intent.getStringExtra(EXTRA_JOB_DATA).orEmpty()
            if (json.isEmpty()) return emptyMap()
            val map = mutableMapOf<String, String>()
            val obj = JSONObject(json)
            for (key in obj.keys()) {
                map[key] = obj.optString(key)
            }
            return map
        }
    }
}
