import 'package:flutter/material.dart';
import 'cat_character.dart';
import 'game_audio.dart';
import 'paw_background.dart';

class AudioSettingsPanel extends StatelessWidget {
  final GameAudio audio;
  const AudioSettingsPanel({super.key, required this.audio});

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    backgroundColor: const Color(0xfffaf6ee),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: PawBackground(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ValueListenableBuilder<int>(
              valueListenable: audio.changes,
              builder: (context, value, child) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    children: [
                      CatActor(cat: CatKind.maru, size: 65, showLabel: false),
                      Expanded(
                        child: Text(
                          'Sonido y música',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: Color(0xff2d4c42),
                          ),
                        ),
                      ),
                      CatActor(cat: CatKind.lady, size: 65, showLabel: false),
                    ],
                  ),
                  const Text(
                    'A tu ritmo, con Maru y Lady',
                    style: TextStyle(fontSize: 12, color: Color(0xff647c6e)),
                  ),
                  const SizedBox(height: 18),
                  _channel(
                    context,
                    title: 'Gatitos y efectos',
                    subtitle: 'Ronroneos y sonidos del juego',
                    icon: Icons.pets_rounded,
                    color: const Color(0xffbd6888),
                    enabled: audio.effectsEnabled,
                    value: audio.effectsVolume,
                    onSwitch: (v) => audio.configure(effects: v),
                    onChanged: (v) => audio.configure(sfxGain: v),
                    music: false,
                  ),
                  const SizedBox(height: 12),
                  _channel(
                    context,
                    title: 'Música de fondo',
                    subtitle: 'La banda sonora de tu rincón',
                    icon: Icons.music_note_rounded,
                    color: const Color(0xff287d67),
                    enabled: audio.musicEnabled,
                    value: audio.musicVolume,
                    onSwitch: (v) => audio.configure(music: v),
                    onChanged: (v) => audio.configure(musicGain: v),
                    music: true,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff287d67),
                        padding: const EdgeInsets.all(14),
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Listo'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _channel(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool enabled,
    required double value,
    required ValueChanged<bool> onSwitch,
    required ValueChanged<double> onChanged,
    required bool music,
  }) => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .92),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: color.withValues(alpha: .18)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Switch(
              key: ValueKey(music ? 'music-toggle' : 'effects-toggle'),
              value: enabled,
              onChanged: onSwitch,
              activeThumbColor: Colors.white,
              activeTrackColor: color,
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                enabled ? subtitle : 'En silencio',
                style: const TextStyle(fontSize: 11, color: Color(0xff748478)),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: enabled ? .13 : .05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${(value * 100).round()} %',
                style: TextStyle(
                  color: enabled ? color : Colors.grey,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 7,
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: .16),
            thumbColor: color,
            disabledThumbColor: const Color(0xffa8b5ad),
            thumbShape: const PawSliderThumb(),
            overlayShape: SliderComponentShape.noOverlay,
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            key: ValueKey(music ? 'music-volume' : 'effects-volume'),
            value: value,
            semanticFormatterCallback: (v) =>
                '$title ${(v * 100).round()} por ciento',
            onChanged: enabled ? onChanged : null,
            onChangeEnd: enabled && !music
                ? (_) => audio.play(GameSfx.kitten)
                : null,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              Icons.volume_mute_rounded,
              size: 17,
              color: color.withValues(alpha: .6),
            ),
            Icon(
              Icons.volume_up_rounded,
              size: 20,
              color: color.withValues(alpha: .6),
            ),
          ],
        ),
        if (music) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: enabled ? audio.skipMusic : null,
              icon: const Icon(Icons.skip_next_rounded),
              label: const Text('Siguiente canción'),
            ),
          ),
        ],
      ],
    ),
  );
}

class PawSliderThumb extends SliderComponentShape {
  const PawSliderThumb();
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(34, 36);
  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final color = Color.lerp(
      sliderTheme.disabledThumbColor,
      sliderTheme.thumbColor,
      enableAnimation.value,
    )!;
    final paw = Path()
      ..moveTo(-10, 8)
      ..cubicTo(-12, 2, -5, 0, -4, -3)
      ..cubicTo(-2, -7, 2, -7, 4, -3)
      ..cubicTo(5, 0, 12, 2, 10, 8)
      ..cubicTo(8, 12, 4, 9, 0, 9)
      ..cubicTo(-4, 9, -8, 12, -10, 8)
      ..close();
    for (final toe in const [
      Offset(-11, -7),
      Offset(-4, -13),
      Offset(4, -13),
      Offset(11, -7),
    ]) {
      paw.addOval(Rect.fromCenter(center: toe, width: 6, height: 8));
    }
    canvas.save();
    canvas.translate(center.dx, center.dy + 3);
    final scale = 1 + activationAnimation.value * .12;
    canvas.scale(scale);
    canvas.drawShadow(paw, const Color(0x44000000), 2, true);
    canvas.drawPath(
      paw,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawPath(paw, Paint()..color = color);
    canvas.restore();
  }
}
