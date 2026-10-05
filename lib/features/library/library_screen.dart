import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../domain/book_format.dart';
import '../../providers.dart';
import '../reader/reader_screen.dart';
import 'import/book_importer.dart';

/// 앱 문서 폴더가 파일 앱에 보이는 플랫폼에서만 "앱 폴더에서 가져오기"를 쓴다.
/// 디버그 빌드에서는 에뮬레이터로 확인할 수 있게 Android에서도 켠다.
bool get _usesAppFolder => Platform.isIOS || kDebugMode;

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // 파일 앱에서 책을 넣고 돌아오면 바로 서재에 나타나게 한다.
    _lifecycle = AppLifecycleListener(onResume: () => _scanAppFolder(silent: true));
    _scanAppFolder(silent: true);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _scanAppFolder({required bool silent}) async {
    if (!_usesAppFolder) return;
    try {
      final count = await ref.read(inboxScannerProvider).scan();
      if (count > 0) {
        _showMessage('앱 폴더에서 $count권을 추가했습니다.');
      } else if (!silent) {
        _showMessage('앱 폴더에 새로 넣은 책이 없습니다. 파일 앱 → 나의 iPhone → Reader App 폴더에 넣어 주세요.');
      }
    } catch (error) {
      _showMessage('앱 폴더를 읽지 못했습니다: $error');
    }
  }

  Future<void> _importFiles() async {
    final importer = ref.read(bookImporterProvider);
    try {
      final picked = await importer.pickFiles();
      if (picked == null) return;
      await importer.importBooks(picked.books);
      var count = picked.books.length;
      if (picked.images.isNotEmpty) {
        final title = await _askComicTitle(picked);
        if (title != null) {
          await importer.importImages(picked.images, title);
          count++;
        }
      }
      final skipped = picked.skipped.isEmpty
          ? ''
          : ' (지원하지 않는 파일 ${picked.skipped.length}개 제외)';
      _showMessage('$count권을 추가했습니다.$skipped');
    } catch (error) {
      _showMessage('가져오기에 실패했습니다: $error');
    }
  }

  /// 낱장 이미지를 묶을 만화 제목을 묻는다. 취소하면 null.
  Future<String?> _askComicTitle(PickedFiles picked) async {
    if (!mounted) return null;
    final title = await showDialog<String>(
      context: context,
      builder: (context) => _ComicTitleDialog(
        imageCount: picked.images.length,
        initialTitle: picked.suggestedTitle,
      ),
    );
    final trimmed = title?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _importFolder() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    var busyShown = false;
    void showBusy() {
      busyShown = true;
      showDialog<void>(
        context: navigator.context,
        barrierDismissible: false,
        builder: (_) => const PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 24),
                Expanded(child: Text('폴더를 가져오는 중입니다…')),
              ],
            ),
          ),
        ),
      );
    }

    void hideBusy() {
      if (busyShown) navigator.pop();
      busyShown = false;
    }

    try {
      final imported = await ref
          .read(bookImporterProvider)
          .pickAndImportFolder(onBusy: showBusy);
      hideBusy();
      if (imported) _showMessage('폴더를 추가했습니다.');
    } on FormatException catch (error) {
      hideBusy();
      _showMessage(error.message);
    } catch (error) {
      hideBusy();
      _showMessage('가져오기에 실패했습니다: $error');
    }
  }

  void _showImportMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('파일 가져오기'),
              subtitle: const Text('txt, epub, zip, cbz, 또는 이미지 여러 장'),
              onTap: () {
                Navigator.pop(sheetContext);
                _importFiles();
              },
            ),
            if (Platform.isAndroid)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('이미지 폴더 가져오기'),
                subtitle: const Text('폴더 하나를 만화 한 권으로 추가'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _importFolder();
                },
              ),
            if (_usesAppFolder)
              ListTile(
                leading: const Icon(Icons.drive_folder_upload_outlined),
                title: const Text('앱 폴더에서 가져오기'),
                subtitle: const Text('파일 앱 → 나의 iPhone → Reader App에 넣은 폴더와 파일'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _scanAppFolder(silent: false);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(booksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('서재')),
      body: books.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('서재를 불러오지 못했습니다.\n$error')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('아래 + 버튼으로 책을 추가하세요.'))
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) => _BookTile(book: list[index]),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showImportMenu,
        tooltip: '가져오기',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// 닫히는 애니메이션이 끝날 때까지 입력 컨트롤러가 살아 있도록 대화상자가 직접 소유한다.
class _ComicTitleDialog extends StatefulWidget {
  const _ComicTitleDialog({required this.imageCount, required this.initialTitle});

  final int imageCount;
  final String initialTitle;

  @override
  State<_ComicTitleDialog> createState() => _ComicTitleDialogState();
}

class _ComicTitleDialogState extends State<_ComicTitleDialog> {
  late final _controller = TextEditingController(text: widget.initialTitle);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('이미지 ${widget.imageCount}장을 만화 한 권으로'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: '제목'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('추가'),
        ),
      ],
    );
  }
}

class _BookTile extends ConsumerWidget {
  const _BookTile({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(switch (book.format) {
        BookFormat.txt => Icons.description_outlined,
        BookFormat.epub => Icons.menu_book_outlined,
        BookFormat.comic => Icons.photo_library_outlined,
      }),
      title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(book.format.name.toUpperCase()),
      onTap: () {
        ref.read(bookRepositoryProvider).markOpened(book.id);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
        );
      },
      onLongPress: () => _confirmDelete(context, ref),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('책 삭제'),
        content: Text('"${book.title}"을(를) 서재에서 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(bookRepositoryProvider).delete(book.id);
    await ref.read(bookStorageProvider).delete(book.fileName);
  }
}
