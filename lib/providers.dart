import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drift_flutter/drift_flutter.dart';

import 'core/storage/book_storage.dart';
import 'core/storage/storage_locations.dart';
import 'core/utils/natural_compare.dart';
import 'data/book_repository.dart';
import 'data/bookmark_repository.dart';
import 'data/db/app_database.dart';
import 'data/progress_repository.dart';
import 'data/settings_repository.dart';
import 'domain/book_format.dart';
import 'domain/reader_settings.dart';
import 'features/library/import/book_importer.dart';
import 'features/library/import/inbox_scanner.dart';

/// 앱이 쓰는 폴더. 시작할 때 정해서 바꿔 넣는다. 없으면 전부 문서 폴더를 쓴다.
final storageLocationsProvider = Provider<StorageLocations?>((ref) => null);

final databaseProvider = Provider<AppDatabase>((ref) {
  final storage = ref.watch(storageLocationsProvider);
  final db = AppDatabase(
    storage == null
        ? null
        : driftDatabase(
            name: 'reader_app',
            native: DriftNativeOptions(databaseDirectory: () async => storage.data),
          ),
  );
  ref.onDispose(db.close);
  return db;
});

final bookStorageProvider = Provider<BookStorage>((ref) {
  final storage = ref.watch(storageLocationsProvider);
  if (storage == null) return BookStorage();
  return BookStorage(
    documentsDirectory: () async => storage.inbox,
    dataDirectory: () async => storage.data,
  );
});

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

final bookmarkRepositoryProvider = Provider<BookmarkRepository>(
  (ref) => BookmarkRepository(ref.watch(databaseProvider)),
);

/// 책 id → 그 책의 북마크(앞쪽부터)
final bookmarksProvider = StreamProvider.family<List<Bookmark>, int>(
  (ref, bookId) => ref.watch(bookmarkRepositoryProvider).watchFor(bookId),
);

/// 설정 저장소. main()에서 실제 인스턴스로 바꿔 넣는다. 없으면 설정을 저장하지 않는다.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);

/// 읽기 화면 설정. 바꾸면 바로 저장된다.
class ReaderSettingsNotifier extends Notifier<ReaderSettings> {
  @override
  ReaderSettings build() => ref.watch(settingsRepositoryProvider).load();

  void update(ReaderSettings Function(ReaderSettings) change) {
    state = change(state);
    ref.read(settingsRepositoryProvider).save(state);
  }
}

final readerSettingsProvider =
    NotifierProvider<ReaderSettingsNotifier, ReaderSettings>(ReaderSettingsNotifier.new);

/// 책 id → 진행률(0.0~1.0). 서재에서 얼마나 읽었는지 보여 준다.
final progressMapProvider = StreamProvider<Map<int, double>>(
  (ref) => ref.watch(progressRepositoryProvider).watchAll(),
);

final inboxScannerProvider = Provider<InboxScanner>(
  (ref) => InboxScanner(
    ref.watch(bookStorageProvider),
    ref.watch(bookRepositoryProvider),
  ),
);

final _allBooksProvider = StreamProvider<List<Book>>(
  (ref) => ref.watch(bookRepositoryProvider).watchAll(),
);

/// 서재에 보여 줄 책. 설정한 정렬 방식을 따른다.
final booksProvider = Provider<AsyncValue<List<Book>>>((ref) {
  final sort = ref.watch(readerSettingsProvider.select((s) => s.librarySort));
  return ref.watch(_allBooksProvider).whenData((books) => sortBooks(books, sort));
});

/// [current] 다음에 읽을 만화. 서재의 만화를 제목 순으로 놓았을 때 바로 다음 책이다.
Book? nextComic(List<Book> books, Book current) {
  final comics = books.where((b) => b.format == BookFormat.comic).toList()
    ..sort((a, b) => naturalCompare(a.title, b.title));
  final index = comics.indexWhere((b) => b.id == current.id);
  return index == -1 || index + 1 >= comics.length ? null : comics[index + 1];
}

final nextComicProvider = Provider.family<Book?, Book>((ref, current) {
  final books = ref.watch(_allBooksProvider).value ?? const <Book>[];
  return nextComic(books, current);
});

List<Book> sortBooks(List<Book> books, LibrarySort sort) {
  int byTitle(Book a, Book b) => naturalCompare(a.title, b.title);
  switch (sort) {
    case LibrarySort.recent:
      // 읽은 책은 최근에 읽은 순으로 위에, 아직 안 읽은 책은 제목 순(1권, 2권, … 10권)으로 그 아래에 둔다.
      final read = books.where((b) => b.lastReadAt != null).toList()
        ..sort((a, b) => b.lastReadAt!.compareTo(a.lastReadAt!));
      final unread = books.where((b) => b.lastReadAt == null).toList()..sort(byTitle);
      return [...read, ...unread];
    case LibrarySort.title:
      return [...books]..sort(byTitle);
    case LibrarySort.added:
      return [...books]..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }
}
