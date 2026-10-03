package cl.nuestrorincon.nuestro_rincon
import org.junit.Assert.*
import org.junit.Test

class ArtworkGeometryTest {
    @Test fun allGifShapesFitWithoutDistortionOrOverflow() {
        for ((width, height) in listOf(135 to 140, 498 to 278, 243 to 498, 400 to 400)) {
            val r = ArtworkGeometry.contain(width, height, 240f, 185f)
            assertTrue(r[0] >= 0f && r[1] >= 0f)
            assertTrue(r[0] + r[2] <= 240.001f && r[1] + r[3] <= 185.001f)
            assertEquals(width.toFloat() / height, r[2] / r[3], .0001f)
        }
    }
    @Test fun invalidAnimationBoundsCannotCoverTheCardTitleOrLeaveTheFrame() {
        assertTrue(ArtworkGeometry.validBounds(floatArrayOf(.08f, .15f, .84f, .6f)))
        for (b in listOf(floatArrayOf(0f), floatArrayOf(-.1f, 0f, 1f, 1f),
            floatArrayOf(0f, .5f, 1f, 1f), floatArrayOf(0f, 0f, 0f, 1f),
            floatArrayOf(Float.NaN, 0f, 1f, 1f))) assertFalse(ArtworkGeometry.validBounds(b))
    }
}
