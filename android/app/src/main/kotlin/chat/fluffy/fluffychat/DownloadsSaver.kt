package chat.fluffy.fluffychat

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Saves files to the shared Downloads folder. Flutter plugins only reach it
 * through a save dialog, which doesn't work for automatic downloads.
 */
object DownloadsSaver {
    private const val CHANNEL = "lv.d0b0.chat/downloads"

    fun register(messenger: BinaryMessenger, context: Context) {
        val appContext = context.applicationContext
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "save") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")!!
            val name = call.argument<String>("name")!!
            val mimeType = call.argument<String>("mimeType")
            val folder = call.argument<String>("folder")!!
            val mainHandler = Handler(Looper.getMainLooper())
            Thread {
                try {
                    val saved = save(appContext, File(path), name, mimeType, folder)
                    mainHandler.post { result.success(saved) }
                } catch (e: Exception) {
                    mainHandler.post { result.error("save_failed", e.message, null) }
                }
            }.start()
        }
    }

    private fun save(
        context: Context,
        source: File,
        name: String,
        mimeType: String?,
        folder: String,
    ): String {
        val relativePath = "${Environment.DIRECTORY_DOWNLOADS}/$folder"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = context.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, name)
                if (mimeType != null) put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Unable to create $name in Downloads")
            try {
                resolver.openOutputStream(uri)!!.use { output ->
                    source.inputStream().use { it.copyTo(output) }
                }
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                throw e
            }
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return "$relativePath/$name"
        }

        // Android 9 and older: write directly, with the storage permission.
        @Suppress("DEPRECATION")
        val directory = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            folder,
        )
        directory.mkdirs()
        val base = name.substringBeforeLast('.')
        val extension = if (name.contains('.')) ".${name.substringAfterLast('.')}" else ""
        var target = File(directory, name)
        var i = 1
        while (target.exists()) {
            target = File(directory, "$base ($i)$extension")
            i++
        }
        source.copyTo(target)
        MediaScannerConnection.scanFile(context, arrayOf(target.path), null, null)
        return target.path
    }
}
