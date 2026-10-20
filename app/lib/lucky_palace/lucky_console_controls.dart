import 'package:flutter/material.dart';
import 'lucky_palace_theme.dart';

/// Casino control: compact physical button; the action stays fully accessible.
class LuckySpinControl extends StatefulWidget {
  const LuckySpinControl({
    super.key,
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;
  @override
  State<LuckySpinControl> createState() => _LuckySpinControlState();
}

class _LuckySpinControlState extends State<LuckySpinControl> {
  bool pressed = false, hovered = false;
  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 140);
    return Tooltip(
      message: widget.label,
      child: Semantics(
        label: widget.label,
        button: true,
        enabled: widget.enabled,
        onTap: widget.enabled ? widget.onPressed : null,
        child: ExcludeSemantics(
          child: AnimatedScale(
            duration: duration,
            scale: pressed ? .94 : 1,
            child: AnimatedContainer(
              duration: duration,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xfffff0ad),
                    Color(0xffefb348),
                    Color(0xffb26a24),
                  ],
                ),
                border: Border.all(color: LuckyPalette.goldLight, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff583127),
                    offset: Offset(0, pressed ? 2 : 5),
                  ),
                  if (hovered && widget.enabled)
                    const BoxShadow(color: Color(0x55ffd46d), blurRadius: 12),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xfff9d576), Color(0xffde9639)],
                    ),
                    border: Border.all(
                      color: const Color(0xff9a592d),
                      width: 1.5,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: widget.enabled ? widget.onPressed : null,
                      onHover: (v) => setState(() => hovered = v),
                      onHighlightChanged: (v) => setState(() => pressed = v),
                      child: AnimatedSwitcher(
                        duration: duration,
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: ScaleTransition(scale: a, child: child),
                        ),
                        child: Icon(
                          widget.icon,
                          key: ValueKey(widget.icon),
                          size: 34,
                          color: widget.enabled
                              ? const Color(0xff592b30)
                              : const Color(0xff8c704f),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animate only a confirmed value change, never fake a counting balance.
class LuckyResourceValue extends StatelessWidget {
  const LuckyResourceValue({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label, value;
  final IconData icon;
  String get displayValue {
    final n = int.tryParse(value);
    if (n == null || n < 10000) return value;
    for (final unit in [
      (1000000000000000, 'P'),
      (1000000000000, 'T'),
      (1000000000, 'B'),
      (1000000, 'M'),
      (1000, 'k'),
    ]) {
      if (n >= unit.$1) {
        final scaled = n / unit.$1;
        return '${scaled < 10 ? scaled.toStringAsFixed(1) : scaled.floor()}${unit.$2}';
      }
    }
    return value;
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: '$label: $value',
    child: Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: LuckyPalette.goldLight, size: 20),
          const SizedBox(width: 4),
          Flexible(
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(
                  scale: Tween<double>(begin: .92, end: 1).animate(a),
                  child: child,
                ),
              ),
              child: Text(
                displayValue,
                key: ValueKey(value),
                style: LuckyPalette.text(16, title: true),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
