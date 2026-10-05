import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PickedFolder {
  const PickedFolder(this.path, {required this.isTemporaryCopy});

  final String path;

  /// true면 앱 임시 폴더에 만들어 둔 복사본이라 옮기거나 지워도 된다(iOS).
  final bool isTemporaryCopy;
}

const _channel = MethodChannel('reader_app/folder_picker');

/// 폴더 선택 창을 띄운다. 취소하면 null.
/// [onPicked]는 사용자가 폴더를 고른 직후, 시간이 걸리는 작업이 시작될 때 불린다.
Future<PickedFolder?> pickFolder({void Function()? onPicked}) async {
  if (Platform.isIOS) {
    // file_picker는 iOS에서 고른 폴더의 읽기 권한을 얻지 않으므로 직접 구현한 채널을 쓴다.
    // 네이티브 쪽이 폴더를 임시 폴더로 복사하기 시작할 때 'copying'을 보낸다.
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'copying') onPicked?.call();
    });
    try {
      final path = await _channel.invokeMethod<String>('pick');
      return path == null ? null : PickedFolder(path, isTemporaryCopy: true);
    } finally {
      _channel.setMethodCallHandler(null);
    }
  }

  // Android는 공용 저장소의 이미지를 읽으려면 권한이 필요하다(13 이상은 사진, 그 아래는 저장소).
  final statuses = await [Permission.photos, Permission.storage].request();
  if (!statuses.values.any((status) => status.isGranted || status.isLimited)) {
    throw const FileSystemException('사진 접근 권한이 없어 폴더를 읽을 수 없습니다.');
  }
  final path = await FilePicker.getDirectoryPath();
  if (path == null) return null;
  onPicked?.call();
  return PickedFolder(path, isTemporaryCopy: false);
}
