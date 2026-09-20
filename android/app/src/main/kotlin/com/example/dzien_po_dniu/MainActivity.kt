package com.example.dzien_po_dniu

import android.content.Intent
import android.content.Context
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.Locale
import java.util.zip.ZipInputStream

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "installZip") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.error("missing_path", "Brakuje ścieżki paczki aktualizacji.", null)
                    return@setMethodCallHandler
                }
                try {
                    openApkInstaller(extractApk(File(path)))
                    result.success(null)
                } catch (error: Exception) {
                    result.error("install_failed", error.message, null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGETS_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "updateWidgets") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    updateWidgetSnapshot(call.arguments as? Map<*, *>)
                    result.success(null)
                } catch (error: Exception) {
                    result.error("widgets_update_failed", error.message, null)
                }
            }
    }

    private fun updateWidgetSnapshot(arguments: Map<*, *>?) {
        val payload = arguments ?: emptyMap<Any, Any>()
        val tasks = payload["tasks"] as? List<*> ?: emptyList<Any>()
        val tasksJson = JSONArray().apply {
            tasks.forEach { rawTask ->
                val task = rawTask as? Map<*, *> ?: return@forEach
                put(
                    JSONObject().apply {
                        put("id", task["id"]?.toString() ?: "")
                        put("title", task["title"]?.toString() ?: "")
                    },
                )
            }
        }.toString()
        val note = payload["selectedNote"] as? Map<*, *>
        getSharedPreferences(WIDGETS_PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putInt("remainingTaskCount", (payload["remainingTaskCount"] as? Number)?.toInt() ?: 0)
            .putString("tasksJson", tasksJson)
            .putString("noteId", note?.get("id")?.toString().orEmpty())
            .putString("noteTitle", note?.get("title")?.toString().orEmpty())
            .putString("notePreview", note?.get("preview")?.toString().orEmpty())
            .apply()

        TodayWidgetProvider.updateAll(this)
        SelectedNoteWidgetProvider.updateAll(this)
    }

    private fun extractApk(zipFile: File): File {
        require(zipFile.isFile) { "Nie znaleziono pobranej paczki aktualizacji." }
        val updatesDirectory = File(cacheDir, "updates").apply { mkdirs() }
        val apkFile = File(updatesDirectory, "update.apk")
        var apkFound = false
        ZipInputStream(BufferedInputStream(FileInputStream(zipFile))).use { archive ->
            var entry = archive.nextEntry
            while (entry != null) {
                if (!entry.isDirectory && entry.name.lowercase(Locale.ROOT).endsWith(".apk")) {
                    FileOutputStream(apkFile).use { output ->
                        val buffer = ByteArray(BUFFER_SIZE)
                        var totalBytes = 0L
                        var count = archive.read(buffer)
                        while (count != -1) {
                            totalBytes += count
                            require(totalBytes <= MAX_APK_BYTES) {
                                "Paczka aktualizacji jest zbyt duża."
                            }
                            output.write(buffer, 0, count)
                            count = archive.read(buffer)
                        }
                    }
                    apkFound = true
                    break
                }
                archive.closeEntry()
                entry = archive.nextEntry
            }
        }
        require(apkFound && apkFile.isFile && apkFile.length() > 0) {
            "Paczka nie zawiera pliku instalacyjnego APK."
        }
        return apkFile
    }

    private fun openApkInstaller(apkFile: File) {
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", apkFile)
        startActivity(
            Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            },
        )
    }

    companion object {
        const val UPDATE_CHANNEL = "dzien_po_dniu/update"
        const val WIDGETS_CHANNEL = "dzien_po_dniu/widgets"
        const val WIDGETS_PREFERENCES = "android_widgets"
        const val BUFFER_SIZE = 8192
        const val MAX_APK_BYTES = 200L * 1024L * 1024L
    }
}
