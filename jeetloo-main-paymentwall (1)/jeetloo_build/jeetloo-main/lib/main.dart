import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jeetloo/reward_ads/bannerads.dart';
import 'package:jeetloo/Screens/home.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeetloo/authentication/signup.dart';
import 'package:jeetloo/Screens/splash.dart';
import 'package:jeetloo/authentication/login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await AdmobHelper.initialize();

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
