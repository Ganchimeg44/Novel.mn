import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/novel_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error, stackTrace) {
    // Хөгжүүлэлтийн үед Firebase холбогдоогүй/буруу тохиргоотой үед
    // апп шууд краш хийхийн оронд алдааг консол дээр харуулна.
    debugPrint('Firebase initialization алдаа: $error');
    debugPrint('$stackTrace');
  }

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