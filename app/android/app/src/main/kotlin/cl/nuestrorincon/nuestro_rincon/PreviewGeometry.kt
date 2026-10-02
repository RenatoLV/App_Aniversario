package cl.nuestrorincon.nuestro_rincon

/** TextureView already rotates the sensor; this only compensates display and scaling. */
data class PreviewGeometry(val scaleX: Float, val scaleY: Float, val rotation: Float) {
    companion object {
        fun calculate(viewWidth: Int, viewHeight: Int, bufferWidth: Int, bufferHeight: Int,
                      sensorRotation: Int, displayRotation: Int): PreviewGeometry {
            require(listOf(viewWidth, viewHeight, bufferWidth, bufferHeight).all { it > 0 })
            val swap = (sensorRotation - displayRotation + 360) % 180 != 0
            val width = if (swap) bufferHeight.toFloat() else bufferWidth.toFloat()
            val height = if (swap) bufferWidth.toFloat() else bufferHeight.toFloat()
            val scale = maxOf(viewWidth / width, viewHeight / height)
            return PreviewGeometry(width * scale / viewWidth, height * scale / viewHeight, -displayRotation.toFloat())
        }
    }
}
