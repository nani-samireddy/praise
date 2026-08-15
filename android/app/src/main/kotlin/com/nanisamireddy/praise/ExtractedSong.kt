package com.nanisamireddy.praise

import com.google.mlkit.genai.schema.annotations.Generable
import com.google.mlkit.genai.schema.annotations.Guide

@Generable("A Christian song extracted from OCR text")
data class ExtractedSong(
    @Guide(
        description = "The song title in its original script. Never leave this empty.",
    )
    val title: String,
    @Guide(
        description = "The English or Latin-script title only when it explicitly appears in the OCR input. Otherwise return an empty string; never translate or create one.",
    )
    val englishTitle: String,
    @Guide(
        description = "True only when an English or Latin-script title is explicitly present in the OCR input, not when one was generated or inferred.",
    )
    val englishTitleFound: Boolean,
    @Guide(
        description = "All original-language lyric lines with stanza line breaks preserved. Keep a title line here too when it is also part of the lyrics.",
    )
    val body: String,
    @Guide(
        description = "English lyrics only when they are explicitly present in the OCR input. Otherwise return an empty string; do not translate.",
    )
    val englishBody: String,
    @Guide(
        description = "The author only when explicitly identified in the OCR input. Otherwise return an empty string.",
    )
    val author: String,
)
