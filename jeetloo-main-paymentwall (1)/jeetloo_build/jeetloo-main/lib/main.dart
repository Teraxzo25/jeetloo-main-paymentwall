import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:jeetloo/Screens/home.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeetloo/authentication/signup.dart'; // keep if used
import 'package:jeetloo/Screens/splash.dart'; // keep if used
import 'package:jeetloo/authentication/login.dart'; // I assume LoginScreen is here

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase

  MobileAds.instance.initialize();

  // Check if logged in
  final prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JeetLOo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      // If logged in, show home, else login or splash (your choice)
      home: isLoggedIn ? JeetLooHomeScreen() : SplashScreen(),
    );
  }
}
