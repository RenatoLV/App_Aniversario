import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../cat_character.dart';
import '../lucky_palace_theme.dart';
import '../art/lucky_reward_burst.dart';
import 'scratch_catalog.dart';
import 'scratch_mask.dart';
import 'scratch_models.dart';
import 'scratch_engine.dart';
import 'scratch_surface.dart';

/// Manifest geometry in virtual coordinates; every visual layer shares this transform.
class ScratchTicketGeometry {
  static const size = Size(640, 960);
  static const area = Rect.fromLTWH(77, 420, 486, 342);
  static const maru = Rect.fromLTWH(81, 198, 196, 190),
      lady = Rect.fromLTWH(369, 198, 196, 190);
  static const title = Rect.fromLTWH(106, 83, 428, 74),
      caption = Rect.fromLTWH(104, 826, 432, 78);
  static Rect cell(int i) => Rect.fromLTWH(
    77 + 12 + (i % 3) * 159.0,
    420 + 12 + (i ~/ 3) * 106.0,
    143,
    92,
  );
}

class ScratchImages {
  ScratchImages(this.layers, this.symbols);
  final Map<String, ui.Image> layers, symbols;
  static Future<ScratchImages> load(ScratchTheme theme) async {
    final loaded = <ui.Image>[];
    Future<ui.Image> image(String path) async {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      try {
        final frame = await codec.getNextFrame();
        loaded.add(frame.image);
        return frame.image;
      } finally {
        codec.dispose();
      }
    }

    try {
      final layers = <String, ui.Image>{}, symbols = <String, ui.Image>{};
      for (final name in ['background', 'frame', 'reveal_board', 'foil']) {
        layers[name] = await image(theme.asset(name));
      }
      for (final id in theme.symbols) {
        symbols[id] = await image(
          '$scratchAssetRoot/symbols/png/${id}_256.png',
        );
      }
      return ScratchImages(layers, symbols);
    } catch (_) {
      for (final img in loaded) {
        img.dispose();
      }
      rethrow;
    }
  }

  void dispose() {
    for (final image in [...layers.values, ...symbols.values]) {
      image.dispose();
    }
  }
}

class ScratchTicketWidget extends StatefulWidget {
  const ScratchTicketWidget({
    super.key,
    required this.theme,
    this.rulesVersion = ScratchRules.version,
    this.receipt,
    required this.mask,
    required this.onChanged,
    required this.onGestureEnd,
    required this.reaction,
    this.enabled = true,
    this.onStart,
  });
  final ScratchTheme theme;
  final String rulesVersion;
  final ScratchReceipt? receipt;
  final ScratchMask mask;
  final VoidCallback onChanged, onGestureEnd;
  final VoidCallback? onStart;
  final Animation<double> reaction;
  final bool enabled;
  @override
  State<ScratchTicketWidget> createState() => _ScratchTicketWidgetState();
}

class _ScratchTicketWidgetState extends State<ScratchTicketWidget> {
  late Future<ScratchImages> future;
  ScratchImages? images;
  @override
  void initState() {
    super.initState();
    future = ScratchImages.load(widget.theme).then((value) {
      if (!mounted) {
        value.dispose();
        return value; // No mounted consumer can paint these disposed images.
      }
      images = value;
      return value;
    });
  }

