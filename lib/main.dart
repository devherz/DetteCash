import 'package:flutter/material.dart';
import 'database/db_helper.dart';
import 'models/commerce.dart';
import 'models/user.dart';
import 'screens/commerce_setup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';

void main() {
  // Ensure Flutter bindings are initialized before accessing database
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DetteCash',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F51B5),
          brightness: Brightness.dark,
          primary: const Color(0xFF7986CB),
          secondary: const Color(0xFF4DB6AC),
          surface: const Color(0xFF1E1E2C),
          error: const Color(0xFFE57373),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF272738),
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F51B5), // Indigo premium
          primary: const Color(0xFF3F51B5),
          secondary: const Color(0xFF009688), // Teal for green positive actions
          surface: Colors.white,
          error: const Color(0xFFD32F2F),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF3F51B5), width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      home: const DetteCashLauncher(),
    );
  }
}

class DetteCashLauncher extends StatefulWidget {
  const DetteCashLauncher({super.key});

  @override
  State<DetteCashLauncher> createState() => _DetteCashLauncherState();
}

class _DetteCashLauncherState extends State<DetteCashLauncher> {
  bool _isLoading = true;
  Commerce? _commerce;
  UserModel? _loggedUser;

  @override
  void initState() {
    super.initState();
    _checkCommerceProfile();
  }

  Future<void> _checkCommerceProfile() async {
    try {
      final commerces = await DatabaseHelper.instance.getAllCommerces();
      if (commerces.isNotEmpty) {
        setState(() {
          _commerce = commerces.first;
          _isLoading = false;
        });
      } else {
        setState(() {
          _commerce = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _commerce = null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Chargement de DetteCash...',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_commerce == null) {
      return CommerceSetupScreen(
        onSetupSuccess: (newCommerce) {
          setState(() {
            _commerce = newCommerce;
          });
        },
      );
    }

    if (_loggedUser == null) {
      return LoginScreen(
        onLoginSuccess: (user) {
          setState(() {
            _loggedUser = user;
          });
        },
      );
    }

    return DashboardScreen(
      commerce: _commerce!,
      loggedUser: _loggedUser!,
      onLogout: () {
        setState(() {
          _loggedUser = null;
        });
      },
      onUserUpdated: (updatedUser) {
        setState(() {
          _loggedUser = updatedUser;
        });
      },
    );
  }
}
