import 'package:flutter/material.dart';

class POSPage extends StatefulWidget {
  const POSPage({super.key});

  @override
  _POSPageState createState() => _POSPageState();
}

class _POSPageState extends State<POSPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Point of Sales'),
      ),
      body: const Center(
        child: Text(
          'POS',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
