import 'package:flutter/material.dart';

/// Animation constants and utilities for smooth transitions
class AppAnimations {
  // Duration constants
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);
  static const Duration durationExtraSlow = Duration(milliseconds: 800);

  // Curve constants
  static const Curve curveDefault = Curves.easeInOut;
  static const Curve curveEaseIn = Curves.easeIn;
  static const Curve curveEaseOut = Curves.easeOut;
  static const Curve curveElastic = Curves.elasticOut;
  static const Curve curveBounce = Curves.bounceOut;
  static const Curve curveDecelerate = Curves.decelerate;

  // Page transition builders
  static Widget slideTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child, {
    Offset begin = const Offset(1.0, 0.0),
    Offset end = Offset.zero,
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: begin,
        end: end,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: curveDefault,
      )),
      child: child,
    );
  }

  static Widget fadeTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: curveDefault,
      ),
      child: child,
    );
  }

  static Widget scaleTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: animation,
        curve: curveElastic,
      ),
      child: child,
    );
  }

  // Custom page route with slide transition
  static PageRouteBuilder<T> createSlideRoute<T>(
    Widget page, {
    Offset begin = const Offset(1.0, 0.0),
    Duration duration = durationMedium,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return slideTransition(
          context,
          animation,
          secondaryAnimation,
          child,
          begin: begin,
        );
      },
    );
  }

  // Custom page route with fade transition
  static PageRouteBuilder<T> createFadeRoute<T>(
    Widget page, {
    Duration duration = durationMedium,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return fadeTransition(context, animation, secondaryAnimation, child);
      },
    );
  }

  // Animated container with smooth transitions
  static Widget animatedContainer({
    required Widget child,
    Duration duration = durationMedium,
    Curve curve = curveDefault,
    Color? color,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    BoxDecoration? decoration,
    double? width,
    double? height,
  }) {
    return AnimatedContainer(
      duration: duration,
      curve: curve,
      color: color,
      padding: padding,
      margin: margin,
      decoration: decoration,
      width: width,
      height: height,
      child: child,
    );
  }

  // Animated opacity with smooth fade
  static Widget animatedOpacity({
    required Widget child,
    required double opacity,
    Duration duration = durationMedium,
    Curve curve = curveDefault,
  }) {
    return AnimatedOpacity(
      opacity: opacity,
      duration: duration,
      curve: curve,
      child: child,
    );
  }

  // Animated scale with bounce effect
  static Widget animatedScale({
    required Widget child,
    required double scale,
    Duration duration = durationMedium,
    Curve curve = curveElastic,
  }) {
    return AnimatedScale(
      scale: scale,
      duration: duration,
      curve: curve,
      child: child,
    );
  }

  // Staggered animation for lists
  static Widget staggeredAnimation({
    required Widget child,
    required int index,
    Duration delay = const Duration(milliseconds: 100),
    Duration duration = durationMedium,
    Offset begin = const Offset(0, 50),
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration + (delay * index),
      curve: curveDefault,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset.lerp(begin, Offset.zero, value)!,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // Ripple effect animation
  static Widget rippleEffect({
    required Widget child,
    required VoidCallback onTap,
    Color? splashColor,
    Color? highlightColor,
    BorderRadius? borderRadius,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: splashColor,
        highlightColor: highlightColor,
        borderRadius: borderRadius,
        child: child,
      ),
    );
  }

  // Shimmer loading animation
  static Widget shimmerLoading({
    required Widget child,
    Color baseColor = const Color(0xFFE0E0E0),
    Color highlightColor = const Color(0xFFF5F5F5),
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -1.0, end: 2.0),
      duration: duration,
      curve: Curves.linear,
      builder: (context, value, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                (value - 1).clamp(0.0, 1.0),
                value.clamp(0.0, 1.0),
                (value + 1).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: child,
    );
  }

  // Hero animation wrapper
  static Widget heroAnimation({
    required String tag,
    required Widget child,
  }) {
    return Hero(
      tag: tag,
      child: child,
    );
  }

  // Animated list item with slide and fade
  static Widget animatedListItem({
    required Widget child,
    required Animation<double> animation,
    Offset begin = const Offset(1.0, 0.0),
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: begin,
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: curveDefault,
      )),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: curveDefault,
        ),
        child: child,
      ),
    );
  }
}
