import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wangku/core/notifications/notification_service.dart';
import 'package:wangku/core/theme/app_theme.dart';
import 'package:wangku/features/index.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sets up the timezone database and notification channel before any
  // screen can try to schedule a reminder.
  await NotificationService.instance.init();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wang Ku',
      theme: AppTheme.light,
      home: const ShellScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}