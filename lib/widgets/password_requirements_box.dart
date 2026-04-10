import 'package:flutter/material.dart';
// ignore_for_file: deprecated_member_use
import 'package:swasth_app/l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// Live password-requirements checklist shown under a password field.
///
/// Each row renders a check/cancel icon plus the requirement text from
/// AppLocalizations. As the user types, the parent screen passes in
/// the current password and this widget re-evaluates the five rules:
/// min length, uppercase, lowercase, digit, special character.
///
/// Used by `registration_screen.dart` (patient signup) and
/// `doctor_registration_screen.dart` (doctor signup). Keeping the rules
/// in one widget prevents the two screens from drifting apart as
/// passwords strength evolves.
class PasswordRequirementsBox extends StatelessWidget {
  final String password;

  const PasswordRequirementsBox({super.key, required this.password});

  // Central rule set — mirrors _validate_password_strength in
  // backend/schemas.py so client-side hints match server-side rejects.
  static const String _specialChars = '!@#\$%^&*(),.?":{}|<>';

  // Static checkers exposed so screen-level form validators can call
  // `PasswordRequirementsBox.meetsAllRequirements(value)` without
  // duplicating the rule set.
  static bool hasMinLength(String p) => p.length >= 8;
  static bool hasUppercase(String p) => p.contains(RegExp(r'[A-Z]'));
  static bool hasLowercase(String p) => p.contains(RegExp(r'[a-z]'));
  static bool hasNumber(String p) => p.contains(RegExp(r'[0-9]'));
  static bool hasSpecialChar(String p) =>
      RegExp('[${RegExp.escape(_specialChars)}]').hasMatch(p);

  static bool meetsAllRequirements(String p) =>
      hasMinLength(p) &&
      hasUppercase(p) &&
      hasLowercase(p) &&
      hasNumber(p) &&
      hasSpecialChar(p);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.passwordRequirementsTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _RequirementRow(
            text: l10n.passwordReqLength,
            isMet: hasMinLength(password),
          ),
          _RequirementRow(
            text: l10n.passwordReqUppercase,
            isMet: hasUppercase(password),
          ),
          _RequirementRow(
            text: l10n.passwordReqLowercase,
            isMet: hasLowercase(password),
          ),
          _RequirementRow(
            text: l10n.passwordReqNumber,
            isMet: hasNumber(password),
          ),
          _RequirementRow(
            text: l10n.passwordReqSpecial,
            isMet: hasSpecialChar(password),
          ),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final String text;
  final bool isMet;

  const _RequirementRow({required this.text, required this.isMet});

  @override
  Widget build(BuildContext context) {
    final color = isMet ? AppColors.statusNormal : AppColors.statusCritical;
    return Row(
      children: [
        Icon(isMet ? Icons.check_circle : Icons.cancel, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            // 14sp minimum for elderly users — Healthify accessibility floor.
            style: TextStyle(color: color, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
