import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../formats/comic/comic_archive.dart';

/// 가져온 책을 앱 내부 books 폴더에 보관한다.
/// 책 하나는 파일(txt, epub, zip) 또는 이미지 폴더다.
class BookStorage {
  BookStorage({Future<Directory> Function()? documentsDirectory})
      : _documentsDirectory = documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;

  Future<Directory> _booksDir() async {
    final docs = await _documentsDirectory();
    final dir = Directory(p.join(docs.path, 'books'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> pathFor(String name) async {
    return p.join((await _booksDir()).path, name);
  }

  Future<File> fileFor(String name) async => File(await pathFor(name));

  /// 같은 이름이 이미 있으면 "이름 (2).txt"처럼 번호를 붙인다.
  Future<String> _uniqueName(Directory dir, String base, String extension) async {
    var name = '$base$extension';
    for (var n = 2;
        await FileSystemEntity.type(p.join(dir.path, name)) !=
            FileSystemEntityType.notFound;
        n++) {
      name = '$base ($n)$extension';
    }
    return name;
  }

  /// 원본 파일을 books 폴더로 복사하고 저장된 이름을 돌려준다.
  Future<String> importFile(String sourcePath) async {
    final dir = await _booksDir();
    final name = await _uniqueName(
      dir,
      p.basenameWithoutExtension(sourcePath),
      p.extension(sourcePath),
    );
    await File(sourcePath).copy(p.join(dir.path, name));
    return name;
  }

  /// 폴더 안의 이미지(하위 폴더 포함)만 books 폴더로 복사하고 저장된 폴더 이름을 돌려준다.
  /// 이미지가 하나도 없으면 [FormatException].
  /// [move]가 true면 복사하지 않고 옮긴다(원본이 앱 임시 폴더의 복사본일 때).
  Future<String> importImageFolder(String sourcePath, {bool move = false}) async {
    final source = Directory(sourcePath);
    final images = [
      await for (final entity in source.list(recursive: true, followLinks: false))
        if (entity is File &&
            isComicPage(
              p.relative(entity.path, from: sourcePath).replaceAll(r'\', '/'),
            ))
          entity,
    ];
    if (images.isEmpty) {
      throw const FormatException('폴더 안에 이미지가 없습니다.');
    }
    final dir = await _booksDir();
    final name = await _uniqueName(dir, p.basename(sourcePath), '');
    for (final image in images) {
      final target = p.join(dir.path, name, p.relative(image.path, from: sourcePath));
      await Directory(p.dirname(target)).create(recursive: true);
      if (move) {
        await image.rename(target);
      } else {
        await image.copy(target);
      }
    }
    return name;
  }

  Future<void> delete(String name) async {
    final path = await pathFor(name);
    switch (await FileSystemEntity.type(path)) {
      case FileSystemEntityType.directory:
        await Directory(path).delete(recursive: true);
      case FileSystemEntityType.notFound:
        break;
      default:
        await File(path).delete();
    }
  }
}
