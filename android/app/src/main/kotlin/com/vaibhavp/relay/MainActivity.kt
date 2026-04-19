package com.vaibhavp.relay

import android.content.ContentValues
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity(), MediaSaverApi {
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
}
