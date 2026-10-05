import 'package:flutter/material.dart';
import 'store.dart';

/// One animated-image implementation shared by every card surface. Image's
/// multi-frame decoder preserves GIF/WebP timing, disposal and loop metadata.
class CardMedia extends StatelessWidget {
  final int cardId;
  final Key? imageKey;
  final bool thumbnail;
  const CardMedia({
    super.key,
    required this.cardId,
    this.imageKey,
    this.thumbnail = false,
  });
  @override
  Widget build(BuildContext context) {
    final asset = cardAsset(cardId);
    if (asset == null) {
      return Center(
        child: Text(
          cardId >= 0 && cardId < cardIcons.length ? cardIcons[cardId] : '?',
          style: const TextStyle(fontSize: 62),
        ),
      );
    }
    Widget image(ImageProvider provider) => Image(
      image: provider,
      key: imageKey,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      semanticLabel:
          '${cardName(cardId)}${isCelestialCard(cardId) ? ', carta celestial animada' : ''}',
      errorBuilder: (_, _, _) => const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.white),
      ),
    );
    if (!thumbnail) return image(AssetImage(asset));
    return LayoutBuilder(
      builder: (context, bounds) {
        if (!bounds.maxWidth.isFinite || !bounds.maxHeight.isFinite) {
          return image(AssetImage(asset));
        }
        final ratio = MediaQuery.devicePixelRatioOf(context);
        // Round up to reusable decode sizes while preserving every displayed pixel.
        int pixels(double logical) =>
            ((logical * ratio / 64).ceil() * 64).clamp(64, 16384);
        return image(
          ResizeImage(
            AssetImage(asset),
            width: pixels(bounds.maxWidth),
            height: pixels(bounds.maxHeight),
            policy: ResizeImagePolicy.fit,
          ),
        );
      },
    );
  }
}
