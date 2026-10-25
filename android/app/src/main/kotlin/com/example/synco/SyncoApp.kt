package com.example.synco

import android.util.Log
import com.yausername.aria2c.Aria2c
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import io.flutter.app.FlutterApplication
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class SyncoApp : FlutterApplication() {
    companion object {
        private const val TAG = "SyncoApp"
        @Volatile
        var isEngineInitialized = false
        @Volatile
        var engineInitError: String? = null
        private val lock = Any()

        fun initializeEngine(appContext: android.content.Context): Boolean {
            if (isEngineInitialized) return true
            return synchronized(lock) {
                if (isEngineInitialized) return true
                try {
                    YoutubeDL.init(appContext)
                    FFmpeg.init(appContext)
                    Aria2c.init(appContext)
                    isEngineInitialized = true
                    engineInitError = null
                    Log.i(TAG, "YoutubeDL, FFmpeg, and Aria2c successfully initialized")

                    // Asynchronously fetch latest yt-dlp core updates in background
                    CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
                        try {
                            YoutubeDL.getInstance().updateYoutubeDL(appContext, YoutubeDL.UpdateChannel.STABLE)
                            Log.i(TAG, "yt-dlp core updated to latest stable release")
                        } catch (t: Throwable) {
                            Log.w(TAG, "yt-dlp background update deferred: ${t.message}")
                        }
                    }
                    true
                } catch (t: Throwable) {
                    engineInitError = t.message ?: t.toString()
                    Log.e(TAG, "Failed to initialize native extractor engine", t)
                    false
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            initializeEngine(this@SyncoApp)
        }
    }
}
