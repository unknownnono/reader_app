import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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
}
