package com.opc.stella

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.FileProvider
import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL

/**
 * DownloadService / 下载服务
 *
 * Background service for downloading APK files with progress notification.
 * 自动在下载完成后安装 APK。
 */
class DownloadService : Service() {

    companion object {
        private const val TAG = "DownloadService"
        private const val CHANNEL_ID = "app_update_download"
        private const val NOTIFICATION_ID = 9999

        // Intent extras
        const val EXTRA_DOWNLOAD_URL = "download_url"
        const val EXTRA_FILE_NAME = "file_name"

        // Actions
        const val ACTION_CANCEL = "com.opc.stella.DOWNLOAD_CANCEL"

        // Progress
        private const val UPDATE_INTERVAL = 500L // Update notification every 500ms
    }

    private var downloadUrl: String? = null
    private var fileName: String? = null
    private var outputFile: File? = null
    private var isDownloading = false
    private var shouldCancel = false

    private lateinit var notificationManager: NotificationManager
    private lateinit var notificationBuilder: NotificationCompat.Builder

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "DownloadService created")
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand called")

        when (intent?.action) {
            ACTION_CANCEL -> {
                Log.d(TAG, "Cancel action received")
                shouldCancel = true
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                // Start download
                downloadUrl = intent?.getStringExtra(EXTRA_DOWNLOAD_URL)
                fileName = intent?.getStringExtra(EXTRA_FILE_NAME) ?: "update.apk"

                if (downloadUrl.isNullOrEmpty()) {
                    Log.e(TAG, "Download URL is null or empty")
                    stopSelf()
                    return START_NOT_STICKY
                }

                Log.d(TAG, "Starting download from: $downloadUrl")
                isDownloading = true
                startDownload()
            }
        }

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?) = null

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "DownloadService destroyed")
        isDownloading = false
    }

    /**
     * Create notification channel for Android O+
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Update Download",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows progress of app update download"
                setShowBadge(false)
                setSound(null, null)
            }

            notificationManager.createNotificationChannel(channel)
        }
    }

    /**
     * Start the download process
     */
    private fun startDownload() {
        // Create initial notification
        notificationBuilder = createNotificationBuilder()

        // Start foreground service
        startForeground(NOTIFICATION_ID, notificationBuilder.build())

        // Start download in background thread
        Thread {
            try {
                downloadApk()
            } catch (e: Exception) {
                Log.e(TAG, "Download failed", e)
                onDownloadFailed(e.message ?: "Unknown error")
            }
        }.start()
    }

    /**
     * Download APK file with progress updates
     */
    private fun downloadApk() {
        val url = URL(downloadUrl)
        val connection = url.openConnection() as HttpURLConnection
        connection.connectTimeout = 30000
        connection.readTimeout = 30000
        connection.requestMethod = "GET"
        connection.connect()

        if (connection.responseCode != HttpURLConnection.HTTP_OK) {
            throw Exception("HTTP error code: ${connection.responseCode}")
        }

        val fileLength = connection.contentLength.toLong()
        Log.d(TAG, "File size: $fileLength bytes")

        // Get cache directory
        val cacheDir = externalCacheDir ?: cacheDir
        outputFile = File(cacheDir, fileName!!)
        Log.d(TAG, "Output file: ${outputFile?.absolutePath}")

        // Delete existing file if present
        if (outputFile?.exists() == true) {
            outputFile?.delete()
        }

        // Download file
        val input = BufferedInputStream(connection.inputStream)
        val output = FileOutputStream(outputFile)
        val data = ByteArray(8192)
        var total: Long = 0
        var count: Int
        var lastUpdateTime = 0L

        while (input.read(data).also { count = it } != -1) {
            if (shouldCancel) {
                Log.d(TAG, "Download cancelled by user")
                input.close()
                output.close()
                outputFile?.delete()
                stopSelf()
                return
            }

            total += count
            output.write(data, 0, count)

            // Update progress periodically
            val currentTime = System.currentTimeMillis()
            if (currentTime - lastUpdateTime > UPDATE_INTERVAL) {
                val progress = if (fileLength > 0) {
                    (total * 100 / fileLength).toInt()
                } else {
                    0
                }
                updateProgress(progress, total, fileLength)
                lastUpdateTime = currentTime
            }
        }

        // Flush and close streams
        output.flush()
        output.close()
        input.close()
        connection.disconnect()

        Log.d(TAG, "Download completed: ${outputFile?.absolutePath}, size: $total bytes")

        // Verify file was downloaded successfully
        if (outputFile?.exists() == true && outputFile?.length() ?: 0 > 0) {
            onDownloadComplete()
        } else {
            onDownloadFailed("Downloaded file is invalid")
        }
    }

    /**
     * Update download progress notification
     */
    private fun updateProgress(progress: Int, downloaded: Long, total: Long) {
        val downloadedMB = downloaded / (1024.0 * 1024.0)
        val totalMB = total / (1024.0 * 1024.0)
        val progressText = if (total > 0) {
            "%.1f MB / %.1f MB".format(downloadedMB, totalMB)
        } else {
            "%.1f MB".format(downloadedMB)
        }

        notificationBuilder
            .setProgress(100, progress, false)
            .setContentText("$progressText ($progress%)")

        notificationManager.notify(NOTIFICATION_ID, notificationBuilder.build())
    }

    /**
     * Handle download completion
     */
    private fun onDownloadComplete() {
        Log.d(TAG, "Download completed successfully")

        // Show completion notification
        notificationBuilder
            .setContentTitle("Download Complete")
            .setContentText("Installing update...")
            .setProgress(0, 0, false)
            .setOngoing(false)
            .setAutoCancel(false)

        notificationManager.notify(NOTIFICATION_ID, notificationBuilder.build())

        // Install APK
        installApk()

        // Stop service after a delay to allow notification to be seen
        Thread {
            Thread.sleep(3000)
            stopSelf()
        }.start()
    }

    /**
     * Handle download failure
     */
    private fun onDownloadFailed(error: String) {
        Log.e(TAG, "Download failed: $error")

        notificationBuilder
            .setContentTitle("Download Failed")
            .setContentText(error)
            .setProgress(0, 0, false)
            .setOngoing(false)
            .setAutoCancel(true)

        notificationManager.notify(NOTIFICATION_ID, notificationBuilder.build())

        // Clean up
        outputFile?.delete()
        stopSelf()
    }

    /**
     * Install the downloaded APK
     */
    private fun installApk() {
        try {
            val file = outputFile ?: run {
                Log.e(TAG, "Output file is null")
                return
            }

            if (!file.exists()) {
                Log.e(TAG, "APK file does not exist: ${file.absolutePath}")
                return
            }

            Log.d(TAG, "Installing APK: ${file.absolutePath}")

            val apkUri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                // Use FileProvider for Android N+
                FileProvider.getUriForFile(
                    this,
                    "${applicationContext.packageName}.fileprovider",
                    file
                )
            } else {
                // Use file:// URI for older versions
                Uri.fromFile(file)
            }

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(apkUri, "application/vnd.android.package-archive")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            startActivity(intent)

            Log.d(TAG, "Install intent launched")

        } catch (e: Exception) {
            Log.e(TAG, "Failed to install APK", e)
            onDownloadFailed("Installation failed: ${e.message}")
        }
    }

    /**
     * Create notification builder
     */
    private fun createNotificationBuilder(): NotificationCompat.Builder {
        val cancelIntent = Intent(this, DownloadService::class.java).apply {
            action = ACTION_CANCEL
        }

        val cancelPendingIntent = PendingIntent.getService(
            this,
            0,
            cancelIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Downloading Update")
            .setContentText("Starting download...")
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Cancel",
                cancelPendingIntent
            )
            .setPriority(NotificationCompat.PRIORITY_LOW)
    }
}
