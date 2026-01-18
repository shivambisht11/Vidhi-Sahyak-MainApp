import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../core/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final Widget? nextScreen; // Optional for Overlay Mode
  const SplashScreen({super.key, this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _hasNavigated = false;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Navigate to next screen OR pop after 3 seconds
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_hasNavigated) {
        // Schedule navigation for after the current frame to avoid _debugLocked errors
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_hasNavigated) {
            _hasNavigated = true;
            if (widget.nextScreen != null) {
              // Cold Start Mode: Replace Splash with Home/Onboarding
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => widget.nextScreen!),
              );
            } else {
              // Overlay/Resume Mode: Just dismiss Splash
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Image with "Dimming" effect
          Image.asset('assets/vidhi_bg.png', fit: BoxFit.cover),
          // Dark Overlay to reduce brightness/opacity
          Container(
            color: Colors.black.withOpacity(0.5), // 50% opacity black layer
          ),

          // 2. New Loader Style (Cupertino/iOS style is clean and different)
          const Center(
            child: CupertinoActivityIndicator(
              radius: 20, // Larger size
              color: Colors.white, // White color stands out on dark bg
            ),
          ),
        ],
      ),
    );
  }
}
