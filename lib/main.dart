import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/auth_gate.dart';
import 'services/notifications/fcm_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await waynThemeController.load();

  // ============================================================
  // Android Platform View mode fix.
  //
  // The default maplibre_gl mode embeds the map's GLSurfaceView
  // through a Virtual Display. During window resizes (e.g. the
  // keyboard opening while the map is visible) Flutter's
  // VirtualDisplayController can resize a SurfaceProducer that has
  // already been released, which crashes the app with:
  //
  //   NullPointerException:
  //   SurfaceProducerPlatformViewRenderTarget.getWidth()
  //
  // `useHybridComposition` makes the plugin render into a
  // TextureView instead, which does not use Virtual Display /
  // SurfaceProducer at all, removing that crash path entirely.
  // Must be set before the first MapLibreMap is built.
  // ============================================================
  MapLibreMap.useHybridComposition = true;

  // Best-effort Firebase/FCM init (no-op if Firebase is not configured).
  // Fire-and-forget: must never block app startup.
  unawaited(initializeFirebasePush());

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
