import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/storage/storage_locations.dart';
import '../providers.dart';
import 'app.dart';

/// 앱을 띄우기 전에 준비해야 하는 것들
class AppBootstrap {
  const AppBootstrap({required this.preferences, required this.storage});

  final SharedPreferences preferences;
  final StorageLocations storage;

  static Future<AppBootstrap> load() async {
    return AppBootstrap(
      preferences: await SharedPreferences.getInstance(),
      // 예전 버전의 자료가 있으면 여기서 보이지 않는 폴더로 옮긴다.
      storage: await resolveStorage(),
    );
  }

  /// 준비한 것을 넣어 앱을 만든다.
  Widget buildApp() {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        storageLocationsProvider.overrideWithValue(storage),
      ],
      child: const ReaderApp(),
    );
  }
}
