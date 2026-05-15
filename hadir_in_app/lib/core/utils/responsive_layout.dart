import 'package:flutter/material.dart';

/// Responsive layout utilities for hadir.in
///
/// Breakpoints:
/// - Phone:   < 600dp
/// - Tablet:  600dp – 900dp
/// - Desktop: > 900dp
class ResponsiveLayout {
  ResponsiveLayout._();

  // ─── Breakpoints ───
  static const double phoneMaxWidth = 600;
  static const double tabletMaxWidth = 900;

  // ─── Device type checks ───
  static bool isPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width < phoneMaxWidth;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= phoneMaxWidth && w < tabletMaxWidth;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletMaxWidth;

  static bool isTabletOrWider(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= phoneMaxWidth;

  // ─── Content max width ───
  /// Returns max content width for the current device.
  /// Phone: no constraint, Tablet: 540, Desktop: 700
  static double contentMaxWidth(BuildContext context) {
    if (isDesktop(context)) return 700;
    if (isTablet(context)) return 540;
    return double.infinity;
  }

  /// Wider content constraint for pages that benefit from more space
  /// (e.g. event detail, help/FAQ).
  static double wideContentMaxWidth(BuildContext context) {
    if (isDesktop(context)) return 800;
    if (isTablet(context)) return 680;
    return double.infinity;
  }

  // ─── Horizontal padding ───
  static double contentPadding(BuildContext context) {
    if (isDesktop(context)) return 64;
    if (isTablet(context)) return 40;
    return 24;
  }

  // ─── Grid count for event cards etc. ───
  static int gridCrossAxisCount(BuildContext context) {
    if (isDesktop(context)) return 3;
    if (isTablet(context)) return 2;
    return 1;
  }

  // ─── Scaling helper ───
  /// Scales a base value by 1.0x (phone), 1.15x (tablet), 1.25x (desktop).
  static double scaled(BuildContext context, double base) {
    if (isDesktop(context)) return base * 1.25;
    if (isTablet(context)) return base * 1.15;
    return base;
  }
}

/// A convenience widget that centers and constrains its child
/// for tablet/desktop layouts, while allowing full-width on phone.
///
/// Usage:
/// ```dart
/// ResponsiveCenter(
///   maxWidth: 540,
///   padding: EdgeInsets.symmetric(horizontal: 24),
///   child: MyContent(),
/// )
/// ```
class ResponsiveCenter extends StatelessWidget {
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final Widget child;

  const ResponsiveCenter({
    super.key,
    this.maxWidth = 540,
    this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    // On phone, no constraint needed
    if (ResponsiveLayout.isPhone(context)) {
      return content;
    }

    // On tablet/desktop, center & constrain
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      ),
    );
  }
}

/// A Sliver version of ResponsiveCenter for use inside CustomScrollView.
class SliverResponsiveCenter extends StatelessWidget {
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final Widget sliver;

  const SliverResponsiveCenter({
    super.key,
    this.maxWidth = 540,
    this.padding,
    required this.sliver,
  });

  @override
  Widget build(BuildContext context) {
    if (ResponsiveLayout.isPhone(context)) {
      if (padding != null) {
        return SliverPadding(padding: padding!, sliver: sliver);
      }
      return sliver;
    }

    // For tablet: wrap in SliverToBoxAdapter with constrained center
    // This works for SliverList/SliverGrid by converting via SliverPadding
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = ((screenWidth - maxWidth) / 2).clamp(0.0, double.infinity);

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      sliver: sliver,
    );
  }
}
