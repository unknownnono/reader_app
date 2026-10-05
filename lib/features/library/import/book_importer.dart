import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../../core/platform/folder_picker.dart';
import '../../../core/storage/book_storage.dart';
import '../../../data/book_repository.dart';
import '../../../domain/book_format.dart';

class ImportResult {
  const ImportResult({required this.imported, required this.skipped});

  final int imported;

  /// 지원하지 않는 확장자라 건너뛴 파일 이름
  final List<String> skipped;
}

class BookImporter {
  BookImporter(this._storage, this._repository);

  final BookStorage _storage;
  final BookRepository _repository;

  /// 파일 선택 창을 띄워 고른 파일들을 서재에 추가한다. 취소하면 null.
  Future<ImportResult?> pickAndImport() async {
    // iOS는 커스텀 확장자 필터가 불안정해서 전부 보여주고 확장자로 직접 거른다.
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return null;
    return importPaths([
      for (final file in files)
        if (file.path != null) file.path!,
    ]);
  }

  /// 폴더 선택 창을 띄워 고른 이미지 폴더를 만화 한 권으로 추가한다. 취소하면 false.
  Future<bool> pickAndImportFolder() async {
    final folder = await pickFolder();
    if (folder == null) return false;
    try {
      final name = await _storage.importImageFolder(folder.path);
      await _repository.add(title: name, fileName: name, format: BookFormat.comic);
      return true;
    } finally {
      if (folder.isTemporaryCopy) {
        await Directory(folder.path).delete(recursive: true);
      }
    }
  }

  Future<ImportResult> importPaths(List<String> paths) async {
    var imported = 0;
    final skipped = <String>[];
    for (final path in paths) {
      final format = BookFormat.fromPath(path);
      if (format == null) {
        skipped.add(p.basename(path));
        continue;
      }
      final fileName = await _storage.importFile(path);
      await _repository.add(
        title: p.basenameWithoutExtension(path),
        fileName: fileName,
        format: format,
      );
      imported++;
    }
    return ImportResult(imported: imported, skipped: skipped);
  }
}
