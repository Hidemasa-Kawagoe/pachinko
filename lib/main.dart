import 'package:flutter/material.dart';

import 'ui/home_page.dart';

void main() {
  runApp(const PachinkoSimApp());
}

class PachinkoSimApp extends StatelessWidget {
  const PachinkoSimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'パチンコ シミュレータ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1E6091),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1E6091),
        brightness: Brightness.dark,
      ),
      home: const HomePage(),
    );
  }
}
