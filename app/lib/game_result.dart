import 'package:flutter/material.dart';
import 'cat_character.dart';

enum ResultTheme { blocks, sweet, wordle, leap }

/// Game-specific end card, also usable inside the leap game's paused overlay.
class GameResultCard extends StatelessWidget {
  final ResultTheme game;
  final bool victory;
  final String title, detail, stat, caption, again;
  final String? word;
  final VoidCallback onAgain, onHome;
  const GameResultCard({
    super.key,
    required this.game,
    this.victory = false,
    required this.title,
    required this.detail,
    required this.stat,
    required this.caption,
    required this.again,
    required this.onAgain,
    required this.onHome,
    this.word,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (game) {
      ResultTheme.blocks => const Color(0xff6141a8),
      ResultTheme.sweet => const Color(0xffad5183),
      ResultTheme.wordle => const Color(0xff258066),
      ResultTheme.leap => const Color(0xff365f99),
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Material(
          color: const Color(0xfffffaf1),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color,
                        Color.lerp(color, const Color(0xff1f2246), .45)!,
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        detail,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xfff2e8ff)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          CatActor(
                            cat: CatKind.maru,
                            size: 76,
                            action: CatAction.blocks,
                            showLabel: false,
                            active: victory,
                            crying: !victory,
                          ),
                          Flexible(
                            child: _ResultEmblem(
                              game: game,
                              word: word,
                              color: color,
                            ),
                          ),
                          CatActor(
                            cat: CatKind.lady,
                            size: 76,
                            action: CatAction.blocks,
                            showLabel: false,
                            active: victory,
                            crying: !victory,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        stat,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: color,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        caption,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xff5d6c63),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: color,
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: onAgain,
                          icon: Icon(
                            victory
                                ? Icons.arrow_forward_rounded
                                : Icons.replay_rounded,
                          ),
                          label: Text(again),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: onHome,
                        icon: const Icon(Icons.home_rounded, size: 20),
                        label: const Text('Volver al rincón'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultEmblem extends StatelessWidget {
  final ResultTheme game;
  final String? word;
  final Color color;
  const _ResultEmblem({
    required this.game,
    required this.word,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    if (game == ResultTheme.wordle) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 3,
        runSpacing: 3,
        children: [
          for (final letter in (word ?? 'GATOS').split(''))
            Container(
              width: 25,
              height: 31,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xff64b596),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xff9ee2bc)),
              ),
              child: Text(
                letter,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                ),
              ),
            ),
        ],
      );
    }
    if (game == ResultTheme.blocks) {
      return SizedBox(
        width: 80,
        height: 80,
        child: GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 3,
          crossAxisSpacing: 3,
          children: [
            for (var i = 0; i < 9; i++)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  gradient: LinearGradient(
                    colors: i == 2 || i == 5
                        ? [const Color(0xff756090), const Color(0xff44355b)]
                        : [const Color(0xffffdc7f), const Color(0xffefa457)],
                  ),
                ),
                child: i == 4
                    ? const Icon(Icons.pets, size: 19, color: Colors.white)
                    : null,
              ),
          ],
        ),
      );
    }
    if (game == ResultTheme.sweet) {
      return const SizedBox(
        width: 80,
        height: 90,
        child: CustomPaint(painter: _SweetEmblem()),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Icon(
        game == ResultTheme.sweet
            ? Icons.catching_pokemon
            : Icons.rocket_launch,
        size: 48,
        color: const Color(0xffffdd8c),
      ),
    );
  }
}

Future<bool?> showGameResult(
  BuildContext context, {
  required ResultTheme game,
  bool victory = false,
  required String title,
  required String detail,
  required String stat,
  required String caption,
  required String again,
  String? word,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (context) => PopScope(
    canPop: false,
    child: Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(18),
      child: GameResultCard(
        game: game,
        victory: victory,
        title: title,
        detail: detail,
        stat: stat,
        caption: caption,
        again: again,
        word: word,
        onAgain: () => Navigator.pop(context, true),
        onHome: () => Navigator.pop(context, false),
      ),
    ),
  ),
);

class _SweetEmblem extends CustomPainter {
  const _SweetEmblem();
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 80, size.height / 90);
    final ink = Paint();
    c.drawOval(
      const Rect.fromLTWH(2, 7, 30, 22),
      ink..color = const Color(0xffffb764),
    );
    c.drawPath(
      Path()
        ..moveTo(27, 18)
        ..lineTo(39, 7)
        ..lineTo(39, 28)
        ..close(),
      ink,
    );
    c.drawCircle(const Offset(10, 14), 2, ink..color = Colors.white);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(15, 40, 46, 43),
        const Radius.circular(13),
      ),
      ink..color = const Color(0xffce90d9),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(20, 44, 35, 27),
        const Radius.circular(9),
      ),
      ink..color = const Color(0xffeec5f3),
    );
    c.drawPath(
      Path()
        ..moveTo(36, 46)
        ..quadraticBezierTo(26, 59, 31, 65)
        ..quadraticBezierTo(38, 71, 45, 65)
        ..quadraticBezierTo(50, 59, 40, 46)
        ..close(),
      ink..color = const Color(0xffa85cbd),
    );
    for (final at in [
      const Offset(28, 51),
      const Offset(33, 47),
      const Offset(43, 47),
      const Offset(48, 51),
    ]) {
      c.drawCircle(at, 2.5, ink);
    }
    c.translate(59, 18);
    c.rotate(.3);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-6, -13, 12, 39),
        const Radius.circular(4),
      ),
      ink..color = const Color(0xffff94b4),
    );
    c.drawRect(
      const Rect.fromLTWH(-5, 5, 10, 6),
      ink..color = const Color(0xffffe4c8),
    );
    c.drawLine(
      const Offset(-4, -8),
      const Offset(4, -8),
      ink
        ..color = Colors.white
        ..strokeWidth = 2,
    );
    c.restore();
  }

  @override
  bool shouldRepaint(_SweetEmblem oldDelegate) => false;
}
