import 'package:flutter/foundation.dart';

/// 기기에서만 나는 문제를 추적하기 위한 화면 표시용 기록.
/// 앱을 끄면 사라진다.
class DiagLog {
  DiagLog._();

  static const _maxLines = 300;
  static final lines = ValueNotifier<List<String>>(const []);

  static void add(String message) {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
    final next = [...lines.value, '$stamp  $message'];
    lines.value = next.length > _maxLines
        ? next.sublist(next.length - _maxLines)
        : next;
    debugPrint('[diag] $message');
  }

  static void clear() => lines.value = const [];
}
