package cl.nuestrorincon.nuestro_rincon

/** Lossless ANMF frames, as specified by https://developers.google.com/speed/webp/docs/riff_container. */
class WebpTimeline(val bytes: ByteArray) {
    data class Frame(val x: Int, val y: Int, val width: Int, val height: Int,
        val duration: Int, val blend: Boolean, val dispose: Boolean,
        val offset: Int, val length: Int)
    val width: Int
    val height: Int
    val background: Int
    val frames: List<Frame>
    val duration: Long
    init {
        require(isWebp(bytes) && bytes.size >= 30)
        require(uint(4, 4).toLong() + 8 == bytes.size.toLong())
        var w = 0; var h = 0; var color = 0
        val parsed = mutableListOf<Frame>()
        var p = 12
        while (p < bytes.size) {
            require(p + 8 <= bytes.size)
            val length = uint(p + 4, 4)
            require(length >= 0 && length <= bytes.size - p - 8)
            val data = p + 8
            when (fourCC(p)) {
                "VP8X" -> {
                    require(length >= 10 && uint(data, 1) and 2 != 0)
                    w = uint(data + 4, 3) + 1; h = uint(data + 7, 3) + 1
                    require(w.toLong() * h <= 16_000_000)
                }
                "ANIM" -> { require(length >= 6); color = uint(data, 4) }
                "ANMF" -> {
                    require(length >= 24 && w > 0 && h > 0 && parsed.size < 4096)
                    val x = uint(data, 3) * 2; val y = uint(data + 3, 3) * 2
                    val fw = uint(data + 6, 3) + 1; val fh = uint(data + 9, 3) + 1
                    require(x + fw <= w && y + fh <= h)
                    // Our verified assets use VP8L: Android 7/8 decode this static
                    // lossless payload natively, including its alpha channel.
                    require(fourCC(data + 16) == "VP8L")
                    val flags = uint(data + 15, 1)
                    parsed.add(Frame(x, y, fw, fh, uint(data + 12, 3).coerceAtLeast(10),
                        flags and 2 == 0, flags and 1 != 0, data + 16, length - 16))
                }
            }
            p += 8 + length + (length and 1)
        }
        require(p == bytes.size && parsed.isNotEmpty())
        width = w; height = h; background = color; frames = parsed
        duration = frames.sumOf { it.duration.toLong() }
    }
    private fun uint(offset: Int, length: Int): Int {
        require(offset >= 0 && offset + length <= bytes.size)
        var value = 0
        for (i in 0 until length) value = value or ((bytes[offset + i].toInt() and 255) shl (i * 8))
        return value
    }
    private fun fourCC(offset: Int) = String(bytes, offset, 4, Charsets.US_ASCII)
    fun frameAt(elapsed: Long): Int {
        var time = elapsed.coerceAtLeast(0) % duration
        for ((i, frame) in frames.withIndex()) {
            if (time < frame.duration) return i
            time -= frame.duration
        }
        return 0
    }
    fun stillFrame(index: Int): ByteArray {
        val frame = frames[index]
        val output = ByteArray(frame.length + 12)
        "RIFF".toByteArray(Charsets.US_ASCII).copyInto(output)
        val size = output.size - 8
        for (i in 0..3) output[4 + i] = (size ushr (i * 8)).toByte()
        "WEBP".toByteArray(Charsets.US_ASCII).copyInto(output, 8)
        bytes.copyInto(output, 12, frame.offset, frame.offset + frame.length)
        return output
    }
    companion object {
        fun isWebp(bytes: ByteArray) = bytes.size >= 12 &&
            String(bytes, 0, 4, Charsets.US_ASCII) == "RIFF" &&
            String(bytes, 8, 4, Charsets.US_ASCII) == "WEBP"
    }
}
