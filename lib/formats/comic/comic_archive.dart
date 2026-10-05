import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/natural_compare.dart';

const _imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'};

/// zip/cbz 만화 파일. 압축을 통째로 풀지 않고 필요한 페이지만 읽는다.
class ComicArchive {
  ComicArchive._(this.path, this._pageNames);

  final String path;
  final List<String> _pageNames;

  int get pageCount => _pageNames.length;

  /// 이미지 항목만 골라 파일 이름 순(자연 정렬)으로 페이지를 만든다.
  static Future<ComicArchive> open(String path) async {
    final names = await Isolate.run(() => _listPages(path));
    return ComicArchive._(path, names);
  }

  /// 압축 해제가 화면을 멈추지 않도록 별도 isolate에서 읽는다.
  Future<Uint8List> readPage(int index) {
    final path = this.path;
    final name = _pageNames[index];
    return Isolate.run(() => _readEntry(path, name));
  }
}

List<String> _listPages(String path) {
  final input = InputFileStream(path);
  try {
    final archive = ZipDecoder().decodeStream(input);
    final names = [
      for (final file in archive.files)
        if (file.isFile && _isPage(file.name)) file.name,
    ];
    return names..sort(naturalCompare);
  } finally {
    input.closeSync();
  }
}

bool _isPage(String name) {
  // macOS가 zip에 끼워 넣는 메타데이터 파일은 이미지가 아니다.
  if (name.startsWith('__MACOSX/') || p.basename(name).startsWith('._')) {
    return false;
  }
  return _imageExtensions.contains(p.extension(name).toLowerCase());
}

Uint8List _readEntry(String path, String name) {
  final input = InputFileStream(path);
  try {
    final file = ZipDecoder().decodeStream(input).find(name);
    if (file == null) throw StateError('압축 파일에서 $name 을(를) 찾을 수 없습니다.');
    return file.content;
  } finally {
    input.closeSync();
  }
}
