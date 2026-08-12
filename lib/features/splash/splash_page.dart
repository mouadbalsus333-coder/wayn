import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/navigation/wayn_shell.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _logoAnimation;
  late final Animation<double> _textAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _logoAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _textAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        0.35,
        1.0,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward();

    Timer(
      const Duration(seconds: 3),
      _goToWaynShell,
    );
  }

  void _goToWaynShell() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (
          context,
          animation,
          secondaryAnimation,
        ) {
          return const WaynShell();
        },
        transitionDuration: const Duration(
          milliseconds: 650,
        ),
        reverseTransitionDuration: const Duration(
          milliseconds: 400,
        ),
        transitionsBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curvedAnimation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.035),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FCFC),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _logoAnimation,
                  child: FadeTransition(
                    opacity: _logoAnimation,
                    child: _buildLogo(),
                  ),
                ),

                const SizedBox(height: 28),

                FadeTransition(
                  opacity: _textAnimation,
                  child: Column(
                    children: [
                      const Text(
                        'أهلًا بك في وين',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF123F46),
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'دليلك الذكي لاكتشاف الأماكن',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: Colors.blueGrey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 42),

                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: const Color(0xFF18B7B0).withValues(
                      alpha: 0.75,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/branding/wayn_logo.png',
      width: 150,
      height: 150,
      fit: BoxFit.contain,
      errorBuilder: (
        context,
        error,
        stackTrace,
      ) {
        return Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            color: const Color(0xFF18B7B0),
            borderRadius: BorderRadius.circular(42),
          ),
          child: const Icon(
            Icons.location_on_rounded,
            size: 78,
            color: Colors.white,
          ),
        );
      },
    );
  }
}