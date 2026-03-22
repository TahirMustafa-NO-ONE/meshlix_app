import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'db/db_service.dart';
import 'screens/splash/splash_screen.dart';
import 'services/auth/auth_service.dart';
import 'services/session/session_manager.dart';
import 'services/storage/user_storage.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await DbService.initializeHive();

  // Restore persisted state before the splash screen decides navigation.
  await SessionManager.instance.initialize();
  await UserStorage.instance.initialize();
  await AuthService.instance.initialize();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MeshlixApp());
}

class MeshlixApp extends StatelessWidget {
  const MeshlixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meshlix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}
