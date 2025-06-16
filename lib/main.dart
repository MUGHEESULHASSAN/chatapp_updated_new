import 'package:chat_application/auth_check_page.dart' show AuthCheckPage;
import 'package:chat_application/splash_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
 
      themeMode: ThemeMode.dark,
 
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.orange,
      ),
 
      darkTheme: ThemeData.dark().copyWith(
  
        primaryColor: Colors.orange,
 
      ),
      home: const SplashPage(),
    );
  }
}
