import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../services/health_reading_service.dart';
import '../services/ocr_service.dart';
import '../services/storage_service.dart';
import '../services/error_mapper.dart';
import '../theme/app_theme.dart';
import 'reading_confirmation_screen.dart';

// Scan-screen color constants — all via AppColors.*. Project rule: no raw
// Colors.* inside widgets. Mirrors the pattern used by _CameraColors in
// food_photo_screen.dart so the two camera surfaces stay theme-aligned.
class _ScanColors {
  static const Color background = AppColors.cameraBackground;
  static const Color foreground = AppColors.cameraForeground;
  static const Color overlay = AppColors.cameraOverlay;
  static const Color overlayText = AppColors.cameraOverlayText;
  static const Color iconDisabled = AppColors.cameraIconDisabled;
  static const Color buttonBorder = AppColors.cameraButtonBorder;
  static const Color buttonEnabled = AppColors.cameraButtonEnabled;
  static const Color buttonDisabled = AppColors.cameraButtonDisabled;
  static const Color buttonIcon = AppColors.cameraButtonIcon;
  static const Color flashOn = AppColors.cameraFlashOn;
  static const Color guideAccent = AppColors.cameraGuideAccent;
  static const Color transparent = AppColors.transparent;
  // Painter needs a base black to apply alpha to for the dim layer.
  static const Color dimBase = AppColors.cameraBackground;
}

class PhotoScanScreen extends StatefulWidget {
  /// 'glucose' or 'blood_pressure'
  final String deviceType;
  final int profileId;

  const PhotoScanScreen({
    super.key,
    required this.deviceType,
    required this.profileId,
  });

  @override
  State<PhotoScanScreen> createState() => _PhotoScanScreenState();
}

class _PhotoScanScreenState extends State<PhotoScanScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isFlashOn = false;
  bool _isCapturing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      if (_cameras.isEmpty) {
        setState(() => _errorMessage = l10n.cameraNotFound);
        return;
      }
      final back = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      _controller = CameraController(
        back,
        ResolutionPreset.medium, // 1080p — sufficient for Gemini, avoids OOM on device
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _controller!.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (_) {
      // Never surface the raw exception — it leaks PlatformException
      // messages and stack frames to the user. The user only needs to
      // know to retry; engineering already has the crash report.
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() => _errorMessage = l10n.cameraError);
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    final next = _isFlashOn ? FlashMode.off : FlashMode.torch;
    await _controller!.setFlashMode(next);
    setState(() => _isFlashOn = !_isFlashOn);
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;

    // No internet check needed — local ML Kit OCR works offline

    setState(() => _isCapturing = true);

    final l10n = AppLocalizations.of(context)!;

    // Tracks whether the loading dialog is currently on the navigator
    // stack. We MUST NOT call Navigator.pop() blindly in the outer catch
    // — if the dialog was already dismissed (inner catch, or success
    // path) pop() would walk one route up and dismiss the camera screen
    // itself. canPop() is not enough either: it returns true whenever
    // there's a parent route (home screen). The flag is the only safe
    // signal for "is the loading dialog still showing?".
    bool loadingShown = false;
    void dismissLoadingIfShown() {
      if (loadingShown && mounted) {
        Navigator.of(context).pop();
        loadingShown = false;
      }
    }

    try {
      if (_isFlashOn) await _controller!.setFlashMode(FlashMode.auto);

      final XFile xfile = await _controller!.takePicture();
      final imageBytes = await xfile.readAsBytes();

      if (!mounted) return;

      loadingShown = true;
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
                  Text(l10n.readingImage),
                ],
              ),
            ),
          ),
        ),
      );

      // Try Gemini Vision via backend (uses fallback chain: Gemini → DeepSeek)
      // ML Kit local OCR disabled on iOS due to arm64 crash on iOS 26.
      OcrResult? result;
      try {
        final token = await StorageService().getToken();
        if (token != null) {
          result = await HealthReadingService().parseImageWithGemini(
            imageBytes,
            xfile.name,
            widget.deviceType,
            token,
          );
        }
      } catch (e) {
        dismissLoadingIfShown();
        if (mounted) {
          final message = ErrorMapper.userMessage(l10n, e);
          _showError(
            title: l10n.error,
            message: message,
          );
        }
        return;
      }

      dismissLoadingIfShown();

      if (!mounted) return;

      if (result == null) {
        _showError(
          title: l10n.scanCouldNotReadTitle,
          message: l10n.scanCouldNotReadMessage,
        );
        setState(() => _isCapturing = false);
        return;
      }

      if (!result.hasValue) {
        // Em-dash is locale-neutral punctuation; avoids hardcoding "no text"
        // in English when the OCR returned an empty rawText.
        final detected = result.rawText.isNotEmpty ? result.rawText : '—';
        _showError(
          title: l10n.scanNumbersNotDetectedTitle,
          message: l10n.scanNumbersNotDetectedMessage(detected),
        );
        setState(() => _isCapturing = false);
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReadingConfirmationScreen(
            ocrResult: result,
            deviceType: widget.deviceType,
            profileId: widget.profileId,
          ),
        ),
      );
    } catch (e) {
      // Route through ErrorMapper instead of leaking the raw exception.
      // The previous string "Capture failed: $e" surfaced things like
      // "PlatformException(IOException, …)" to elderly users.
      //
      // Only dismiss the loading dialog if it is actually still showing;
      // a blind pop() here would dismiss the camera screen when the
      // failure happened before the dialog was shown (takePicture
      // throwing) or after it was already dismissed (success path
      // followed by an unrelated push failure).
      dismissLoadingIfShown();
      if (mounted) {
        await ErrorMapper.showSnack(context, e);
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  // _showBlurryError method removed - not currently used
  /*
  void _showBlurryError(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.photoBlurryTitle),
        content: Text(l10n.photoBlurryMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.tryAgain),
          ),
        ],
      ),
    );
  }
  */

  void _showError({required String title, required String message}) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.tryAgain),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReadingConfirmationScreen(
                    ocrResult: null,
                    deviceType: widget.deviceType,
                    profileId: widget.profileId,
                  ),
                ),
              );
            },
            child: Text(l10n.enterManually),
          ),
        ],
      ),
    );
  }

  // _showParseError removed — replaced by _showError with specific messages

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isGlucose = widget.deviceType == 'glucose';
    final isWeight = widget.deviceType == 'weight';
    final String deviceLabel;

    if (isGlucose) {
      deviceLabel = l10n.glucometer;
    } else if (isWeight) {
      deviceLabel = l10n.weightScale;
    } else {
      deviceLabel = l10n.bpMeter;
    }

    return Scaffold(
      backgroundColor: _ScanColors.background,
      appBar: AppBar(
        backgroundColor: _ScanColors.background,
        foregroundColor: _ScanColors.foreground,
        title: Text(l10n.scanTitle(deviceLabel)),
        actions: [
          IconButton(
            icon: Icon(
              _isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: _isFlashOn ? _ScanColors.flashOn : _ScanColors.foreground,
            ),
            tooltip: l10n.toggleFlash,
            onPressed: _isInitialized ? _toggleFlash : null,
          ),
        ],
      ),
      body: _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt,
                        color: _ScanColors.iconDisabled, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: _ScanColors.overlayText),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : !_isInitialized
              ? const Center(
                  child: CircularProgressIndicator(
                      color: _ScanColors.foreground))
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(_controller!),
                    _GuideOverlay(deviceType: widget.deviceType),

                    // Top instruction label
                    Positioned(
                      top: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _ScanColors.overlay,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            l10n.placeDeviceInBox(deviceLabel),
                            style: const TextStyle(
                                color: _ScanColors.foreground, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),

                    // Bottom capture button
                    Positioned(
                      bottom: 40,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: _isCapturing ? null : _capture,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: _ScanColors.buttonBorder, width: 4),
                              color: _isCapturing
                                  ? _ScanColors.buttonDisabled
                                  : _ScanColors.buttonEnabled,
                            ),
                            child: _isCapturing
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(strokeWidth: 3),
                                  )
                                : const Icon(Icons.camera_alt,
                                    size: 32, color: _ScanColors.buttonIcon),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

