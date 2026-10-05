import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:reader_app/core/storage/book_storage.dart';
import 'package:reader_app/data/book_repository.dart';
import 'package:reader_app/data/db/app_database.dart';
import 'package:reader_app/domain/book_format.dart';
import 'package:reader_app/features/library/import/book_importer.dart';
import 'package:reader_app/features/library/import/inbox_scanner.dart';
import 'package:reader_app/formats/comic/comic_archive.dart';

void main() {
  late Directory docs;
  late BookStorage storage;
  late BookRepository repository;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('import_test');
    addTearDown(() => docs.delete(recursive: true));
    storage = BookStorage(documentsDirectory: () async => docs);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    repository = BookRepository(db);
  });

  Future<void> write(String relativePath) async {
    final file = File(p.join(docs.path, relativePath));
    await file.create(recursive: true);
    await file.writeAsBytes([1]);
  }

  Future<Map<String, Book>> booksByTitle() async {
    return {for (final book in await repository.watchAll().first) book.title: book};
  }

  group('InboxScanner', () {
    test('앱 폴더에 넣은 폴더와 파일을 책으로 가져오고 books로 옮긴다', () async {
      await write('짱 01/01-001.jpg');
      await write('짱 01/01-002.jpg');
      await write('나루토/01/001.png');
      await write('나루토/02/001.png');
      await write('소설.txt');
      await write('만화.cbz');
      await write('메모.pdf');
      await write('reader_app.sqlite');
      await write('books/기존 책/1.jpg');

      expect(await InboxScanner(storage, repository).scan(), 5);

      final books = await booksByTitle();
      expect(books.keys, unorderedEquals(['짱 01', '나루토 01', '나루토 02', '소설', '만화']));
      expect(books['짱 01']!.format, BookFormat.comic);
      expect(books['소설']!.format, BookFormat.txt);

      final comic = await ComicArchive.open(
        await storage.pathFor(books['짱 01']!.fileName),
      );
      expect(comic.pageCount, 2);

      // 가져온 것은 문서 폴더에서 사라지고, 모르는 파일과 기존 책은 그대로 둔다.
      final left = await docs.list().map((e) => p.basename(e.path)).toList();
      expect(left, unorderedEquals(['books', '메모.pdf', 'reader_app.sqlite']));
      expect(await File(p.join(docs.path, 'books', '기존 책', '1.jpg')).exists(), isTrue);

      // 다시 스캔해도 중복으로 들어가지 않는다.
      expect(await InboxScanner(storage, repository).scan(), 0);
    });

    test('같은 이름의 책이 이미 있으면 번호를 붙여 따로 보관한다', () async {
      await write('짱 01/1.jpg');
      await InboxScanner(storage, repository).scan();
      await write('짱 01/1.jpg');
      await InboxScanner(storage, repository).scan();

      final books = await repository.watchAll().first;
      expect(books.map((b) => b.fileName), unorderedEquals(['짱 01', '짱 01 (2)']));
    });
  });

  group('BookImporter', () {
    test('고른 파일을 책, 이미지, 지원하지 않는 파일로 나눈다', () {
      final picked = BookImporter(storage, repository).classify([
        '/tmp/짱01-010.jpg',
        '/tmp/짱01-002.jpg',
        '/tmp/소설.txt',
        '/tmp/메모.pdf',
      ]);
      expect(picked.books, ['/tmp/소설.txt']);
      expect(picked.images, ['/tmp/짱01-002.jpg', '/tmp/짱01-010.jpg']);
      expect(picked.skipped, ['메모.pdf']);
      expect(picked.suggestedTitle, '짱01');
    });

    test('낱장 이미지를 만화 한 권으로 모은다', () async {
      await write('picked/2.jpg');
      await write('picked/10.jpg');
      final importer = BookImporter(storage, repository);
      await importer.importImages(
        [p.join(docs.path, 'picked', '2.jpg'), p.join(docs.path, 'picked', '10.jpg')],
        '짱: 1권',
      );

      final book = (await repository.watchAll().first).single;
      expect(book.title, '짱: 1권');
      // 폴더 이름에 쓸 수 없는 글자는 바꾼다.
      expect(book.fileName, '짱_ 1권');
      final comic = await ComicArchive.open(await storage.pathFor(book.fileName));
      expect(comic.pageCount, 2);
    });
  });
}
