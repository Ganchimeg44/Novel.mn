import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/novel_list_screen.dart';

void main() {
  runApp(const NovelApp());
}

class NovelApp extends StatelessWidget {
  const NovelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Novel Reader',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const NovelListScreen(),
    );
  }
}