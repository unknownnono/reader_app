import 'package:flutter/material.dart';

import '../features/library/library_screen.dart';

/// 홈 화면과 파일 앱에 보이는 앱 이름.
/// iOS의 Info.plist(CFBundleDisplayName), Android의 AndroidManifest(android:label)와 맞춘다.
const appName = 'ebook·comics viewer';

class ReaderApp extends StatelessWidget {
  const ReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.brown, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: Colors.brown, brightness: Brightness.dark),
      home: const LibraryScreen(),
    );
  }
}
