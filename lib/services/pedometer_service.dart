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

  final StorageService _storage = StorageService();
  
  Stream<StepCount>? _stepCountStream;
  StreamSubscription<StepCount>? _stepSubscription;
  
  int _todaySteps = 0;
  int _stepsGoal = 7500; // Default daily goal
  DateTime? _lastStepDate;
  int _baselineSteps = 0; // Steps count at the start of today
  
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
      
      // Force an initial sync to backend after receiving first step event
      Future.delayed(const Duration(seconds: 3), () {
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
      final savedBaseline = await _storage.getBaselineSteps();

      // If it's a new day, reset step count and capture new baseline
      if (savedDate == null || 
          savedDate.year != today.year || 
          savedDate.month != today.month || 
          savedDate.day != today.day) {
        _todaySteps = 0;
        _lastStepDate = today;
        // We'll set baseline when we get the first step event
        _baselineSteps = 0;
        debugPrint('PedometerService: New day, resetting steps to 0');
      } else {
        _todaySteps = savedSteps ?? 0;
        _baselineSteps = savedBaseline ?? 0;
        _lastStepDate = savedDate;
        debugPrint('PedometerService: Loaded saved steps: $_todaySteps, baseline: $_baselineSteps');
      }

      // Load steps goal
      final savedGoal = await _storage.getStepsGoal();
      if (savedGoal != null && savedGoal > 0) {
        _stepsGoal = savedGoal;
      }
    } catch (e) {
      debugPrint('PedometerService: Error loading steps: $e');
      _todaySteps = 0;
      _baselineSteps = 0;
    }
  }

  /// Handle step count updates from the pedometer sensor
  void _onStepCountUpdate(StepCount event) {
    try {
      final today = DateTime.now();
      
      // Check if it's a new day
      if (_lastStepDate == null || 
          _lastStepDate!.year != today.year || 
          _lastStepDate!.month != today.month || 
          _lastStepDate!.day != today.day) {
        debugPrint('PedometerService: New day detected, resetting steps');
        _baselineSteps = event.steps;
        _todaySteps = 0;
        _lastStepDate = today;
      } else {
        // Calculate today's steps by subtracting baseline from current absolute count
        if (_baselineSteps > 0) {
          _todaySteps = event.steps - _baselineSteps;
          // Ensure we don't get negative values (shouldn't happen but safety check)
          if (_todaySteps < 0) {
            debugPrint('PedometerService: Negative steps detected, resetting baseline');
            _baselineSteps = event.steps;
            _todaySteps = 0;
          }
        } else {
          // First event of the day - set this as baseline
          _baselineSteps = event.steps;
          _todaySteps = 0;
        }
      }
      
      // Save to local storage
      _saveSteps();
      
      // Sync to backend every 10 steps for more real-time updates
      if (_todaySteps > 0 && _todaySteps % 10 == 0) {
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
      await _storage.saveBaselineSteps(_baselineSteps);
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
