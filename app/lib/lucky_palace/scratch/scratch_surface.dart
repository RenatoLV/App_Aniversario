import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'scratch_mask.dart';

class ScratchSurface extends StatefulWidget {
  const ScratchSurface({
    super.key,
    required this.foil,
    required this.mask,
    required this.revealed,
    required this.onChanged,
    required this.onGestureEnd,
    this.enabled = true,
    this.onStart,
  });
  final ui.Image foil;
  final ScratchMask mask;
  final bool revealed, enabled;
  final VoidCallback onChanged, onGestureEnd;
  final VoidCallback? onStart;
  @override
  State<ScratchSurface> createState() => _ScratchSurfaceState();
}

class _ScratchSurfaceState extends State<ScratchSurface>
    with SingleTickerProviderStateMixin {
  final pointers = <int, Offset>{};
  final revision = ValueNotifier<int>(0);
  late final AnimationController dust;
  Path holes = Path();
  final flecks = <Offset>[];
  bool dragging = false;
  @override
  void initState() {
    super.initState();
    dust = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _rebuildPath();
  }

  @override
  void didUpdateWidget(ScratchSurface old) {
    super.didUpdateWidget(old);
    if (old.mask != widget.mask) {
      _rebuildPath();
    }
  }

  void _rebuildPath() {
    final p = Path();
    for (var y = 0; y < ScratchMask.rows; y++) {
      var x = 0;
      while (x < ScratchMask.columns) {
        if (!widget.mask.isSet(y * ScratchMask.columns + x)) {
          x++;
          continue;
        }
        final start = x;
        while (x < ScratchMask.columns &&
            widget.mask.isSet(y * ScratchMask.columns + x)) {
          x++;
        }
        p.addRect(
          Rect.fromLTRB(
            start * ScratchMask.width / ScratchMask.columns,
            y * ScratchMask.height / ScratchMask.rows,
            x * ScratchMask.width / ScratchMask.columns,
            (y + 1) * ScratchMask.height / ScratchMask.rows,
          ),
        );
      }
    }
    holes = p;
    revision.value++;
  }

  void _point(PointerEvent e, {bool first = false}) {
    if (!widget.enabled || widget.revealed) return;
    final box = context.findRenderObject() as RenderBox;
    if (box.size.isEmpty) return;
    final local = box.globalToLocal(e.position);
    final point = Offset(
      local.dx / box.size.width * ScratchMask.width,
      local.dy / box.size.height * ScratchMask.height,
    );
    final previous = pointers[e.pointer];
    if (first && !(Offset.zero & box.size).contains(local)) return;
    pointers[e.pointer] = point;
    dragging = true;
    if (widget.mask.segment(
      previous?.dx ?? point.dx,
      previous?.dy ?? point.dy,
      point.dx,
      point.dy,
      18 * ScratchMask.width / box.size.width,
    )) {
      if (!MediaQuery.disableAnimationsOf(context)) {
        flecks.add(point);
        if (flecks.length > 16) flecks.removeAt(0);
        dust.value = 0;
      }
      _rebuildPath();
      widget.onChanged();
    }
    if (first) widget.onStart?.call();
  }

  void _end(PointerEvent e) {
    pointers.remove(e.pointer);
    dragging = pointers.isNotEmpty;
    if (!dragging) {
      if (!MediaQuery.disableAnimationsOf(context)) dust.forward(from: 0);
      widget.onGestureEnd();
    }
  }

  @override
  void dispose() {
    pointers.clear();
    revision.dispose();
    dust.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.revealed
        ? 'Boleto revelado'
        : 'Superficie plateada. Rasca con el dedo o utiliza Revelar todo.',
    child: Listener(
      key: const ValueKey('scratch-surface'),
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => _point(e, first: true),
      onPointerMove: (e) {
        if (pointers.containsKey(e.pointer)) _point(e);
      },
      onPointerUp: _end,
      onPointerCancel: _end,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _FoilPainter(
            widget.foil,
            () => holes,
            widget.revealed,
            flecks: flecks,
            dust: dust,
            dragging: () => dragging,
            reduced: MediaQuery.disableAnimationsOf(context),
            repaint: Listenable.merge([revision, dust]),
          ),
        ),
      ),
    ),
  );
}

class _FoilPainter extends CustomPainter {
  _FoilPainter(
    this.foil,
    this.holes,
    this.revealed, {
    required this.flecks,
    required this.dust,
    required this.dragging,
    required this.reduced,
    required Listenable repaint,
  }) : super(repaint: repaint);
  final ui.Image foil;
  final Path Function() holes;
  final bool revealed, reduced;
  final List<Offset> flecks;
  final Animation<double> dust;
  final bool Function() dragging;
  @override
  void paint(Canvas canvas, Size size) {
    if (revealed || size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(ScratchMask.corner * size.width / ScratchMask.width),
      ),
    );
    // Only the foil is composed into this bounded layer. Board/symbols stay below.
    canvas.saveLayer(rect, Paint());
    canvas.drawImageRect(
      foil,
      Offset.zero & Size(foil.width.toDouble(), foil.height.toDouble()),
      rect,
      Paint(),
    );
    canvas.save();
    canvas.scale(
      size.width / ScratchMask.width,
      size.height / ScratchMask.height,
    );
    canvas.drawPath(
      holes(),
      Paint()
        ..blendMode = BlendMode.clear
        ..isAntiAlias = false,
    );
    canvas.restore();
    canvas.restore();
    if (!reduced) {
      final alpha = dragging() ? 1.0 : 1 - dust.value;
      for (var i = 0; i < flecks.length; i++) {
        final origin = flecks[i];
        final drift = dust.value;
        final p = Offset(
          origin.dx * size.width / ScratchMask.width + (i % 3 - 1) * drift * 12,
          origin.dy * size.height / ScratchMask.height +
              drift * (8 + i % 4 * 3),
        );
        canvas.drawCircle(
          p,
          1.2 + (i % 2) * .5,
          Paint()
            ..color = Color.lerp(
              const Color(0xffeae8ff),
              const Color(0xffa3a0b6),
              i / 16,
            )!.withValues(alpha: alpha * .7),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FoilPainter old) =>
      old.foil != foil || old.revealed != revealed || old.reduced != reduced;
}
