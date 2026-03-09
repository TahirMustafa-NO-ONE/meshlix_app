import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/auth/auth_service.dart';
import 'services/storage/user_storage.dart';
import 'services/session/session_manager.dart';
import 'theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';

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

  // Initialize services AFTER widget tree is established.
  // This prevents crashes from native channel calls during SDK init.
  // Non-fatal on first launch — the user just needs to log in.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // Initialize in order: SessionManager -> UserStorage -> AuthService
    // SessionManager must be first as AuthService depends on it for session persistence
    await SessionManager.instance.initialize();
    await UserStorage.instance.initialize();
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
      // Start with SplashScreen - it will check session and route appropriately
      home: const SplashScreen(),
    );
  }
}
