package com.example.tapasya_vendor_app

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.util.Log

/** Shared looping job alert sound — must stop instantly on Accept / Decline. */
object JobSoundPlayer {
    private const val TAG = "JobSoundPlayer"
    private var player: MediaPlayer? = null

    fun start(context: Context) {
        stop()
        try {
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            player = MediaPlayer.create(context.applicationContext, R.raw.new_job_alert)?.apply {
                setAudioAttributes(attrs)
                isLooping = true
                setVolume(1f, 1f)
                start()
            }
            Log.d(TAG, "sound started")
        } catch (e: Exception) {
            Log.e(TAG, "start failed", e)
        }
    }

    /** Stop and release immediately — safe to call multiple times. */
    fun stop() {
        val current = player
        player = null
        if (current == null) return
        try {
            if (current.isPlaying) {
                current.pause()
            }
        } catch (_: Exception) {}
        try {
            current.stop()
        } catch (_: Exception) {}
        try {
            current.reset()
        } catch (_: Exception) {}
        try {
            current.release()
        } catch (_: Exception) {}
        Log.d(TAG, "sound stopped")
    }

    fun stopWithContext(context: Context) {
        stop()
        try {
            val am = context.applicationContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            @Suppress("DEPRECATION")
            am.abandonAudioFocus(null)
        } catch (_: Exception) {}
    }
}
