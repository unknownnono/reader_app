import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../providers.dart';

/// 책의 북마크 목록. 누르면 그 자리로 가고, 휴지통으로 지운다.
class BookmarkList extends ConsumerWidget {
  const BookmarkList({
    super.key,
    required this.bookId,
    required this.onOpen,
    required this.detailOf,
  });

  final int bookId;
  final void Function(Bookmark bookmark) onOpen;

  /// 북마크 아래에 작게 보여 줄 위치 표시(예: "37%")
  final String Function(Bookmark bookmark) detailOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarksProvider(bookId)).value ?? const [];
    if (bookmarks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('북마크가 없습니다.\n위쪽 북마크 버튼으로 지금 보는 곳을 저장하세요.')),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        return ListTile(
          leading: const Icon(Icons.bookmark),
          title: Text(bookmark.label, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(detailOf(bookmark)),
          trailing: IconButton(
            tooltip: '북마크 삭제',
            onPressed: () => ref.read(bookmarkRepositoryProvider).delete(bookmark.id),
            icon: const Icon(Icons.delete_outline),
          ),
          onTap: () => onOpen(bookmark),
        );
      },
    );
  }
}