/// Custom overlay that dims the edges and shows a clear guide rectangle.
class _GuideOverlay extends StatelessWidget {
  final String deviceType;

  const _GuideOverlay({required this.deviceType});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GuidePainter(),
    );
  }
}

class _GuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()
      ..color = _ScanColors.dimBase.withValues(alpha: 0.5);
    final clearPaint = Paint()
      ..color = _ScanColors.transparent
      ..blendMode = BlendMode.clear;
    final borderPaint = Paint()
      ..color = _ScanColors.foreground
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final cornerPaint = Paint()
      ..color = _ScanColors.guideAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final boxW = size.width * 0.8;
    final boxH = size.height * 0.4;
    final left = (size.width - boxW) / 2;
    final top = (size.height - boxH) / 2;
    final rect = Rect.fromLTWH(left, top, boxW, boxH);

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), dimPaint);
    canvas.drawRect(rect, clearPaint);
    canvas.restore();

    canvas.drawRect(rect, borderPaint);

    const cornerLen = 24.0;
    canvas.drawLine(Offset(left, top + cornerLen), Offset(left, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLen, top), cornerPaint);
    canvas.drawLine(Offset(left + boxW - cornerLen, top), Offset(left + boxW, top), cornerPaint);
    canvas.drawLine(Offset(left + boxW, top), Offset(left + boxW, top + cornerLen), cornerPaint);
    canvas.drawLine(Offset(left, top + boxH - cornerLen), Offset(left, top + boxH), cornerPaint);
    canvas.drawLine(Offset(left, top + boxH), Offset(left + cornerLen, top + boxH), cornerPaint);
    canvas.drawLine(Offset(left + boxW - cornerLen, top + boxH), Offset(left + boxW, top + boxH), cornerPaint);
    canvas.drawLine(Offset(left + boxW, top + boxH), Offset(left + boxW, top + boxH - cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(_GuidePainter oldDelegate) => false;
}
