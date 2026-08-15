# OCR components and model provenance

Praise performs Android OCR on-device with the following open-source assets:

- [Tesseract4Android 4.9.0](https://github.com/adaptech-cz/Tesseract4Android),
  licensed under Apache License 2.0.
- [`tessdata_fast`](https://github.com/tesseract-ocr/tessdata_fast) Telugu and
  English trained models, licensed under Apache License 2.0. A copy of the model
  license is bundled at `assets/tessdata/LICENSE.txt`.
- Flutter's [`image_picker`](https://pub.dev/packages/image_picker), used to
  open the camera and system photo picker under its published BSD-3-Clause and
  Apache-2.0 terms.

## Bundled model checksums

| File | SHA-256 |
| --- | --- |
| `tel.traineddata` | `d10691fddd5b67802e1c12800ebb321d3b8bcd8d24a2ac3ff206f93188c04ab5` |
| `eng.traineddata` | `7d4322bd2a7749724879683fc3912cb542f19906c83bcc1a52132556427170b2` |

These files came from the `main` branch of the official Tesseract
`tessdata_fast` repository on 2026-08-15.

## Optional on-device AI organization

On supported Android devices, Praise can pass OCR text to ML Kit GenAI Prompt
`1.0.0-beta4` with the Structured Output schema API `1.0.0-alpha1`. Inference
runs through Android AICore/Gemini Nano; Praise does not bundle that model and
does not send OCR text to an application server. This optional integration is
subject to the [ML Kit GenAI API terms](https://developers.google.com/ml-kit/terms/genai).
Ordinary Tesseract OCR remains available when this feature cannot run.
