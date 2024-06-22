import 'package:flutter/material.dart';
import 'package:unlock_detector/unlock_detector.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ExampleWidget());
}

class ExampleWidget extends StatefulWidget {
  const ExampleWidget({super.key});

  @override
  State<ExampleWidget> createState() => _ExampleWidgetState();
}

class _ExampleWidgetState extends State<ExampleWidget> {
  final UnlockDetector _unlockDetector = UnlockDetector();
  UnlockDetectorStatus _status = UnlockDetectorStatus.unknown;

  @override
  void initState() {
    super.initState();
    _unlockDetector.initalize();

    // here we will listen for lock/unlock events
    _unlockDetector.lockUnlockStream?.listen((status) {
      setState(() {
        _status = status;
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
          child: Text('Lock/Unlock Status: ${_status.name}'),
        ),
      ),
    );
  }
}
