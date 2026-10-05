import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/book_format.dart';

part 'app_database.g.dart';

class Books extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();

  /// 앱 내부 books 폴더 기준 파일 이름.
  /// iOS는 설치/업데이트마다 샌드박스 절대 경로가 바뀌므로 절대 경로를 저장하지 않는다.
  TextColumn get fileName => text()();
  TextColumn get format => textEnum<BookFormat>()();
  TextColumn get coverPath => text().nullable()();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get lastReadAt => dateTime().nullable()();
}

class ReadingProgress extends Table {
  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get section => integer().withDefault(const Constant(0))();
  IntColumn get charOffset => integer().withDefault(const Constant(0))();
  RealColumn get progress => real().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {bookId};
}

class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();

  /// txt·epub은 글자 오프셋, 만화는 쪽 번호(0부터)
  IntColumn get position => integer()();

  /// 목록에 보여 줄 글. 그 자리의 첫 문장이나 "12쪽" 같은 표시다.
  TextColumn get label => text()();
  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(tables: [Books, ReadingProgress, Bookmarks])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'reader_app'));

  /// 2: 북마크 표 추가
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 2) await migrator.createTable(bookmarks);
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
