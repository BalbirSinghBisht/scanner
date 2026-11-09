package com.mediabackup.scanner.scanner

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.util.Log
import java.io.File
import java.nio.ByteBuffer

object VideoTrimmerHelper {
    private const val TAG = "VideoTrimmerHelper"

    /**
     * Losslessly trims an MP4/video file between startMs and endMs without full re-encoding.
     * Extracts samples and muxes into outputPath.
     */
    fun trim(
        inputPath: String,
        outputPath: String,
        startMs: Long,
        endMs: Long,
        muteAudio: Boolean
    ): Boolean {
        val inputFile = File(inputPath)
        if (!inputFile.exists()) {
            Log.e(TAG, "Input file does not exist: $inputPath")
            return false
        }

        val outputFile = File(outputPath)
        if (outputFile.exists()) {
            outputFile.delete()
        }
        outputFile.parentFile?.mkdirs()

        val extractor = MediaExtractor()
        var muxer: MediaMuxer? = null

        try {
            extractor.setDataSource(inputPath)
            val trackCount = extractor.trackCount
            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

            val indexMap = HashMap<Int, Int>()
            val trackOffsets = HashMap<Int, Long>()
            val startUs = startMs * 1000L
            val endUs = endMs * 1000L
            var maxBufferSize = 1024 * 1024

            for (i in 0 until trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
                val isAudio = mime.startsWith("audio/")

                if (isAudio && muteAudio) {
                    continue
                }

                if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                    try {
                        val bufferSize = format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)
                        if (bufferSize > maxBufferSize) {
                            maxBufferSize = bufferSize
                        }
                    } catch (_: Exception) {}
                }

                extractor.selectTrack(i)
                val dstIndex = muxer.addTrack(format)
                indexMap[i] = dstIndex
            }

            if (indexMap.isEmpty()) {
                Log.e(TAG, "No valid tracks found to trim")
                return false
            }

            // Seek to start position on keyframe
            extractor.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)

            muxer.start()

            val buffer = ByteBuffer.allocateDirect(maxBufferSize)
            val bufferInfo = MediaCodec.BufferInfo()

            while (true) {
                val trackIndex = extractor.sampleTrackIndex
                if (trackIndex < 0) break

                val dstIndex = indexMap[trackIndex]
                if (dstIndex != null) {
                    bufferInfo.offset = 0
                    bufferInfo.size = extractor.readSampleData(buffer, 0)
                    if (bufferInfo.size < 0) {
                        break
                    }

                    val sampleTime = extractor.sampleTime

                    // Stop if beyond end timestamp
                    if (sampleTime > endUs) {
                        break
                    }

                    if (sampleTime >= startUs) {
                        // Normalize PTS so video starts cleanly from 0
                        var offset = trackOffsets[trackIndex]
                        if (offset == null) {
                            offset = sampleTime
                            trackOffsets[trackIndex] = offset
                        }

                        val pts = Math.max(0L, sampleTime - offset)
                        bufferInfo.presentationTimeUs = pts
                        bufferInfo.flags = extractor.sampleFlags

                        muxer.writeSampleData(dstIndex, buffer, bufferInfo)
                    }
                }
                extractor.advance()
            }

            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed trimming video: ${e.message}", e)
            return false
        } finally {
            try {
                muxer?.stop()
                muxer?.release()
            } catch (e: Exception) {
                Log.w(TAG, "Muxer release warning: ${e.message}")
            }
            try {
                extractor.release()
            } catch (e: Exception) {
                Log.w(TAG, "Extractor release warning: ${e.message}")
            }
        }
    }
}

