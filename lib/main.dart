import 'package:flutter/material.dart';
import 'package:localpkg/theme.dart';
import 'package:trafficlightsimulator/home.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ping!',
      theme: brandTheme(seedColor: Colors.red),
      darkTheme: brandTheme(seedColor: Colors.red, darkMode: true),
      home: const Home(home: true),
    );
  }
}
