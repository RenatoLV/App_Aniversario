import 'package:flutter/material.dart';

/// Observes a deliberate header swipe without stealing scroll/drag gestures.
class MenuSwipe extends StatefulWidget {
  final Widget child;
  final ValueChanged<int> onStep;
  const MenuSwipe({super.key, required this.child, required this.onStep});
  @override
  State<MenuSwipe> createState() => _MenuSwipeState();
}

class _MenuSwipeState extends State<MenuSwipe> {
  Offset? _start;
  Duration? _time;
  int? _pointer;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) {
      if (_pointer != null) {
        _start = null;
        return;
      }
      _pointer = event.pointer;
      // Header only: never mistake moving a note/card/cat for navigation.
      _start = event.localPosition.dy < 170 ? event.position : null;
      _time = event.timeStamp;
    },
    onPointerCancel: (_) {
      _pointer = null;
      _start = null;
    },
    onPointerUp: (event) {
      if (event.pointer != _pointer) return;
      final start = _start;
      _pointer = null;
      _start = null;
      if (start == null || _time == null) return;
      final delta = event.position - start;
      final seconds = (event.timeStamp - _time!).inMicroseconds / 1000000;
      if (seconds > 0 &&
          seconds < .45 &&
          delta.dy.abs() >= 150 &&
          delta.dy.abs() > delta.dx.abs() * 2.5 &&
          delta.dy.abs() / seconds >= 1000 &&
          ModalRoute.of(context)?.isCurrent == true) {
        widget.onStep(delta.dy < 0 ? 1 : -1);
      }
    },
    child: widget.child,
  );
}
