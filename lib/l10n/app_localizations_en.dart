// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Swasth Health App';

  @override
  String get appName => 'Swasth';

  @override
  String get loading => 'Loading...';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get accept => 'Accept';

  @override
  String get reject => 'Reject';

  @override
  String get invite => 'Invite';

  @override
  String get revoke => 'Revoke';

  @override
  String get connect => 'Connect';

  @override
  String get refresh => 'Refresh';

  @override
  String get logout => 'Logout';

  @override
  String get profile => 'Profile';

  @override
  String get error => 'Error';

  @override
  String get loginTitle => 'Login';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get rememberMe => 'Remember me';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get loginButton => 'Login';

  @override
  String get noAccount => 'Don\'t have an account?';

  @override
  String get register => 'Register';

  @override
  String get loginSuccessful => 'Login successful!';

  @override
  String get emailValidationEmpty => 'Please enter your email';

  @override
  String get emailValidationInvalid => 'Please enter a valid email';

  @override
  String get passwordValidationEmpty => 'Please enter your password';

  @override
  String get registerTitle => 'Register';

  @override
  String get accountDetailsSection => 'Account Details';

  @override
  String get healthProfileSection => 'Initial Health Profile';

  @override
  String get fullNameLabel => 'Full Name';

  @override
  String get phoneLabel => 'Phone Number';

  @override
  String get confirmPasswordLabel => 'Confirm Password';

  @override
  String get profileNameLabel => 'Profile Name';

  @override
  String get ageLabel => 'Age';

  @override
  String get genderLabel => 'Gender';

  @override
  String get heightLabel => 'Height (cm)';

  @override
  String get bloodGroupLabel => 'Blood Group';

  @override
  String get medicationsLabel => 'Current Medications (optional)';

  @override
  String get medicalConditionsSection => 'Medical Conditions';

  @override
  String get passwordRequirementsTitle => 'Password Requirements:';

  @override
  String get passwordReqLength => 'At least 8 characters';

  @override
  String get passwordReqUppercase => 'One uppercase letter';

  @override
  String get passwordReqLowercase => 'One lowercase letter';

  @override
  String get passwordReqNumber => 'One number';

  @override
  String get passwordReqSpecial => 'One special character';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get registerSuccessful => 'Registration successful! Please login.';

  @override
  String get specifyOtherCondition => 'Please specify other condition';

  @override
  String get selectProfileTitle => 'Select Profile';

  @override
  String get myProfilesSection => 'My Profiles';

  @override
  String get sharedWithMeSection => 'Shared With Me';

  @override
  String get noSharedProfiles => 'No shared profiles yet.';

  @override
  String get addProfile => 'Add Profile';

  @override
  String pendingInvitesBanner(int count) {
    return 'You have $count pending invites';
  }

  @override
  String get homeTitle => 'Swasth Health App';

  @override
  String viewingProfile(String name) {
    return 'Viewing: $name\'s Health';
  }

  @override
  String get switchProfile => 'Switch';

  @override
  String get shareProfile => 'Share Profile';

  @override
  String get welcomeTitle => 'Welcome to Swasth!';

  @override
  String get welcomeSubtitle => 'Your health monitoring companion';

  @override
  String get selectDevice => 'Select Device';

  @override
  String get recordNewMetrics => 'Record New Metrics';

  @override
  String get flagFitFine => 'Fit & Fine';

  @override
  String get flagCaution => 'Caution';

  @override
  String get flagAtRisk => 'At Risk';

  @override
  String get flagUrgent => 'Urgent';

  @override
  String get weeklyWinnersTitle => 'Top this week';

  @override
  String get weeklyWinnersSoon => 'coming soon';

  @override
  String pointsLabel(int pts) {
    return '$pts pts';
  }

  @override
  String get glucometer => 'Glucometer';

  @override
  String get bpMeter => 'BP Meter';

  @override
  String get armband => 'Armband';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get connectNewDevice => 'Connect New Device';

  @override
  String get connectNewDeviceSubtitle => 'Scan and pair Bluetooth devices';

  @override
  String get viewHistory => 'View History';

  @override
  String get viewHistorySubtitle => 'Check your past readings';

  @override
  String get selectProfileFirst => 'Please select a profile first';

  @override
  String logReading(String device) {
    return 'Log $device Reading';
  }

  @override
  String get howToLog => 'How would you like to log this reading?';

  @override
  String get healthTrends => 'Health Trends';

  @override
  String get sevenDays => '7 Days';

  @override
  String get thirtyDays => '30 Days';

  @override
  String get ninetyDays => '90 Days';

  @override
  String get oneYear => '1 Year';

  @override
  String get glucoseTrend => 'Glucose Trend';

  @override
  String get bpTrend => 'Blood Pressure Trend';

  @override
  String get avgLabel => 'Avg';

  @override
  String get minLabel => 'Min';

  @override
  String get maxLabel => 'Max';

  @override
  String get normalPct => 'Normal';

  @override
  String get noChartData => 'No readings in this period';

  @override
  String get tapToViewTrends => 'Tap to view trends →';

  @override
  String get viewTrends => 'View Trends';

  @override
  String get viewTrendsSubtitle => '7 and 30-day glucose & BP charts';

  @override
  String get healthScore => 'Health Score';

  @override
  String dayStreak(int n) {
    return '$n-day streak';
  }

  @override
  String lastLogged(String time) {
    return 'Last logged: $time';
  }

  @override
  String get noReadingsYetScore => 'Log your first reading to see your score';

  @override
  String get todayGlucose => 'Glucose';

  @override
  String get todayBP => 'BP';

  @override
  String get scanWithCamera => 'Scan with Camera';

  @override
  String get connectViaBluetooth => 'Connect via Bluetooth';

  @override
  String get enterManually => 'Enter Manually';

  @override
  String scanTitle(String device) {
    return 'Scan $device';
  }

  @override
  String placeDeviceInBox(String device) {
    return 'Place $device screen inside the box';
  }

  @override
  String get toggleFlash => 'Toggle Flash';

  @override
  String get photoBlurryTitle => 'Photo is too blurry';

  @override
  String get photoBlurryMessage =>
      'We couldn\'t read the display. Please retake the photo with:\n\n• Camera steady (no shake)\n• Device screen centered in the guide box\n• Good lighting or flash on';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get readingImage => 'Reading the image...';

  @override
  String get glucoseReadingTitle => 'Glucose Reading';

  @override
  String get bpReadingTitle => 'BP Reading';

  @override
  String get glucoseValueLabel => 'Glucose Value';

  @override
  String get systolicLabel => 'Systolic';

  @override
  String get diastolicLabel => 'Diastolic';

  @override
  String get pulseLabel => 'Pulse (optional)';

  @override
  String get mealContextSection => 'Meal Context';

  @override
  String get fasting => 'Fasting';

  @override
  String get beforeMeal => 'Before Meal';

  @override
  String get afterMeal => 'After Meal';

  @override
  String get readingTime => 'Reading Time';

  @override
  String get saveReading => 'Save Reading';

  @override
  String get readingSavedSuccess => 'Reading saved successfully';

  @override
  String get ocrSuccessPrefix => 'We read:';

  @override
  String get ocrEditButton => 'Edit';

  @override
  String get ocrConfirmHint =>
      'Is this correct? You can edit above before saving.';

  @override
  String get ocrFailedMessage =>
      'Couldn\'t read the value from the photo. Please enter it manually below.';

  @override
  String get manualEntryHint => 'Enter the value shown on your device.';

  @override
  String get glucoseValidation => 'Enter a valid glucose value (20–600 mg/dL)';

  @override
  String get systolicValidation => 'Enter a valid systolic value (60–250 mmHg)';

  @override
  String get diastolicValidation =>
      'Enter a valid diastolic value (40–150 mmHg)';

  @override
  String saveFailed(String error) {
    return 'Failed to save: $error';
  }

  @override
  String get historyTitle => 'Reading History';

  @override
  String get filterByType => 'Filter by type';

  @override
  String get allReadings => 'All Readings';

  @override
  String get glucoseOnly => 'Glucose Only';

  @override
  String get bpOnly => 'BP Only';

  @override
  String get noReadingsYet => 'No readings yet';

  @override
  String get noReadingsSubtitle =>
      'Connect a device and take a measurement\nto see your reading history here';

  @override
  String get deleteReading => 'Delete Reading';

  @override
  String get deleteReadingConfirm =>
      'Are you sure you want to delete this reading?';

  @override
  String get readingDeleted => 'Reading deleted';

  @override
  String get statusNormal => 'Normal';

  @override
  String get statusElevated => 'Elevated';

  @override
  String get statusHighStage1 => 'High - Stage 1';

  @override
  String get statusHighStage2 => 'High - Stage 2';

  @override
  String get statusLow => 'Low';

  @override
  String get statusCritical => 'Critical';

  @override
  String get profileDetailsTitle => 'Profile Details';

  @override
  String get manageAccess => 'Manage Access';

  @override
  String get yourProfile => 'Your Profile';

  @override
  String get sharedBySomeone => 'Shared by Someone';

  @override
  String get healthInfoSection => 'Health Information';

  @override
  String get ageField => 'Age';

  @override
  String ageYears(String age) {
    return '$age years';
  }

  @override
  String get genderField => 'Gender';

  @override
  String get bloodGroupField => 'Blood Group';

  @override
  String get heightField => 'Height';

  @override
  String heightCm(String height) {
    return '$height cm';
  }

  @override
  String get medicalConditionsField => 'Conditions';

  @override
  String get accountSettingsSection => 'Account Settings';

  @override
  String get linkedEmail => 'Linked Email';

  @override
  String get changePassword => 'Change Account Password';

  @override
  String get changePasswordTitle => 'Change Password';

  @override
  String get currentPasswordLabel => 'Current Password';

  @override
  String get newPasswordLabel => 'New Password';

  @override
  String get confirmNewPasswordLabel => 'Confirm New Password';

  @override
  String get passwordMinChars => 'Min. 6 characters';

  @override
  String get passwordChanged => 'Password changed!';

  @override
  String get enterCurrentPassword => 'Enter current password';

  @override
  String get passwordTooShort => 'Min 6 characters';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get appLanguageSection => 'App Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'हिंदी';

  @override
  String get myDoctorTitle => 'My Doctor';

  @override
  String get contactOnWhatsApp => 'Contact on WhatsApp';

  @override
  String get doctorDetailsSection => 'Doctor Details';

  @override
  String get doctorNameField => 'Doctor Name';

  @override
  String get doctorSpecialtyField => 'Specialty';

  @override
  String get doctorWhatsappField => 'WhatsApp Number';

  @override
  String get noDoctorLinked => 'No doctor linked yet.';

  @override
  String get addDoctor => 'Add Doctor';

  @override
  String get editDoctor => 'Edit Doctor Details';

  @override
  String get editDoctorTitle => 'Doctor Details';

  @override
  String get doctorWhatsappHint => 'e.g. +917001234567';

  @override
  String get addHealthProfileTitle => 'Add Health Profile';

  @override
  String get createProfileSubtitle =>
      'Create a profile for someone you care for (e.g. parents, child)';

  @override
  String get profileNameHint => 'e.g. Papa, Mummy';

  @override
  String get createProfile => 'Create Profile';

  @override
  String get manageAccessTitle => 'Manage Access';

  @override
  String get inviteSomeoneTitle => 'Invite someone to view this profile';

  @override
  String get enterEmailHint => 'Enter email address';

  @override
  String get notSharedYet => 'Not shared with anyone yet.';

  @override
  String get inviteSentSuccess => 'Invite sent successfully';

  @override
  String get revokeAccessTitle => 'Revoke Access?';

  @override
  String revokeAccessConfirm(String name) {
    return 'Are you sure you want to stop sharing this profile with $name?';
  }

  @override
  String get pendingInvitesTitle => 'Pending Invites';

  @override
  String get noPendingInvites => 'No pending invites.';

  @override
  String wantsToShare(String profileName) {
    return 'wants to share \"$profileName\"';
  }

  @override
  String expiresInDays(int days, String date) {
    return 'Expires in $days days ($date)';
  }

  @override
  String acceptedInvite(String profileName) {
    return 'Accepted invite for $profileName';
  }

  @override
  String rejectedInvite(String profileName) {
    return 'Rejected invite for $profileName';
  }

  @override
  String get scanDevicesTitle => 'Swasth — Scan Devices';

  @override
  String get pressScanToFind => 'Press Scan to find your device';

  @override
  String get scanButton => 'Scan';

  @override
  String get scanningButton => 'Scanning...';

  @override
  String get noDevicesFound => 'No devices found yet';

  @override
  String get lookingForDevices => 'Looking for devices...';

  @override
  String get noDevicesFoundAfterScan =>
      'No devices found. Make sure device is powered on.';

  @override
  String get connectButton => 'Connect';

  @override
  String get forgotPasswordTitle => 'Forgot Password';

  @override
  String get forgotPasswordHeadline => 'Forgot Password?';

  @override
  String get forgotPasswordSubtitle =>
      'Enter your email address and we\'ll send you an OTP to reset your password.';

  @override
  String get sendOtp => 'Send OTP';

  @override
  String get otpSentSuccess => 'OTP sent successfully! Check your email.';

  @override
  String get rememberPassword => 'Remember your password?';

  @override
  String get verifyOtpTitle => 'Verify OTP';

  @override
  String get enterOtpHeadline => 'Enter OTP';

  @override
  String otpSentTo(String email) {
    return 'We\'ve sent a 6-digit OTP to\n$email';
  }

  @override
  String get otpLabel => 'OTP';

  @override
  String get verifyOtp => 'Verify OTP';

  @override
  String get otpVerifiedSuccess => 'OTP verified successfully!';

  @override
  String get didNotReceiveOtp => 'Didn\'t receive OTP?';

  @override
  String resendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get resendOtp => 'Resend OTP';

  @override
  String get otpResent => 'OTP resent successfully! Check your email.';

  @override
  String get wantToGoBack => 'Want to go back?';

  @override
  String get resetPasswordTitle => 'Reset Password';

  @override
  String get createNewPasswordHeadline => 'Create New Password';

  @override
  String get createNewPasswordSubtitle =>
      'Your new password must be different from your old password.';

  @override
  String get resetPasswordButton => 'Reset Password';

  @override
  String get passwordResetSuccess => 'Password reset successfully!';

  @override
  String get wellnessScoreSection => 'Wellness Score';

  @override
  String get vitalSummarySection => 'Vital Summary';

  @override
  String get ninetyDayAvg => '90 Days Avg';

  @override
  String get aiInsightSection => 'AI Health Insight';

  @override
  String get primaryPhysicianSection => 'Primary Physician';

  @override
  String get individualMetricsSection => 'Individual Metrics';

  @override
  String get footerDisclaimer =>
      'Not a medical diagnosis. Consult your doctor for clinical advice. All AI insights are for informational purposes.';

  @override
  String get goodMorning => 'Good morning,';

  @override
  String get goodAfternoon => 'Good afternoon,';

  @override
  String get goodEvening => 'Good evening,';

  @override
  String get hello => 'Hello,';

  @override
  String get trendStable => 'Stable';

  @override
  String get optimumRange => 'Optimum Range';

  @override
  String get physicianConnected => 'Connected';

  @override
  String get physicianNotLinked => 'Not Linked';

  @override
  String get activeSync => 'Active Sync';

  @override
  String get notConnected => 'Not Connected';

  @override
  String get lastBP => 'Last BP';

  @override
  String get lastSugar => 'Last Sugar';

  @override
  String get liveSteps => 'Live Steps';

  @override
  String get offlineBanner => 'You are offline. Some features may be limited.';

  @override
  String get loggedInOffline => 'Logged in offline';

  @override
  String get readingSavedOffline =>
      'Reading saved offline. Will sync when connected.';

  @override
  String syncComplete(int count) {
    return 'Synced $count readings';
  }

  @override
  String get offlineLoginExpired => 'Please connect to the internet to log in';
}
