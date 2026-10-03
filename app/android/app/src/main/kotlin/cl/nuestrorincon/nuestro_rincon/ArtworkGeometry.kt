package cl.nuestrorincon.nuestro_rincon

/** Normalized art bounds keep animation inside the printed card frame. */
object ArtworkGeometry {
    fun validBounds(b: FloatArray) = b.size == 4 && b.all { it.isFinite() } &&
        b[0] >= 0 && b[1] >= 0 && b[2] > 0 && b[3] > 0 &&
        b[0] + b[2] <= 1.00001f && b[1] + b[3] <= 1.00001f

    // Returns left, top, width, height; no stretching or cropping.
    fun contain(sourceWidth: Int, sourceHeight: Int, width: Float, height: Float): FloatArray {
        require(sourceWidth > 0 && sourceHeight > 0 && width > 0 && height > 0)
        val scale = kotlin.math.min(width / sourceWidth, height / sourceHeight)
        val w = sourceWidth * scale
        val h = sourceHeight * scale
        return floatArrayOf((width - w) / 2, (height - h) / 2, w, h)
    }
}
