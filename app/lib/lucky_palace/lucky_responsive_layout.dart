import 'package:flutter/material.dart';
import 'lucky_palace_theme.dart';

/// Region budgets depend on available height and scaled text, never phone names.
class LuckyLayoutPolicy {
  const LuckyLayoutPolicy(this.landscape, this.compact);
  static const header = 56.0, toolbar = 56.0, maxWidth = 1200.0;
  static const compactHud = 48.0,
      normalHud = 48.0,
      sidebar = 176.0,
      accessibleSidebar = 208.0,
      actionsWidth = 520.0;
  final bool landscape, compact;
  factory LuckyLayoutPolicy.of(BoxConstraints c, TextScaler text) {
    final landscape = c.maxWidth > c.maxHeight;
    final compact = text.scale(16) > 22 || c.maxHeight < 720;
    return LuckyLayoutPolicy(landscape, compact);
  }
  double get hudHeight => compact ? compactHud : normalHud;
}

class LuckyResponsiveLayout extends StatelessWidget {
  const LuckyResponsiveLayout({
    super.key,
    required this.policy,
    required this.header,
    required this.hud,
    required this.sidebar,
    required this.cabinet,
    required this.actions,
  });
  final LuckyLayoutPolicy policy;
  final Widget header, hud, sidebar, cabinet, actions;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: LuckyLayoutPolicy.maxWidth),
      child: IconButtonTheme(
        data: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: LuckyPalette.goldLight,
            disabledForegroundColor: LuckyPalette.goldLight.withValues(
              alpha: .45,
            ),
          ),
        ),
        child: FocusTraversalGroup(
          child: Column(
            children: [
              SizedBox(
                key: const ValueKey('lucky-appbar-region'),
                height: LuckyLayoutPolicy.header,
                child: header,
              ),
              if (!policy.landscape)
                SizedBox(
                  key: const ValueKey('lucky-hud-region'),
                  height: policy.hudHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xaa29182f), Color(0x88281835)],
                      ),
                      border: Border.symmetric(
                        horizontal: BorderSide(
                          color: LuckyPalette.gold.withValues(alpha: .35),
                        ),
                      ),
                    ),
                    child: hud,
                  ),
                ),
              Expanded(
                child: policy.landscape
                    ? Row(
                        children: [
                          SizedBox(
                            width:
                                MediaQuery.textScalerOf(context).scale(16) > 22
                                ? LuckyLayoutPolicy.accessibleSidebar
                                : LuckyLayoutPolicy.sidebar,
                            child: SingleChildScrollView(
                              key: const ValueKey('lucky-hud-region'),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0x99281835),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: LuckyPalette.gold.withValues(
                                      alpha: .35,
                                    ),
                                  ),
                                ),
                                child: sidebar,
                              ),
                            ),
                          ),
                          Expanded(
                            child: SizedBox.expand(
                              key: const ValueKey('lucky-cabinet-region'),
                              child: cabinet,
                            ),
                          ),
                        ],
                      )
                    : SizedBox.expand(
                        key: const ValueKey('lucky-cabinet-region'),
                        child: cabinet,
                      ),
              ),
              SizedBox(
                key: const ValueKey('lucky-toolbar-region'),
                height: LuckyLayoutPolicy.toolbar,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: LuckyLayoutPolicy.actionsWidth,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xcc21172d),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: LuckyPalette.gold.withValues(alpha: .4),
                        ),
                      ),
                      child: actions,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
