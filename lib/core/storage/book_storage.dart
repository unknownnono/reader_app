import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 가져온 책 파일을 앱 내부 books 폴더에 보관한다.
class BookStorage {
  Future<Directory> _booksDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'books'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> fileFor(String fileName) async {
    return File(p.join((await _booksDir()).path, fileName));
  }

  /// 원본을 books 폴더로 복사하고 저장된 파일 이름을 돌려준다.
  /// 같은 이름이 이미 있으면 "이름 (2).txt"처럼 번호를 붙인다.
  Future<String> importFile(String sourcePath) async {
    final dir = await _booksDir();
    final base = p.basenameWithoutExtension(sourcePath);
    final ext = p.extension(sourcePath);
    var name = '$base$ext';
    for (var n = 2; await File(p.join(dir.path, name)).exists(); n++) {
      name = '$base ($n)$ext';
    }
    await File(sourcePath).copy(p.join(dir.path, name));
    return name;
  }

  Future<void> deleteFile(String fileName) async {
    final file = await fileFor(fileName);
    if (await file.exists()) await file.delete();
  }
}
