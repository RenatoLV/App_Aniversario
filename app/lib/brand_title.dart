import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BrandTitle extends StatefulWidget {
  final SharedPreferences prefs;
  const BrandTitle({super.key, required this.prefs});
  @override
  State<BrandTitle> createState() => _BrandTitleState();
}

class _BrandTitleState extends State<BrandTitle> {
  static const fonts = <String?>[null, 'Fredoka', 'Nunito', 'Monocraft'];
  late int index =
      (widget.prefs.getInt('appearance.logoFont') ?? 0) % fonts.length;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Toca para cambiar la letra · ${fonts[index] ?? 'Clásica'}',
    child: InkWell(
      key: const ValueKey('brand-font-switch'),
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() => index = (index + 1) % fonts.length);
        widget.prefs.setInt('appearance.logoFont', index);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎈', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 5),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    'Anivermaru',
                    key: ValueKey(index),
                    style: TextStyle(
                      fontFamily: fonts[index],
                      fontWeight: FontWeight.w900,
                      fontSize: index == 3 ? 17 : 20,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            const Text('🎈', style: TextStyle(fontSize: 22)),
          ],
        ),
      ),
    ),
  );
}
