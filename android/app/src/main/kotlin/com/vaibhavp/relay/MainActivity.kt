package com.vaibhavp.relay

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterActivity(), MediaSaverApi {
	private val pickRequestCode = 7331
	private var pickCallback: ((Result<List<String>>) -> Unit)? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MediaSaverApi.setUp(flutterEngine.dartExecutor.binaryMessenger, this)
	}

	override fun saveFile(
		path: String,
		name: String,
		mime: String,
		callback: (Result<Boolean>) -> Unit,
	) {
		try {
			val src = File(path)
			if (!src.exists()) {
				callback(Result.success(false))
				return
			}

			val vals = ContentValues().apply {
				put(MediaStore.MediaColumns.DISPLAY_NAME, name)
				put(MediaStore.MediaColumns.MIME_TYPE, mime)
				put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
			}

			val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, vals)
				?: run {
					callback(Result.success(false))
					return
				}

			val out = contentResolver.openOutputStream(uri)
			if (out == null) {
				callback(Result.success(false))
				return
			}

			out.use { stream ->
				FileInputStream(src).use { inp ->
					inp.copyTo(stream)
				}
			}

			callback(Result.success(true))
		} catch (_: Exception) {
			callback(Result.success(false))
		}
	}

	override fun shareFile(
		path: String,
		mime: String,
		callback: (Result<Unit>) -> Unit,
	) {
		try {
			val src = File(path)
			if (!src.exists()) {
				callback(Result.failure(FlutterError("share_missing_file", "File not found", path)))
				return
			}

			val uri = FileProvider.getUriForFile(
				this,
				"$packageName.fileprovider",
				src,
			)

			val req = Intent(Intent.ACTION_SEND).apply {
				type = mime
				putExtra(Intent.EXTRA_STREAM, uri)
				addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
			}

			startActivity(Intent.createChooser(req, "Share File"))
			callback(Result.success(Unit))
		} catch (e: Exception) {
			callback(Result.failure(FlutterError("share_failed", e.message, null)))
		}
	}

	override fun pickFiles(allowMultiple: Boolean, callback: (Result<List<String>>) -> Unit) {
		if (pickCallback != null) {
			callback(Result.failure(FlutterError("picker_busy", "File picker already open", null)))
			return
		}

		pickCallback = callback
		try {
			val req = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
				addCategory(Intent.CATEGORY_OPENABLE)
				type = "*/*"
				putExtra(Intent.EXTRA_ALLOW_MULTIPLE, allowMultiple)
			}
			startActivityForResult(Intent.createChooser(req, "Select Files"), pickRequestCode)
		} catch (e: Exception) {
			pickCallback = null
			callback(Result.failure(FlutterError("picker_failed", e.message, null)))
		}
	}

	override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
		super.onActivityResult(requestCode, resultCode, data)
		if (requestCode != pickRequestCode) {
			return
		}

		if (resultCode != Activity.RESULT_OK) {
			onPickResult(emptyList())
			return
		}

		onPickResult(extractUris(data))
	}

	private fun extractUris(data: Intent?): List<Uri> {
		if (data == null) {
			return emptyList()
		}

		val uris = mutableListOf<Uri>()
		data.data?.let { uris.add(it) }

		val clip = data.clipData
		if (clip != null) {
			for (idx in 0 until clip.itemCount) {
				clip.getItemAt(idx).uri?.let { uris.add(it) }
			}
		}

		return uris.distinct()
	}

	private fun onPickResult(uris: List<Uri>) {
		val callback = pickCallback ?: return
		pickCallback = null
		val paths = uris.mapNotNull { copyUriToLocalPath(it) }
		callback(Result.success(paths))
	}

	private fun copyUriToLocalPath(uri: Uri): String? {
		val name = queryFileName(uri) ?: "picked_${System.currentTimeMillis()}"
		val dir = File(filesDir, "picked")
		if (!dir.exists()) {
			dir.mkdirs()
		}

		val dstName = "${System.currentTimeMillis()}_${name.replace('/', '_')}"
		val dst = File(dir, dstName)

		return try {
			contentResolver.openInputStream(uri)?.use { input ->
				FileOutputStream(dst).use { output ->
					input.copyTo(output)
				}
			} ?: return null
			dst.absolutePath
		} catch (_: Exception) {
			null
		}
	}

	private fun queryFileName(uri: Uri): String? {
		return try {
			contentResolver.query(uri, null, null, null, null)?.use { cursor ->
				val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
				if (idx == -1 || !cursor.moveToFirst()) {
					null
				} else {
					cursor.getString(idx)
				}
			}
		} catch (_: Exception) {
			null
		}
	}
}
