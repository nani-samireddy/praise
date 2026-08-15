package com.nanisamireddy.praise

import com.googlecode.tesseract.android.TessBaseAPI
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val ocrExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.nanisamireddy.praise/song_scan",
        ).setMethodCallHandler { call, result ->
            if (call.method != "recognize") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val imagePath = call.argument<String>("imagePath")
            if (imagePath.isNullOrBlank()) {
                result.error("invalid_image", "The image path is missing.", null)
                return@setMethodCallHandler
            }
            ocrExecutor.execute {
                try {
                    val text = recognize(File(imagePath))
                    runOnUiThread { result.success(text) }
                } catch (error: Exception) {
                    runOnUiThread {
                        result.error("ocr_failed", error.message, null)
                    }
                }
            }
        }
    }

    private fun recognize(image: File): String {
        require(image.isFile) { "The selected image is unavailable." }
        val dataRoot = prepareLanguageData()
        val api = TessBaseAPI()
        try {
            check(api.init(dataRoot.absolutePath, "tel+eng")) {
                "Could not initialize Telugu OCR."
            }
            api.pageSegMode = TessBaseAPI.PageSegMode.PSM_SINGLE_COLUMN
            api.setVariable("preserve_interword_spaces", "1")
            api.setImage(image)
            return api.utF8Text.orEmpty()
        } finally {
            api.recycle()
        }
    }

    private fun prepareLanguageData(): File {
        val dataRoot = File(filesDir, "tesseract")
        val tessData = File(dataRoot, "tessdata")
        check(tessData.exists() || tessData.mkdirs()) {
            "Could not prepare OCR storage."
        }
        listOf("tel.traineddata", "eng.traineddata").forEach { name ->
            val target = File(tessData, name)
            if (!target.isFile || target.length() == 0L) {
                assets.open("flutter_assets/assets/tessdata/$name").use { input ->
                    target.outputStream().use { output -> input.copyTo(output) }
                }
            }
        }
        return dataRoot
    }

    override fun onDestroy() {
        ocrExecutor.shutdownNow()
        super.onDestroy()
    }
}
