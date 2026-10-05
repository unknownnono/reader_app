import 'package:drift/drift.dart';

import 'db/app_database.dart';

class BookmarkRepository {
  BookmarkRepository(this._db);

  final AppDatabase _db;

  /// 책의 북마크를 앞쪽부터 순서대로
  Stream<List<Bookmark>> watchFor(int bookId) {
    final query = _db.select(_db.bookmarks)
      ..where((b) => b.bookId.equals(bookId))
      ..orderBy([(b) => OrderingTerm.asc(b.position)]);
    return query.watch();
  }

  Future<void> add({required int bookId, required int position, required String label}) {
    return _db.into(_db.bookmarks).insert(
          BookmarksCompanion.insert(
            bookId: bookId,
            position: position,
            label: label,
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.bookmarks)..where((b) => b.id.equals(id))).go();
  }
}
