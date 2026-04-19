import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../services/chat_service.dart';
import '../services/error_mapper.dart';
import '../services/health_reading_service.dart';
import '../services/storage_service.dart';

class ChatScreen extends StatefulWidget {
  final int profileId;
  final String? initialMessage;

  const ChatScreen({super.key, required this.profileId, this.initialMessage});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final StorageService _storageService = StorageService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  int _remainingQuota = 5;
  String _resetsAt = '';
  bool _isLoading = true;
  bool _isSending = false;
  PlatformFile? _selectedImage;

  // Header vitals
  String _profileName = '';
  String _lastBp = '--';
  String _lastSugar = '--';
  bool _canEdit = true;

  @override
  void initState() {
    super.initState();
    _loadAccessLevel();
    _loadMessages().then((_) {
      // Send initial message if provided (from "Discuss with AI" button)
      if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
        _sendMessage(imageDescription: widget.initialMessage);
      }
    });
    _loadVitals();
  }

  Future<void> _loadAccessLevel() async {
    final level = await _storageService.getActiveProfileAccessLevel();
    if (mounted) setState(() => _canEdit = level != 'viewer');
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadVitals() async {
    try {
      final token = await _storageService.getToken();
      if (token == null) return;
      final data = await HealthReadingService().getHealthScore(
        token,
        widget.profileId,
      );
      setState(() {
        final sys = (data['last_bp_systolic'] as num?)?.toDouble();
        final dia = (data['last_bp_diastolic'] as num?)?.toDouble();
        _lastBp = sys != null && dia != null
            ? '${sys.toStringAsFixed(0)}/${dia.toStringAsFixed(0)}'
            : '--';
        final glucose = (data['last_glucose_value'] as num?)?.toDouble();
        _lastSugar = glucose != null
            ? '${glucose.toStringAsFixed(0)} mg/dL'
            : '--';
        _profileName = data['profile_name'] as String? ?? '';
      });
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    try {
      final token = await _storageService.getToken();
      if (token == null) return;
      final data = await _chatService.getMessages(token, widget.profileId);
      final quota = data['quota'] as Map<String, dynamic>? ?? {};
      setState(() {
        _messages = List<Map<String, dynamic>>.from(data['messages'] ?? []);
        _remainingQuota = (quota['remaining'] as num?)?.toInt() ?? 5;
        _resetsAt = quota['resets_at'] as String? ?? '';
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _selectedImage = result.files.first);
      }
    } catch (e) {
      if (mounted) {
        await ErrorMapper.showSnack(context, e);
      }
    }
  }

  Future<void> _sendMessage({String? imageDescription}) async {
    final text = imageDescription ?? _inputController.text.trim();
    final imageFile = _selectedImage;

    if (text.isEmpty && imageFile == null) return;
    if (_isSending || _remainingQuota <= 0) return;

    if (imageDescription == null) _inputController.clear();
    final displayText = text.isNotEmpty ? text : 'Analyzing uploaded image...';

    setState(() {
      _messages.add({
        'user_message': displayText,
        'ai_response': null,
        'created_at': DateTime.now().toIso8601String(),
      });
      _isSending = true;
      _selectedImage = null;
    });
    _scrollToBottom();

    try {
      final token = await _storageService.getToken();
      if (token == null) return;

      Map<String, dynamic> response;
      if (imageFile != null) {
        final bytes =
            imageFile.bytes ??
            ((!kIsWeb && imageFile.path != null)
                ? await File(imageFile.path!).readAsBytes()
                : null);
        if (bytes != null) {
          final base64Str = base64Encode(bytes);
          final msg = text.isNotEmpty ? text : 'Please analyze this image';
          response = await _chatService.sendImageMessage(
            token,
            widget.profileId,
            msg,
            base64Str,
          );
        } else {
          response = await _chatService.sendMessage(
            token,
            widget.profileId,
            text,
          );
        }
      } else {
        response = await _chatService.sendMessage(
          token,
          widget.profileId,
          text,
        );
      }

      if (response.containsKey('error') &&
          response['error'] == 'quota_exceeded') {
        setState(() {
          _messages.last['ai_response'] =
              response['message'] ?? 'Quota exceeded.';
          _remainingQuota = 0;
          _resetsAt = response['resets_at'] ?? '';
          _isSending = false;
        });
        return;
      }

      setState(() {
        _messages.last['ai_response'] = response['ai_response'];
        _remainingQuota =
            (response['remaining_quota'] as num?)?.toInt() ??
            _remainingQuota - 1;
        _resetsAt = response['resets_at'] as String? ?? _resetsAt;
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.last['ai_response'] =
            'Failed to get response. Please try again.';
        _isSending = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // --- Compact vitals bar ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.health_and_safety,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.chatTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  _VitalChip(label: 'BP', value: _lastBp),
                  const SizedBox(width: 6),
                  _VitalChip(label: 'Sugar', value: _lastSugar),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.separator),

            // --- Messages ---
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.health_and_safety,
                              size: 48,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.chatEmptyState,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        return _MessageBubble(
                          userMessage: msg['user_message'] as String? ?? '',
                          aiResponse: msg['ai_response'] as String?,
                          isTyping:
                              msg['ai_response'] == null &&
                              index == _messages.length - 1 &&
                              _isSending,
                        );
                      },
                    ),
            ),

            // --- Quota indicator ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                _remainingQuota > 0
                    ? '$_remainingQuota ${l10n.chatQuotaRemaining}'
                    : l10n.chatQuotaExceeded,
                style: TextStyle(
                  fontSize: 11,
                  color: _remainingQuota > 0
                      ? AppColors.textSecondary
                      : AppColors.statusCritical,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // --- Image preview (if selected) ---
            if (_selectedImage != null && _canEdit)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _selectedImage!.bytes != null
                          ? Image.memory(
                              _selectedImage!.bytes!,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            )
                          : const SizedBox(
                              width: 60,
                              height: 60,
                              child: Icon(Icons.image, size: 30),
                            ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Image ready to send',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _selectedImage = null),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

            // --- Input bar (hidden for viewers) ---
            if (_canEdit)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: GlassCard(
                  borderRadius: 28,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      // Attachment button
                      GestureDetector(
                        onTap: _remainingQuota > 0 && !_isSending
                            ? _pickImage
                            : null,
                        child: Icon(
                          Icons.attach_file,
                          color: _remainingQuota > 0
                              ? AppColors.textSecondary
                              : AppColors.textSecondary.withValues(alpha: 0.4),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          key: const Key('chat_input'),
                          controller: _inputController,
                          enabled: _remainingQuota > 0 && !_isSending,
                          decoration: InputDecoration(
                            hintText: _remainingQuota > 0
                                ? l10n.chatPlaceholder
                                : l10n.chatQuotaExceeded,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        key: const Key('chat_send_button'),
                        onTap: _remainingQuota > 0 && !_isSending
                            ? () => _sendMessage()
                            : null,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _remainingQuota > 0
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.arrow_upward,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  'View-only access — you cannot send messages for this profile.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- Small vital chip for the header ---
class _VitalChip extends StatelessWidget {
  final String label;
  final String value;
  const _VitalChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Message bubble ---
class _MessageBubble extends StatelessWidget {
  final String userMessage;
  final String? aiResponse;
  final bool isTyping;

  const _MessageBubble({
    required this.userMessage,
    this.aiResponse,
    this.isTyping = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // User message — right aligned
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Text(
                userMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // AI response — left aligned
          if (isTyping)
            Align(
              alignment: Alignment.centerLeft,
              child: GlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDot(0),
                    const SizedBox(width: 4),
                    _buildDot(1),
                    const SizedBox(width: 4),
                    _buildDot(2),
                  ],
                ),
              ),
            )
          else if (aiResponse != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.85,
                ),
                child: GlassCard(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    aiResponse!,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 600 + index * 200),
      builder: (_, value, child) => Opacity(opacity: value, child: child),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
