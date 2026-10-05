import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../domain/book_format.dart';
import '../../providers.dart';
import '../reader/reader_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(booksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('서재')),
      body: books.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('서재를 불러오지 못했습니다.\n$error')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('아래 + 버튼으로 txt, epub, zip/cbz 파일을 추가하세요.'))
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) => _BookTile(book: list[index]),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _import(context, ref),
        tooltip: '파일 가져오기',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(bookImporterProvider).pickAndImport();
      if (result == null) return;
      final skipped = result.skipped.isEmpty
          ? ''
          : ' (지원하지 않는 파일 ${result.skipped.length}개 제외)';
      messenger.showSnackBar(
        SnackBar(content: Text('${result.imported}권을 추가했습니다.$skipped')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('가져오기에 실패했습니다: $error')));
    }
  }
}

class _BookTile extends ConsumerWidget {
  const _BookTile({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(switch (book.format) {
        BookFormat.txt => Icons.description_outlined,
        BookFormat.epub => Icons.menu_book_outlined,
        BookFormat.comic => Icons.photo_library_outlined,
      }),
      title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(book.format.name.toUpperCase()),
      onTap: () {
        ref.read(bookRepositoryProvider).markOpened(book.id);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
        );
      },
      onLongPress: () => _confirmDelete(context, ref),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('책 삭제'),
        content: Text('"${book.title}"을(를) 서재에서 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(bookRepositoryProvider).delete(book.id);
    await ref.read(bookStorageProvider).deleteFile(book.fileName);
  }
}
