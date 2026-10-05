import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:reader_app/core/storage/book_storage.dart';
import 'package:reader_app/core/utils/natural_compare.dart';
import 'package:reader_app/formats/comic/comic_archive.dart';

void main() {
  test('숫자를 수로 비교해 정렬한다', () {
    final names = ['10.jpg', '2.jpg', '1.jpg', 'ch2/1.jpg', 'ch10/1.jpg', 'Ch1/3.jpg'];
    expect(names..sort(naturalCompare), [
      '1.jpg',
      '2.jpg',
      '10.jpg',
      'Ch1/3.jpg',
      'ch2/1.jpg',
      'ch10/1.jpg',
    ]);
  });

  test('이미지만 골라 정렬된 순서로 페이지를 읽는다', () async {
    final archive = Archive()
      ..addFile(ArchiveFile.bytes('p10.jpg', [10]))
      ..addFile(ArchiveFile.bytes('p2.PNG', [2]))
      ..addFile(ArchiveFile.bytes('p1.jpg', [1]))
      ..addFile(ArchiveFile.bytes('readme.txt', [99]))
      ..addFile(ArchiveFile.bytes('__MACOSX/._p1.jpg', [98]));
    final dir = await Directory.systemTemp.createTemp('comic_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'sample.cbz'));
    await file.writeAsBytes(ZipEncoder().encodeBytes(archive));

    final comic = await ComicArchive.open(file.path);
    expect(comic.pageCount, 3);
    expect(await comic.readPage(0), [1]);
    expect(await comic.readPage(1), [2]);
    expect(await comic.readPage(2), [10]);
  });

  test('이미지 폴더를 가져와 만화로 읽고, 삭제하면 폴더째 지운다', () async {
    final root = await Directory.systemTemp.createTemp('folder_test');
    addTearDown(() => root.delete(recursive: true));
    final source = Directory(p.join(root.path, 'picked', '내 만화'));
    for (final entry in {'10.jpg': 10, '2.jpg': 2, 'ch2/1.png': 21, 'memo.txt': 99}.entries) {
      final file = File(p.join(source.path, entry.key));
      await file.create(recursive: true);
      await file.writeAsBytes([entry.value]);
    }
    final storage = BookStorage(
      documentsDirectory: () async => Directory(p.join(root.path, 'docs')),
    );

    final name = await storage.importImageFolder(source.path);
    expect(name, '내 만화');
    final comic = await ComicArchive.open(await storage.pathFor(name));
    expect(comic.pageCount, 3);
    expect(await comic.readPage(0), [2]);
    expect(await comic.readPage(1), [10]);
    expect(await comic.readPage(2), [21]);

    // 같은 폴더를 다시 가져오면 이름이 겹치지 않게 번호가 붙는다.
    expect(await storage.importImageFolder(source.path), '내 만화 (2)');

    await storage.delete(name);
    expect(await Directory(await storage.pathFor(name)).exists(), isFalse);
  });

  test('이미지가 없는 폴더는 가져오지 않는다', () async {
    final root = await Directory.systemTemp.createTemp('folder_test');
    addTearDown(() => root.delete(recursive: true));
    await File(p.join(root.path, 'empty', 'memo.txt')).create(recursive: true);
    final storage = BookStorage(
      documentsDirectory: () async => Directory(p.join(root.path, 'docs')),
    );
    expect(
      () => storage.importImageFolder(p.join(root.path, 'empty')),
      throwsFormatException,
    );
  });
}
