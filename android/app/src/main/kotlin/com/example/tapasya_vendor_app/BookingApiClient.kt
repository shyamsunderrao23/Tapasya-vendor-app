package com.example.tapasya_vendor_app

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

object BookingApiClient {
    private const val TAG = "BookingApiClient"
    private const val BASE_URL = "https://tapasyaserver.sreerasthusilvers.co.in/api"

    data class BookingDetails(
        val amount: String,
        val serviceName: String,
        val subService: String,
        val customerName: String,
        val address: String,
        val timeSlot: String,
        val distance: String,
    )

    fun fetchBookingDetails(
        context: Context,
        bookingId: String,
        fallback: BookingDetails,
        callback: (BookingDetails) -> Unit,
    ) {
        val token = FlutterPrefs.getString(context, "auth_token")
        if (token.isNullOrBlank()) {
            callback(fallback)
            return
        }

        Thread {
            val details = try {
                val url = URL("$BASE_URL/admin/bookings/$bookingId")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    setRequestProperty("Accept", "application/json")
                    setRequestProperty("Authorization", "Bearer $token")
                    connectTimeout = 15_000
                    readTimeout = 15_000
                }
                if (conn.responseCode == HttpURLConnection.HTTP_OK) {
                    val body = conn.inputStream.bufferedReader().readText()
                    parseBookingJson(body, fallback)
                } else {
                    Log.w(TAG, "HTTP ${conn.responseCode} for booking $bookingId")
                    fallback
                }
            } catch (e: Exception) {
                Log.e(TAG, "fetch failed", e)
                fallback
            }

            Handler(Looper.getMainLooper()).post { callback(details) }
        }.start()
    }

    private fun parseBookingJson(body: String, fallback: BookingDetails): BookingDetails {
        val root = JSONObject(body)
        val booking = when {
            root.optJSONObject("booking") != null -> root.getJSONObject("booking")
            root.optJSONObject("data") != null -> root.getJSONObject("data")
            else -> root
        }

        val amount = firstNonBlank(
            booking,
            listOf("amount", "price", "total_amount", "service_charge", "final_amount"),
            fallback.amount,
        )

        val customerName = firstNonBlank(
            booking,
            listOf("user_name", "customer_name", "full_name", "name"),
            fallback.customerName,
        )

        val addressObj = booking.opt("address") ?: booking.opt("location") ?: booking.opt("addr")
        val address = when (addressObj) {
            is JSONObject -> firstNonBlank(
                addressObj,
                listOf("address_line1", "address", "formatted_address"),
                fallback.address,
            )
            is String -> addressObj.ifBlank { fallback.address }
            else -> firstNonBlank(
                booking,
                listOf("formatted_address", "address_line1", "address", "pickup_address"),
                fallback.address,
            )
        }

        val timeSlot = firstNonBlank(
            booking,
            listOf("time_slot", "slot", "booking_time"),
            fallback.timeSlot,
        )

        val distanceRaw = firstNonBlank(
            booking,
            listOf("distance_km", "pickup_distance", "distance"),
            fallback.distance,
        )
        val distance = when {
            distanceRaw.isBlank() -> ""
            distanceRaw.contains("km", ignoreCase = true) -> distanceRaw
            else -> "$distanceRaw km away"
        }

        var mainService = fallback.serviceName
        var subService = fallback.subService
        val services = booking.optJSONArray("services")
            ?: booking.optJSONArray("services_list")
            ?: booking.optJSONArray("service_details")
        if (services != null && services.length() > 0) {
            val first = services.getJSONObject(0)
            mainService = firstNonBlank(first, listOf("service_name", "service"), mainService)
            subService = firstNonBlank(first, listOf("sub_service_name", "sub_service"), subService)
        } else {
            mainService = firstNonBlank(
                booking,
                listOf("service_name", "service", "category"),
                mainService,
            )
            subService = firstNonBlank(
                booking,
                listOf("sub_service_name", "sub_service", "task"),
                subService,
            )
        }

        return BookingDetails(
            amount = amount,
            serviceName = mainService,
            subService = subService,
            customerName = customerName,
            address = address,
            timeSlot = timeSlot,
            distance = distance,
        )
    }

    private fun firstNonBlank(obj: JSONObject, keys: List<String>, fallback: String): String {
        for (key in keys) {
            val value = obj.optString(key, "").trim()
            if (value.isNotEmpty()) return value
        }
        return fallback
    }
}
