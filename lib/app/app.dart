import 'package:flutter/material.dart';

import '../features/library/library_screen.dart';

class ReaderApp extends StatelessWidget {
  const ReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.brown, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: Colors.brown, brightness: Brightness.dark),
      home: const LibraryScreen(),
    );
  }
}
