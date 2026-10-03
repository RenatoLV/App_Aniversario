import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'store.dart';
import 'paw_background.dart';

class BlocBoard extends StatefulWidget {
  final GameStore store;
  final VoidCallback onAdd, onDraw, onPhoto, onShare;
  final ValueChanged<PocketNote> onEdit;
  final String? status;
  const BlocBoard({
    super.key,
    required this.store,
    required this.onAdd,
    required this.onDraw,
    required this.onPhoto,
    required this.onShare,
    required this.onEdit,
    this.status,
  });
  @override
  State<BlocBoard> createState() => BlocBoardState();
}

class BlocBoardState extends State<BlocBoard> {
  static const world = Size(1100, 1400);
  final view = TransformationController();
  PocketNote? selected;
  bool moving = false;
  bool framedNotes = false;
  Size viewport = Size.zero;
  double startScale = 1;
  double get zoom => view.value.getMaxScaleOnAxis();
  @override
  void dispose() {
    view.dispose();
    super.dispose();
  }

  void focus(PocketNote n) {
    if (!mounted || viewport.isEmpty) return;
    framedNotes = true;
    setState(() => selected = n);
    final at = Offset(
      n.x * (world.width - 180 * n.scale) + 90 * n.scale,
      n.y * (world.height - 170 * n.scale) + 85 * n.scale,
    );
    view.value = Matrix4.identity()
      ..translateByDouble(
        viewport.width / 2 - at.dx,
        viewport.height / 2 - at.dy,
        0,
        1,
      );
  }

