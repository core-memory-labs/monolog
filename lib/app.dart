import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'providers/theme_notifier.dart';
import 'screens/share_receiver_screen.dart';
import 'screens/topic_list_screen.dart';

class MonologApp extends ConsumerStatefulWidget {
  const MonologApp({super.key});

  @override
  ConsumerState<MonologApp> createState() => _MonologAppState();
}

class _MonologAppState extends ConsumerState<MonologApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  StreamSubscription<List<SharedMediaFile>>? _mediaStreamSub;

  /// True when the app was launched via a share intent (cold start).
  /// Determines whether to close the entire app after saving.
  bool _launchedViaShare = false;

  /// Guards against duplicate share handling.
  ///
  /// receive_sharing_intent on some Android devices emits the same intent
  /// through both getInitialMedia() and getMediaStream(). This flag ensures
  /// we only push ShareReceiverScreen once per intent.
  bool _processingShare = false;

  @override
  void initState() {
    super.initState();
    _handleInitialShare();
    _listenShareStream();
  }

  @override
  void dispose() {
    _mediaStreamSub?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Share intent handling
  // ---------------------------------------------------------------------------

  /// Checks for shared data that launched the app (cold start).
  Future<void> _handleInitialShare() async {
    final media = await ReceiveSharingIntent.instance.getInitialMedia();
    if (media.isNotEmpty) {
      _launchedViaShare = true;
      _handleSharedMedia(media.first);
    }
  }

  /// Listens for shared data arriving while the app is already running
  /// (warm start / app in background).
  void _listenShareStream() {
    _mediaStreamSub =
        ReceiveSharingIntent.instance.getMediaStream().listen((media) {
      if (media.isNotEmpty) {
        _handleSharedMedia(media.first);
      }
    });
  }

  void _handleSharedMedia(SharedMediaFile file) {
    // Guard against duplicate emissions: receive_sharing_intent may fire the
    // same intent through both getInitialMedia() and getMediaStream().
    if (_processingShare) return;
    _processingShare = true;

    String? imagePath;
    String? sharedText;
    String? filePath;
    String? fileMimeType;

    if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
      sharedText = file.path;
    } else if (file.type == SharedMediaType.image) {
      imagePath = file.path;
    } else if (file.type == SharedMediaType.file ||
        file.type == SharedMediaType.video) {
      filePath = file.path;
      fileMimeType = file.mimeType;
    } else {
      // Unsupported type — release the guard and ignore.
      _processingShare = false;
      return;
    }

    _navigateToShareReceiver(
      imagePath: imagePath,
      sharedText: sharedText,
      filePath: filePath,
      fileMimeType: fileMimeType,
    );
  }

  void _navigateToShareReceiver({
    String? imagePath,
    String? sharedText,
    String? filePath,
    String? fileMimeType,
  }) {
    // Wait for the navigator to be ready (relevant for cold start).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ShareReceiverScreen(
            sharedImagePath: imagePath,
            sharedText: sharedText,
            sharedFilePath: filePath,
            sharedFileMimeType: fileMimeType,
            onDone: _onShareDone,
          ),
        ),
      );
    });
  }

  /// Called by [ShareReceiverScreen] after saving or cancelling.
  void _onShareDone() {
    ReceiveSharingIntent.instance.reset();
    // Release the guard so the next share intent is handled correctly.
    _processingShare = false;

    if (_launchedViaShare) {
      // Close the entire app and return to the source app.
      SystemNavigator.pop();
    }
    // For warm start, ShareReceiverScreen pops itself via Navigator.pop().
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Monolog',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const TopicListScreen(),
    );
  }
}
