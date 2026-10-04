import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';

/// Placeholder. Replaced by the streak header and year grid in step 5.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GymGrid')),
      body: Center(
        child: TextButton(
          onPressed: () => context.push(AppRoutes.dayDetail(DateTime.now())),
          child: const Text("Open today's detail"),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.checkIn),
        icon: const Icon(Icons.photo_camera_outlined),
        label: const Text('Check in'),
      ),
    );
  }
}