  void _zoom(double factor) {
    final center = Offset(viewport.width / 2, viewport.height / 2);
    final at = view.toScene(center), scale = (zoom * factor).clamp(.3, 2.5);
    view.value = Matrix4.identity()
      ..translateByDouble(
        center.dx - at.dx * scale,
        center.dy - at.dy * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _fit() {
    final visible = widget.store.notes.where((n) => !n.deleted).toList();
    if (visible.isEmpty) {
      view.value = Matrix4.identity();
      return;
    }
    var left = double.infinity,
        top = double.infinity,
        right = 0.0,
        bottom = 0.0;
    for (final n in visible) {
      final x = n.x * (world.width - 180 * n.scale),
          y = n.y * (world.height - 170 * n.scale);
      left = math.min(left, x);
      top = math.min(top, y);
      right = math.max(right, x + 180 * n.scale);
      bottom = math.max(bottom, y + 170 * n.scale);
    }
    final scale = math
        .min(
          (viewport.width - 40) / (right - left + 30),
          (viewport.height - 40) / (bottom - top + 30),
        )
        .clamp(.3, 1.3);
    view.value = Matrix4.identity()
      ..translateByDouble(
        viewport.width / 2 - (left + right) / 2 * scale,
        viewport.height / 2 - (top + bottom) / 2 * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  Future<void> _delete() async {
    final n = selected;
    if (n == null) return;
    await widget.store.deleteNote(n);
    if (!mounted) return;
    setState(() => selected = null);
    if (widget.store.notes.every((note) => note.deleted)) {
      view.value = Matrix4.identity();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Elemento retirado del mural'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () async {
            await widget.store.restoreNote(n);
            if (mounted) focus(n);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final notes = widget.store.notes.where((n) => !n.deleted).toList();
      if (selected != null && !notes.contains(selected)) selected = null;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nuestro bloc',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Un rincón para guardar lo que compartimos',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Compartir / unirme al bloc',
                  onPressed: widget.onShare,
                  icon: const Icon(Icons.people_alt_outlined),
                ),
              ],
            ),
          ),
          if (widget.status != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.status!,
                maxLines: 2,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                FilledButton.icon(
                  onPressed: widget.onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Una notita'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onDraw,
                  icon: const Icon(Icons.draw_outlined, size: 18),
                  label: const Text('Pintar'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onPhoto,
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 18,
                  ),
                  label: const Text('Foto'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: LayoutBuilder(
                  builder: (context, c) {
                    viewport = Size(c.maxWidth, c.maxHeight);
                    if (!framedNotes && notes.isNotEmpty) {
                      framedNotes = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _fit();
                      });
                    }
                    return Stack(
                      children: [
                        const Positioned.fill(
                          child: ColoredBox(
                            color: Color(0xfff6efdc),
                            child: CustomPaint(
                              painter: PawPatternPainter(
                                spacing: 110,
                                opacity: .17,
                              ),
                            ),
                          ),
                        ),
                        InteractiveViewer(
                          key: const ValueKey('bloc-viewer'),
                          transformationController: view,
                          constrained: false,
                          minScale: .3,
                          maxScale: 2.5,
                          boundaryMargin: const EdgeInsets.all(180),
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: world.width,
                            height: world.height,
                            child: Stack(
                              children: [
                                const Positioned.fill(
                                  child: CustomPaint(
                                    painter: BlocPaperPainter(),
                                  ),
                                ),
                                if (notes.isEmpty)
                                  Positioned(
                                    left: 25,
                                    top: 28,
                                    child: Container(
                                      width: 270,
                                      padding: const EdgeInsets.all(22),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: .85,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.favorite_outline,
                                            color: Color(0xffcd7d82),
                                            size: 32,
                                          ),
                                          SizedBox(height: 10),
                                          Text(
                                            'Aquí empiezan nuestros recuerdos',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Pega una nota, una foto o un dibujo. Pellizca para acercarte y arrastra el fondo para explorar.',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                for (final n in notes)
                                  _card(n, notes.indexOf(n)),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: Material(
                            color: const Color(0xfffffcf5),
                            borderRadius: BorderRadius.circular(18),
                            elevation: 2,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Alejar mural',
                                  onPressed: () => _zoom(.8),
                                  icon: const Icon(Icons.remove),
                                ),
                                IconButton(
                                  tooltip: 'Encuadrar notas',
                                  onPressed: _fit,
                                  icon: const Icon(Icons.center_focus_strong),
                                ),
                                IconButton(
                                  tooltip: 'Acercar mural',
                                  onPressed: () => _zoom(1.25),
                                  icon: const Icon(Icons.add),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          if (selected != null && !selected!.deleted)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => widget.onEdit(selected!),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar'),
                  ),
                  IconButton(
                    tooltip: 'Reducir elemento',
                    onPressed: () => _resize(.9),
                    icon: const Icon(Icons.zoom_out),
                  ),
                  IconButton(
                    tooltip: 'Agrandar elemento',
                    onPressed: () => _resize(1.1),
                    icon: const Icon(Icons.zoom_in),
                  ),
                  IconButton(
                    tooltip: 'Borrar elemento',
                    onPressed: _delete,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xffb45665),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Quitar selección',
                    onPressed: () => setState(() => selected = null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilterChip(
                  label: Text(moving ? 'Mover notas' : 'Explorar'),
                  avatar: Icon(
                    moving ? Icons.open_with : Icons.pan_tool_alt_outlined,
                    size: 16,
                  ),
                  selected: moving,
                  onSelected: (v) => setState(() => moving = v),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'Toca para seleccionar · pellizca para zoom',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
  void _resize(double factor) {
    final n = selected;
    if (n == null) return;
    setState(() => n.scale = (n.scale * factor).clamp(.46, 2.4));
    widget.store.saveNote(n, waitForSync: false);
  }

  Widget _card(PocketNote n, int index) {
    final w = 180 * n.scale, h = 170 * n.scale;
    return Positioned(
      left: n.x * (world.width - w),
      top: n.y * (world.height - h),
      child: GestureDetector(
        key: ValueKey('bloc-note-${n.cloudId ?? identityHashCode(n)}'),
        onTap: () => setState(() => selected = n),
        onDoubleTap: () => widget.onEdit(n),
        onScaleStart: moving
            ? (d) {
                selected = n;
                startScale = n.scale;
                widget.store.beginNoteEdit(n);
              }
            : null,
        onScaleUpdate: moving
            ? (d) {
                setState(() {
                  if (d.pointerCount > 1) {
                    n.scale = (startScale * d.scale).clamp(.46, 2.4);
                  }
                  n.x = (n.x + d.focalPointDelta.dx / zoom / (world.width - w))
                      .clamp(0, 1);
                  n.y = (n.y + d.focalPointDelta.dy / zoom / (world.height - h))
                      .clamp(0, 1);
                });
              }
            : null,
        onScaleEnd: moving
            ? (d) => widget.store.saveNote(n, waitForSync: false)
            : null,
        child: Container(
          width: w,
          height: h,
          padding: EdgeInsets.all(10 * n.scale),
          decoration: BoxDecoration(
            color: n.imageBase64 != null
                ? const Color(0xfffffcf6)
                : [
                    const Color(0xffffe4a7),
                    const Color(0xffd2eadc),
                    const Color(0xffffd8df),
                  ][index % 3],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected == n
                  ? const Color(0xff278d75)
                  : const Color(0xffdccba9),
              width: selected == n ? 2.5 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 7,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40 * n.scale,
                  height: 5 * n.scale,
                  decoration: BoxDecoration(
                    color: const Color(0xffbbad97).withValues(alpha: .35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              SizedBox(height: 8 * n.scale),
              if (n.imageBase64 != null)
                Expanded(
                  flex: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: _image(n),
                  ),
                ),
              if (n.imageBase64 != null) SizedBox(height: 6 * n.scale),
              Expanded(
                flex: n.imageBase64 != null ? 1 : 5,
                child: Text(
                  n.text,
                  maxLines: n.imageBase64 != null ? 1 : 6,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14 * n.scale,
                    height: 1.4,
                    color: const Color(0xff33493f),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _image(PocketNote n) {
    try {
      return Image.memory(
        base64Decode(n.imageBase64!),
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (context, error, stack) =>
            const Icon(Icons.broken_image_outlined),
      );
    } catch (_) {
      return const Icon(Icons.broken_image_outlined);
    }
  }
}

class BlocPaperPainter extends CustomPainter {
  const BlocPaperPainter();
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xfff6efdc), Color(0xffeee2c9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & s),
    );
    const PawPatternPainter(
      spacing: 140,
      opacity: .23,
      pawScale: 1.35,
    ).paint(c, s);
    final dots = Paint()
      ..color = const Color(0xffb5a78c).withValues(alpha: .14);
    for (var y = 20.0; y < s.height; y += 24) {
      for (var x = 20.0; x < s.width; x += 24) {
        c.drawCircle(Offset(x, y), .8, dots);
      }
    }
    c.drawLine(
      const Offset(18, 0),
      Offset(18, s.height),
      Paint()
        ..color = const Color(0xffc98588).withValues(alpha: .25)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(BlocPaperPainter old) => false;
}
