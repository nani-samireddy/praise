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
        description = "All original-language lyric stanzas in their original order. Never omit a lyric line.",
        minItems = 1,
        maxItems = 30,
    )
    val stanzas: List<ExtractedStanza>,
    @Guide(
        description = "English lyric stanzas only when separate English lyrics explicitly appear in the OCR input. Otherwise return an empty list; never translate.",
        maxItems = 30,
    )
    val englishStanzas: List<ExtractedStanza>,
    @Guide(
        description = "The author only when explicitly identified in the OCR input. Otherwise return an empty string.",
    )
    val author: String,
)

@Generable("One ordered stanza or explicitly labelled section of song lyrics")
data class ExtractedStanza(
    @Guide(
        description = "Every lyric line in this stanza, in order. Keep an explicit label such as [Chorus] as its own first line, but never invent labels.",
        minItems = 1,
        maxItems = 12,
    )
    val lines: List<String>,
)
