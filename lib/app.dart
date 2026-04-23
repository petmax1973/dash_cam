import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/home_screen.dart';
import 'screens/review_screen.dart';

class DashCamApp extends StatelessWidget {
  const DashCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DashCam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFE53935),
          secondary: const Color(0xFFFF5252),
          surface: const Color(0xFF1A1A1A),
          onSurface: Colors.white,
          error: const Color(0xFFFF1744),
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/review': (context) => const ReviewScreen(),
      },
    );
  }
}