  @override
  void dispose() {
    final old = images;
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        old.dispose();
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ScratchImages>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(
          child: Text('No se pudo cargar la ilustración. Vuelve a intentarlo.'),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final art = snapshot.data!;
      return LayoutBuilder(
        builder: (context, c) {
          final scale = (c.maxWidth / 640).clamp(0.0, c.maxHeight / 960);
          final width = 640 * scale, height = 960 * scale;
          Rect rect(Rect r) => Rect.fromLTWH(
            r.left * scale,
            r.top * scale,
            r.width * scale,
            r.height * scale,
          );
          Widget layer(String name, Rect r) => Positioned.fromRect(
            rect: rect(r),
            child: RepaintBoundary(
              child: RawImage(image: art.layers[name], fit: BoxFit.fill),
            ),
          );
          final receipt = widget.receipt;
          return Center(
            child: SizedBox(
              key: const ValueKey('scratch-ticket'),
              width: width,
              height: height,
              child: Semantics(
                image: true,
                label:
                    '${widget.theme.title}. ${receipt?.revealed == true ? 'Nueve símbolos revelados. Premio ${receipt!.gross}, neto ${receipt.net}.' : 'Boleto cubierto, resultado oculto.'}',
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    layer(
                      'background',
                      Offset.zero & ScratchTicketGeometry.size,
                    ),
                    for (final entry in [
                      (true, ScratchTicketGeometry.maru),
                      (false, ScratchTicketGeometry.lady),
                    ])
                      Positioned.fromRect(
                        rect: rect(entry.$2),
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: widget.reaction,
                            builder: (context, _) {
                              final reduced = MediaQuery.disableAnimationsOf(
                                context,
                              );
                              final p = reduced
                                  ? 0.0
                                  : math.sin(widget.reaction.value * math.pi);
                              final joy = receipt?.revealed == true
                                  ? (receipt!.gross > 0 ? .55 : .08)
                                  : .12;
                              return Transform.translate(
                                offset: Offset(
                                  0,
                                  -p *
                                      (receipt?.net != null && receipt!.net > 0
                                          ? 5
                                          : 2),
                                ),
                                child: CustomPaint(
                                  painter: entry.$1
                                      ? MaruPainter(phase: p * .2, joy: joy * p)
                                      : LadyPainter(
                                          phase: p * .2,
                                          joy: joy * p,
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    layer('reveal_board', ScratchTicketGeometry.area),
                    if (receipt != null)
                      for (var i = 0; i < 9; i++)
                        Positioned.fromRect(
                          rect: rect(ScratchTicketGeometry.cell(i).deflate(7)),
                          child: ExcludeSemantics(
                            child: RawImage(
                              image:
                                  art.symbols[widget.theme.symbols[receipt
                                      .outcome
                                      .cells[i]]],
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                    Positioned.fromRect(
                      rect: rect(ScratchTicketGeometry.area),
                      child: receipt == null
                          ? RawImage(
                              image: art.layers['foil'],
                              fit: BoxFit.fill,
                            )
                          : ScratchSurface(
                              key: ValueKey('foil-${receipt.id}'),
                              foil: art.layers['foil']!,
                              mask: widget.mask,
                              revealed: receipt.revealed,
                              enabled: widget.enabled,
                              onChanged: widget.onChanged,
                              onGestureEnd: widget.onGestureEnd,
                              onStart: widget.onStart,
                            ),
                    ),
                    // Frame must never intercept a scratch pointer.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ClipPath(
                          clipper: _FrameOpening(
                            rect(ScratchTicketGeometry.area.deflate(4)),
                          ),
                          child: RawImage(
                            image: art.layers['frame'],
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _TicketText(
                            widget.theme,
                            receipt,
                            widget.rulesVersion,
                          ),
                        ),
                      ),
                    ),
                    if (receipt?.revealed == true)
                      Positioned.fromRect(
                        rect: rect(ScratchTicketGeometry.area),
                        child: IgnorePointer(
                          child: RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: widget.reaction,
                              builder: (context, _) => CustomPaint(
                                painter: _Winners(
                                  receipt!,
                                  MediaQuery.disableAnimationsOf(context)
                                      ? 0
                                      : widget.reaction.value,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// The supplied frame includes a 40% shadow inside the board. Keep its rim,
/// but leave the scratch interior clear so it never dims the revealed symbols.
class _FrameOpening extends CustomClipper<Path> {
  const _FrameOpening(this.opening);
  final Rect opening;
  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addRRect(
      RRect.fromRectAndRadius(opening, Radius.circular(14 * size.width / 640)),
    );
  @override
  bool shouldReclip(_FrameOpening oldClipper) => oldClipper.opening != opening;
}

class _TicketText extends CustomPainter {
  _TicketText(this.theme, this.receipt, this.rulesVersion);
  final ScratchTheme theme;
  final ScratchReceipt? receipt;
  final String rulesVersion;
  void _text(Canvas c, Rect rect, String value, double font) {
    final p = TextPainter(
      text: TextSpan(text: value, style: LuckyPalette.text(font, title: true)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: rect.width);
    p.paint(
      c,
      rect.topLeft +
          Offset((rect.width - p.width) / 2, (rect.height - p.height) / 2),
    );
  }

  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 640, size.height / 960);
    _text(c, ScratchTicketGeometry.title, theme.title, 32);
    _text(
      c,
      ScratchTicketGeometry.caption,
      receipt?.revealed == true
          ? 'Premio ${receipt!.gross} · Coste ${receipt!.cost}\nNeto ${receipt!.net >= 0 ? '+' : ''}${receipt!.net}'
          : (receipt?.rulesVersion ?? rulesVersion) ==
                ScratchRules.enhancedVersion
          ? '3 iguales pagan · 6 ×3 · 9 ×20\n${theme.subtitle}'
          : 'Encuentra tres símbolos iguales\n${theme.subtitle}',
      24,
    );
    c.restore();
  }

  @override
  bool shouldRepaint(_TicketText old) =>
      old.theme != theme ||
      old.receipt != receipt ||
      old.rulesVersion != rulesVersion;
}

class _Winners extends CustomPainter {
  _Winners(this.receipt, this.pulse);
  final ScratchReceipt receipt;
  final double pulse;
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 486, size.height / 342);
    final winners = receipt.outcome.winningSymbols;
    for (var i = 0; i < 9; i++) {
      if (!winners.contains(receipt.outcome.cells[i])) continue;
      final r = ScratchTicketGeometry.cell(
        i,
      ).shift(-ScratchTicketGeometry.area.topLeft).deflate(3);
      c.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(14)),
        Paint()
          ..color = Color(
            receipt.theme.accent,
          ).withValues(alpha: .7 + pulse * .25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 + pulse * 2,
      );
    }
    if (receipt.net > 0) {
      LuckyRewardBurst.paint(
        c,
        const Rect.fromLTWH(0, 0, 486, 342),
        progress: pulse,
        accent: Color(receipt.theme.accent),
        amount: receipt.gross,
        heading: receipt.net > 0 ? '¡PREMIO!' : 'PREMIO BRUTO',
        grand: receipt.net >= receipt.cost,
      );
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_Winners old) =>
      old.receipt != receipt || old.pulse != pulse;
}
