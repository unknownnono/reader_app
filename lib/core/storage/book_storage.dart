import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../formats/comic/comic_archive.dart';

final _invalidNameChars = RegExp(r'[\\/:*?"<>|]');

/// 가져온 책을 앱 내부 books 폴더에 보관한다.
/// 책 하나는 파일(txt, epub, zip) 또는 이미지 폴더다.
class BookStorage {
  BookStorage({Future<Directory> Function()? documentsDirectory})
      : _documentsDirectory = documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;

  /// 앱 문서 폴더. iOS에서는 파일 앱의 "나의 iPhone" 아래에 앱 이름으로 보인다.
  Future<Directory> documentsDir() => _documentsDirectory();

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

  /// 같은 저장소 안이면 이름만 바꿔 바로 옮기고, 안 되면 복사 후 원본을 지운다.
  Future<void> _moveFile(File source, String target) async {
    try {
      await source.rename(target);
    } on FileSystemException {
      await source.copy(target);
      await source.delete();
    }
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
  Future<String> importImageFolder(String sourcePath) async {
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
      await image.copy(target);
    }
    return name;
  }

  /// 낱장 이미지들을 [title] 이름의 폴더 하나로 모으고 저장된 폴더 이름을 돌려준다.
  /// 원본은 파일 선택 창이 만든 임시 복사본이므로 옮긴다.
  Future<String> importImages(List<String> imagePaths, String title) async {
    final dir = await _booksDir();
    final safeTitle = title.replaceAll(_invalidNameChars, '_').trim();
    final name = await _uniqueName(dir, safeTitle.isEmpty ? '만화' : safeTitle, '');
    final target = Directory(p.join(dir.path, name));
    await target.create();
    for (final path in imagePaths) {
      await _moveFile(File(path), p.join(target.path, p.basename(path)));
    }
    return name;
  }

  /// 앱 문서 폴더 안에 있던 파일이나 폴더를 books 폴더로 옮기고 저장된 이름을 돌려준다.
  /// 같은 저장소 안이라 복사 없이 바로 끝난다.
  Future<String> adopt(FileSystemEntity entity) async {
    final dir = await _booksDir();
    if (entity is Directory) {
      final name = await _uniqueName(dir, p.basename(entity.path), '');
      await entity.rename(p.join(dir.path, name));
      return name;
    }
    final name = await _uniqueName(
      dir,
      p.basenameWithoutExtension(entity.path),
      p.extension(entity.path),
    );
    await entity.rename(p.join(dir.path, name));
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
