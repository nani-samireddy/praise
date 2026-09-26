package com.nanisamireddy.praise

import android.content.Context
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.SamplerConfig
import com.google.android.play.core.assetpacks.AssetPackManagerFactory
import com.google.android.play.core.ktx.requestFetch
import com.google.android.play.core.ktx.requestPackStates
import com.google.android.play.core.assetpacks.model.AssetPackStatus
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import org.json.JSONObject
import java.io.File

class SongStructuringService(context: Context) {
    private val appContext = context.applicationContext
    private val assetPackManager = AssetPackManagerFactory.getInstance(appContext)

    suspend fun status(): String {
        if (gemmaAssetFile() != null) return "available"
        val packStatus = runCatching {
            assetPackManager.requestPackStates(listOf(gemmaAssetPackName))
                .packStates()[gemmaAssetPackName]
                ?.status()
        }.getOrNull()
        return when (packStatus) {
            AssetPackStatus.PENDING,
            AssetPackStatus.DOWNLOADING,
            AssetPackStatus.TRANSFERRING,
            AssetPackStatus.WAITING_FOR_WIFI,
            -> "downloading"
            AssetPackStatus.REQUIRES_USER_CONFIRMATION -> "unavailable"
            else -> "downloadable"
        }
    }

    suspend fun downloadModel() = withContext(Dispatchers.IO) {
        if (gemmaAssetFile() != null) return@withContext
        val initialState = assetPackManager.requestFetch(listOf(gemmaAssetPackName))
            .packStates()[gemmaAssetPackName]
        check(initialState?.status() != AssetPackStatus.REQUIRES_USER_CONFIRMATION) {
            "Install Praise from Google Play to download the song AI model."
        }
        withTimeout(gemmaDownloadTimeoutMillis) {
            while (true) {
                val state = assetPackManager.requestPackStates(listOf(gemmaAssetPackName))
                    .packStates()[gemmaAssetPackName]
                when (state?.status()) {
                    AssetPackStatus.COMPLETED -> {
                        check(gemmaAssetFile() != null) {
                            "The Gemma model asset is missing or incomplete."
                        }
                        return@withTimeout
                    }
                    AssetPackStatus.FAILED -> error(
                        "Google Play couldn’t download the song AI model (${state.errorCode()}).",
                    )
                    AssetPackStatus.CANCELED -> error(
                        "The song AI model download was canceled.",
                    )
                    AssetPackStatus.REQUIRES_USER_CONFIRMATION -> error(
                        "Install Praise from Google Play to download the song AI model.",
                    )
                    else -> delay(gemmaDownloadPollMillis)
                }
            }
        }
    }

    suspend fun structure(ocrText: String): Map<String, Any?> {
        val modelFile = gemmaAssetFile()
            ?: error("Download the song AI model from Google Play before scanning.")
        return structureWithGemma(modelFile, ocrText)
    }

    private suspend fun structureWithGemma(
        modelFile: File,
        ocrText: String,
    ): Map<String, Any?> = withContext(Dispatchers.IO) {
        val engine = Engine(
            EngineConfig(
                modelPath = modelFile.absolutePath,
                backend = Backend.CPU(),
                cacheDir = appContext.cacheDir.absolutePath,
            ),
        )
        try {
            engine.initialize()
            val conversation = engine.createConversation(
                ConversationConfig(
                    systemInstruction = Contents.of(
                        "You clean OCR text from Telugu Christian worship songs. " +
                            "Return only valid JSON matching the requested keys. " +
                            "Ignore device status bars, clocks, buttons, navigation, and app controls. " +
                            "Never invent, summarize, or semantically translate lyrics. Provide a line-for-line Latin-script transliteration as the English version.",
                    ),
                    samplerConfig = SamplerConfig(
                        temperature = 0.0,
                        topK = 1,
                        topP = 1.0,
                    ),
                ),
            )
            try {
                val response = conversation.sendMessage(
                    buildPrompt(ocrText),
                    maxOutputToken = 1200,
                ).toString()
                parseGemmaResponse(response)
            } finally {
                conversation.close()
            }
        } finally {
            engine.close()
        }
    }

    private fun parseGemmaResponse(response: String): Map<String, Any?> {
        val jsonStart = response.indexOf('{')
        val jsonEnd = response.lastIndexOf('}')
        check(jsonStart >= 0 && jsonEnd > jsonStart) {
            "On-device AI returned an invalid song response."
        }
        val value = JSONObject(response.substring(jsonStart, jsonEnd + 1))
        val body = value.optString("body").trim()
        check(value.optString("title").isNotBlank() && body.isNotBlank()) {
            "On-device AI returned an incomplete song."
        }
        return mapOf(
            "title" to value.optString("title").trim(),
            "englishTitle" to value.optString("englishTitle").trim(),
            "body" to body,
            "englishBody" to value.optString("englishBody").trim(),
            "author" to value.optString("author").trim(),
        )
    }

    private fun buildPrompt(ocrText: String): String = """
        Extract one Christian worship song from the OCR text below.

        Rules:
        - Exclude non-lyric OCR such as device status bars, clocks, buttons, navigation, app controls, and headings like Lyrics or Song controls.
        - Do not copy an OCR line into the song just because it is readable; include only the song title and actual lyric/section text.
        - Clean the scan into a readable song: fix obvious OCR spacing, merged words, and broken lines without changing the lyrics.
        - Choose the printed song heading as the title, excluding clocks, controls, and other screen text. If no heading exists, use the first complete lyric line.
        - Put each sung line on its own line and separate stanzas with exactly one blank line.
        - Never combine multiple lyric lines into one line.
        - Keep printed section labels, but never invent section labels.
        - Preserve repetition counts at the end of their lyric line, such as ×2, x2, or *2.
        - Never invent, summarize, semantically translate, or omit lyric lines.
        - Use the Telugu song heading as title; otherwise use the first meaningful Telugu lyric line.
        - Set englishTitle to a readable Latin-script transliteration of the title; transliterate, do not translate.
        - Set englishBody to a line-for-line Latin-script transliteration of body, preserving stanza and line breaks; do not semantically translate.
        - Return an author only if the input explicitly identifies one.
        - Return only a JSON object with string keys title, englishTitle, body, englishBody, author.
        - Use empty strings for missing optional fields. Keep Telugu characters unchanged.

        OCR text:
        ---
        $ocrText
        ---
    """.trimIndent()

    private fun gemmaAssetFile(): File? {
        val location = assetPackManager.getPackLocation(gemmaAssetPackName) ?: return null
        return File(location.assetsPath(), gemmaAssetRelativePath)
            .takeIf { it.isFile && it.length() == gemmaModelSize }
    }

    private companion object {
        const val gemmaAssetPackName = "gemma_model"
        const val gemmaAssetRelativePath = "models/gemma3-1b-it-int4.litertlm"
        const val gemmaModelSize = 584_417_280L
        const val gemmaDownloadTimeoutMillis = 30 * 60 * 1000L
        const val gemmaDownloadPollMillis = 1000L
    }
}
