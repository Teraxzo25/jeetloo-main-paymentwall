import 'package:flutter/material.dart';
import 'dart:async';

import 'package:jeetloo/authentication/login.dart';
import 'package:jeetloo/Screens/home.dart'; // Replace with your actual login screen

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _controller.forward();

    Timer(Duration(seconds: 4), () {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen()));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Color(0xff7daddb),

        // decoration: BoxDecoration(
        //   color: Color(0xff7daddb),
        //   // gradient: LinearGradient(
        //   //   colors: [Color(0xff7daddb), Color(0xff141c27)],
        //     begin: Alignment.topCenter,
        //     end: Alignment.bottomCenter,
        //   ),
        // ),
        child: FadeTransition(
          opacity: _animation,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _animation,
                  child: Image.asset(
                    'assets/Images/logo1.png', // Make sure the path is correct
                  ),
                ),
                // SizedBox(height: 24),
                // Text(
                //   'JeetLOo',
                //   style: TextStyle(
                //     fontSize: 32,
                //     fontWeight: FontWeight.bold,
                //     color: Colors.white,
                //     letterSpacing: 1.2,
                //   ),
                // ),
                // SizedBox(height: 8),
                // Text(
                //   'Earn Smart. Earn Fast.',
                //   style: TextStyle(
                //     color: Colors.white70,
                //     fontSize: 16,
                //     fontStyle: FontStyle.italic,
                //   ),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
