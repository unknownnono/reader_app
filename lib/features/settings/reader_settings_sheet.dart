import 'package:flutter/material.dart';

import 'settings_controls.dart';

/// 글 읽기 화면에서 여는 설정 창. 바꾸는 즉시 뒤의 본문에 반영된다.
void showReaderSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    // 뒤의 본문이 바뀌는 모습이 보이도록 어둡게 덮지 않는다.
    barrierColor: Colors.transparent,
    builder: (_) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: TextReadingControls(),
      ),
    ),
  );
}
