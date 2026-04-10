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
  String get phoneValidationEmpty => 'Please enter your phone number';

  @override
  String get phoneValidationDigits => 'Phone number can only contain digits';

  @override
  String get phoneValidationLength => 'Phone number must be 10-15 digits';

  @override
  String get confirmPasswordLabel => 'Confirm Password';

  @override
  String get profileNameLabel => 'Profile Name';

  @override
  String get relationshipLabel => 'Relationship to patient';

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
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get deleteAccount => 'Delete My Account';

  @override
  String get deleteAccountConfirmMessage =>
      'This will permanently delete your account, all health readings, profiles, and AI insights. This action cannot be undone.';

  @override
  String get deleteAccountConfirm => 'Delete Permanently';

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
  String get vitalsSection => 'Vitals';

  @override
  String get trendsSection => 'Trends';

  @override
  String get lastSpO2 => 'Last SpO2';

  @override
  String get lastSteps => 'Steps Today';

  @override
  String get spO2Unit => '%';

  @override
  String get viaArmband => 'via Armband';

  @override
  String get viaPhone => 'via Phone / Armband';

  @override
  String get pairDevice => 'Pair Device';

  @override
  String get connectedDevices => 'Connected Devices';

  @override
  String get readMore => 'Read more';

  @override
  String get mealSlotBreakfast => 'Breakfast';

  @override
  String get mealSlotLunch => 'Lunch';

  @override
  String get mealSlotSnack => 'Snack';

  @override
  String get mealSlotDinner => 'Dinner';

  @override
  String get mealSlotLogged => 'Logged';

  @override
  String get mealSlotTapToLog => 'Tap to log';

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
  String get relationshipFather => 'Father';

  @override
  String get relationshipMother => 'Mother';

  @override
  String get relationshipSpouse => 'Spouse';

  @override
  String get relationshipSon => 'Son';

  @override
  String get relationshipDaughter => 'Daughter';

  @override
  String get relationshipBrother => 'Brother';

  @override
  String get relationshipSister => 'Sister';

  @override
  String get relationshipUncle => 'Uncle';

  @override
  String get relationshipAunt => 'Aunt';

  @override
  String get relationshipFriend => 'Friend';

  @override
  String get relationshipOther => 'Other';

  @override
  String get consentTitle => 'Privacy & Consent';

  @override
  String get consentSubject => 'Consent for Health Data Processing';

  @override
  String get consentIntro => 'By using Swasth, I agree to the following:';

  @override
  String get consentDataCollectionTitle => 'Data Collection';

  @override
  String get consentDataCollection =>
      'I allow Swasth to store my blood glucose, blood pressure, and food photos.';

  @override
  String get consentFamilySharingTitle => 'Family Sharing';

  @override
  String get consentFamilySharing =>
      'I understand that if I share my profile, my designated family members (e.g., son/daughter) will see my health scores and receive alerts.';

  @override
  String get consentPurposeTitle => 'Purpose';

  @override
  String get consentPurpose =>
      'My data will be used to provide me with health insights and shared with my doctor for my treatment.';

  @override
  String get consentRightsTitle => 'My Rights';

  @override
  String get consentRights =>
      'I can withdraw my consent or ask to delete my data at any time through the app settings.';

  @override
  String get consentAiTitle => 'AI-Powered Insights';

  @override
  String get consentAiBody =>
      'Swasth uses third-party AI services (Google Gemini and DeepSeek) to generate personalised health recommendations. A summary of my health data (not raw readings) may be sent to these services. I can opt out at any time, and rule-based insights will be used instead.';

  @override
  String get consentAccept => 'I Accept';

  @override
  String get consentDecline => 'I Decline';

  @override
  String get consentDeclineTitle => 'Decline Consent?';

  @override
  String get consentDeclineMessage =>
      'You cannot use Swasth without accepting the privacy notice. Your registration will not be completed.';

  @override
  String get consentDeclineConfirm => 'Go Back';

  @override
  String get consentScrollToAccept => 'Scroll down to read the full notice';

  @override
  String get ppDataCollectionTitle => 'Data We Collect';

  @override
  String get ppDataCollection =>
      'Swasth collects: blood glucose readings, blood pressure readings, pulse rate, meal notes, profile information (name, age, gender, medical conditions, medications), and photos of medical devices for automated reading capture.';

  @override
  String get ppPurposeTitle => 'Purpose of Collection';

  @override
  String get ppPurpose =>
      'Your health data is used to: display trends and health scores, generate personalised health insights, share with your designated family members, and provide information to your doctor for treatment.';

  @override
  String get ppAiTitle => 'AI Processing';

  @override
  String get ppAi =>
      'Swasth uses third-party AI services — Google Gemini and DeepSeek — to generate health recommendations. A summarised version of your data (averages and ranges, not individual readings) is sent to these services. You can opt out of AI processing at any time; rule-based insights will be used instead.';

  @override
  String get ppSharingTitle => 'Data Sharing';

  @override
  String get ppSharing =>
      'Your data is shared only with: family members you explicitly invite, AI services (Google Gemini, DeepSeek) for health insights if you consent, and your doctor if you choose to share. We do not sell or share your data with advertisers or any other third parties.';

  @override
  String get ppSecurityTitle => 'Security Measures';

  @override
  String get ppSecurity =>
      'We protect your data with: AES-256 encryption for health readings stored in our database, bcrypt password hashing, JWT-based authentication with token expiration, TLS/HTTPS for all data in transit, and encrypted local storage on your device.';

  @override
  String get ppRetentionTitle => 'Data Retention';

  @override
  String get ppRetention =>
      'Your data is stored as long as your account is active. You may request deletion of all your data at any time through the app settings. Upon account deletion, all readings, profiles, AI logs, and personal information are permanently removed.';

  @override
  String get ppRightsTitle => 'Your Rights';

  @override
  String get ppRights =>
      'Under Indian data protection law (SPDI Rules 2011 and DPDP Act 2023), you have the right to: access your data, correct inaccuracies, withdraw consent, request deletion of your data, and file a grievance. To exercise these rights, use the in-app settings or contact us.';

  @override
  String get ppContactTitle => 'Contact';

  @override
  String get ppContact =>
      'For privacy-related questions or grievances, contact: support@swasth.app';

  @override
  String get chatTitle => 'Swasth AI';

  @override
  String get chatSubtitle => 'ONLINE & ANALYZING';

  @override
  String get chatPlaceholder => 'Ask about your health...';

  @override
  String get chatEmptyState =>
      'Ask me anything about your health readings, medications, diet, or lifestyle. I have access to your health data and past conversations.';

  @override
  String get chatQuotaRemaining => 'questions remaining today';

  @override
  String get chatQuotaExceeded =>
      'Daily question limit reached. Resets at midnight.';

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

  @override
  String get glucometerPrerequisites => 'Glucometer – Prerequisites:';

  @override
  String get heartStatusHealthy => 'You\'re doing great';

  @override
  String get heartStatusCaution => 'Monitor closely today';

  @override
  String get heartStatusUrgent => 'Call your doctor today';

  @override
  String get heartFaceHealthy => 'All is well';

  @override
  String get heartFaceCaution => 'Stay alert today';

  @override
  String get heartFaceUrgent => 'Need doctor\'s help';

  @override
  String get heartCallDoctor => 'Call your doctor now';

  @override
  String get quickSelectTitle => 'Log Meal';

  @override
  String get mealHighCarb => 'Heavy — Rice / Roti';

  @override
  String get mealLowCarb => 'Light — Sabzi / Dal';

  @override
  String get mealSweets => 'Sweets / Meetha';

  @override
  String get mealHighProtein => 'Protein — Egg / Paneer';

  @override
  String get mealModerateCarb => 'Mixed / Balanced';

  @override
  String get mealMoreOptions => 'More options';

  @override
  String get mealLessOptions => 'Less options';

  @override
  String get mealSavedSuccess => 'Meal logged!';

  @override
  String get mealTypeBreakfast => 'Breakfast';

  @override
  String get mealTypeLunch => 'Lunch';

  @override
  String get mealTypeSnack => 'Snack';

  @override
  String get mealTypeDinner => 'Dinner';

  @override
  String get mealDisclaimer => 'For general wellness, not medical advice';

  @override
  String get foodPhotoTitle => 'Take Food Photo';

  @override
  String get foodPhotoHint => 'Point camera at your food';

  @override
  String get foodPhotoGallery => 'Choose from Gallery';

  @override
  String get foodPhotoAnalyzing => 'Analyzing your food...';

  @override
  String get foodPhotoFailed =>
      'Could not classify food. Please select manually.';

  @override
  String get foodResultTitle => 'Meal Result';

  @override
  String get foodCategoryHighCarb => 'High Carb';

  @override
  String get foodCategoryModerateCarb => 'Moderate Carb';

  @override
  String get foodCategoryLowCarb => 'Low Carb';

  @override
  String get foodCategoryHighProtein => 'High Protein';

  @override
  String get foodCategorySweets => 'Sweets';

  @override
  String get foodMealTypeLabel => 'Meal Type';

  @override
  String get foodNotCorrectChange => 'Not correct? Change';

  @override
  String get foodDisclaimer => 'For general wellness, not medical advice';

  @override
  String get foodPhotoSaved => 'Meal saved!';

  @override
  String get foodPhotoSaveFailed => 'Could not save meal. Please try again.';

  @override
  String get mealsTileLabel => 'Meals';

  @override
  String mealsTodayCount(int count) {
    return '$count today';
  }

  @override
  String get todaysMeals => 'Today\'s Meals';

  @override
  String get noMealsToday => 'No meals logged today';

  @override
  String get tapToLogMeal => 'Tap to log';

  @override
  String get logMeal => 'Log Meal';

  @override
  String get logMealSubtitle => 'How would you like to log?';

  @override
  String get quickSelectOption => 'Quick Select';

  @override
  String get scanFoodPhotoOption => 'Scan Food Photo';

  @override
  String get photoAiHint => 'Photo lets AI detect carb level automatically';

  @override
  String wellnessHubTitle(String relationship) {
    return '$relationship\'s Wellness Hub';
  }

  @override
  String wellnessHubSubtitle(String name, String location) {
    return '$name | $location';
  }

  @override
  String caregiverStatusGreat(String relationship) {
    return 'Your $relationship is doing great today. Vitals are stable.';
  }

  @override
  String caregiverStatusCaution(String relationship) {
    return 'Your $relationship needs attention today. Check vitals.';
  }

  @override
  String caregiverStatusUrgent(String relationship) {
    return 'Your $relationship needs immediate care. Call now.';
  }

  @override
  String get activityFeedTitle => 'Activity Feed';

  @override
  String get careCircleTitle => 'Care Circle';

  @override
  String get priorityCall => 'Priority Call';

  @override
  String get noRecentActivity => 'No recent activity';

  @override
  String get wellnessRingTitle => 'Wellness Ring';

  @override
  String get takeReadings => 'Take Readings';

  @override
  String get backToWellnessHub => 'Back to Wellness Hub';
}
