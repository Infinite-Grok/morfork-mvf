import 'package:flutter/material.dart';

/// A simple widget to demonstrate successful widget creation and rendering
class TestSuccessWidget extends StatelessWidget {
  const TestSuccessWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: Colors.green.shade700,
            width: 2.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 48.0,
            ),
            const SizedBox(height: 16.0),
            Text(
              'Widget Created Successfully!',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              'The test widget is rendering correctly',
              style: TextStyle(
                color: Colors.green.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Example usage:
///