package cl.nuestrorincon.nuestro_rincon

import java.io.File
import org.junit.Assert.*
import org.junit.Test

class WebpTimelineTest {
    @Test fun everyOptimizedCardHasReadableLosslessFramesAndAnExactLoop() {
        val assets = listOf(File("../assets/celestials"), File("../../assets/celestials"))
            .first { it.isDirectory }
        val expected = mapOf(10000 to 34,
            10002 to 16,
            10003 to 50,
            10006 to 64,
            10007 to 29,
            10009 to 115,
            10010 to 79,
            10015 to 73,
            10018 to 301,
            10020 to 186,
            10022 to 145,
            10027 to 121,
            10028 to 25,
            10030 to 151,
            10031 to 25,
            10033 to 84,
            10034 to 57,
            10035 to 97,
            10037 to 42,
            10038 to 59,
            10039 to 65,
            10043 to 64)
        for ((id, count) in expected) {
            val animation = WebpTimeline(File(assets, "celestial_$id.webp").readBytes())
            assertEquals(count, animation.frames.size)
            assertEquals(0, animation.frameAt(0))
            assertEquals(count - 1, animation.frameAt(animation.duration - 1))
            assertEquals(0, animation.frameAt(animation.duration))
            for ((i, frame) in animation.frames.withIndex()) {
                val still = animation.stillFrame(i)
                assertTrue(WebpTimeline.isWebp(still))
                assertEquals("VP8L", String(still, 12, 4, Charsets.US_ASCII))
                assertTrue(frame.duration >= 10)
                assertTrue(frame.x + frame.width <= animation.width)
                assertTrue(frame.y + frame.height <= animation.height)
            }
        }
    }

    private fun number(value: Int, count: Int) = ByteArray(count) { (value ushr (it * 8)).toByte() }
    private fun chunk(name: String, data: ByteArray) =
        name.toByteArray() + number(data.size, 4) + data + if (data.size % 2 == 1) byteArrayOf(0) else byteArrayOf()
    private fun sample(): ByteArray {
        val header = byteArrayOf(2, 0, 0, 0) + number(19, 3) + number(19, 3)
        fun frame(delay: Int, flags: Int, x: Int) = chunk("ANMF",
            number(x, 3) + number(1, 3) + number(3, 3) + number(3, 3) +
                number(delay, 3) + byteArrayOf(flags.toByte()) + chunk("VP8L", byteArrayOf(47, 0, 0, 0, 0)))
        val data = chunk("VP8X", header) + chunk("ANIM", number(0, 6)) +
            frame(40, 2, 0) + frame(80, 1, 2)
        return "RIFF".toByteArray() + number(data.size + 4, 4) + "WEBP".toByteArray() + data
    }
    @Test fun frameOffsetsDisposalAndTimingArePreserved() {
        val clip = WebpTimeline(sample())
        assertEquals(20, clip.width)
        assertEquals(4, clip.frames[1].x)
        assertEquals(2, clip.frames[1].y)
        assertFalse(clip.frames[0].blend)
        assertTrue(clip.frames[1].blend)
        assertTrue(clip.frames[1].dispose)
        assertEquals(0, clip.frameAt(39))
        assertEquals(1, clip.frameAt(40))
        assertEquals(0, clip.frameAt(120))
    }
    @Test(expected = IllegalArgumentException::class) fun truncatedAnimationIsRejected() {
        val bytes = sample()
        WebpTimeline(bytes.copyOf(bytes.size - 5))
    }
}
