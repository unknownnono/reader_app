import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../providers.dart';

/// 책을 읽는 동안에만 적용되는 화면 상태.
/// 화면이 저절로 꺼지지 않게 하고, 설정한 밝기를 적용했다가 나갈 때 되돌린다.
class ReadingSession extends ConsumerStatefulWidget {
  const ReadingSession({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ReadingSession> createState() => _ReadingSessionState();
}

class _ReadingSessionState extends ConsumerState<ReadingSession> {
  @override
  void initState() {
    super.initState();
    _guard(WakelockPlus.enable);
    _applyBrightness(ref.read(readerSettingsProvider).brightness);
  }

  @override
  void dispose() {
    _guard(WakelockPlus.disable);
    _guard(ScreenBrightness.instance.resetApplicationScreenBrightness);
    super.dispose();
  }

  void _applyBrightness(double brightness) {
    if (brightness < 0) {
      _guard(ScreenBrightness.instance.resetApplicationScreenBrightness);
    } else {
      _guard(() => ScreenBrightness.instance.setApplicationScreenBrightness(brightness));
    }
  }

  /// 기기 기능을 쓸 수 없는 환경(테스트 등)에서도 읽기는 계속되어야 한다.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // 화면 꺼짐 방지나 밝기 조절이 안 되는 것은 읽기를 막을 이유가 아니다.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      readerSettingsProvider.select((settings) => settings.brightness),
      (_, brightness) => _applyBrightness(brightness),
    );
    return widget.child;
  }
}
