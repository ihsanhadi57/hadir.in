import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class BrandText extends StatelessWidget {
  final double fontSize;
  final FontWeight fontWeight;
  final Color? hadirColor;
  final Color? inColor;
  final bool useWhiteForHadir;

  const BrandText({
    super.key,
    this.fontSize = 28,
    this.fontWeight = FontWeight.w800,
    this.hadirColor,
    this.inColor,
    this.useWhiteForHadir = false,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: -0.5,
        ),
        children: [
          TextSpan(
            text: 'hadir',
            style: TextStyle(
              color: hadirColor ?? (useWhiteForHadir ? Colors.white : AppTheme.primary),
            ),
          ),
          TextSpan(
            text: '.in',
            style: TextStyle(
              color: inColor ?? AppTheme.primaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
