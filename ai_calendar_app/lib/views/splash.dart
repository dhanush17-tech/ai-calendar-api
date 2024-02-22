import 'dart:math';

import 'package:ai_calendar_app/views/home.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(vsync: this, duration: Duration(seconds: 3))
          ..repeat(reverse: true);

    _animation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    navigateToHome();
  }

  void navigateToHome() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
            context,
            PageTransition(
                isIos: true,
                duration: const Duration(milliseconds: 500),
                type: PageTransitionType.scale,
                alignment: Alignment.center,
                child: HomeScreen()),
            (route) => false);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.only(right: 10.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/icon/c.png',
                height: 200,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 15.0, bottom: 10),
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return ShaderMask(
                      child: child,
                      shaderCallback: (Rect bounds) {
                        return LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            ColorTween(begin: Colors.blue, end: Colors.green)
                                .lerp(_animation.value)!,
                            ColorTween(
                                    begin: Colors.purpleAccent,
                                    end: Colors.yellow)
                                .lerp(_animation.value)!,
                          ],
                        ).createShader(bounds);
                      },
                    );
                  },
                  child: Image.asset(
                    'assets/icon/star.png',
                    height: 150,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
