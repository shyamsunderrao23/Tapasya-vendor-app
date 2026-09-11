package com.example.tapasya_vendor_app

import android.content.Context

object JobPayload {
    fun extractBookingId(data: Map<String, String>): String? {
        val keys = listOf("booking_id", "bookingId", "id", "job_id")
        for (key in keys) {
            val value = data[key]?.trim()
            if (!value.isNullOrEmpty()) return value
        }
        return null
    }

    fun isAutoJob(context: Context, data: Map<String, String>): Boolean {
        val type = data["type"]?.lowercase().orEmpty()
        if (type == "job_assigned") return true

        val mode = (data["mode"] ?: data["job_mode"] ?: "manual").lowercase()
        if (mode == "auto" || mode == "assigned" || mode == "automatic") return true

        val vendorMode = FlutterPrefs.getString(context, "vendor_job_mode")?.lowercase() ?: "manual"
        return vendorMode == "auto"
    }

    fun isJobMessage(data: Map<String, String>): Boolean {
        if (extractBookingId(data) != null) return true
        val type = data["type"]?.lowercase().orEmpty()
        return type.contains("job") || type.contains("booking")
    }

    fun canReceiveJobAlert(context: Context): Boolean {
        val token = FlutterPrefs.getString(context, "auth_token")
        if (token.isNullOrBlank()) return false
        return FlutterPrefs.getInt(context, "vendor_active_status", 0) == 1
    }

    fun customerName(data: Map<String, String>): String =
        data["user_name"] ?: data["customer_name"] ?: data["name"] ?: "Customer"

    fun serviceName(data: Map<String, String>): String {
        val main = data["service_name"] ?: data["service"] ?: "Service Request"
        val sub = data["sub_service_name"] ?: data["sub_service"]
        return if (!sub.isNullOrBlank()) "$main — $sub" else main
    }

    fun address(data: Map<String, String>): String =
        data["address"] ?: data["pickup_address"] ?: data["formatted_address"] ?: "Location pending..."

    fun distance(data: Map<String, String>): String {
        val raw = data["distance_km"] ?: data["distance"] ?: data["pickup_distance"] ?: return ""
        return if (raw.contains("km", ignoreCase = true)) raw else "$raw km away"
    }

    fun timeSlot(data: Map<String, String>): String =
        data["time_slot"] ?: data["slot"] ?: data["booking_time"] ?: ""

    fun amount(data: Map<String, String>): String =
        data["amount"] ?: data["price"] ?: data["total_amount"] ?: ""
}
