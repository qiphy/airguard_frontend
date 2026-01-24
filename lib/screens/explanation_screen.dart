import 'package:flutter/material.dart';

class ExplanationScreen extends StatelessWidget {
  const ExplanationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Risk Explanation")),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          "High risk is driven by elevated PM2.5 averages "
          "and sustained upward trends detected by the model.",
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
