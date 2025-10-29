import 'dart:async';
import 'package:flutter/material.dart';
import 'package:unlock_detector/unlock_detector.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OnlineStatusApp());
}

class OnlineStatusApp extends StatelessWidget {
  const OnlineStatusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Online Status Detector',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  UnlockDetectorStatus _status = UnlockDetectorStatus.unknown;
  bool _isOnline = false;
  final List<StatusLog> _logs = [];
  StreamSubscription<UnlockDetectorStatus>? _subscription;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await UnlockDetector.initialize();

      _subscription = UnlockDetector.stream.listen((status) {
        setState(() {
          _status = status;
          _isOnline = status.isOnline;

          // Add to log
          _logs.insert(0, StatusLog(status: status, timestamp: DateTime.now()));
          if (_logs.length > 10) _logs.removeLast();
        });

        // Here you would update your backend
        _updateBackendStatus(status);
      });
    } catch (e) {
      debugPrint('Failed to initialize: $e');
    }
  }

  void _updateBackendStatus(UnlockDetectorStatus status) {
    // Example: Update user's online status in your backend
    if (status.isOnline) {
      debugPrint('📱 USER ONLINE - Update backend: user is active');
      // await api.updateUserStatus(userId, online: true);
    } else if (status.isOffline) {
      debugPrint('💤 USER OFFLINE - Update backend: user is away');
      // await api.updateUserStatus(userId, online: false);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    UnlockDetector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _isOnline
                ? [Colors.green.shade50, Colors.white]
                : [Colors.grey.shade200, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              _buildStatusIndicator(),
              const SizedBox(height: 40),
              _buildInfoCards(),
              const SizedBox(height: 20),
              Expanded(child: _buildRecentLogs()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isOnline ? Colors.green : Colors.grey.shade400,
            boxShadow: [
              BoxShadow(
                color: (_isOnline ? Colors.green : Colors.grey)
                    .withValues(alpha: .3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(
            _isOnline ? Icons.check_circle : Icons.brightness_2,
            size: 60,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _isOnline ? 'ONLINE' : 'OFFLINE',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: _isOnline ? Colors.green.shade700 : Colors.grey.shade700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          _getStatusMessage(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInfoCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
              child: _buildInfoCard('Current', _status.name.toUpperCase())),
          const SizedBox(width: 12),
          Expanded(
            child: _buildInfoCard(
              'Platform',
              UnlockDetector.isAndroid ? 'Android' : 'iOS',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentLogs() {
    if (_logs.isEmpty) {
      return Center(
        child: Text(
          'Waiting for status changes...',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'RECENT ACTIVITY',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.grey.shade600,
                  letterSpacing: 1.2,
                ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _logs.length,
            itemBuilder: (context, index) {
              final log = _logs[index];
              return _buildLogItem(log);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLogItem(StatusLog log) {
    final timeStr = '${log.timestamp.hour.toString().padLeft(2, '0')}:'
        '${log.timestamp.minute.toString().padLeft(2, '0')}:'
        '${log.timestamp.second.toString().padLeft(2, '0')}';

    Color color;
    IconData icon;

    switch (log.status) {
      case UnlockDetectorStatus.foreground:
        color = Colors.green;
        icon = Icons.phone_android;
        break;
      case UnlockDetectorStatus.background:
        color = Colors.orange;
        icon = Icons.minimize;
        break;
      case UnlockDetectorStatus.locked:
        color = Colors.red;
        icon = Icons.lock;
        break;
      case UnlockDetectorStatus.unlocked:
        color = Colors.blue;
        icon = Icons.lock_open;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              log.status.name.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            timeStr,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusMessage() {
    switch (_status) {
      case UnlockDetectorStatus.foreground:
        return 'User is actively using the app';
      case UnlockDetectorStatus.background:
        return 'User switched to another app';
      case UnlockDetectorStatus.locked:
        return 'Device is locked';
      case UnlockDetectorStatus.unlocked:
        return 'Device was unlocked';
      default:
        return 'Detecting status...';
    }
  }
}

class StatusLog {
  final UnlockDetectorStatus status;
  final DateTime timestamp;

  StatusLog({required this.status, required this.timestamp});
}
