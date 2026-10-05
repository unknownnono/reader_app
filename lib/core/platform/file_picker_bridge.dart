import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../diag/diag_log.dart';

const _channel = MethodChannel('reader_app/file_picker');

/// 파일 선택 창을 띄우고 고른 파일들의 경로를 돌려준다. 취소하면 빈 목록.
///
/// iOS에서는 직접 구현한 선택 창을 쓴다. file_picker 플러그인은 선택 창이 닫히는 신호를
/// 취소로 처리해서, 여러 파일을 골랐을 때 결과가 오기 전에 요청이 끝나 버릴 수 있다.
Future<List<String>> pickFilePaths() async {
  if (!Platform.isIOS) return pickFilePathsWithPlugin();

  DiagLog.add('파일 선택(직접 구현) 호출');
  final response = await _channel.invokeMapMethod<String, dynamic>('pick');
  final paths = List<String>.from(response?['paths'] as List? ?? const []);
  final log = List<String>.from(response?['log'] as List? ?? const []);
  DiagLog.add('파일 선택 반환: ${paths.length}개, 단계: ${log.join(' → ')}');
  return paths;
}

Future<List<String>> pickFilePathsWithPlugin() async {
  DiagLog.add('파일 선택(플러그인) 호출');
  final files = await FilePicker.pickFiles();
  DiagLog.add('파일 선택(플러그인) 반환: ${files.length}개');
  return [
    for (final file in files)
      if (file.path != null) file.path!,
  ];
}
