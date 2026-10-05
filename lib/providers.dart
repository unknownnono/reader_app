import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/storage/book_storage.dart';
import 'core/utils/natural_compare.dart';
import 'data/book_repository.dart';
import 'data/db/app_database.dart';
import 'data/progress_repository.dart';
import 'data/settings_repository.dart';
import 'domain/reader_settings.dart';
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

/// 읽은 책은 최근에 읽은 순으로 위에, 아직 안 읽은 책은 제목 순(1권, 2권, … 10권)으로 그 아래에 둔다.
final booksProvider = StreamProvider<List<Book>>(
  (ref) => ref.watch(bookRepositoryProvider).watchAll().map((books) {
    final read = books.where((b) => b.lastReadAt != null);
    final unread = books.where((b) => b.lastReadAt == null).toList()
      ..sort((a, b) => naturalCompare(a.title, b.title));
    return [...read, ...unread];
  }),
);
