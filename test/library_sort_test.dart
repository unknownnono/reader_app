import 'package:flutter_test/flutter_test.dart';
import 'package:reader_app/data/db/app_database.dart';
import 'package:reader_app/domain/book_format.dart';
import 'package:reader_app/domain/reader_settings.dart';
import 'package:reader_app/providers.dart';

void main() {
  Book book(int id, String title, {required int addedDay, int? readDay}) {
    return Book(
      id: id,
      title: title,
      fileName: title,
      format: BookFormat.comic,
      addedAt: DateTime(2026, 1, addedDay),
      lastReadAt: readDay == null ? null : DateTime(2026, 2, readDay),
    );
  }

  final books = [
    book(1, '짱 10', addedDay: 1),
    book(2, '짱 2', addedDay: 3, readDay: 5),
    book(3, '가나다', addedDay: 2, readDay: 9),
    book(4, '짱 1', addedDay: 4),
  ];

  List<String> titles(LibrarySort sort) {
    return sortBooks(books, sort).map((b) => b.title).toList();
  }

  test('최근 읽은 순: 읽은 책이 최근 순으로 먼저, 안 읽은 책은 제목 순으로 뒤에 온다', () {
    expect(titles(LibrarySort.recent), ['가나다', '짱 2', '짱 1', '짱 10']);
  });

  test('제목 순: 권 번호를 수로 비교한다', () {
    expect(titles(LibrarySort.title), ['가나다', '짱 1', '짱 2', '짱 10']);
  });

  test('추가한 순: 나중에 넣은 책이 먼저 온다', () {
    expect(titles(LibrarySort.added), ['짱 1', '짱 2', '가나다', '짱 10']);
  });
}
