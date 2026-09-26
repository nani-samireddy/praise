import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.net.HttpURLConnection
import java.net.URI
import java.security.MessageDigest

plugins {
    id("com.android.asset-pack")
}

assetPack {
    packName.set("gemma_model")
    dynamicDelivery {
        deliveryType.set("on-demand")
    }
}

val modelFile = layout.projectDirectory.file(
    "src/main/assets/models/gemma3-1b-it-int4.litertlm",
).asFile
val noticeFile = layout.projectDirectory.file(
    "src/main/assets/GEMMA_NOTICE.txt",
).asFile
val expectedModelSize = 584_417_280L
val expectedModelSha256 = "1325ae366d31950f137c9c357b9fa89448b176d76998180c08ceaca78bba98be"
val modelDownloadUrl =
    "https://huggingface.co/On-device/Gemma3-1B-IT-litert-lm/resolve/a80fead/gemma3-1b-it-int4.litertlm"

fun File.sha256(): String {
    val digest = MessageDigest.getInstance("SHA-256")
    BufferedInputStream(inputStream()).use { input ->
        val buffer = ByteArray(64 * 1024)
        while (true) {
            val count = input.read(buffer)
            if (count < 0) break
            digest.update(buffer, 0, count)
        }
    }
    return digest.digest().joinToString("") { "%02x".format(it.toInt() and 0xff) }
}

val prepareGemmaAsset = tasks.register("prepareGemmaAsset") {
    outputs.files(modelFile, noticeFile)
    outputs.upToDateWhen {
        modelFile.isFile &&
            modelFile.length() == expectedModelSize &&
            modelFile.sha256() == expectedModelSha256 &&
            noticeFile.isFile
    }

    doLast {
        modelFile.parentFile.mkdirs()
        if (!modelFile.isFile ||
            modelFile.length() != expectedModelSize ||
            modelFile.sha256() != expectedModelSha256
        ) {
            val partialFile = File(modelFile.parentFile, "${modelFile.name}.part")
            val connection = URI(modelDownloadUrl).toURL().openConnection() as HttpURLConnection
            connection.connectTimeout = 30_000
            connection.readTimeout = 120_000
            connection.instanceFollowRedirects = true
            try {
                connection.connect()
                check(connection.responseCode in 200..299) {
                    "Could not download the pinned Gemma model asset."
                }
                val digest = MessageDigest.getInstance("SHA-256")
                var bytesWritten = 0L
                BufferedInputStream(connection.inputStream).use { input ->
                    BufferedOutputStream(partialFile.outputStream()).use { output ->
                        val buffer = ByteArray(64 * 1024)
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            bytesWritten += count
                            check(bytesWritten <= expectedModelSize) {
                                "The downloaded Gemma model has an unexpected size."
                            }
                            digest.update(buffer, 0, count)
                            output.write(buffer, 0, count)
                        }
                    }
                }
                val actualSha256 = digest.digest().joinToString("") {
                    "%02x".format(it.toInt() and 0xff)
                }
                check(bytesWritten == expectedModelSize && actualSha256 == expectedModelSha256) {
                    "The downloaded Gemma model failed its size or integrity check."
                }
                check(partialFile.renameTo(modelFile)) {
                    "Could not place the Gemma model in its Play Asset Pack."
                }
            } catch (error: Exception) {
                partialFile.delete()
                throw error
            } finally {
                connection.disconnect()
            }
        }

        layout.projectDirectory.file("../../assets/model_licenses/GEMMA_NOTICE.txt")
            .asFile.copyTo(noticeFile, overwrite = true)
    }
}

tasks.named("generateAssetPackManifest") {
    dependsOn(prepareGemmaAsset)
}
