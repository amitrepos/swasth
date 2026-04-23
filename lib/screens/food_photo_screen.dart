import 'dart:async';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';

import '../models/nutrition_analysis_result.dart';
import '../services/meal_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/meal_type_detector.dart';
import 'meal_result_screen.dart';
import 'nutrition_result_screen.dart';

// Camera screen color constants
class _CameraColors {
  static const Color background = Colors.black;
  static const Color foreground = Colors.white;
  static const Color overlay = Colors.black54;
  static const Color overlayText = Colors.white70;
  static const Color iconDisabled = Colors.white54;
  static const Color buttonBorder = Colors.white;
  static const Color buttonEnabled = Colors.white;
  static const Color buttonDisabled = Colors.grey;
  static const Color buttonIcon = Colors.black87;
}

/// Food Photo Capture Screen — SECONDARY option for meal logging.
///
/// Patient takes a photo of food -> Gemini Vision classifies carb level ->
/// shows result with tip. On failure/timeout (5s), falls back to Quick Select.
class FoodPhotoScreen extends StatefulWidget {
  final int profileId;

  /// Called when Gemini fails or times out, so the parent can navigate
  /// to Quick Select instead.
  final VoidCallback? onFallbackToQuickSelect;

  const FoodPhotoScreen({
    super.key,
    required this.profileId,
    this.onFallbackToQuickSelect,
  });

  @override
  State<FoodPhotoScreen> createState() => _FoodPhotoScreenState();
}

class _FoodPhotoScreenState extends State<FoodPhotoScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No camera found on this device.');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _controller!.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _errorMessage = 'Camera error: $e');
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isProcessing)
      return;

    setState(() => _isProcessing = true);

    try {
      final XFile xfile = await _controller!.takePicture();
      await _classifyImage(xfile);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showFallbackSnackbar();
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null) return;

    setState(() => _isProcessing = true);
    final platformFile = result.files.single;
    final xfile = XFile.fromData(
      platformFile.bytes!,
      name: platformFile.name,
    );
    await _classifyImage(xfile);
  }

  Future<void> _classifyImage(XFile file) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    // Show loading dialog with cancel button for poor network conditions
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(l10n.nutritionAnalyzing),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // dismiss dialog
                    if (mounted) {
                      Navigator.of(context).pop(); // return to previous screen
                      widget.onFallbackToQuickSelect?.call();
                    }
                  },
                  child: Text(l10n.useQuickSelect),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final token = await StorageService().getToken();
      if (token == null) {
        if (mounted) Navigator.of(context).pop(); // dismiss dialog
        _showFallbackSnackbar();
        return;
      }

      // Detailed nutrition analysis (timeout handled in meal_service.dart)
      final nutritionResult = await MealService()
          .analyzeNutrition(widget.profileId, file, token);

      if (mounted) Navigator.of(context).pop(); // dismiss dialog
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NutritionResultScreen(
            profileId: widget.profileId,
            result: nutritionResult,
            mealType: _detectMealType(),
            onFallbackToQuickSelect: widget.onFallbackToQuickSelect,
          ),
        ),
      );
    } on TimeoutException {
      if (mounted) Navigator.of(context).pop(); // dismiss dialog
      _showFallbackSnackbar();
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // dismiss dialog
      String errorMsg = e.toString();
      // Clean up common exception prefixes
      if (errorMsg.contains('Exception: ')) {
        errorMsg = errorMsg.split('Exception: ').last;
      }
      _showFallbackSnackbar(message: errorMsg);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showFallbackSnackbar({String? message}) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? l10n.foodPhotoFailed),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: l10n.retry,
          onPressed: _capturePhoto,
        ),
      ),
    );
    // Navigate to quick select fallback
    if (widget.onFallbackToQuickSelect != null) {
      widget.onFallbackToQuickSelect!();
    } else {
      Navigator.of(context).pop();
    }
  }

  String _detectMealType() {
    return detectMealType();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: _CameraColors.background,
      appBar: AppBar(
        backgroundColor: _CameraColors.background,
        foregroundColor: _CameraColors.foreground,
        title: Text(l10n.foodPhotoTitle),
      ),
      body: _errorMessage != null
          ? _buildErrorState()
          : !_isInitialized
          ? const Center(child: CircularProgressIndicator(color: _CameraColors.foreground))
          : _buildCameraView(l10n),
    );
  }

  Widget _buildErrorState() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt, color: _CameraColors.iconDisabled, size: 64),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: _CameraColors.overlayText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Even without camera, allow gallery pick
            ElevatedButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library),
              label: Text(l10n.foodPhotoGallery),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: _CameraColors.foreground,
                minimumSize: const Size(200, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView(AppLocalizations l10n) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_controller!),

        // Overlay hint at top
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _CameraColors.overlay,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                l10n.foodPhotoHint,
                style: const TextStyle(color: _CameraColors.foreground, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),

        // Bottom controls: gallery + capture button
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Gallery button
              IconButton(
                onPressed: _isProcessing ? null : _pickFromGallery,
                icon: const Icon(
                  Icons.photo_library,
                  color: _CameraColors.foreground,
                  size: 32,
                ),
                tooltip: l10n.foodPhotoGallery,
              ),

              // Capture button
              GestureDetector(
                onTap: _isProcessing ? null : _capturePhoto,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _CameraColors.buttonBorder, width: 4),
                    color: _isProcessing ? _CameraColors.buttonDisabled : _CameraColors.buttonEnabled,
                  ),
                  child: _isProcessing
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : const Icon(
                          Icons.camera_alt,
                          size: 32,
                          color: _CameraColors.buttonIcon,
                        ),
                ),
              ),

              // Spacer to balance the row
              const SizedBox(width: 48),
            ],
          ),
        ),
      ],
    );
  }
}
