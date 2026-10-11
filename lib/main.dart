import 'package:flutter/material.dart';

void main() {
  runApp(const LNLocateApp());
}

class LNLocateApp extends StatelessWidget {
  const LNLocateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LNLocate',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const Scaffold(
        body: Center(child: Text('LNLocate')),
      ),
    );
  }
}
