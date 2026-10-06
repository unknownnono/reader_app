import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../providers.dart';
import 'transfer_server.dart';

/// Wi-Fi로 PC에서 파일을 받는 화면. 열려 있는 동안에만 받는다.
class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  TransferServer? _server;
  List<String> _addresses = const [];
  Object? _error;
  final _received = <String>[];
  String? _result;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _server?.stop();
    _keepAwake(false);
    super.dispose();
  }

  /// 받는 도중에 화면이 꺼지면 연결이 끊기므로 켜 둔다.
  Future<void> _keepAwake(bool on) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } catch (_) {
      // 화면 꺼짐 방지가 안 되는 기기에서도 전송은 할 수 있다.
    }
  }

  Future<void> _start() async {
    try {
      final inbox = await ref.read(bookStorageProvider).documentsDir();
      final scanner = ref.read(inboxScannerProvider);
      final server = TransferServer(
        inbox: inbox,
        onFileReceived: (path) {
          if (mounted) setState(() => _received.insert(0, path));
        },
        onBatchDone: () async {
          final count = await scanner.scan();
          if (mounted) setState(() => _result = '서재에 $count권을 추가했습니다.');
          return count;
        },
      );
      await server.start();
      final addresses = await transferAddresses(server.port!);
      if (!mounted) {
        await server.stop();
        return;
      }
      setState(() {
        _server = server;
        _addresses = addresses;
      });
      _keepAwake(true);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Wi-Fi로 받기')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_error != null)
            Text('받기를 시작하지 못했습니다.\n$_error')
          else if (_server == null)
            const Center(child: CircularProgressIndicator())
          else if (_addresses.isEmpty)
            const Text('Wi-Fi에 연결되어 있지 않습니다. 폰과 PC를 같은 Wi-Fi에 연결한 뒤 다시 열어 주세요.')
          else ...[
            const Text('같은 Wi-Fi에 연결된 PC의 브라우저에서 아래 주소를 여세요.'),
            const SizedBox(height: 12),
            for (final address in _addresses)
              SelectableText(address, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              '이 화면을 닫으면 받기가 끝납니다. 받는 동안에는 화면이 꺼지지 않습니다.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 20),
            Text(_result!, style: theme.textTheme.titleMedium),
          ],
          if (_received.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('받은 파일 ${_received.length}개', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final path in _received.take(100))
              Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}
