import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/novel_list_screen.dart';
import 'screens/auth/login_screen.dart';
import 'services/auth_service.dart';

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
      home: const _AuthGate(),
    );
  }
}

/// App нээгдэхэд Firebase-т нэвтэрсэн эсэхийг шалгаад,
/// нэвтрээгүй бол `LoginScreen`, нэвтэрсэн бол `NovelListScreen`
/// харуулдаг гарц (gate) widget.
///
/// `AuthService.authStateChanges()`-г сонсдог тул хэрэглэгч login/register
/// амжилттай хийх үед Firebase auth төлөв өөрчлөгдөнгүүт энэ widget
/// автоматаар дахин зурагдаж `NovelListScreen` рүү сэлгэнэ — screen-үүд
/// дотор шинээр Navigator.push/pop бичих шаардлагагүй.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges(),
      initialData: authService.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }
        return const NovelListScreen();
      },
    );
  }
}