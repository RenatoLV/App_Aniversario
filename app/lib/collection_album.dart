import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Two numbered pockets per spread; undiscovered cards keep their catalog slot.
class CollectionAlbum extends StatefulWidget {
  final String title;
  final bool teal;
  final List<int> cardIds;
  final Set<int> ownedIds;
  final VoidCallback onClose;
  final Widget Function(int id, List<int> companions, bool active) cardBuilder;
  const CollectionAlbum({
    super.key,
    required this.title,
    required this.teal,
    required this.cardIds,
    required this.ownedIds,
    required this.onClose,
    required this.cardBuilder,
  });

  @override
  State<CollectionAlbum> createState() => _CollectionAlbumState();
}

class _CollectionAlbumState extends State<CollectionAlbum> {
  final _pages = PageController();
  int _spread = 0;
  bool _onlyOwned = false;
  List<int> get _ids => widget.cardIds
      .where((id) => !_onlyOwned || widget.ownedIds.contains(id))
      .toList();
  int get _count => math.max(1, (_ids.length / 2).ceil());

  void _turn(int page) {
    if (page < 0 || page >= _count || !_pages.hasClients) return;
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ids = _ids;
    final accent = widget.teal
        ? const Color(0xff176f70)
        : const Color(0xff67408e);
    final count = _count;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) widget.onClose();
      },
      child: ColoredBox(
        color: const Color(0xffeee5d6),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onClose,
                    tooltip: 'Cerrar álbum',
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 19,
                      ),
                    ),
                  ),
                  Text(
                    '${widget.cardIds.where(widget.ownedIds.contains).length}/${widget.cardIds.length}',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Desliza para pasar las páginas',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  FilterChip(
                    label: const Text('Mis cartas'),
                    selected: _onlyOwned,
                    onSelected: (value) {
                      if (_pages.hasClients) _pages.jumpToPage(0);
                      setState(() {
                        _onlyOwned = value;
                        _spread = 0;
                      });
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ClipRect(
                child: ids.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Aún no has descubierto cartas de este volumen.\nAbre un sobre para empezar tu álbum.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : TweenAnimationBuilder<double>(
                        tween: Tween(begin: .18, end: 0),
                        duration: const Duration(milliseconds: 550),
                        builder: (context, angle, child) => Transform(
                          alignment: Alignment.centerLeft,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, .001)
                            ..rotateY(angle),
                          child: child,
                        ),
                        child: PageView.builder(
                          key: const ValueKey('album-pages'),
                          controller: _pages,
                          itemCount: count,
                          onPageChanged: (page) =>
                              setState(() => _spread = page),
                          itemBuilder: (context, spread) {
                            final visible = ids
                                .skip(spread * 2)
                                .take(2)
                                .toList();
                            final companions = visible
                                .where(widget.ownedIds.contains)
                                .toList();
                            return TickerMode(
                              enabled: spread == _spread,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final pocketWidth = math.max(
                                    70.0,
                                    (constraints.maxWidth - 72) / 2,
                                  );
                                  final cardHeight = pocketWidth / .58;
                                  return SingleChildScrollView(
                                    key: PageStorageKey('album-spread-$spread'),
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      12,
                                      16,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xfffffbf1),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: accent,
                                          width: 5,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x26000000),
                                            blurRadius: 10,
                                            offset: Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Stack(
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                for (
                                                  var side = 0;
                                                  side < 2;
                                                  side++
                                                )
                                                  Expanded(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.fromLTRB(
                                                            9,
                                                            18,
                                                            9,
                                                            12,
                                                          ),
                                                      child: Column(
                                                        children: [
                                                          SizedBox(
                                                            height: cardHeight,
                                                            child:
                                                                side <
                                                                    visible
                                                                        .length
                                                                ? widget.cardBuilder(
                                                                    visible[side],
                                                                    companions,
                                                                    spread ==
                                                                        _spread,
                                                                  )
                                                                : const Center(
                                                                    child: Icon(
                                                                      Icons
                                                                          .auto_stories,
                                                                      color: Color(
                                                                        0xffccbda6,
                                                                      ),
                                                                    ),
                                                                  ),
                                                          ),
                                                          const SizedBox(
                                                            height: 22,
                                                          ),
                                                          Text(
                                                            side <
                                                                    visible
                                                                        .length
                                                                ? 'Carta ${widget.cardIds.indexOf(visible[side]) + 1}'
                                                                : 'Fin del álbum',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 11,
                                                                  color: Color(
                                                                    0xff81715b,
                                                                  ),
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            Positioned.fill(
                                              child: IgnorePointer(
                                                child: Center(
                                                  child: Container(
                                                    width: 16,
                                                    decoration:
                                                        const BoxDecoration(
                                                          gradient:
                                                              LinearGradient(
                                                                colors: [
                                                                  Color(
                                                                    0x00aa987c,
                                                                  ),
                                                                  Color(
                                                                    0x44998469,
                                                                  ),
                                                                  Color(
                                                                    0x00aa987c,
                                                                  ),
                                                                ],
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
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Página anterior',
                  onPressed: _spread > 0 ? () => _turn(_spread - 1) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                DropdownButton<int>(
                  value: _spread.clamp(0, count - 1),
                  underline: const SizedBox(),
                  menuMaxHeight: 280,
                  onChanged: ids.isEmpty
                      ? null
                      : (page) {
                          if (page != null) _turn(page);
                        },
                  items: [
                    for (var page = 0; page < count; page++)
                      DropdownMenuItem(
                        value: page,
                        child: Text(
                          '${page * 2 + 1}–${page * 2 + 2} / ${count * 2}',
                          style: TextStyle(color: accent, fontSize: 13),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  tooltip: 'Página siguiente',
                  onPressed: _spread < count - 1
                      ? () => _turn(_spread + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
