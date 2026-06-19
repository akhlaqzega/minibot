import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'auth/login_screen.dart';
import 'firebase_options.dart';
import 'pages/dashboard_page.dart';
import 'theme/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        final primaryColor = ThemeService.instance.primaryColor;
        final themeMode = ThemeService.instance.themeMode;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'MiniBot TRKJ',
          themeMode: themeMode,
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: primaryColor,
            colorScheme: ColorScheme.fromSeed(
              seedColor: primaryColor,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF4F5F9),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: primaryColor,
            colorScheme: ColorScheme.fromSeed(
              seedColor: primaryColor,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF0D0E15),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF12131E),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
          home: const AuthWrapper(),
        );
      },
    );
  }
}

/// AuthWrapper: Cek status login Firebase secara real-time.
/// - Jika sudah login  → langsung ke DashboardPage
/// - Jika belum login  → ke LoginScreen
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Masih loading state Firebase
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D0E15),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
            ),
          );
        }
        // Sudah login
        if (snapshot.hasData && snapshot.data != null) {
          return const DashboardPage();
        }
        // Belum login
        return const LoginScreen();
      },
    );
  }
}