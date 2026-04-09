/// Feature flags for controlled rollout of new features.
///
/// Flip a flag to `true` to enable the feature during testing.
/// Remove the flag entirely once the feature is stable and shipped.
class FeatureFlags {
  /// When true AND viewing a shared profile (viewer/editor),
  /// shows the caregiver "Wellness Hub" dashboard instead of the
  /// standard patient dashboard.
  static bool caregiverDashboard = true;
}
