import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  print('Starting simple app...');

  runApp(const SimpleApp());
}

class SimpleApp extends StatelessWidget {
  const SimpleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Test App',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Simple Test'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('App is working!'),
              Text('This is a simple test to check if the app starts'),
            ],
          ),
        ),
      ),
    );
  }
}
