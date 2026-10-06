import 'dart:ui';

import 'package:flutter/material.dart';

/// 읽기 화면 위아래에 뜨는 메뉴 막대. 아이폰의 막대처럼 뒤가 흐리게 비친다.
class ReaderBar extends StatelessWidget {
  const ReaderBar({super.key, required this.top, required this.child});

  /// 위쪽 막대인지. 본문과 맞닿는 쪽에 가는 선을 긋는다.
  final bool top;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final line = BorderSide(color: scheme.outline, width: 0.5);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.86),
            border: top ? Border(bottom: line) : Border(top: line),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: IconTheme.merge(
              data: IconThemeData(color: scheme.primary),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
