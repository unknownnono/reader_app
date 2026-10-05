import 'package:path/path.dart' as p;

enum BookFormat {
  txt,
  epub,
  comic;

  /// 파일 확장자로 포맷을 판별한다. 지원하지 않는 확장자면 null.
  static BookFormat? fromPath(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.txt':
        return BookFormat.txt;
      case '.epub':
        return BookFormat.epub;
      case '.zip':
      case '.cbz':
        return BookFormat.comic;
      default:
        return null;
    }
  }
}
