import 'package:flutter/material.dart';
import 'screens/main_shell_screen.dart';
import 'services/api_config.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CompanyRegistrationApp());
  
  // Asynchronously test connection to Spring Boot backend after app renders
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ApiConfig().checkConnection();
  });
}

class CompanyRegistrationApp extends StatelessWidget {
  const CompanyRegistrationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CorpRegistry PRO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainShellScreen(),
    );
  }
}