import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/db/app_database.dart';
import '../../providers.dart';
import '../library/book_cover.dart';
import '../reader/reader_screen.dart';

/// 한 번에 보여 줄 최근 책 수
const _maxRecent = 30;

/// 최근 탭. 마지막으로 읽던 책을 크게 보여 주고 그 아래에 최근에 읽은 책을 늘어놓는다.
class RecentScreen extends ConsumerWidget {
  const RecentScreen({super.key, required this.onOpenFiles});

  /// 읽은 책이 없을 때 파일 탭으로 보내는 버튼이 부른다.
  final VoidCallback onOpenFiles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentBooksProvider).take(_maxRecent).toList();

    void open(Book book) {
      ref.read(bookRepositoryProvider).markOpened(book.id);
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 20,
        title: const LargeTitle('최근'),
      ),
      body: recent.isEmpty
          ? _Empty(onOpenFiles: onOpenFiles)
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _ContinueCard(book: recent.first, onOpen: () => open(recent.first)),
                if (recent.length > 1) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
                    child: Text('이전에 읽은 책', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  for (final book in recent.skip(1))
                    _RecentRow(book: book, onOpen: () => open(book)),
                ],
              ],
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onOpenFiles});

  final VoidCallback onOpenFiles;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.book, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text('아직 읽은 책이 없습니다.'),
            const SizedBox(height: 4),
            Text(
              '책을 열면 여기에서 바로 이어 읽을 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onOpenFiles, child: const Text('파일에서 책 고르기')),
          ],
        ),
      ),
    );
  }
}

String _progressText(Book book, double? progress) {
  final format = book.format.name.toUpperCase();
  return progress == null ? format : '$format · ${(progress * 100).round()}%';
}

/// 마지막으로 읽던 책. 표지를 크게 보여 주고 바로 이어 읽게 한다.
class _ContinueCard extends ConsumerWidget {
  const _ContinueCard({required this.book, required this.onOpen});

  final Book book;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progress = ref.watch(progressMapProvider.select((map) => map.value?[book.id]));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  height: 144,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: BookCover(book: book),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 144,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '읽던 책',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _progressText(book, progress),
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        if (progress != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(value: progress, minHeight: 4),
                          ),
                        const SizedBox(height: 10),
                        FilledButton(onPressed: onOpen, child: const Text('이어 읽기')),
                      ],
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
}

class _RecentRow extends ConsumerWidget {
  const _RecentRow({required this.book, required this.onOpen});

  final Book book;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressMapProvider.select((map) => map.value?[book.id]));
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: SizedBox(
        width: 40,
        height: 56,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: BookCover(book: book),
        ),
      ),
      title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(_progressText(book, progress)),
      onTap: onOpen,
    );
  }
}
