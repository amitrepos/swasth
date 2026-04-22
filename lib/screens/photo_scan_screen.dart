import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../services/health_reading_service.dart';
import '../services/ocr_service.dart';
import '../services/storage_service.dart';
import 'reading_confirmation_screen.dart';

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
      if (_cameras.isEmpty) {
        setState(() => _errorMessage = 'No camera found on this device.');
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
    } catch (e) {
      setState(() => _errorMessage = 'Camera error: $e');
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

    try {
      if (_isFlashOn) await _controller!.setFlashMode(FlashMode.auto);

      final XFile xfile = await _controller!.takePicture();
      final file = File(xfile.path);

      if (!mounted) return;

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
      final token = await StorageService().getToken();
      if (token != null) {
        result = await HealthReadingService().parseImageWithGemini(
          file,
          widget.deviceType,
          token,
        );
      }

      if (mounted) Navigator.of(context).pop();

      if (!mounted) return;

      if (result == null) {
        _showError(
          title: 'Could Not Read Display',
          message: 'Neither the on-device reader nor the AI could extract values from this photo.\n\n'
              'Try:\n'
              '  • Hold the phone steady and closer to the display\n'
              '  • Make sure the screen is lit and numbers are visible\n'
              '  • Avoid glare or shadows on the display',
        );
        setState(() => _isCapturing = false);
        return;
      }

      if (!result.hasValue) {
        _showError(
          title: 'Numbers Not Detected',
          message: 'The photo was captured but no valid reading was found.\n\n'
              'The camera detected: "${result.rawText.isNotEmpty ? result.rawText : 'no text'}"\n\n'
              'Try taking the photo again or enter the reading manually.',
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
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e')),
        );
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
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Try Again"),
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
            child: const Text("Enter Manually"),
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
      deviceLabel = 'Weight Scale';
    } else {
      deviceLabel = l10n.bpMeter;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l10n.scanTitle(deviceLabel)),
        actions: [
          IconButton(
            icon: Icon(
              _isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: _isFlashOn ? Colors.yellow : Colors.white,
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
                    const Icon(Icons.camera_alt, color: Colors.white54, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : !_isInitialized
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
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
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            l10n.placeDeviceInBox(deviceLabel),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
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
                              border: Border.all(color: Colors.white, width: 4),
                              color: _isCapturing ? Colors.grey : Colors.white,
                            ),
                            child: _isCapturing
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(strokeWidth: 3),
                                  )
                                : const Icon(Icons.camera_alt, size: 32, color: Colors.black87),
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
    final dimPaint = Paint()..color = Colors.black.withOpacity(0.5);
    final clearPaint = Paint()
      ..color = Colors.transparent
      ..blendMode = BlendMode.clear;
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final cornerPaint = Paint()
      ..color = Colors.greenAccent
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
