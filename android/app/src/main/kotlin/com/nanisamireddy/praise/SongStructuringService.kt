package com.nanisamireddy.praise

import com.google.mlkit.genai.common.DownloadStatus
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.TextPart
import com.google.mlkit.genai.prompt.generateTypedContentRequest
import kotlinx.coroutines.flow.collect

class SongStructuringService {
    private val model by lazy { Generation.getClient() }

    suspend fun status(): String =
        when (model.checkStatus()) {
            FeatureStatus.AVAILABLE -> "available"
            FeatureStatus.DOWNLOADABLE -> "downloadable"
            FeatureStatus.DOWNLOADING -> "downloading"
            else -> "unavailable"
        }

    suspend fun structure(ocrText: String): Map<String, Any?> {
        prepareModel()
        check(model.isStructuredOutputFeatureAvailable()) {
            "Structured on-device AI is unavailable on this device."
        }

        val prompt = """
            Extract one Christian worship song from the OCR text below.

            Rules:
            - Correct only obvious OCR spacing and broken line issues.
            - Preserve Telugu text, wording, stanza breaks, labels, and repetition marks.
            - Never invent, translate, summarize, or omit lyric lines.
            - Use the actual heading as title when one is clearly present; otherwise use the first meaningful lyric line.
            - Keep every lyric line in body, including the selected title when that line is part of the lyrics.
            - Return an English title only when it explicitly appears in the OCR text.
            - Never translate or create an English title. Set englishTitleFound to false when one is absent.
            - Put text in englishBody only when separate English lyrics appear in the input.
            - Return an author only when the input explicitly identifies one.

            OCR text:
            ---
            $ocrText
            ---
        """.trimIndent()
        val request = generateTypedContentRequest(
            generateContentRequest =
                com.google.mlkit.genai.prompt.GenerateContentRequest.Builder(
                    TextPart(prompt),
                ).apply {
                    temperature = 0.0f
                    candidateCount = 1
                }
                    .build(),
            outputClass = ExtractedSong::class,
        )
        val response = model.generateContent(request)
        val song = response.candidates.firstOrNull()?.response
            ?: error("On-device AI did not return a song.")
        check(song.title.isNotBlank() && song.body.isNotBlank()) {
            "On-device AI returned an incomplete song."
        }
        return mapOf(
            "title" to song.title.trim(),
            "englishTitle" to if (song.englishTitleFound) song.englishTitle.trim() else "",
            "body" to song.body.trim(),
            "englishBody" to song.englishBody.trim(),
            "author" to song.author.trim(),
        )
    }

    private suspend fun prepareModel() {
        when (model.checkStatus()) {
            FeatureStatus.AVAILABLE -> return
            FeatureStatus.DOWNLOADABLE,
            FeatureStatus.DOWNLOADING,
            -> {
                var completed = false
                var failure: Throwable? = null
                model.download().collect { downloadStatus ->
                    when (downloadStatus) {
                        DownloadStatus.DownloadCompleted -> completed = true
                        is DownloadStatus.DownloadFailed -> failure = downloadStatus.e
                        else -> Unit
                    }
                }
                failure?.let { throw it }
                check(completed || model.checkStatus() == FeatureStatus.AVAILABLE) {
                    "The on-device AI model could not be prepared."
                }
            }
            else -> error("On-device AI is unavailable on this device.")
        }
    }
}
