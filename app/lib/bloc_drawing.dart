import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class BlocDrawingDialog extends StatefulWidget {
  final Uint8List? initialImage;
  const BlocDrawingDialog({super.key, this.initialImage});
  @override
  State<BlocDrawingDialog> createState() => _BlocDrawingDialogState();
}

class _BlocDrawingDialogState extends State<BlocDrawingDialog> {
  final key = GlobalKey();
  final strokes = <BlocStroke>[], redo = <BlocStroke>[];
  ui.Image? initial;
  Color color = const Color(0xff36534b);
  double width = 5;
  String tool = 'Lápiz';
  bool saving = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.initialImage == null) return;
    final codec = await ui.instantiateImageCodec(widget.initialImage!);
    final frame = await codec.getNextFrame();
    codec.dispose();
    if (mounted) {
      setState(() => initial = frame.image);
    } else {
      frame.image.dispose();
    }
  }

  @override
  void dispose() {
    initial?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => saving = true);
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (mounted) Navigator.pop(context, data!.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: Scaffold(
      backgroundColor: const Color(0xfffaf6ee),
      appBar: AppBar(
        title: const Text('Nuestro dibujo'),
        leading: IconButton(
          tooltip: 'Cancelar dibujo',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        actions: [
          TextButton(
            onPressed: saving || strokes.isEmpty ? null : _save,
            child: Text(saving ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      Offset point(Offset p) => Offset(
                        (p.dx / c.maxWidth).clamp(0, 1),
                        (p.dy / c.maxHeight).clamp(0, 1),
                      );
                      return RepaintBoundary(
                        key: key,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (d) => setState(() {
                            redo.clear();
                            strokes.add(
                              BlocStroke(
                                color,
                                width,
                                [point(d.localPosition)],
                                erase: tool == 'Goma',
                                marker: tool == 'Marcador',
                              ),
                            );
                          }),
                          onPanStart: (d) => setState(() {
                            redo.clear();
                            strokes.add(
                              BlocStroke(
                                color,
                                width,
                                [point(d.localPosition)],
                                erase: tool == 'Goma',
                                marker: tool == 'Marcador',
                              ),
                            );
                          }),
                          onPanUpdate: (d) => setState(
                            () =>
                                strokes.last.points.add(point(d.localPosition)),
                          ),
                          child: CustomPaint(
                            painter: BlocDrawingPainter(
                              strokes,
                              initial: initial,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'Lápiz',
                  label: Text('Lápiz'),
                  icon: Icon(Icons.edit_outlined),
                ),
                ButtonSegment(
                  value: 'Marcador',
                  label: Text('Marcador'),
                  icon: Icon(Icons.brush_outlined),
                ),
                ButtonSegment(
                  value: 'Goma',
                  label: Text('Goma'),
                  icon: Icon(Icons.auto_fix_normal_outlined),
                ),
              ],
              selected: {tool},
              onSelectionChanged: (v) => setState(() => tool = v.first),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Wrap(
                spacing: 9,
                runSpacing: 8,
                children: [
                  for (final ink in const [
                    Color(0xff36534b),
                    Color(0xffd67186),
                    Color(0xff568ac7),
                    Color(0xff7aad8e),
                    Color(0xffe7b956),
                    Color(0xffa38bc8),
                    Colors.black,
                    Colors.white,
                  ])
                    Semantics(
                      label: 'Color ${ink.toARGB32()}',
                      button: true,
                      child: InkWell(
                        onTap: () => setState(() => color = ink),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: ink,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == ink
                                  ? const Color(0xff24483f)
                                  : const Color(0xffc9c9c9),
                              width: color == ink ? 3 : 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                const SizedBox(width: 16),
                const Text('Trazo'),
                Expanded(
                  child: Slider(
                    value: width,
                    min: 2,
                    max: 20,
                    onChanged: (v) => setState(() => width = v),
                  ),
                ),
                IconButton(
                  tooltip: 'Deshacer trazo',
                  onPressed: strokes.isEmpty
                      ? null
                      : () => setState(() => redo.add(strokes.removeLast())),
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  tooltip: 'Rehacer trazo',
                  onPressed: redo.isEmpty
                      ? null
                      : () => setState(() => strokes.add(redo.removeLast())),
                  icon: const Icon(Icons.redo),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class BlocStroke {
  final Color color;
  final double width;
  final List<Offset> points;
  final bool erase, marker;
  BlocStroke(
    this.color,
    this.width,
    this.points, {
    this.erase = false,
    this.marker = false,
  });
}

class BlocDrawingPainter extends CustomPainter {
  final List<BlocStroke> strokes;
  final ui.Image? initial;
  BlocDrawingPainter(this.strokes, {this.initial});
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xfffffcf5));
    c.saveLayer(Offset.zero & s, Paint());
    if (initial != null) {
      paintImage(
        canvas: c,
        rect: Offset.zero & s,
        image: initial!,
        fit: BoxFit.contain,
      );
    }
    for (final stroke in strokes) {
      final p = Paint()
        ..color = stroke.color.withValues(alpha: stroke.marker ? 0.4 : 1.0)
        ..strokeWidth = stroke.erase ? stroke.width * 2 : stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..blendMode = stroke.erase ? BlendMode.clear : BlendMode.srcOver;
      Offset at(Offset v) => Offset(v.dx * s.width, v.dy * s.height);
      if (stroke.points.length == 1) {
        c.drawCircle(
          at(stroke.points.first),
          p.strokeWidth / 2,
          p..style = PaintingStyle.fill,
        );
        continue;
      }
      final path = Path()
        ..moveTo(at(stroke.points.first).dx, at(stroke.points.first).dy);
      for (var i = 1; i < stroke.points.length; i++) {
        final prev = at(stroke.points[i - 1]), next = at(stroke.points[i]);
        final middle = (prev + next) / 2;
        path.quadraticBezierTo(prev.dx, prev.dy, middle.dx, middle.dy);
      }
      final last = at(stroke.points.last);
      path.lineTo(last.dx, last.dy);
      c.drawPath(path, p);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(BlocDrawingPainter old) => true;
}
