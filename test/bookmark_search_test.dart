import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:reader_app/data/book_repository.dart';
import 'package:reader_app/data/bookmark_repository.dart';
import 'package:reader_app/data/db/app_database.dart';
import 'package:reader_app/domain/book_format.dart';
import 'package:reader_app/features/reader/text_search.dart';

void main() {
  group('BookmarkRepository', () {
    late AppDatabase db;
    late int bookId;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      bookId = await BookRepository(db).add(
        title: '소설',
        fileName: '소설.txt',
        format: BookFormat.txt,
      );
    });

    test('북마크를 앞쪽부터 순서대로 돌려주고 지울 수 있다', () async {
      final repository = BookmarkRepository(db);
      await repository.add(bookId: bookId, position: 500, label: '뒤');
      await repository.add(bookId: bookId, position: 20, label: '앞');

      var bookmarks = await repository.watchFor(bookId).first;
      expect(bookmarks.map((b) => b.label), ['앞', '뒤']);

      await repository.delete(bookmarks.first.id);
      bookmarks = await repository.watchFor(bookId).first;
      expect(bookmarks.map((b) => b.label), ['뒤']);
    });

    test('책을 지우면 그 책의 북마크도 함께 지워진다', () async {
      final repository = BookmarkRepository(db);
      await repository.add(bookId: bookId, position: 1, label: '표시');
      await BookRepository(db).delete(bookId);
      expect(await repository.watchFor(bookId).first, isEmpty);
    });
  });

  test('북마크가 없던 예전 버전의 저장소를 열어도 책은 그대로 있고 북마크를 쓸 수 있다', () async {
    final dir = await Directory.systemTemp.createTemp('migration_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'reader_app.sqlite'));

    // 지금 구조로 만든 뒤 북마크 표를 없애고 버전을 1로 되돌려 예전 상태를 만든다.
    var db = AppDatabase(NativeDatabase(file));
    final bookId = await BookRepository(db).add(
      title: '예전 책',
      fileName: '예전 책.txt',
      format: BookFormat.txt,
    );
    await db.customStatement('DROP TABLE bookmarks');
    await db.customStatement('PRAGMA user_version = 1');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect((await BookRepository(db).watchAll().first).single.title, '예전 책');
    await BookmarkRepository(db).add(bookId: bookId, position: 3, label: '표시');
    expect(await BookmarkRepository(db).watchFor(bookId).first, hasLength(1));
  });

  group('searchText', () {
    const text = '첫 줄에 Apple이 있다.\n둘째 줄에는 없다.\n셋째 줄에 apple 그리고 APPLE.';

    test('대소문자 구분 없이 모두 찾고 위치를 돌려준다', () {
      final matches = searchText(text, 'apple');
      expect(matches, hasLength(3));
      for (final match in matches) {
        expect(text.substring(match.offset, match.offset + 5).toLowerCase(), 'apple');
        expect(match.snippet.toLowerCase(), contains('apple'));
      }
      // 미리보기는 줄바꿈을 공백으로 바꿔 한 줄로 보여 준다.
      expect(matches.first.snippet, isNot(contains('\n')));
    });

    test('빈 검색어나 없는 말은 결과가 없다', () {
      expect(searchText(text, '   '), isEmpty);
      expect(searchText(text, '바나나'), isEmpty);
    });

    test('결과가 많으면 정해진 수까지만 돌려준다', () {
      expect(searchText('가' * 1000, '가'), hasLength(maxSearchResults));
    });
  });
}
