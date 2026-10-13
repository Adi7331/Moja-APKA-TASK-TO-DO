package com.example.dzien_po_dniu

import android.content.Intent
import android.content.Context
import android.app.Activity
import android.database.Cursor
import android.net.Uri
import android.provider.DocumentsContract
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
    private var taskDigestChannel: MethodChannel? = null
    private var pendingOpenToday = false
    private var pendingBackupFolderResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        taskDigestChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TASK_DIGEST_CHANNEL)
        taskDigestChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> {
                    val arguments = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    TaskDigestScheduler.update(
                        this,
                        arguments["enabled"] as? Boolean ?: false,
                        arguments["interval"] as? Int ?: 60,
                        arguments["start"] as? Int ?: 540,
                        arguments["end"] as? Int ?: 1260,
                    )
                    result.success(null)
                }
                "cancel" -> {
                    TaskDigestScheduler.update(this, false, 60, 540, 1260)
                    result.success(null)
                }
                "consumeOpenToday" -> {
                    result.success(pendingOpenToday || intent?.getBooleanExtra("open_today", false) == true)
                    pendingOpenToday = false
                    intent?.removeExtra("open_today")
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DAILY_PLAN_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "schedule" -> {
                        DailyPlanScheduler.update(
                            this,
                            call.argument<Boolean>("enabled") ?: false,
                            call.argument<Int>("hour") ?: 9,
                            call.argument<Int>("minute") ?: 0,
                        )
                        result.success(null)
                    }
                    "cancel" -> {
                        DailyPlanScheduler.update(this, false, 9, 0)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        if (intent?.getBooleanExtra("open_today", false) == true) {
            pendingOpenToday = true
            intent?.removeExtra("open_today")
        }
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKUP_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "chooseFolder") {
                    if (pendingBackupFolderResult != null) {
                        result.error("busy", "Wybór folderu już trwa.", null)
                    } else {
                        pendingBackupFolderResult = result
                        startActivityForResult(
                            Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                            },
                            BACKUP_PICKER_REQUEST,
                        )
                    }
                    return@setMethodCallHandler
                }
                try {
                    val folder = call.argument<String>("folder")
                        ?: throw IllegalArgumentException("Nie wybrano folderu kopii.")
                    val tree = Uri.parse(folder)
                    require(contentResolver.persistedUriPermissions.any {
                        it.uri == tree && it.isReadPermission && it.isWritePermission
                    }) { "Utracono dostęp do folderu kopii. Wybierz go ponownie." }
                    when (call.method) {
                        "list" -> result.success(backupDocumentNames(tree))
                        "write" -> {
                            val name = safeBackupName(call.argument<String>("name"))
                            val path = call.argument<String>("path")
                                ?: throw IllegalArgumentException("Brakuje pliku kopii.")
                            val source = File(path)
                            require(source.isFile) { "Nie znaleziono przygotowanej kopii." }
                            require(backupDocumentNames(tree).none { it == name }) {
                                "Kopia o tej nazwie już istnieje."
                            }
                            val document = DocumentsContract.createDocument(
                                contentResolver, childDocumentsUri(tree), "application/octet-stream", name,
                            ) ?: throw IllegalStateException("Nie można utworzyć kopii w folderze.")
                            try {
                                contentResolver.openOutputStream(document, "w")?.use { output ->
                                    FileInputStream(source).use { input -> input.copyTo(output) }
                                } ?: throw IllegalStateException("Nie można zapisać kopii w folderze.")
                            } catch (error: Exception) {
                                DocumentsContract.deleteDocument(contentResolver, document)
                                throw error
                            }
                            result.success(null)
                        }
                        "read" -> {
                            val document = findBackupDocument(tree, safeBackupName(call.argument<String>("name")))
                                ?: throw IllegalArgumentException("Nie znaleziono wybranej kopii.")
                            val target = File.createTempFile("dniowka-restore-", ".dniowka", cacheDir)
                            contentResolver.openInputStream(document)?.use { input ->
                                FileOutputStream(target).use { output -> input.copyTo(output) }
                            } ?: throw IllegalStateException("Nie można odczytać kopii.")
                            result.success(target.absolutePath)
                        }
                        "delete" -> {
                            val document = findBackupDocument(tree, safeBackupName(call.argument<String>("name")))
                            if (document != null) DocumentsContract.deleteDocument(contentResolver, document)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("backup_failed", error.message, null)
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != BACKUP_PICKER_REQUEST) return
        val pending = pendingBackupFolderResult ?: return
        pendingBackupFolderResult = null
        val tree = data?.data
        if (resultCode != Activity.RESULT_OK || tree == null) {
            pending.success(null)
            return
        }
        try {
            contentResolver.takePersistableUriPermission(
                tree, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
            pending.success(tree.toString())
        } catch (error: Exception) {
            pending.error("folder_access_failed", error.message, null)
        }
    }

    private fun safeBackupName(name: String?): String {
        require(name != null && name.matches(Regex("dniowka-[a-f0-9]{16}-[0-9]+-[0-9]+\\.dniowka"))) {
            "Nieprawidłowa nazwa kopii."
        }
        return name
    }

    private fun childDocumentsUri(tree: Uri): Uri =
        DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))

    private fun backupDocumentNames(tree: Uri): List<String> {
        val parentId = DocumentsContract.getTreeDocumentId(tree)
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentId)
        val names = mutableListOf<String>()
        contentResolver.query(children, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                while (cursor.moveToNext()) names.add(cursor.getString(0))
            } ?: throw IllegalStateException("Nie można odczytać folderu kopii.")
        return names
    }

    private fun findBackupDocument(tree: Uri, name: String): Uri? {
        val parentId = DocumentsContract.getTreeDocumentId(tree)
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentId)
        contentResolver.query(
            children,
            arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null, null, null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                if (cursor.getString(1) == name) {
                    return DocumentsContract.buildDocumentUriUsingTree(tree, cursor.getString(0))
                }
            }
        }
        return null
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra("open_today", false)) {
            pendingOpenToday = true
            intent.removeExtra("open_today")
            taskDigestChannel?.invokeMethod("openToday", null)
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
        const val TASK_DIGEST_CHANNEL = "dzien_po_dniu/task_digest"
        const val BACKUP_CHANNEL = "dniowka/local_backup"
        const val DAILY_PLAN_CHANNEL = "dniowka/daily_plan"
        const val BACKUP_PICKER_REQUEST = 8152
        const val WIDGETS_PREFERENCES = "android_widgets"
        const val BUFFER_SIZE = 8192
        const val MAX_APK_BYTES = 200L * 1024L * 1024L
    }
}
