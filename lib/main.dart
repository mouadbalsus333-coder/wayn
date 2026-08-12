import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/supabase/supabase_initializer.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initSupabase();

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

      themeMode: ThemeMode.light,

      locale: const Locale('ar'),

      supportedLocales: const [Locale('ar'), Locale('en')],

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const SplashPage(),
    );
  }
}
