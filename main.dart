import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';
import 'role_selection_page.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'teacher_home_page.dart';
import 'student_dashboard.dart';
import 'student_signup_page.dart';
import 'teacher_signup_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    print("Firebase initialized with LOCAL persistence");
  } catch (e) {
    debugPrint("Error initializing Firebase: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Teacher Connect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey.shade50,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
      ),
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/login') {
          final role = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => LoginPage(role: role),
          );
        }
        return null;
      },
      routes: {
        '/role-selection': (context) => const RoleSelectionPage(),
        '/home': (context) => const HomePage(role: 'student'),
        '/teacher-home': (context) => const TeacherHomePage(),
        '/student-dashboard': (context) => const StudentDashboard(),
        '/student-signup': (context) => const StudentSignupPage(),
        '/teacher-signup': (context) => const TeacherSignupPage(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final dbRef = FirebaseDatabase.instance.ref();
        final snapshot = await dbRef.child("users/${user.uid}/role").get();
        if (mounted) {
          if (snapshot.exists && snapshot.value.toString().toLowerCase() == 'teacher') {
            Navigator.pushReplacementNamed(context, '/teacher-home');
          } else {
            Navigator.pushReplacementNamed(context, '/student-dashboard');
          }
        }
      } catch (e) {
        debugPrint("Error fetching user role: $e");
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/student-dashboard');
        }
      }
    } else {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/role-selection');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade700, Colors.blue.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade200.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.school,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            const Text(
              'Student Teacher Connect',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Connecting Students with Great Teachers',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}