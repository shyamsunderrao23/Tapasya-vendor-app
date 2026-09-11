package com.example.tapasya_vendor_app

import android.content.Context
import org.json.JSONArray

object FlutterPrefs {
    private const val PREFS = "FlutterSharedPreferences"

    fun getString(context: Context, key: String): String? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return prefs.getString("flutter.$key", null)
    }

    fun getInt(context: Context, key: String, default: Int = 0): Int {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val flutterKey = "flutter.$key"
        val all = prefs.all
        val value = all[flutterKey] ?: return default
        return when (value) {
            is Int -> value
            is Long -> value.toInt()
            is String -> value.removePrefix("This is a prefix for an int.").toIntOrNull() ?: default
            else -> default
        }
    }

    fun putString(context: Context, key: String, value: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString("flutter.$key", value)
            .apply()
    }

    /** Sync with Flutter [NotificationHelper.markJobHandled]. */
    fun addHandledJobId(context: Context, bookingId: String) {
        if (bookingId.isBlank()) return
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val key = "flutter.handled_job_booking_ids"
        val existing = prefs.getString(key, null)
        val list = mutableListOf<String>()
        if (!existing.isNullOrBlank()) {
            try {
                val arr = JSONArray(existing)
                for (i in 0 until arr.length()) {
                    list.add(arr.getString(i))
                }
            } catch (_: Exception) {}
        }
        if (!list.contains(bookingId)) {
            list.add(bookingId)
            while (list.size > 50) list.removeAt(0)
            prefs.edit().putString(key, JSONArray(list).toString()).apply()
        }
    }
}
