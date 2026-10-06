import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:reader_app/core/storage/book_storage.dart';
import 'package:reader_app/core/storage/storage_locations.dart';
import 'package:reader_app/data/book_repository.dart';
import 'package:reader_app/data/db/app_database.dart';
import 'package:reader_app/domain/book_format.dart';

void main() {
  late Directory root;
  late Directory docs;
  late Directory support;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('storage_test');
    addTearDown(() => root.delete(recursive: true));
    docs = await Directory(p.join(root.path, 'Documents')).create();
    // 실제 기기에서도 이 폴더는 처음에 없을 수 있다.
    support = Directory(p.join(root.path, 'Library', 'Application Support'));
  });

  Future<StorageLocations> resolve() {
    return resolveStorage(documents: () async => docs, support: () async => support);
  }

  Future<List<String>> names(Directory dir) async {
    return (await dir.list().map((e) => p.basename(e.path)).toList())..sort();
  }

  test('처음 설치했으면 자료를 보이지 않는 폴더에 둔다', () async {
    final storage = await resolve();
    expect(storage.inbox.path, docs.path);
    expect(storage.data.path, support.path);
    expect(await support.exists(), isTrue);
  });

  test('예전 버전의 저장소와 책을 옮기고, 옮긴 뒤에도 책이 그대로 열린다', () async {
    // 예전 버전처럼 문서 폴더에 저장소와 책을 만든다.
    final oldStorage = BookStorage(documentsDirectory: () async => docs);
    final source = File(p.join(root.path, '소설.txt'));
    await source.writeAsString('본문');
    final fileName = await oldStorage.importFile(source.path);
    var db = AppDatabase(NativeDatabase(File(p.join(docs.path, databaseFileName))));
    await BookRepository(db).add(title: '소설', fileName: fileName, format: BookFormat.txt);
    await db.close();
    // 정리되지 않고 남은 보조 파일과, 사용자가 넣어 둔 아직 가져오지 않은 파일
    await File(p.join(docs.path, '$databaseFileName-wal')).writeAsBytes([1, 2, 3]);
    await File(p.join(docs.path, '새 책.txt')).writeAsString('아직 안 가져옴');

    final storage = await resolve();
    expect(storage.data.path, support.path);
    expect(await names(docs), ['새 책.txt']);
    expect(await names(support), ['books', databaseFileName, '$databaseFileName-wal']);

    await File(p.join(support.path, '$databaseFileName-wal')).delete();
    db = AppDatabase(NativeDatabase(File(p.join(support.path, databaseFileName))));
    addTearDown(db.close);
    final book = (await BookRepository(db).watchAll().first).single;
    final newStorage = BookStorage(
      documentsDirectory: () async => storage.inbox,
      dataDirectory: () async => storage.data,
    );
    expect(await (await newStorage.fileFor(book.fileName)).readAsString(), '본문');

    // 다시 실행해도 그대로다.
    final again = await resolve();
    expect(again.data.path, support.path);
    expect(await names(support), ['books', databaseFileName]);
  });

  test('저장소만 옮겨지고 책 폴더가 예전 자리에 남았으면 마저 옮긴다', () async {
    await support.create(recursive: true);
    await File(p.join(support.path, databaseFileName)).writeAsBytes([1]);
    await File(p.join(docs.path, 'books', '남은 책.txt')).create(recursive: true);

    final storage = await resolve();
    expect(storage.data.path, support.path);
    expect(await names(docs), isEmpty);
    expect(await names(Directory(p.join(support.path, 'books'))), ['남은 책.txt']);
  });

  test('옮길 자리에 이미 책이 있으면 덮어쓰지 않고 예전 자리를 그대로 쓴다', () async {
    await File(p.join(docs.path, databaseFileName)).writeAsBytes([1]);
    await File(p.join(docs.path, 'books', '예전.txt')).create(recursive: true);
    await File(p.join(support.path, 'books', '다른 책.txt')).create(recursive: true);

    final storage = await resolve();
    expect(storage.data.path, docs.path);
    expect(await names(docs), ['books', databaseFileName]);
    expect(await names(Directory(p.join(docs.path, 'books'))), ['예전.txt']);
    expect(await names(Directory(p.join(support.path, 'books'))), ['다른 책.txt']);
  });
}
