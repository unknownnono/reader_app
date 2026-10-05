import 'package:drift/drift.dart';

import '../domain/book_format.dart';
import 'db/app_database.dart';

class BookRepository {
  BookRepository(this._db);

  final AppDatabase _db;

  /// 최근에 읽은 책, 그다음 최근에 추가한 책 순.
  Stream<List<Book>> watchAll() {
    final query = _db.select(_db.books)
      ..orderBy([
        (b) => OrderingTerm.desc(b.lastReadAt),
        (b) => OrderingTerm.desc(b.addedAt),
      ]);
    return query.watch();
  }

  Future<int> add({
    required String title,
    required String fileName,
    required BookFormat format,
  }) {
    return _db.into(_db.books).insert(
          BooksCompanion.insert(
            title: title,
            fileName: fileName,
            format: format,
            addedAt: DateTime.now(),
          ),
        );
  }

  Future<void> markOpened(int id) {
    return (_db.update(_db.books)..where((b) => b.id.equals(id)))
        .write(BooksCompanion(lastReadAt: Value(DateTime.now())));
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.books)..where((b) => b.id.equals(id))).go();
  }
}
