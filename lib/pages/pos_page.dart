import 'package:flutter/material.dart';

import '../widgets/glass_app_bar.dart';
import '../widgets/modern_bottom_nav.dart';
class POSPage extends StatefulWidget {
  const POSPage({super.key});

  @override
  POSPageState createState() => POSPageState();
}

class POSPageState extends State<POSPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('Point of Sales'),
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Center(
          child: Text(
            'POS',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: 3,
        onTap: (index) {
          if (index != 3) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}
