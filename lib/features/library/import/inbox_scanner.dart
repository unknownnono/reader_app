import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/storage/book_storage.dart';
import '../../../core/utils/natural_compare.dart';
import '../../../data/book_repository.dart';
import '../../../domain/book_format.dart';
import '../../../formats/comic/comic_archive.dart';

/// 사용자가 파일 앱으로 앱 문서 폴더에 넣어 둔 책을 서재로 가져온다.
///
/// - 이미지가 바로 들어 있는 폴더는 만화 한 권이 된다.
/// - 이미지 없이 하위 폴더만 있는 폴더는 묶음으로 보고 하위 폴더를 각각 한 권으로 가져온다.
/// - txt, epub, zip, cbz 파일은 그대로 한 권이 된다.
/// 가져온 것은 books 폴더로 옮겨지므로 문서 폴더에서는 사라진다.
class InboxScanner {
  InboxScanner(this._storage, this._repository);

  static const _maxDepth = 3;

  /// 앱이 직접 쓰는 폴더. flutter_assets는 Android에서 Flutter 엔진이 문서 폴더에 둔다.
  static const _reserved = {'books', 'flutter_assets'};

  final BookStorage _storage;
  final BookRepository _repository;
  Future<int>? _running;

  /// 가져온 책 수를 돌려준다. 이미 스캔 중이면 그 결과를 함께 기다린다.
  Future<int> scan() {
    return _running ??= _scan().whenComplete(() => _running = null);
  }

  Future<int> _scan() async {
    final docs = await _storage.documentsDir();
    var count = 0;
    for (final entity in await _sortedChildren(docs)) {
      final name = p.basename(entity.path);
      if (_reserved.contains(name) || name.startsWith('.')) continue;
      count += await _adopt(entity, depth: 0);
    }
    return count;
  }

  Future<List<FileSystemEntity>> _sortedChildren(Directory dir) async {
    final children = await dir.list(followLinks: false).toList();
    return children..sort((a, b) => naturalCompare(a.path, b.path));
  }

  Future<int> _adopt(FileSystemEntity entity, {required int depth, String? parent}) async {
    final name = p.basename(entity.path);
    if (entity is File) {
      final format = BookFormat.fromPath(entity.path);
      if (format == null) return 0;
      final title = p.basenameWithoutExtension(entity.path);
      await _repository.add(
        title: title,
        fileName: await _storage.adopt(entity),
        format: format,
      );
      return 1;
    }
    if (entity is! Directory) return 0;

    final children = await _sortedChildren(entity);
    final hasImages = children.any((c) => c is File && isComicPage(p.basename(c.path)));
    if (hasImages) {
      // "짱/01"처럼 권 번호만 있는 폴더는 묶음 이름을 앞에 붙여 구분한다.
      final title = parent == null || name.contains(parent) ? name : '$parent $name';
      await _repository.add(
        title: title,
        fileName: await _storage.adopt(entity),
        format: BookFormat.comic,
      );
      return 1;
    }
    if (depth >= _maxDepth) return 0;

    var count = 0;
    for (final child in children) {
      count += await _adopt(child, depth: depth + 1, parent: name);
    }
    if (count > 0 && await entity.list().isEmpty) await entity.delete();
    return count;
  }
}
