package cl.nuestrorincon.nuestro_rincon
import org.junit.Assert.*
import org.junit.Test

class PreviewGeometryTest {
    @Test fun portraitNeverRotatesTheSensorTwice() {
        for (sensor in listOf(90, 270)) {
            val result = PreviewGeometry.calculate(390, 600, 1280, 720, sensor, 0)
            assertEquals(0f, result.rotation, .001f)
            assertEquals(720f / 1280f, 390f * result.scaleX / (600f * result.scaleY), .001f)
            assertTrue(result.scaleX >= 1f && result.scaleY >= 1f)
        }
    }
    @Test fun onlyDisplayRotationChangesThePreviewAngle() {
        val result = PreviewGeometry.calculate(800, 400, 1280, 720, 90, 90)
        assertEquals(-90f, result.rotation, .001f)
        assertEquals(1280f / 720f, 800f * result.scaleX / (400f * result.scaleY), .001f)
    }
}
