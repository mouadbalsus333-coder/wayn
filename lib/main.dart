import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await waynThemeController.load();

  runApp(const WaynApp());
}

class WaynApp extends StatelessWidget {
  const WaynApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WAYN',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        if (child == null) {
          return const SizedBox.shrink();
        }

        return ValueListenableBuilder<ThemeMode>(
          valueListenable: waynThemeController,
          builder: (context, themeMode, _) {
            return Theme(
              data:
                  themeMode == ThemeMode.dark ? AppTheme.dark : AppTheme.light,
              child: child,
            );
          },
        );
      },
      home: const AuthGate(),
    );
  }
}
