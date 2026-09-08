package com.tyreest.kira_artisi_hesapla

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val backupChannel = "com.tyreest.kiraartisi/backup_files"
    private var pendingPickResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, backupChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickBackupJson" -> {
                        if (pendingPickResult != null) {
                            result.error("busy", "Dosya seçici zaten açık", null)
                            return@setMethodCallHandler
                        }
                        pendingPickResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/json"
                            putExtra(
                                Intent.EXTRA_MIME_TYPES,
                                arrayOf("application/json", "text/plain", "*/*"),
                            )
                        }
                        startActivityForResult(intent, REQUEST_PICK_BACKUP)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_PICK_BACKUP) return
        val reply = pendingPickResult
        pendingPickResult = null
        if (reply == null) return
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            reply.success(null)
            return
        }
        try {
            val uri = data.data!!
            val name = queryDisplayName(uri)
            val size = querySize(uri)
            if (size != null && size > MAX_BACKUP_BYTES) {
                reply.error(
                    "too_large",
                    "Yedek dosyası çok büyük (en fazla 2 MB).",
                    null,
                )
                return
            }
            val bytes = contentResolver.openInputStream(uri)?.use { input ->
                val out = ByteArrayOutputStream()
                val buf = ByteArray(8192)
                var total = 0
                while (true) {
                    val n = input.read(buf)
                    if (n < 0) break
                    total += n
                    if (total > MAX_BACKUP_BYTES) {
                        reply.error(
                            "too_large",
                            "Yedek dosyası çok büyük (en fazla 2 MB).",
                            null,
                        )
                        return
                    }
                    out.write(buf, 0, n)
                }
                out.toByteArray()
            }
            if (bytes == null) {
                reply.success(null)
                return
            }
            reply.success(
                mapOf(
                    "bytes" to bytes,
                    "name" to (name ?: "yedek.json"),
                ),
            )
        } catch (e: Exception) {
            reply.error("read_failed", e.message, null)
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) {
                return cursor.getString(index)
            }
        }
        return uri.lastPathSegment
    }

    private fun querySize(uri: Uri): Long? {
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.SIZE)
            if (index >= 0 && cursor.moveToFirst() && !cursor.isNull(index)) {
                return cursor.getLong(index)
            }
        }
        return null
    }

    companion object {
        private const val REQUEST_PICK_BACKUP = 9917
        private const val MAX_BACKUP_BYTES = 2 * 1024 * 1024
    }
}
