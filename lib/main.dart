import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/auth/auth_service.dart';
import 'theme/app_theme.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  await dotenv.load(fileName: ".env");

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MeshlixApp());

  // Initialize Web3Auth SDK AFTER widget tree is established.
  // This prevents crashes from native channel calls during SDK init.
  // Non-fatal on first launch — the user just needs to log in.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await AuthService.instance.initialize();
  });
}

class MeshlixApp extends StatelessWidget {
  const MeshlixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meshlix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: AuthService.instance.isAuthenticated
          ? const HomeScreen()
          : const AuthScreen(),
    );
  }
}
