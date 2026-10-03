import 'package:flutter/material.dart';
import 'store.dart';

/// One animated-image implementation shared by every card surface. Image's
/// multi-frame decoder preserves the GIF's timing, disposal and loop metadata.
class CardMedia extends StatelessWidget {
  final int cardId;
  final Key? imageKey;
  const CardMedia({super.key, required this.cardId, this.imageKey});
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
    return Image.asset(
      asset,
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
  }
}
