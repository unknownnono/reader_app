import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/natural_compare.dart';
import '../zip_entry.dart';

const _imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'};

/// 만화 페이지로 쓸 이미지인지. [name]은 압축 파일이나 폴더 안의 상대 경로.
bool isComicPage(String name) {
  // macOS가 끼워 넣는 메타데이터 파일은 이미지가 아니다.
  if (name.startsWith('__MACOSX/') || p.basename(name).startsWith('._')) {
    return false;
  }
  return _imageExtensions.contains(p.extension(name).toLowerCase());
}

/// 만화 한 권. zip/cbz 파일이거나 이미지가 든 폴더다.
/// 압축 파일은 통째로 풀지 않고 필요한 페이지만 읽는다.
class ComicArchive {
  ComicArchive._(this.path, this._pageNames, this._isFolder);

  final String path;
  final List<String> _pageNames;
  final bool _isFolder;

  int get pageCount => _pageNames.length;

  /// 이미지만 골라 이름 순(자연 정렬)으로 페이지를 만든다.
  static Future<ComicArchive> open(String path) async {
    final isFolder = await FileSystemEntity.isDirectory(path);
    final names = isFolder
        ? await _listFolder(path)
        : await Isolate.run(() => _listZip(path));
    return ComicArchive._(path, names..sort(naturalCompare), isFolder);
  }

  Future<Uint8List> readPage(int index) {
    final path = this.path;
    final name = _pageNames[index];
    if (_isFolder) return File(p.join(path, name)).readAsBytes();
    return readZipEntry(path, name);
  }
}

Future<List<String>> _listFolder(String path) async {
  return [
    await for (final entity in Directory(path).list(recursive: true))
      if (entity is File)
        // 정렬과 필터가 플랫폼과 무관하도록 구분자를 /로 통일한다.
        p.relative(entity.path, from: path).replaceAll(r'\', '/'),
  ].where(isComicPage).toList();
}

List<String> _listZip(String path) {
  final input = InputFileStream(path);
  try {
    final archive = ZipDecoder().decodeStream(input);
    return [
      for (final file in archive.files)
        if (file.isFile && isComicPage(file.name)) file.name,
    ];
  } finally {
    input.closeSync();
  }
}
