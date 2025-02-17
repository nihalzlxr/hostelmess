import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hostel_mess/firebase_options.dart';
import 'package:hostel_mess/screen/admin_home_page.dart';
import 'package:hostel_mess/screen/forgot_psw_page.dart';
import 'package:hostel_mess/screen/landing_page.dart';
import 'package:hostel_mess/screen/login_page.dart';
import 'package:hostel_mess/screen/signup_page.dart';
import 'package:hostel_mess/screen/user_home_page.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      switch (task) {
        case 'resetMealCounts':
          final today = DateTime.now().toIso8601String().split('T')[0];
          await FirebaseFirestore.instance
              .collection('meal_counts')
              .doc(today)
              .set({
            'breakfast': {'total_count': 0, 'users': {}},
            'lunch': {'total_count': 0, 'users': {}},
            'dinner': {'total_count': 0, 'users': {}},
          });
          break;
      }
      return Future.value(true);
    } catch (e) {
      print('Background task error: $e');
      return Future.value(false);
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);

    print('Workmanager initialized successfully');
  } catch (e) {
    print('Error initializing Workmanager: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LandingPage(),
      routes: {
        '/login': (context) => Loginpage(),
        '/signup': (context) => SignupPage(),
        '/forgot-password': (context) => ForgotPswPage(),
        '/user-home': (context) => UserHomePage(),
        '/admin-home': (context) => AdminHomePage(),
      },
    );
  }
}
