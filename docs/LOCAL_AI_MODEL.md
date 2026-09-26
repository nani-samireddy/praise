# Local song-scanning AI

Android song structuring uses Gemma 3 1B through LiteRT-LM. Gemini Nano/AICore is not used. OCR and song structuring run on-device.

The model is delivered as the `gemma_model` on-demand Play Asset Pack. When someone chooses **Read from image**, Praise asks for Gemma terms acceptance, then fetches the model from Google Play and uses it. The model download is about 584 MB; Play may pause it until the device is on Wi-Fi. Users do not download a separate model from a model-hosting site.

The asset-pack build task fetches the pinned 584,417,280-byte int4 LiteRT-LM artifact from the `On-device/Gemma3-1B-IT-litert-lm` Hugging Face revision `a80fead`, verifies SHA-256 `1325ae366d31950f137c9c357b9fa89448b176d76998180c08ceaca78bba98be`, and stages it in the asset pack. The binary is generated locally during the asset-pack build and is not checked into Git. The build therefore needs network access and about 584 MB of additional local storage.

Build and publish an Android App Bundle (`bundleRelease`) through Google Play. Play Asset Delivery is not available from the standalone APK produced by a normal `flutter run` or `assembleRelease`; sideloaded installs cannot fetch the pack. Test through a Play internal-testing track or use Google's documented App Bundle local-testing workflow.

The pack includes the Gemma notice. Gemma is provided under and subject to the [Gemma Terms of Use](https://ai.google.dev/gemma/terms) and [Prohibited Use Policy](https://ai.google.dev/gemma/prohibited_use_policy). Praise obtains user acceptance before requesting the model pack.
