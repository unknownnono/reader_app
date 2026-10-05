import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android에서 폴더 선택 창을 띄우고 고른 폴더의 경로를 돌려준다. 취소하면 null.
///
/// iOS에서는 쓰지 않는다. 폴더 선택 창의 "열기"가 동작하지 않아서
/// 대신 앱 폴더에 넣은 책을 읽어 들인다(InboxScanner).
Future<String?> pickFolder() async {
  // 공용 저장소의 이미지를 읽으려면 권한이 필요하다(13 이상은 사진, 그 아래는 저장소).
  final statuses = await [Permission.photos, Permission.storage].request();
  if (!statuses.values.any((status) => status.isGranted || status.isLimited)) {
    throw const FileSystemException('사진 접근 권한이 없어 폴더를 읽을 수 없습니다.');
  }
  return FilePicker.getDirectoryPath();
}
