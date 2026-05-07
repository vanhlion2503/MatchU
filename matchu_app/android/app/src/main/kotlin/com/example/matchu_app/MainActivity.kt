package com.example.matchu_app

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class MainActivity : FlutterActivity() {
    private val qrImageSaverChannel = "matchu_app/qr_image_saver"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            qrImageSaverChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "savePng" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val fileName = call.argument<String>("fileName")

                    if (bytes == null || bytes.isEmpty() || fileName.isNullOrBlank()) {
                        result.error(
                            "INVALID_ARGUMENTS",
                            "Image bytes and fileName are required.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    if (needsLegacyStoragePermission()) {
                        result.error(
                            "STORAGE_PERMISSION_REQUIRED",
                            "Storage permission is required on this Android version.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        result.success(savePngToPictures(bytes, fileName))
                    } catch (error: Exception) {
                        result.error("SAVE_FAILED", error.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun needsLegacyStoragePermission(): Boolean {
        return Build.VERSION.SDK_INT <= Build.VERSION_CODES.P &&
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
            PackageManager.PERMISSION_GRANTED
    }

    private fun savePngToPictures(bytes: ByteArray, fileName: String): String {
        val resolver = applicationContext.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_PICTURES}/MatchU"
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            } else {
                val picturesDirectory = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_PICTURES
                )
                val matchuDirectory = File(picturesDirectory, "MatchU")
                if (!matchuDirectory.exists() && !matchuDirectory.mkdirs()) {
                    throw IOException("Could not create MatchU pictures directory.")
                }
                put(MediaStore.Images.Media.DATA, File(matchuDirectory, fileName).absolutePath)
            }
        }

        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IOException("Could not create media store record.")

        try {
            resolver.openOutputStream(uri)?.use { stream ->
                stream.write(bytes)
                stream.flush()
            } ?: throw IOException("Could not open media store output stream.")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            }

            return uri.toString()
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
    }
}
