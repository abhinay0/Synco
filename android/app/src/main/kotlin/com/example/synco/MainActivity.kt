package com.example.synco

import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import com.yausername.aria2c.Aria2c
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLException
import com.yausername.youtubedl_android.YoutubeDLRequest
import com.yausername.youtubedl_android.YoutubeDLResponse
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "synco/ytdlp"
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var isInitialized = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        // Initialize YoutubeDL, FFmpeg, and Aria2c asynchronously on startup
        scope.launch(Dispatchers.IO) {
            try {
                YoutubeDL.init(applicationContext)
                FFmpeg.init(applicationContext)
                Aria2c.init(applicationContext)
                isInitialized = true
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    scope.launch(Dispatchers.IO) {
                        try {
                            YoutubeDL.init(applicationContext)
                            FFmpeg.init(applicationContext)
                            Aria2c.init(applicationContext)
                            isInitialized = true
                            withContext(Dispatchers.Main) { result.success(true) }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) { result.error("INIT_ERROR", e.message, null) }
                        }
                    }
                }

                "execute" -> {
                    val taskId = call.argument<String>("taskId") ?: ""
                    val url = call.argument<String>("url") ?: ""
                    val args = call.argument<List<String>>("args") ?: emptyList()

                    scope.launch(Dispatchers.IO) {
                        try {
                            if (!isInitialized) {
                                YoutubeDL.init(applicationContext)
                                FFmpeg.init(applicationContext)
                                Aria2c.init(applicationContext)
                                isInitialized = true
                            }

                            val request = if (url.isNotEmpty()) YoutubeDLRequest(url) else YoutubeDLRequest(emptyList())
                            for (arg in args) {
                                if (arg != url) {
                                    request.addOption(arg)
                                }
                            }

                            val response = YoutubeDL.getInstance().execute(request, taskId) { progress, eta, line ->
                                mainHandler.post {
                                    channel.invokeMethod(
                                        "onProgress",
                                        mapOf(
                                            "taskId" to taskId,
                                            "progress" to progress.toDouble(),
                                            "eta" to eta.toLong(),
                                            "line" to line
                                        )
                                    )
                                }
                            }

                            withContext(Dispatchers.Main) {
                                result.success(
                                    mapOf(
                                        "exitCode" to 0,
                                        "out" to (response.out ?: ""),
                                        "err" to (response.err ?: "")
                                    )
                                )
                            }
                        } catch (e: YoutubeDL.CanceledException) {
                            withContext(Dispatchers.Main) {
                                result.success(
                                    mapOf(
                                        "exitCode" to -1,
                                        "out" to "",
                                        "err" to "Download cancelled"
                                    )
                                )
                            }
                        } catch (e: Throwable) {
                            e.printStackTrace()
                            withContext(Dispatchers.Main) {
                                result.success(
                                    mapOf(
                                        "exitCode" to 1,
                                        "out" to "",
                                        "err" to (e.message ?: e.toString())
                                    )
                                )
                            }
                        }
                    }
                }

                "cancel" -> {
                    val taskId = call.argument<String>("taskId") ?: ""
                    if (taskId.isNotEmpty()) {
                        scope.launch(Dispatchers.IO) {
                            try {
                                YoutubeDL.getInstance().destroyProcessById(taskId)
                            } catch (_: Exception) {}
                        }
                    }
                    result.success(true)
                }

                "getInfo" -> {
                    val url = call.argument<String>("url") ?: ""
                    scope.launch(Dispatchers.IO) {
                        try {
                            if (!isInitialized) {
                                YoutubeDL.init(applicationContext)
                                FFmpeg.init(applicationContext)
                                Aria2c.init(applicationContext)
                                isInitialized = true
                            }

                            val request = YoutubeDLRequest(url).apply {
                                addOption("--dump-single-json")
                                addOption("--socket-timeout", "12")
                                addOption("-R", "2")
                                addOption("--no-warnings")
                            }
                            val response = YoutubeDL.getInstance().execute(request, null, null)
                            withContext(Dispatchers.Main) {
                                result.success(response.out ?: "")
                            }
                        } catch (e: Throwable) {
                            withContext(Dispatchers.Main) {
                                result.error("INFO_ERROR", e.message, null)
                            }
                        }
                    }
                }

                "getYtDlpVersion" -> {
                    try {
                        val version = YoutubeDL.getInstance().version(applicationContext)
                        result.success(version)
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }

                "updateYtDlp" -> {
                    scope.launch(Dispatchers.IO) {
                        try {
                            val status = YoutubeDL.getInstance().updateYoutubeDL(applicationContext, YoutubeDL.UpdateChannel.STABLE)
                            val version = YoutubeDL.getInstance().version(applicationContext)
                            withContext(Dispatchers.Main) {
                                result.success(
                                    mapOf(
                                        "status" to (status?.name ?: "UNKNOWN"),
                                        "version" to (version ?: "")
                                    )
                                )
                            }
                        } catch (e: Throwable) {
                            withContext(Dispatchers.Main) {
                                result.error("UPDATE_ERROR", e.message, null)
                            }
                        }
                    }
                }

                "getDownloadDirectory" -> {
                    try {
                        val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "Synco")
                        if (!dir.exists()) dir.mkdirs()
                        result.success(dir.absolutePath)
                    } catch (e: Exception) {
                        result.error("DIR_ERROR", e.message, null)
                    }
                }

                "scanFile" -> {
                    val path = call.argument<String>("path") ?: ""
                    if (path.isNotEmpty()) {
                        MediaScannerConnection.scanFile(applicationContext, arrayOf(path), null, null)
                    }
                    result.success(true)
                }

                "installApk" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    try {
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "APK file does not exist at $filePath", null)
                            return@setMethodCallHandler
                        }
                        val contentUri = FileProvider.getUriForFile(
                            this@MainActivity,
                            "${applicationContext.packageName}.provider",
                            file
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            setDataAndType(contentUri, "application/vnd.android.package-archive")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Throwable) {
                        e.printStackTrace()
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
