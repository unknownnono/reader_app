import 'package:flutter/material.dart';

import 'settings_controls.dart';

/// 만화 뷰어에서 여는 설정 창.
void showComicSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (_) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: ComicReadingControls(),
      ),
    ),
  );
}
