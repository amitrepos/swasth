import 'package:swasth_app/l10n/app_localizations.dart';

/// Canonical list of doctor specialty API keys recognised by the
/// Swasth backend.
///
/// **Important: keep in sync with `backend/schemas.py`'s
/// `DOCTOR_SPECIALTY_OPTIONS`.** The backend validates the wire value
/// against that list, so any specialty added here MUST also be added
/// there or registrations will be rejected with a 422.
///
/// These strings are stable identifiers — never translate them. Use
/// [doctorSpecialtyDisplayName] to render the localized label.
const List<String> doctorSpecialtyApiKeys = <String>[
  'General Physician',
  'Endocrinologist',
  'Cardiologist',
  'Diabetologist',
  'Internal Medicine',
  'Family Medicine',
  // Bihar-pilot specialties added per Dr. Rajesh's review of PR #100
  // (Phase 3 polish). BHMS / AYUSH are intentionally excluded until
  // legal signs off on telemedicine scope-of-practice for those.
  'Gynaecology',
  'Paediatrics',
  'General Surgery',
  'Other',
];

/// Returns the user-facing label for a specialty API key in the
/// current locale. Falls back to the API key itself if a translation
/// is missing — never returns null.
String doctorSpecialtyDisplayName(AppLocalizations l10n, String apiKey) {
  switch (apiKey) {
    case 'General Physician':
      return l10n.doctorSpecialtyGeneral;
    case 'Endocrinologist':
      return l10n.doctorSpecialtyEndocrinologist;
    case 'Cardiologist':
      return l10n.doctorSpecialtyCardiologist;
    case 'Diabetologist':
      return l10n.doctorSpecialtyDiabetologist;
    case 'Internal Medicine':
      return l10n.doctorSpecialtyInternal;
    case 'Family Medicine':
      return l10n.doctorSpecialtyFamily;
    case 'Gynaecology':
      return l10n.doctorSpecialtyGynaecology;
    case 'Paediatrics':
      return l10n.doctorSpecialtyPaediatrics;
    case 'General Surgery':
      return l10n.doctorSpecialtyGeneralSurgery;
    case 'Other':
      return l10n.doctorSpecialtyOther;
    default:
      return apiKey;
  }
}
