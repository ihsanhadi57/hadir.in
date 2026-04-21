import 'package:flutter/material.dart';

class ZoomPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  ZoomPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            );

            // Karena logo sudah membesar (zoom-in sangat ekstrim di SplashPage),
            // kita HANYA butuh Fade agar halaman Home/Login muncul dengan mulus.
            // Jika ada ScaleTransition di sini lagi, akan ada ilusi visual "berhenti".
            return FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curve),
              child: child,
            );
          },
        );
}
