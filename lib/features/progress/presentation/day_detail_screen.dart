import 'package:flutter/material.dart';

/// Placeholder. Shows the day's photo, workout type and note in step 6.
class DayDetailScreen extends StatelessWidget {
  const DayDetailScreen({required this.day, super.key});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final label = MaterialLocalizations.of(context).formatMediumDate(day);
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: const Center(child: Text('Day detail')),
    );
  }
}
