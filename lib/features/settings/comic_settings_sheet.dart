import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/reader_settings.dart';
import '../../providers.dart';

/// 만화 뷰어에서 여는 설정 창.
void showComicSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (_) => const _ComicSettingsSheet(),
  );
}

class _ComicSettingsSheet extends ConsumerWidget {
  const _ComicSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);
    final paged = settings.comicMode == ComicMode.paged;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('보기 방식'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final mode in ComicMode.values)
                  ChoiceChip(
                    label: Text(mode.label),
                    selected: settings.comicMode == mode,
                    onSelected: (_) => notifier.update((s) => s.copyWith(comicMode: mode)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('넘기는 방향'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final rightToLeft in [false, true])
                  ChoiceChip(
                    label: Text(rightToLeft ? '오른쪽 → 왼쪽 (일본 만화)' : '왼쪽 → 오른쪽'),
                    selected: settings.comicRightToLeft == rightToLeft,
                    // 세로 스크롤에는 좌우 방향이 없다.
                    onSelected: paged
                        ? (_) => notifier.update(
                              (s) => s.copyWith(comicRightToLeft: rightToLeft),
                            )
                        : null,
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('가로 화면에서 두 쪽 보기'),
              value: settings.comicDoublePage,
              onChanged: paged
                  ? (value) => notifier.update((s) => s.copyWith(comicDoublePage: value))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
