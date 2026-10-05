import 'package:drift/drift.dart';

import '../domain/reading_position.dart';
import 'db/app_database.dart';

class ProgressRepository {
  ProgressRepository(this._db);

  final AppDatabase _db;

  Future<ReadingPosition> get(int bookId) async {
    final row = await (_db.select(_db.readingProgress)
          ..where((p) => p.bookId.equals(bookId)))
        .getSingleOrNull();
    if (row == null) return const ReadingPosition();
    return ReadingPosition(
      section: row.section,
      offset: row.charOffset,
      progress: row.progress,
    );
  }

  Future<void> save(int bookId, ReadingPosition position) {
    return _db.into(_db.readingProgress).insertOnConflictUpdate(
          ReadingProgressCompanion.insert(
            bookId: Value(bookId),
            section: Value(position.section),
            charOffset: Value(position.offset),
            progress: Value(position.progress),
            updatedAt: DateTime.now(),
          ),
        );
  }
}
