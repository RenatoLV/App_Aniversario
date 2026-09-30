import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Nothing is persisted until the caller receives an explicit true result.
class CardArPhotoReview extends StatelessWidget {
  final Uint8List photo;
  const CardArPhotoReview({super.key, required this.photo});

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tu foto AR'),
    content: SizedBox(
      width: 320,
      height: MediaQuery.sizeOf(context).height * .46,
      child: Image.memory(photo, fit: BoxFit.contain),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Descartar'),
      ),
      FilledButton.icon(
        onPressed: () => Navigator.pop(context, true),
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('Guardar en Nuestro bloc'),
      ),
    ],
  );
}
