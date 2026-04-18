import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/health_reading_service.dart';
import '../services/storage_service.dart';

/// Service that handles phone-based step counting using the device's pedometer sensor.
/// 
/// This service:
/// - Requests activity recognition permissions
/// - Listens to step count updates from the device sensor
/// - Stores daily step counts locally
/// - Syncs steps to the backend when requested
class PedometerService {
  static final PedometerService _instance = PedometerService._internal();
  factory PedometerService() => _instance;
  PedometerService._internal();

  final Pedometer _pedometer = Pedometer();
  final StorageService _storage = StorageService();
  
  Stream<StepCount>? _stepCountStream;
  StreamSubscription<StepCount>? _stepSubscription;
  
  int _todaySteps = 0;
  int _stepsGoal = 7500; // Default daily goal
  DateTime? _lastStepDate;
  
  /// Current step count for today
  int get todaySteps => _todaySteps;
  
  /// Daily step goal
  int get stepsGoal => _stepsGoal;
  
  /// Set custom daily step goal
  void setStepsGoal(int goal) {
    _stepsGoal = goal;
    _storage.saveStepsGoal(goal);
  }

  /// Initialize pedometer and start listening to step updates
  Future<void> initialize() async {
    debugPrint('PedometerService: Initializing...');
    
    // Check and request permissions
    final hasPermission = await _requestPermissions();
    if (!hasPermission) {
      debugPrint('PedometerService: Permission denied');
      return;
    }

    // Load saved steps from today
    await _loadTodaySteps();

    // Start listening to step count stream
    try {
      debugPrint('PedometerService: Starting step count stream listener...');
      _stepCountStream = Pedometer.stepCountStream;
      
      _stepSubscription = _stepCountStream!.listen(
        _onStepCountUpdate,
        onError: (error) {
          debugPrint('PedometerService: Stream error: $error');
        },
        onDone: () {
          debugPrint('PedometerService: Stream completed');
        },
      );
      
      debugPrint('PedometerService: Successfully listening to step count stream');
      debugPrint('PedometerService: Current step count: $_todaySteps');
      
      // Force an initial sync to backend after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        debugPrint('PedometerService: Initial steps value: $_todaySteps');
        syncStepsToBackend();
      });
    } catch (e) {
      debugPrint('PedometerService: Error starting pedometer: $e');
    }
  }

  /// Stop listening to step updates
  void dispose() {
    _stepSubscription?.cancel();
    debugPrint('PedometerService: Disposed');
  }

  /// Request necessary permissions for step counting
  Future<bool> _requestPermissions() async {
    try {
      // For Android 10+ (API 29+), we need ACTIVITY_RECOGNITION
      final status = await Permission.activityRecognition.status;
      
      if (status.isDenied) {
        debugPrint('PedometerService: Requesting activity recognition permission');
        final result = await Permission.activityRecognition.request();
        return result.isGranted;
      }
      
      return status.isGranted;
    } catch (e) {
      debugPrint('PedometerService: Error requesting permissions: $e');
      return false;
    }
  }

  /// Load today's step count from local storage
  Future<void> _loadTodaySteps() async {
    try {
      final today = DateTime.now();
      final savedDate = await _storage.getLastStepsDate();
      final savedSteps = await _storage.getTodaySteps();

      // If it's a new day, reset step count
      if (savedDate == null || 
          savedDate.year != today.year || 
          savedDate.month != today.month || 
          savedDate.day != today.day) {
        _todaySteps = 0;
        _lastStepDate = today;
        debugPrint('PedometerService: New day, resetting steps to 0');
      } else {
        _todaySteps = savedSteps ?? 0;
        _lastStepDate = savedDate;
        debugPrint('PedometerService: Loaded saved steps: $_todaySteps');
      }

      // Load steps goal
      final savedGoal = await _storage.getStepsGoal();
      if (savedGoal != null && savedGoal > 0) {
        _stepsGoal = savedGoal;
      }
    } catch (e) {
      debugPrint('PedometerService: Error loading steps: $e');
      _todaySteps = 0;
    }
  }

  /// Handle step count updates from the pedometer sensor
  void _onStepCountUpdate(StepCount event) {
    try {
      final today = DateTime.now();
      
      debugPrint('PedometerService: Received step event - steps: ${event.steps}');
      
      // Check if it's a new day
      if (_lastStepDate == null || 
          _lastStepDate!.year != today.year || 
          _lastStepDate!.month != today.month || 
          _lastStepDate!.day != today.day) {
        debugPrint('PedometerService: New day detected, resetting steps');
        _todaySteps = event.steps;
        _lastStepDate = today;
      } else {
        // Update step count (pedometer gives absolute count from device boot)
        _todaySteps = event.steps;
      }

      debugPrint('PedometerService: Updated step count to: $_todaySteps');
      
      // Save to local storage
      _saveSteps();
      
      // Sync to backend every 100 steps to avoid too many API calls
      if (_todaySteps > 0 && _todaySteps % 100 == 0) {
        debugPrint('PedometerService: Syncing to backend at $_todaySteps steps');
        syncStepsToBackend();
      }
    } catch (e) {
      debugPrint('PedometerService: Error processing step update: $e');
    }
  }

  /// Save current step count to local storage
  Future<void> _saveSteps() async {
    try {
      await _storage.saveTodaySteps(_todaySteps);
      await _storage.saveLastStepsDate(DateTime.now());
    } catch (e) {
      debugPrint('PedometerService: Error saving steps: $e');
    }
  }

  /// Sync today's steps to the backend
  Future<bool> syncStepsToBackend() async {
    try {
      debugPrint('PedometerService: Syncing steps to backend: $_todaySteps');
      
      final token = await _storage.getToken();
      final profileId = await _storage.getActiveProfileId();
      
      if (token == null || profileId == null) {
        debugPrint('PedometerService: No token or profile ID, skipping sync');
        return false;
      }

      final readingService = HealthReadingService();
      
      // Create a steps reading
      await readingService.saveStepsReading(
        token: token,
        profileId: profileId,
        stepsCount: _todaySteps,
        stepsGoal: _stepsGoal,
      );

      debugPrint('PedometerService: Steps synced successfully');
      return true;
    } catch (e) {
      debugPrint('PedometerService: Error syncing steps: $e');
      return false;
    }
  }

  /// Manually update step count (for testing or manual entry)
  void updateStepCount(int count) {
    _todaySteps = count;
    _saveSteps();
    debugPrint('PedometerService: Manual step update: $_todaySteps');
  }
}
