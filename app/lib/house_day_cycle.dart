import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

enum HousePeriod { dawn, day, dusk, night }

/// Uses the device's local wall clock, including its timezone and clock changes.
@immutable
class HouseLight {
  final double daylight, warmth;
  final HousePeriod period;
  const HouseLight(this.daylight, this.warmth, this.period);

  factory HouseLight.at(DateTime localTime) {
    final hour = localTime.hour + localTime.minute / 60;
    if (hour >= 7 && hour < 17) {
      return const HouseLight(1, 0, HousePeriod.day);
    }
    if (hour >= 5.5 && hour < 7) {
      final t = (hour - 5.5) / 1.5;
      return HouseLight(_smooth(t), math.sin(t * math.pi), HousePeriod.dawn);
    }
    if (hour >= 17 && hour < 19) {
      final t = (hour - 17) / 2;
      return HouseLight(
        1 - _smooth(t),
        math.sin(t * math.pi),
        HousePeriod.dusk,
      );
    }
    return const HouseLight(0, 0, HousePeriod.night);
  }

  static double _smooth(double t) => t * t * (3 - 2 * t);
  double get night => 1 - daylight;
  String get label => switch (period) {
    HousePeriod.dawn => 'Amanecer',
    HousePeriod.day => 'Día',
    HousePeriod.dusk => 'Atardecer',
    HousePeriod.night => 'Noche',
  };
  IconData get icon => switch (period) {
    HousePeriod.night => Icons.nightlight_round,
    HousePeriod.dawn || HousePeriod.dusk => Icons.wb_twilight_rounded,
    HousePeriod.day => Icons.wb_sunny_rounded,
  };

  Color tint(Color day, Color night, [Color? sunset]) => Color.lerp(
    Color.lerp(night, day, daylight),
    sunset ?? day,
    warmth * .55,
  )!;
  Color get wallTop => tint(
    const Color(0xfff8eddf),
    const Color(0xff292b43),
    const Color(0xfff5d8bf),
  );
  Color get wallBottom => tint(
    const Color(0xffeee0ce),
    const Color(0xff403b50),
    const Color(0xffdcb69d),
  );
  Color get floor => tint(const Color(0xffdfc4a8), const Color(0xff65525b));
  Color get text => tint(const Color(0xff435d4c), const Color(0xfff7e9cf));
  Color get skyTop => tint(
    const Color(0xffa4dcec),
    const Color(0xff131d42),
    const Color(0xffb48eae),
  );
  Color get skyBottom => tint(
    const Color(0xffd9f0ef),
    const Color(0xff424264),
    const Color(0xffffb981),
  );

  static HouseLight lerp(HouseLight a, HouseLight b, double t) => HouseLight(
    a.daylight + (b.daylight - a.daylight) * t,
    a.warmth + (b.warmth - a.warmth) * t,
    b.period,
  );
}

class _HouseLightTween extends Tween<HouseLight> {
  _HouseLightTween({required HouseLight begin, required HouseLight end})
    : super(begin: begin, end: end);
  @override
  HouseLight lerp(double t) => HouseLight.lerp(begin!, end!, t);
}

/// Refreshes while open and immediately after resuming from the background.
/// No time is saved or synchronized: each phone shows its own current time.
class HouseDayCycle extends StatefulWidget {
  final Widget Function(BuildContext, HouseLight) builder;
  final DateTime Function()? clock;
  const HouseDayCycle({super.key, required this.builder, this.clock});
  @override
  State<HouseDayCycle> createState() => _HouseDayCycleState();
}

class _HouseDayCycleState extends State<HouseDayCycle>
    with WidgetsBindingObserver {
  late HouseLight _light;
  Timer? _timer;
  HouseLight _read() => HouseLight.at((widget.clock ?? DateTime.now)());

  @override
  void initState() {
    super.initState();
    _light = _read();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  void _refresh() {
    final next = _read();
    if (next.daylight != _light.daylight ||
        next.warmth != _light.warmth ||
        next.period != _light.period) {
      setState(() => _light = next);
    }
  }

  @override
  void didUpdateWidget(covariant HouseDayCycle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clock != widget.clock) _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _startTimer();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<HouseLight>(
    tween: _HouseLightTween(begin: _light, end: _light),
    duration: const Duration(milliseconds: 900),
    curve: Curves.easeInOut,
    builder: (context, light, _) => widget.builder(context, light),
  );
}

class HouseTimeBadge extends StatelessWidget {
  final HouseLight light;
  const HouseTimeBadge({super.key, required this.light});
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${light.label} en la casita, según la hora del dispositivo',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(light.icon, size: 17, color: light.text),
        const SizedBox(width: 5),
        Text(light.label, style: TextStyle(fontSize: 10, color: light.text)),
      ],
    ),
  );
}

/// A gentle lamp halo behind the cats keeps night scenes legible.
class HouseLampPainter extends CustomPainter {
  final HouseLight light;
  const HouseLampPainter(this.light);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .5, size.height * .35);
    final halo = Rect.fromCenter(
      center: center,
      width: size.width,
      height: size.height * 1.2,
    );
    canvas.drawOval(
      halo,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xffffcd86).withValues(alpha: light.night * .32),
            Colors.transparent,
          ],
        ).createShader(halo),
    );
    final p = Paint()
      ..color = light.tint(const Color(0xffb48e69), const Color(0xffedcba0));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 25, height: 15),
        const Radius.circular(6),
      ),
      p,
    );
    canvas.drawLine(
      center + const Offset(-8, 9),
      center + const Offset(8, 9),
      Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = const Color(
          0xffffd58f,
        ).withValues(alpha: .15 + light.night * .85),
    );
  }

  @override
  bool shouldRepaint(covariant HouseLampPainter old) => old.light != light;
}
