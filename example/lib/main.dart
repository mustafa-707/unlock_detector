import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:unlock_detector/unlock_detector.dart';

/// How long the user may be inactive before the status becomes `idle`.
///
/// On desktop this is compared against the system-wide idle time reported by
/// the OS. On mobile and web it is an in-app timer fed by
/// [UnlockDetector.reportActivity], which [UnlockDetector.activityDetector]
/// wires up for us in [main].
const _idleTimeout = Duration(seconds: 15);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(UnlockDetector.activityDetector(child: const OnlineStatusApp()));
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
  final List<StatusLog> _logs = [];
  StreamSubscription<UnlockDetectorStatus>? _subscription;
  bool _deviceLocked = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await UnlockDetector.initialize(idleTimeout: _idleTimeout);

      _subscription = UnlockDetector.stream.listen((status) {
        if (!mounted) return;
        setState(() {
          _status = status;
          _logs.insert(0, StatusLog(status: status, timestamp: DateTime.now()));
          if (_logs.length > 10) _logs.removeLast();
        });

        // Here you would update your backend.
        _updateBackendStatus(status);
      });

      // One-shot query, separate from the stream: reliable on Android,
      // best-effort on iOS, always false elsewhere.
      final locked = await UnlockDetector.isDeviceLocked();
      if (mounted) setState(() => _deviceLocked = locked);
    } catch (e) {
      debugPrint('Failed to initialize: $e');
    }
  }

  void _updateBackendStatus(UnlockDetectorStatus status) {
    if (status.isOnline) {
      debugPrint('📱 USER ONLINE — update backend: user is active');
      // await api.updateUserStatus(userId, online: true);
    } else if (status.isIdle) {
      debugPrint('🕒 USER IDLE — update backend: away from keyboard');
      // await api.updateUserStatus(userId, away: true);
    } else if (status.isOffline) {
      debugPrint('💤 USER OFFLINE — update backend: user is away');
      // await api.updateUserStatus(userId, online: false);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(UnlockDetector.dispose());
    super.dispose();
  }

  /// The platform this build is running on — the plugin behaves differently on
  /// each, so the example names the real one rather than guessing.
  String get _platformLabel {
    if (kIsWeb) return 'Web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
  }

  @override
  Widget build(BuildContext context) {
    final presence = _PresenceStyle.of(_status);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              presence.color.withValues(alpha: .18),
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              _buildStatusIndicator(presence),
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

  Widget _buildStatusIndicator(_PresenceStyle presence) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: presence.color,
            boxShadow: [
              BoxShadow(
                color: presence.color.withValues(alpha: .3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(presence.icon, size: 60, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Text(
          presence.headline,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: presence.color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          presence.message,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
          Expanded(child: _buildInfoCard('Current', _status.name.toUpperCase())),
          const SizedBox(width: 12),
          Expanded(child: _buildInfoCard('Platform', _platformLabel)),
          const SizedBox(width: 12),
          Expanded(
            child: _buildInfoCard('Device', _deviceLocked ? 'LOCKED' : 'OPEN'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentLogs() {
    final theme = Theme.of(context);

    if (_logs.isEmpty) {
      return Center(
        child: Text(
          'Waiting for status changes...',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
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
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _logs.length,
            itemBuilder: (context, index) => _buildLogItem(_logs[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildLogItem(StatusLog log) {
    final theme = Theme.of(context);
    final presence = _PresenceStyle.of(log.status);
    final timeStr = '${log.timestamp.hour.toString().padLeft(2, '0')}:'
        '${log.timestamp.minute.toString().padLeft(2, '0')}:'
        '${log.timestamp.second.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: presence.color.withValues(alpha: .4)),
      ),
      child: Row(
        children: [
          Icon(presence.icon, color: presence.color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              log.status.name.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            timeStr,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// How one status is presented — colour, icon and copy in a single place, so
/// every status the plugin can emit is covered exactly once.
class _PresenceStyle {
  const _PresenceStyle({
    required this.color,
    required this.icon,
    required this.headline,
    required this.message,
  });

  final Color color;
  final IconData icon;
  final String headline;
  final String message;

  static _PresenceStyle of(UnlockDetectorStatus status) {
    return switch (status) {
      UnlockDetectorStatus.foreground => const _PresenceStyle(
          color: Colors.green,
          icon: Icons.check_circle,
          headline: 'ONLINE',
          message: 'User is actively using the app',
        ),
      UnlockDetectorStatus.idle => const _PresenceStyle(
          color: Colors.amber,
          icon: Icons.hourglass_bottom,
          headline: 'IDLE',
          message: 'App is open, but there has been no input',
        ),
      UnlockDetectorStatus.background => const _PresenceStyle(
          color: Colors.orange,
          icon: Icons.minimize,
          headline: 'OFFLINE',
          message: 'User switched to another app or window',
        ),
      UnlockDetectorStatus.locked => const _PresenceStyle(
          color: Colors.red,
          icon: Icons.lock,
          headline: 'OFFLINE',
          message: 'Device screen is off or locked',
        ),
      UnlockDetectorStatus.unlocked => const _PresenceStyle(
          color: Colors.blue,
          icon: Icons.lock_open,
          headline: 'UNLOCKED',
          message: 'Device was just unlocked',
        ),
      UnlockDetectorStatus.screenOn => const _PresenceStyle(
          color: Colors.indigo,
          icon: Icons.light_mode,
          headline: 'SCREEN ON',
          message: 'Screen turned on — it may still be locked',
        ),
      UnlockDetectorStatus.unknown => const _PresenceStyle(
          color: Colors.grey,
          icon: Icons.help,
          headline: 'UNKNOWN',
          message: 'Detecting status...',
        ),
    };
  }
}

class StatusLog {
  StatusLog({required this.status, required this.timestamp});

  final UnlockDetectorStatus status;
  final DateTime timestamp;
}
