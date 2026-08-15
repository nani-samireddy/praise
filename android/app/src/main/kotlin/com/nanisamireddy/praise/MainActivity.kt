package com.nanisamireddy.praise

import com.googlecode.tesseract.android.TessBaseAPI
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    private val ocrExecutor = Executors.newSingleThreadExecutor()
    private val aiScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val songStructuringService = SongStructuringService()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.nanisamireddy.praise/song_scan",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "recognize" -> recognize(call.argument("imagePath"), result)
                "aiStatus" -> aiStatus(result)
                "structure" -> structure(call.argument("ocrText"), result)
                else -> result.notImplemented()
            }
        }
    }

    private fun recognize(imagePath: String?, result: MethodChannel.Result) {
        if (imagePath.isNullOrBlank()) {
            result.error("invalid_image", "The image path is missing.", null)
            return
        }
        ocrExecutor.execute {
            try {
                val text = recognizeImage(File(imagePath))
                runOnUiThread { result.success(text) }
            } catch (error: Exception) {
                runOnUiThread { result.error("ocr_failed", error.message, null) }
            }
        }
    }

    private fun aiStatus(result: MethodChannel.Result) {
        aiScope.launch {
            try {
                result.success(songStructuringService.status())
            } catch (error: Exception) {
                result.success("unavailable")
            }
        }
    }

    private fun structure(ocrText: String?, result: MethodChannel.Result) {
        if (ocrText.isNullOrBlank()) {
            result.error("invalid_text", "The OCR text is empty.", null)
            return
        }
        aiScope.launch {
            try {
                result.success(songStructuringService.structure(ocrText))
            } catch (error: Exception) {
                result.error("ai_failed", error.message, null)
            }
        }
    }

    private fun recognizeImage(image: File): String {
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
        aiScope.cancel()
        super.onDestroy()
    }
}
