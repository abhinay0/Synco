package com.example.synco

import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.FileProvider
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
import java.util.concurrent.atomic.AtomicInteger

class MainActivity : FlutterActivity() {
    private val CHANNEL = "synco/ytdlp"
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val activeTasks = AtomicInteger(0)

    private val booleanFlags = setOf(
        "-x", "-4", "-6", "--newline", "--no-mtime", "--restrict-filenames",
        "--embed-metadata", "--embed-thumbnail", "--add-metadata", "--embed-chapters",
        "--embed-subs", "--write-auto-subs", "--split-chapters", "--no-playlist",
        "--flat-playlist", "--dump-single-json", "--dump-json", "--no-warnings",
        "--audio-multistreams", "--write-subs", "--write-thumbnail"
    )

    private fun ensureNativeInit(): Boolean {
        return SyncoApp.initializeEngine(applicationContext)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        // Initialize YoutubeDL, FFmpeg, and Aria2c asynchronously on startup
        scope.launch(Dispatchers.IO) {
            ensureNativeInit()
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    scope.launch(Dispatchers.IO) {
                        val success = ensureNativeInit()
                        withContext(Dispatchers.Main) {
                            if (success) {
                                result.success(true)
                            } else {
                                val err = SyncoApp.engineInitError ?: "Failed to initialize native extractor engine"
                                result.error("INIT_ERROR", err, null)
                            }
                        }
                    }
                }

                "startForegroundService" -> {
                    DownloadService.start(applicationContext)
                    result.success(true)
                }

                "stopForegroundService" -> {
                    DownloadService.stop(applicationContext)
                    result.success(true)
                }

                "execute" -> {
                    val taskId = call.argument<String>("taskId") ?: ""
                    val url = call.argument<String>("url") ?: ""
                    val args = call.argument<List<String>>("args") ?: emptyList()

                    scope.launch(Dispatchers.IO) {
                        // Start foreground service to guarantee background networking and avoid Doze socket death
                        if (activeTasks.incrementAndGet() == 1) {
                            DownloadService.start(applicationContext)
                        }

                        try {
                            if (!ensureNativeInit()) {
                                val err = SyncoApp.engineInitError ?: "Extractor engine failed to initialize"
                                withContext(Dispatchers.Main) {
                                    result.success(
                                        mapOf(
                                            "exitCode" to 1,
                                            "out" to "",
                                            "err" to err
                                        )
                                    )
                                }
                                return@launch
                            }

                            val request = if (url.isNotEmpty()) YoutubeDLRequest(url) else YoutubeDLRequest(emptyList())

                            // Build paired options accurately to prevent argument duplication or skipping
                            var i = 0
                            while (i < args.size) {
                                val arg = args[i]
                                if (arg == url) {
                                    i++
                                    continue
                                }
                                if (arg.startsWith("-")) {
                                    if (!booleanFlags.contains(arg) && i + 1 < args.size && args[i + 1] != url) {
                                        request.addOption(arg, args[i + 1])
                                        i += 2
                                    } else {
                                        request.addOption(arg)
                                        i++
                                    }
                                } else {
                                    i++
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
                        } catch (e: YoutubeDLException) {
                            Log.e("MainActivity", "YoutubeDL error for task $taskId", e)
                            withContext(Dispatchers.Main) {
                                result.success(
                                    mapOf(
                                        "exitCode" to 1,
                                        "out" to "",
                                        "err" to (e.message ?: e.toString())
                                    )
                                )
                            }
                        } catch (e: Throwable) {
                            Log.e("MainActivity", "Execution error for task $taskId", e)
                            withContext(Dispatchers.Main) {
                                result.success(
                                    mapOf(
                                        "exitCode" to 1,
                                        "out" to "",
                                        "err" to (e.message ?: e.toString())
                                    )
                                )
                            }
                        } finally {
                            if (activeTasks.decrementAndGet() <= 0) {
                                DownloadService.stop(applicationContext)
                            }
                        }
                    }
                }

                "cancel" -> {
                    val taskId = call.argument<String>("taskId") ?: ""
                    scope.launch(Dispatchers.IO) {
                        try {
                            if (taskId.isNotEmpty()) {
                                YoutubeDL.getInstance().destroyProcessById(taskId)
                            }
                        } catch (e: Throwable) {
                            Log.e("MainActivity", "Failed to cancel task $taskId", e)
                        }
                    }
                    result.success(true)
                }

                "getInfo" -> {
                    val url = call.argument<String>("url") ?: ""
                    scope.launch(Dispatchers.IO) {
                        try {
                            if (!ensureNativeInit()) {
                                withContext(Dispatchers.Main) {
                                    result.error("INIT_ERROR", "Extractor engine not initialized", null)
                                }
                                return@launch
                            }

                            val request = YoutubeDLRequest(url).apply {
                                addOption("--dump-single-json")
                                addOption("--no-playlist")
                                addOption("--socket-timeout", "10")
                                addOption("-R", "2")
                                addOption("--no-warnings")
                                addOption("--extractor-args", "youtube:player_client=ios,web,mweb;skip=translated_subs")
                            }
                            val response = YoutubeDL.getInstance().execute(request, null, null)
                            withContext(Dispatchers.Main) {
                                result.success(response.out ?: "")
                            }
                        } catch (e: Throwable) {
                            Log.e("MainActivity", "getInfo error", e)
                            withContext(Dispatchers.Main) {
                                result.error("INFO_ERROR", e.message ?: e.toString(), null)
                            }
                        }
                    }
                }

                "getYtDlpVersion" -> {
                    scope.launch(Dispatchers.IO) {
                        try {
                            ensureNativeInit()
                            val version = YoutubeDL.getInstance().version(applicationContext)
                            withContext(Dispatchers.Main) {
                                result.success(version)
                            }
                        } catch (e: Throwable) {
                            withContext(Dispatchers.Main) {
                                result.success(null)
                            }
                        }
                    }
                }

                "updateYtDlp" -> {
                    scope.launch(Dispatchers.IO) {
                        try {
                            ensureNativeInit()
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
                                result.error("UPDATE_ERROR", e.message ?: e.toString(), null)
                            }
                        }
                    }
                }

                "getDownloadDirectory" -> {
                    try {
                        val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "Synco")
                        if (!dir.exists()) dir.mkdirs()
                        result.success(dir.absolutePath)
                    } catch (e: Throwable) {
                        result.error("DIR_ERROR", e.message ?: e.toString(), null)
                    }
                }

                "scanFile" -> {
                    val path = call.argument<String>("path") ?: ""
                    if (path.isNotEmpty()) {
                        try {
                            MediaScannerConnection.scanFile(applicationContext, arrayOf(path), null, null)
                        } catch (e: Throwable) {
                            e.printStackTrace()
                        }
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
                        result.error("INSTALL_ERROR", e.message ?: e.toString(), null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
