import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_app/data/book_repository.dart';
import 'package:reader_app/data/db/app_database.dart';
import 'package:reader_app/domain/book_format.dart';

void main() {
  test('확장자로 포맷을 판별한다', () {
    expect(BookFormat.fromPath('a/소설.TXT'), BookFormat.txt);
    expect(BookFormat.fromPath('book.epub'), BookFormat.epub);
    expect(BookFormat.fromPath('comic.cbz'), BookFormat.comic);
    expect(BookFormat.fromPath('comic.zip'), BookFormat.comic);
    expect(BookFormat.fromPath('photo.pdf'), isNull);
  });

  test('책을 추가하고 삭제한다', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = BookRepository(db);

    final id = await repository.add(
      title: '소설',
      fileName: '소설.txt',
      format: BookFormat.txt,
    );
    var books = await repository.watchAll().first;
    expect(books.single.title, '소설');
    expect(books.single.format, BookFormat.txt);

    await repository.delete(id);
    books = await repository.watchAll().first;
    expect(books, isEmpty);
  });
}
