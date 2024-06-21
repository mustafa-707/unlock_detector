import 'package:flutter/material.dart';
import 'package:unlock_detector/unlock_detector.dart';

void main() {
  runApp(const ExampleWidget());
}

class ExampleWidget extends StatefulWidget {
  const ExampleWidget({super.key});

  @override
  State<ExampleWidget> createState() => _ExampleWidgetState();
}

class _ExampleWidgetState extends State<ExampleWidget> {
  final UnlockDetector _unlockDetector = UnlockDetector();
  String _status = 'Unknown';

  @override
  void initState() {
    super.initState();
    _unlockDetector.startDetection();
    _unlockDetector.lockUnlockStream?.listen((event) {
      setState(() {
        _status = event;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Unlock Detector'),
        ),
        body: Center(
          child: Text('Lock/Unlock Status: $_status'),
        ),
      ),
    );
  }
}
