import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/diag/diag_log.dart';
import '../../core/platform/file_picker_bridge.dart';
import '../../providers.dart';

/// 가져오기가 안 될 때 어디서 멈추는지 보여 주는 화면.
class DiagScreen extends ConsumerWidget {
  const DiagScreen({super.key});

  Future<void> _logAppFolder(WidgetRef ref) async {
    try {
      final docs = await ref.read(bookStorageProvider).documentsDir();
      final entries = await docs.list(followLinks: false).toList();
      DiagLog.add('앱 폴더 항목 ${entries.length}개');
      for (final entry in entries) {
        final kind = entry is Directory ? '폴더' : '파일';
        DiagLog.add('  $kind: ${p.basename(entry.path)}');
      }
    } catch (error) {
      DiagLog.add('앱 폴더 읽기 실패: $error');
    }
  }

  Future<void> _testPluginPicker() async {
    try {
      final paths = await pickFilePathsWithPlugin();
      for (final path in paths.take(5)) {
        DiagLog.add('  ${p.basename(path)}');
      }
    } catch (error) {
      DiagLog.add('플러그인 선택 창 실패: $error');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('진단 기록'),
        actions: [
          IconButton(
            tooltip: '기록 지우기',
            onPressed: DiagLog.clear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _logAppFolder(ref),
                  child: const Text('앱 폴더 내용 기록'),
                ),
                OutlinedButton(
                  onPressed: _testPluginPicker,
                  child: const Text('플러그인 선택 창 시험'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: DiagLog.lines,
              builder: (context, lines, _) => lines.isEmpty
                  ? const Center(child: Text('기록이 없습니다.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: lines.length,
                      itemBuilder: (context, index) => SelectableText(
                        lines[index],
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
