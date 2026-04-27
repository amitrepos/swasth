import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:workmanager/workmanager.dart';
import '../services/storage_service.dart';
import '../services/health_reading_service.dart';

/// Background task callback - MUST be a top-level function
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('BackgroundStepService: Executing task: $task');
    
    try {
      if (task == 'syncSteps') {
        await _syncStepsToBackend();
      }
      return Future.value(true);
    } catch (e) {
      debugPrint('BackgroundStepService: Error in task $task: $e');
      return Future.value(false);
    }
  });
}

/// Sync steps from pedometer to backend in background
@pragma('vm:entry-point')
Future<void> _syncStepsToBackend() async {
  try {
    debugPrint('BackgroundStepService: Starting background step sync');
    
    final storage = StorageService();
    final token = await storage.getToken();
    final profileId = await storage.getActiveProfileId();
    
    if (token == null || profileId == null) {
      debugPrint('BackgroundStepService: No token or profile ID, skipping sync');
      return;
    }

    // Read current step count from pedometer
    int currentSteps = 0;
    
    try {
      // Get the latest step count from the stream
      final stepStream = Pedometer.stepCountStream;
      final completer = Completer<int>();
      StreamSubscription? subscription;
      
      subscription = stepStream.listen(
        (event) {
          if (!completer.isCompleted) {
            debugPrint('BackgroundStepService: Got step count: ${event.steps}');
            completer.complete(event.steps);
            subscription?.cancel();
          }
        },
        onError: (error) {
          debugPrint('BackgroundStepService: Error reading pedometer: $error');
          if (!completer.isCompleted) {
            completer.completeError(error);
            subscription?.cancel();
          }
        },
      );
      
      // Wait for step count with timeout
      currentSteps = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          subscription?.cancel();
          debugPrint('BackgroundStepService: Timeout reading pedometer');
          return 0;
        },
      );
    } catch (e) {
      debugPrint('BackgroundStepService: Error getting step count: $e');
      currentSteps = 0;
    }

    // Get baseline and calculate today's steps
    final baselineSteps = await storage.getBaselineSteps() ?? 0;
    final todaySteps = baselineSteps > 0 ? currentSteps - baselineSteps : 0;
    
    if (todaySteps < 0) {
      debugPrint('BackgroundStepService: Negative steps, resetting baseline');
      await storage.saveBaselineSteps(currentSteps);
      await storage.saveLastSyncedSteps(-1); // Reset synced count
      return;
    }

    // Check if steps have changed since last sync
    final lastSyncedSteps = await storage.getLastSyncedSteps() ?? -1;
    if (todaySteps == lastSyncedSteps) {
      debugPrint('BackgroundStepService: Steps unchanged ($todaySteps), skipping sync');
      return;
    }

    debugPrint('BackgroundStepService: Syncing $todaySteps steps to backend (was: $lastSyncedSteps)');
    
    // Save to local storage
    await storage.saveTodaySteps(todaySteps);
    await storage.saveLastStepsDate(DateTime.now());
    await storage.saveLastSyncedSteps(todaySteps);

    // Sync to backend
    final readingService = HealthReadingService();
    await readingService.saveStepsReading(
      token: token,
      profileId: profileId,
      stepsCount: todaySteps,
      stepsGoal: await storage.getStepsGoal() ?? 7500,
    );

    debugPrint('BackgroundStepService: Steps synced successfully');
  } catch (e) {
    debugPrint('BackgroundStepService: Error syncing steps: $e');
  }
}

/// Service that manages background step counting
class BackgroundStepService {
  static final BackgroundStepService _instance = BackgroundStepService._internal();
  factory BackgroundStepService() => _instance;
  BackgroundStepService._internal();

  /// Initialize background step counting
  Future<void> initialize() async {
    debugPrint('BackgroundStepService: Initializing...');
    
    try {
      // Initialize workmanager
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );

      // Register periodic task - runs every 15 minutes (minimum allowed)
      await Workmanager().registerPeriodicTask(
        'stepSyncTask',
        'syncSteps',
        frequency: const Duration(minutes: 15),
        initialDelay: const Duration(seconds: 10),
        constraints: Constraints(
          networkType: NetworkType.not_required,
          requiresBatteryNotLow: false,
        ),
      );

      debugPrint('BackgroundStepService: Background task registered successfully');
    } catch (e) {
      debugPrint('BackgroundStepService: Error initializing background service: $e');
    }
  }

  /// Cancel background tasks
  Future<void> cancel() async {
    debugPrint('BackgroundStepService: Cancelling background tasks');
    await Workmanager().cancelAll();
  }

  /// Manually trigger a step sync
  Future<void> triggerSync() async {
    debugPrint('BackgroundStepService: Manual sync triggered');
    await Workmanager().registerOneOffTask(
      'manualStepSync',
      'syncSteps',
      initialDelay: const Duration(seconds: 1),
    );
  }
}
