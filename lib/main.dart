import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'auth/login_screen.dart';
import 'firebase_options.dart';
import 'pages/dashboard_page.dart';

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MiniBot TRKJ',
      theme: ThemeData(
        brightness:   Brightness.dark,
        primaryColor: const Color(0xFF00D4FF),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
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