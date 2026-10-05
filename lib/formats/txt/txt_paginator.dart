import 'dart:math';

import 'package:flutter/painting.dart';

/// 글자 오프셋 기준으로 페이지 경계를 계산한다.
/// 전체를 미리 나누지 않고 현재 위치에서 한 페이지씩만 계산하므로
/// 큰 파일도 바로 열리고, 글꼴 크기가 바뀌어도 위치를 잃지 않는다.
class TxtPaginator {
  TxtPaginator({
    required this.text,
    required this.style,
    required this.strutStyle,
    required this.pageSize,
  });

  final String text;
  final TextStyle style;
  final StrutStyle strutStyle;
  final Size pageSize;

  /// 한 페이지에 들어갈 수 있는 글자 수의 넉넉한 상한.
  late final int _window = () {
    final fontSize = style.fontSize ?? 14;
    final lineHeight = fontSize * (style.height ?? 1.2);
    final perLine = pageSize.width / (fontSize * 0.4);
    final lines = pageSize.height / lineHeight;
    return max(500, (perLine * lines).ceil());
  }();

  TextPainter _layout(String slice) {
    return TextPainter(
      text: TextSpan(text: slice, style: style),
      strutStyle: strutStyle,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: pageSize.width);
  }

  /// [start]에서 시작하는 페이지가 끝나는 오프셋(다음 페이지의 시작).
  int pageEnd(int start) {
    if (start >= text.length) return text.length;
    final sliceEnd = min(start + _window, text.length);
    final painter = _layout(text.substring(start, sliceEnd));
    try {
      final lines = painter.computeLineMetrics();
      var fit = 0;
      for (final line in lines) {
        if (line.baseline + line.descent > pageSize.height + 0.5) break;
        fit++;
      }
      if (fit >= lines.length) return sliceEnd;
      if (fit == 0) fit = 1;
      final position = painter.getPositionForOffset(
        Offset(0, lines[fit - 1].baseline),
      );
      var end = start + painter.getLineBoundary(position).end;
      // 줄을 끝내는 개행은 이 페이지에 포함시켜 다음 페이지가 빈 줄로 시작하지 않게 한다.
      if (end < text.length && text.codeUnitAt(end) == 0x0A) end++;
      return max(end, start + 1);
    } finally {
      painter.dispose();
    }
  }

  /// [end]에서 끝나는 페이지의 시작 오프셋(이전 페이지로 넘길 때 사용).
  int pageStartBefore(int end) {
    if (end <= 0) return 0;
    final sliceStart = max(0, end - _window);
    // 끝의 개행을 그대로 두면 빈 줄 하나가 더 잡혀 한 줄을 손해 본다.
    final sliceEnd = text.codeUnitAt(end - 1) == 0x0A ? end - 1 : end;
    if (sliceEnd <= sliceStart) return sliceStart;
    final painter = _layout(text.substring(sliceStart, sliceEnd));
    try {
      final lines = painter.computeLineMetrics();
      var first = lines.length - 1;
      for (var i = 0; i < lines.length; i++) {
        final top = lines[i].baseline - lines[i].ascent;
        if (painter.height - top <= pageSize.height + 0.5) {
          first = i;
          break;
        }
      }
      final position = painter.getPositionForOffset(
        Offset(0, lines[first].baseline),
      );
      final start = sliceStart + painter.getLineBoundary(position).start;
      return min(start, end - 1);
    } finally {
      painter.dispose();
    }
  }
}
