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
