import 'package:path/path.dart' as p;

import '../../../core/diag/diag_log.dart';
import '../../../core/platform/file_picker_bridge.dart';
import '../../../core/platform/folder_picker.dart';
import '../../../core/storage/book_storage.dart';
import '../../../core/utils/natural_compare.dart';
import '../../../data/book_repository.dart';
import '../../../domain/book_format.dart';
import '../../../formats/comic/comic_archive.dart';

/// 파일 선택 창에서 고른 파일을 종류별로 나눈 것.
class PickedFiles {
  const PickedFiles({
    required this.books,
    required this.images,
    required this.skipped,
  });

  /// txt, epub, zip, cbz
  final List<String> books;

  /// 낱장 이미지. 모아서 만화 한 권으로 만든다.
  final List<String> images;

  /// 지원하지 않는 확장자라 건너뛴 파일 이름
  final List<String> skipped;

  /// 이미지 파일 이름에서 끝의 쪽 번호를 떼어 만든 제목 후보. "짱01-003.jpg" → "짱01"
  String get suggestedTitle {
    if (images.isEmpty) return '';
    final first = p.basenameWithoutExtension(images.first);
    final trimmed = first.replaceFirst(RegExp(r'[\s_\-.]*\d+$'), '');
    return trimmed.isEmpty ? first : trimmed;
  }
}

class BookImporter {
  BookImporter(this._storage, this._repository);

  final BookStorage _storage;
  final BookRepository _repository;

  /// 파일 선택 창을 띄우고 고른 파일을 종류별로 나눈다. 취소하면 null.
  Future<PickedFiles?> pickFiles() async {
    // iOS는 커스텀 확장자 필터가 불안정해서 전부 보여주고 확장자로 직접 거른다.
    final paths = await pickFilePaths();
    if (paths.isEmpty) return null;
    final picked = classify(paths);
    DiagLog.add(
      '분류: 책 ${picked.books.length}, 이미지 ${picked.images.length}, '
      '제외 ${picked.skipped.length} (첫 파일: ${p.basename(paths.first)})',
    );
    return picked;
  }

  PickedFiles classify(List<String> paths) {
    final books = <String>[];
    final images = <String>[];
    final skipped = <String>[];
    for (final path in paths) {
      if (BookFormat.fromPath(path) != null) {
        books.add(path);
      } else if (isComicPage(p.basename(path))) {
        images.add(path);
      } else {
        skipped.add(p.basename(path));
      }
    }
    images.sort(naturalCompare);
    return PickedFiles(books: books, images: images, skipped: skipped);
  }

  Future<void> importBooks(List<String> paths) async {
    for (final path in paths) {
      await _repository.add(
        title: p.basenameWithoutExtension(path),
        fileName: await _storage.importFile(path),
        format: BookFormat.fromPath(path)!,
      );
    }
  }

  /// 낱장 이미지들을 [title] 제목의 만화 한 권으로 추가한다.
  Future<void> importImages(List<String> imagePaths, String title) async {
    final name = await _storage.importImages(imagePaths, title);
    await _repository.add(title: title, fileName: name, format: BookFormat.comic);
  }

  /// Android: 폴더 선택 창을 띄워 고른 이미지 폴더를 만화 한 권으로 추가한다. 취소하면 false.
  /// [onBusy]는 폴더를 고른 뒤 복사가 시작될 때 불린다.
  Future<bool> pickAndImportFolder({void Function()? onBusy}) async {
    final path = await pickFolder();
    if (path == null) return false;
    onBusy?.call();
    final name = await _storage.importImageFolder(path);
    await _repository.add(title: name, fileName: name, format: BookFormat.comic);
    return true;
  }
}
