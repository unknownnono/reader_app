import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/storage/book_storage.dart';
import 'data/book_repository.dart';
import 'data/db/app_database.dart';
import 'data/progress_repository.dart';
import 'core/utils/natural_compare.dart';
import 'features/library/import/book_importer.dart';
import 'features/library/import/inbox_scanner.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final bookStorageProvider = Provider<BookStorage>((ref) => BookStorage());

final bookRepositoryProvider = Provider<BookRepository>(
  (ref) => BookRepository(ref.watch(databaseProvider)),
);

final bookImporterProvider = Provider<BookImporter>(
  (ref) => BookImporter(
    ref.watch(bookStorageProvider),
    ref.watch(bookRepositoryProvider),
  ),
);

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(ref.watch(databaseProvider)),
);

/// txt 뷰어 글자 크기. 아직 저장하지 않으므로 앱을 다시 켜면 기본값으로 돌아간다.
class TxtFontSize extends Notifier<double> {
  @override
  double build() => 18;

  void set(double size) => state = size;
}

final txtFontSizeProvider = NotifierProvider<TxtFontSize, double>(TxtFontSize.new);

/// 만화 넘김 방향. 일본 만화는 오른쪽에서 왼쪽으로 읽는다. 아직 저장하지 않는다.
class ComicRightToLeft extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final comicRightToLeftProvider =
    NotifierProvider<ComicRightToLeft, bool>(ComicRightToLeft.new);

final inboxScannerProvider = Provider<InboxScanner>(
  (ref) => InboxScanner(
    ref.watch(bookStorageProvider),
    ref.watch(bookRepositoryProvider),
  ),
);

/// 읽은 책은 최근에 읽은 순으로 위에, 아직 안 읽은 책은 제목 순(1권, 2권, … 10권)으로 그 아래에 둔다.
final booksProvider = StreamProvider<List<Book>>(
  (ref) => ref.watch(bookRepositoryProvider).watchAll().map((books) {
    final read = books.where((b) => b.lastReadAt != null);
    final unread = books.where((b) => b.lastReadAt == null).toList()
      ..sort((a, b) => naturalCompare(a.title, b.title));
    return [...read, ...unread];
  }),
);
