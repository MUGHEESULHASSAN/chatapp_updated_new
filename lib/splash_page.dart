import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chat_application/auth_check_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Animation setup
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward(); // Start animation

    // Navigate after delay
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthCheckPage()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose(); // Clean up
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double imageSize = MediaQuery.of(context).size.width * 0.6;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: CircleAvatar(
              radius: imageSize / 2,
              backgroundColor: Colors.black,
              child: ClipOval(
                child: Image.asset(
                  'assets/Images/Logo.png',
                  width: imageSize,
                  height: imageSize,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
