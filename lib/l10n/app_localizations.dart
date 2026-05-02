import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Swasth Health App'**
  String get appTitle;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Swasth'**
  String get appName;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @invite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get invite;

  /// No description provided for @revoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revoke;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Shown when a network call fails due to no connectivity, DNS failure, timeout, or TLS handshake error. Plain-language so Sunita (55yo Ranchi patient) can understand.
  ///
  /// In en, this message translates to:
  /// **'No internet. Please check your connection and try again.'**
  String get errNetwork;

  /// Shown on HTTP 401 before auto-logout. User is about to be sent back to the login screen.
  ///
  /// In en, this message translates to:
  /// **'Your session has ended. Please log in again.'**
  String get errSessionExpired;

  /// Shown on HTTP 5xx or when the server returns a malformed body we can't parse. Never expose the raw error.
  ///
  /// In en, this message translates to:
  /// **'Our server is having trouble right now. Please try again in a moment.'**
  String get errServer;

  /// Fallback for any unexpected exception that doesn't fit a known category.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errGeneric;

  /// Placeholder text shown in AI Insight card when no insights are available yet. Encourages patients to log readings regularly.
  ///
  /// In en, this message translates to:
  /// **'Log daily readings for the best health insights.'**
  String get aiInsightEmptyState;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMe;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccount;

  /// No description provided for @loginDoctorRegisterLink.
  ///
  /// In en, this message translates to:
  /// **'Are you a doctor? Register here'**
  String get loginDoctorRegisterLink;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @loginSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Login successful!'**
  String get loginSuccessful;

  /// No description provided for @emailValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get emailValidationEmpty;

  /// No description provided for @emailValidationInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get emailValidationInvalid;

  /// No description provided for @emailAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered. Please log in or use a different email.'**
  String get emailAlreadyRegistered;

  /// No description provided for @passwordValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get passwordValidationEmpty;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerTitle;

  /// No description provided for @accountDetailsSection.
  ///
  /// In en, this message translates to:
  /// **'Account Details'**
  String get accountDetailsSection;

  /// No description provided for @healthProfileSection.
  ///
  /// In en, this message translates to:
  /// **'Initial Health Profile'**
  String get healthProfileSection;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullNameLabel;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneLabel;

  /// No description provided for @phoneValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number'**
  String get phoneValidationEmpty;

  /// No description provided for @phoneValidationDigits.
  ///
  /// In en, this message translates to:
  /// **'Phone number can only contain digits'**
  String get phoneValidationDigits;

  /// No description provided for @phoneValidationLength.
  ///
  /// In en, this message translates to:
  /// **'Phone number must be 10-15 digits'**
  String get phoneValidationLength;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPasswordLabel;

  /// No description provided for @profileNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Profile Name'**
  String get profileNameLabel;

  /// No description provided for @relationshipLabel.
  ///
  /// In en, this message translates to:
  /// **'Relationship to patient'**
  String get relationshipLabel;

  /// No description provided for @ageLabel.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get ageLabel;

  /// No description provided for @genderLabel.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get genderLabel;

  /// No description provided for @heightLabel.
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get heightLabel;

  /// No description provided for @bloodGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Blood Group'**
  String get bloodGroupLabel;

  /// No description provided for @medicationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Medications (optional)'**
  String get medicationsLabel;

  /// No description provided for @medicalConditionsSection.
  ///
  /// In en, this message translates to:
  /// **'Medical Conditions'**
  String get medicalConditionsSection;

  /// No description provided for @passwordRequirementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Password Requirements:'**
  String get passwordRequirementsTitle;

  /// No description provided for @passwordReqLength.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordReqLength;

  /// No description provided for @passwordReqUppercase.
  ///
  /// In en, this message translates to:
  /// **'One uppercase letter'**
  String get passwordReqUppercase;

  /// No description provided for @passwordReqLowercase.
  ///
  /// In en, this message translates to:
  /// **'One lowercase letter'**
  String get passwordReqLowercase;

  /// No description provided for @passwordReqNumber.
  ///
  /// In en, this message translates to:
  /// **'One number'**
  String get passwordReqNumber;

  /// No description provided for @passwordReqSpecial.
  ///
  /// In en, this message translates to:
  /// **'One special character'**
  String get passwordReqSpecial;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @registerSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Registration successful! Please login.'**
  String get registerSuccessful;

  /// No description provided for @specifyOtherCondition.
  ///
  /// In en, this message translates to:
  /// **'Please specify other condition'**
  String get specifyOtherCondition;

  /// No description provided for @selectProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Profile'**
  String get selectProfileTitle;

  /// No description provided for @myProfilesSection.
  ///
  /// In en, this message translates to:
  /// **'My Profiles'**
  String get myProfilesSection;

  /// No description provided for @sharedWithMeSection.
  ///
  /// In en, this message translates to:
  /// **'Shared With Me'**
  String get sharedWithMeSection;

  /// No description provided for @noSharedProfiles.
  ///
  /// In en, this message translates to:
  /// **'No shared profiles yet.'**
  String get noSharedProfiles;

  /// No description provided for @addProfile.
  ///
  /// In en, this message translates to:
  /// **'Add Profile'**
  String get addProfile;

  /// No description provided for @pendingInvitesBanner.
  ///
  /// In en, this message translates to:
  /// **'You have {count} pending invites'**
  String pendingInvitesBanner(int count);

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Swasth Health App'**
  String get homeTitle;

  /// No description provided for @viewingProfile.
  ///
  /// In en, this message translates to:
  /// **'Viewing: {name}\'s Health'**
  String viewingProfile(String name);

  /// No description provided for @switchProfile.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get switchProfile;

  /// No description provided for @shareProfile.
  ///
  /// In en, this message translates to:
  /// **'Share Profile'**
  String get shareProfile;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Swasth!'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your health monitoring companion'**
  String get welcomeSubtitle;

  /// No description provided for @selectDevice.
  ///
  /// In en, this message translates to:
  /// **'Select Device'**
  String get selectDevice;

  /// No description provided for @recordNewMetrics.
  ///
  /// In en, this message translates to:
  /// **'Record New Metrics'**
  String get recordNewMetrics;

  /// No description provided for @flagFitFine.
  ///
  /// In en, this message translates to:
  /// **'Fit & Fine'**
  String get flagFitFine;

  /// No description provided for @flagCaution.
  ///
  /// In en, this message translates to:
  /// **'Caution'**
  String get flagCaution;

  /// No description provided for @flagAtRisk.
  ///
  /// In en, this message translates to:
  /// **'At Risk'**
  String get flagAtRisk;

  /// No description provided for @flagUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get flagUrgent;

  /// No description provided for @weeklyWinnersTitle.
  ///
  /// In en, this message translates to:
  /// **'Top this week'**
  String get weeklyWinnersTitle;

  /// No description provided for @weeklyWinnersSoon.
  ///
  /// In en, this message translates to:
  /// **'coming soon'**
  String get weeklyWinnersSoon;

  /// No description provided for @pointsLabel.
  ///
  /// In en, this message translates to:
  /// **'{pts} pts'**
  String pointsLabel(int pts);

  /// No description provided for @glucometer.
  ///
  /// In en, this message translates to:
  /// **'Glucometer'**
  String get glucometer;

  /// No description provided for @bpMeter.
  ///
  /// In en, this message translates to:
  /// **'BP Meter'**
  String get bpMeter;

  /// No description provided for @armband.
  ///
  /// In en, this message translates to:
  /// **'Armband'**
  String get armband;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @connectNewDevice.
  ///
  /// In en, this message translates to:
  /// **'Connect New Device'**
  String get connectNewDevice;

  /// No description provided for @connectNewDeviceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan and pair Bluetooth devices'**
  String get connectNewDeviceSubtitle;

  /// No description provided for @viewHistory.
  ///
  /// In en, this message translates to:
  /// **'View History'**
  String get viewHistory;

  /// No description provided for @viewHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check your past readings'**
  String get viewHistorySubtitle;

  /// No description provided for @selectProfileFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select a profile first'**
  String get selectProfileFirst;

  /// No description provided for @logReading.
  ///
  /// In en, this message translates to:
  /// **'Log {device} Reading'**
  String logReading(String device);

  /// No description provided for @howToLog.
  ///
  /// In en, this message translates to:
  /// **'How would you like to log this reading?'**
  String get howToLog;

  /// No description provided for @healthTrends.
  ///
  /// In en, this message translates to:
  /// **'Health Trends'**
  String get healthTrends;

  /// No description provided for @sevenDays.
  ///
  /// In en, this message translates to:
  /// **'7 Days'**
  String get sevenDays;

  /// No description provided for @thirtyDays.
  ///
  /// In en, this message translates to:
  /// **'30 Days'**
  String get thirtyDays;

  /// No description provided for @ninetyDays.
  ///
  /// In en, this message translates to:
  /// **'90 Days'**
  String get ninetyDays;

  /// No description provided for @oneYear.
  ///
  /// In en, this message translates to:
  /// **'1 Year'**
  String get oneYear;

  /// No description provided for @glucoseTrend.
  ///
  /// In en, this message translates to:
  /// **'Glucose Trend'**
  String get glucoseTrend;

  /// No description provided for @bpTrend.
  ///
  /// In en, this message translates to:
  /// **'Blood Pressure Trend'**
  String get bpTrend;

  /// No description provided for @avgLabel.
  ///
  /// In en, this message translates to:
  /// **'Avg'**
  String get avgLabel;

  /// No description provided for @minLabel.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get minLabel;

  /// No description provided for @maxLabel.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get maxLabel;

  /// No description provided for @normalPct.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normalPct;

  /// No description provided for @noChartData.
  ///
  /// In en, this message translates to:
  /// **'No readings in this period'**
  String get noChartData;

  /// Empty state for glucose chart when there are no glucose readings in the selected window.
  ///
  /// In en, this message translates to:
  /// **'No glucose readings in the last {days} days.'**
  String noReadingsInWindowGlucose(int days);

  /// Empty state for BP chart when there are no BP readings in the selected window.
  ///
  /// In en, this message translates to:
  /// **'No blood pressure readings in the last {days} days.'**
  String noReadingsInWindowBp(int days);

  /// Empty state for weight chart when there are no weight readings in the selected window.
  ///
  /// In en, this message translates to:
  /// **'No weight readings in the last {days} days.'**
  String noReadingsInWindowWeight(int days);

  /// No description provided for @logFromHomeHint.
  ///
  /// In en, this message translates to:
  /// **'Log a reading from the Home screen to see it here.'**
  String get logFromHomeHint;

  /// No description provided for @tapToViewTrends.
  ///
  /// In en, this message translates to:
  /// **'Tap to view trends →'**
  String get tapToViewTrends;

  /// No description provided for @viewTrends.
  ///
  /// In en, this message translates to:
  /// **'View Trends'**
  String get viewTrends;

  /// No description provided for @viewTrendsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'7 and 30-day glucose & BP charts'**
  String get viewTrendsSubtitle;

  /// No description provided for @healthScore.
  ///
  /// In en, this message translates to:
  /// **'Health Score'**
  String get healthScore;

  /// No description provided for @dayStreak.
  ///
  /// In en, this message translates to:
  /// **'{n}-day streak'**
  String dayStreak(int n);

  /// No description provided for @lastLogged.
  ///
  /// In en, this message translates to:
  /// **'Last logged: {time}'**
  String lastLogged(String time);

  /// No description provided for @noReadingsYetScore.
  ///
  /// In en, this message translates to:
  /// **'Log your first reading to see your score'**
  String get noReadingsYetScore;

  /// No description provided for @todayGlucose.
  ///
  /// In en, this message translates to:
  /// **'Glucose'**
  String get todayGlucose;

  /// No description provided for @todayBP.
  ///
  /// In en, this message translates to:
  /// **'BP'**
  String get todayBP;

  /// No description provided for @scanWithCamera.
  ///
  /// In en, this message translates to:
  /// **'Scan with Camera'**
  String get scanWithCamera;

  /// No description provided for @connectViaBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Connect via Bluetooth'**
  String get connectViaBluetooth;

  /// No description provided for @enterManually.
  ///
  /// In en, this message translates to:
  /// **'Enter Manually'**
  String get enterManually;

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan {device}'**
  String scanTitle(String device);

  /// No description provided for @placeDeviceInBox.
  ///
  /// In en, this message translates to:
  /// **'Place {device} screen inside the box'**
  String placeDeviceInBox(String device);

  /// No description provided for @toggleFlash.
  ///
  /// In en, this message translates to:
  /// **'Toggle Flash'**
  String get toggleFlash;

  /// No description provided for @photoBlurryTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo is too blurry'**
  String get photoBlurryTitle;

  /// No description provided for @photoBlurryMessage.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t read the display. Please retake the photo with:\n\n• Camera steady (no shake)\n• Device screen centered in the guide box\n• Good lighting or flash on'**
  String get photoBlurryMessage;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @readingImage.
  ///
  /// In en, this message translates to:
  /// **'Reading the image...'**
  String get readingImage;

  /// No description provided for @glucoseReadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Glucose Reading'**
  String get glucoseReadingTitle;

  /// No description provided for @bpReadingTitle.
  ///
  /// In en, this message translates to:
  /// **'BP Reading'**
  String get bpReadingTitle;

  /// No description provided for @glucoseValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Glucose Value'**
  String get glucoseValueLabel;

  /// No description provided for @systolicLabel.
  ///
  /// In en, this message translates to:
  /// **'Systolic'**
  String get systolicLabel;

  /// No description provided for @diastolicLabel.
  ///
  /// In en, this message translates to:
  /// **'Diastolic'**
  String get diastolicLabel;

  /// No description provided for @pulseLabel.
  ///
  /// In en, this message translates to:
  /// **'Pulse (optional)'**
  String get pulseLabel;

  /// No description provided for @mealContextSection.
  ///
  /// In en, this message translates to:
  /// **'Meal Context'**
  String get mealContextSection;

  /// No description provided for @fasting.
  ///
  /// In en, this message translates to:
  /// **'Fasting'**
  String get fasting;

  /// No description provided for @beforeMeal.
  ///
  /// In en, this message translates to:
  /// **'Before Meal'**
  String get beforeMeal;

  /// No description provided for @afterMeal.
  ///
  /// In en, this message translates to:
  /// **'After Meal'**
  String get afterMeal;

  /// No description provided for @readingTime.
  ///
  /// In en, this message translates to:
  /// **'Reading Time'**
  String get readingTime;

  /// No description provided for @saveReading.
  ///
  /// In en, this message translates to:
  /// **'Save Reading'**
  String get saveReading;

  /// No description provided for @readingSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Reading saved successfully'**
  String get readingSavedSuccess;

  /// No description provided for @ocrSuccessPrefix.
  ///
  /// In en, this message translates to:
  /// **'We read:'**
  String get ocrSuccessPrefix;

  /// No description provided for @ocrEditButton.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get ocrEditButton;

  /// No description provided for @ocrConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'Is this correct? You can edit above before saving.'**
  String get ocrConfirmHint;

  /// No description provided for @ocrFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the value from the photo. Please enter it manually below.'**
  String get ocrFailedMessage;

  /// No description provided for @manualEntryHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the value shown on your device.'**
  String get manualEntryHint;

  /// No description provided for @glucoseValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid glucose value (20–600 mg/dL)'**
  String get glucoseValidation;

  /// No description provided for @systolicValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid systolic value (60–250 mmHg)'**
  String get systolicValidation;

  /// No description provided for @diastolicValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid diastolic value (40–150 mmHg)'**
  String get diastolicValidation;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String saveFailed(String error);

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading History'**
  String get historyTitle;

  /// No description provided for @filterByType.
  ///
  /// In en, this message translates to:
  /// **'Filter by type'**
  String get filterByType;

  /// No description provided for @allReadings.
  ///
  /// In en, this message translates to:
  /// **'All Readings'**
  String get allReadings;

  /// No description provided for @glucoseOnly.
  ///
  /// In en, this message translates to:
  /// **'Glucose Only'**
  String get glucoseOnly;

  /// No description provided for @bpOnly.
  ///
  /// In en, this message translates to:
  /// **'BP Only'**
  String get bpOnly;

  /// No description provided for @mealsOnly.
  ///
  /// In en, this message translates to:
  /// **'Meals Only'**
  String get mealsOnly;

  /// No description provided for @noMealsYet.
  ///
  /// In en, this message translates to:
  /// **'No meals logged yet'**
  String get noMealsYet;

  /// No description provided for @mealCarbLoadLow.
  ///
  /// In en, this message translates to:
  /// **'Low-carb meal'**
  String get mealCarbLoadLow;

  /// No description provided for @mealCarbLoadModerate.
  ///
  /// In en, this message translates to:
  /// **'Medium-carb meal'**
  String get mealCarbLoadModerate;

  /// No description provided for @mealCarbLoadHigh.
  ///
  /// In en, this message translates to:
  /// **'High-carb meal'**
  String get mealCarbLoadHigh;

  /// No description provided for @mealCarbLoadVeryHigh.
  ///
  /// In en, this message translates to:
  /// **'Sugary meal'**
  String get mealCarbLoadVeryHigh;

  /// No description provided for @mealLabelDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Food labels describe typical carbohydrate content, not your body\'s response.'**
  String get mealLabelDisclaimer;

  /// No description provided for @caregiverLogMealsHint.
  ///
  /// In en, this message translates to:
  /// **'To log meals, use the patient view toggle at the top.'**
  String get caregiverLogMealsHint;

  /// No description provided for @noReadingsYet.
  ///
  /// In en, this message translates to:
  /// **'No readings yet'**
  String get noReadingsYet;

  /// No description provided for @noReadingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect a device and take a measurement\nto see your reading history here'**
  String get noReadingsSubtitle;

  /// No description provided for @deleteReading.
  ///
  /// In en, this message translates to:
  /// **'Delete Reading'**
  String get deleteReading;

  /// No description provided for @deleteReadingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this reading?'**
  String get deleteReadingConfirm;

  /// No description provided for @readingDeleted.
  ///
  /// In en, this message translates to:
  /// **'Reading deleted'**
  String get readingDeleted;

  /// No description provided for @deleteMeal.
  ///
  /// In en, this message translates to:
  /// **'Delete Meal'**
  String get deleteMeal;

  /// No description provided for @deleteMealConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this meal?'**
  String get deleteMealConfirm;

  /// No description provided for @mealDeleted.
  ///
  /// In en, this message translates to:
  /// **'Meal deleted'**
  String get mealDeleted;

  /// No description provided for @editReading.
  ///
  /// In en, this message translates to:
  /// **'Edit Reading'**
  String get editReading;

  /// No description provided for @readingUpdated.
  ///
  /// In en, this message translates to:
  /// **'Reading updated'**
  String get readingUpdated;

  /// No description provided for @weightLabel.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weightLabel;

  /// No description provided for @weightValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid weight (1–400 kg)'**
  String get weightValidation;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notes;

  /// No description provided for @statusNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get statusNormal;

  /// No description provided for @statusElevated.
  ///
  /// In en, this message translates to:
  /// **'Elevated'**
  String get statusElevated;

  /// No description provided for @statusHighStage1.
  ///
  /// In en, this message translates to:
  /// **'High - Stage 1'**
  String get statusHighStage1;

  /// No description provided for @statusHighStage2.
  ///
  /// In en, this message translates to:
  /// **'High - Stage 2'**
  String get statusHighStage2;

  /// No description provided for @statusLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get statusLow;

  /// No description provided for @statusCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get statusCritical;

  /// No description provided for @profileDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile Details'**
  String get profileDetailsTitle;

  /// No description provided for @manageAccess.
  ///
  /// In en, this message translates to:
  /// **'Manage Access'**
  String get manageAccess;

  /// No description provided for @yourProfile.
  ///
  /// In en, this message translates to:
  /// **'Your Profile'**
  String get yourProfile;

  /// No description provided for @sharedBySomeone.
  ///
  /// In en, this message translates to:
  /// **'Shared by Someone'**
  String get sharedBySomeone;

  /// No description provided for @healthInfoSection.
  ///
  /// In en, this message translates to:
  /// **'Health Information'**
  String get healthInfoSection;

  /// No description provided for @ageField.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get ageField;

  /// No description provided for @ageYears.
  ///
  /// In en, this message translates to:
  /// **'{age} years'**
  String ageYears(String age);

  /// No description provided for @genderField.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get genderField;

  /// No description provided for @bloodGroupField.
  ///
  /// In en, this message translates to:
  /// **'Blood Group'**
  String get bloodGroupField;

  /// No description provided for @heightField.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get heightField;

  /// No description provided for @heightCm.
  ///
  /// In en, this message translates to:
  /// **'{height} cm'**
  String heightCm(String height);

  /// No description provided for @medicalConditionsField.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get medicalConditionsField;

  /// No description provided for @accountSettingsSection.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get accountSettingsSection;

  /// No description provided for @shareWithDoctorSection.
  ///
  /// In en, this message translates to:
  /// **'Share with a Doctor'**
  String get shareWithDoctorSection;

  /// No description provided for @myDoctorsSection.
  ///
  /// In en, this message translates to:
  /// **'My Doctors'**
  String get myDoctorsSection;

  /// No description provided for @primaryPhysicianSubheading.
  ///
  /// In en, this message translates to:
  /// **'Primary Physician'**
  String get primaryPhysicianSubheading;

  /// No description provided for @sharingHealthDataWithSubheading.
  ///
  /// In en, this message translates to:
  /// **'Sharing health data with'**
  String get sharingHealthDataWithSubheading;

  /// No description provided for @sharingHealthDataWithEmpty.
  ///
  /// In en, this message translates to:
  /// **'You are not sharing health data with any doctor yet.'**
  String get sharingHealthDataWithEmpty;

  /// No description provided for @linkAnotherDoctor.
  ///
  /// In en, this message translates to:
  /// **'Link another doctor'**
  String get linkAnotherDoctor;

  /// No description provided for @linkedDoctorsTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Doctors with access'**
  String get linkedDoctorsTileTitle;

  /// No description provided for @linkedDoctorsTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See who can view your readings'**
  String get linkedDoctorsTileSubtitle;

  /// No description provided for @linkedDoctorsTitle.
  ///
  /// In en, this message translates to:
  /// **'Doctors with access'**
  String get linkedDoctorsTitle;

  /// No description provided for @linkedDoctorsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No doctor is currently linked to this profile.'**
  String get linkedDoctorsEmpty;

  /// No description provided for @linkedDoctorsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap \'Link a Doctor\' on your profile to share your readings.'**
  String get linkedDoctorsEmptyHint;

  /// No description provided for @linkedDoctorsError.
  ///
  /// In en, this message translates to:
  /// **'Could not load linked doctors.'**
  String get linkedDoctorsError;

  /// No description provided for @linkedDoctorsLinkedSince.
  ///
  /// In en, this message translates to:
  /// **'Linked since {date}'**
  String linkedDoctorsLinkedSince(String date);

  /// No description provided for @linkedDoctorsRevoke.
  ///
  /// In en, this message translates to:
  /// **'Stop sharing'**
  String get linkedDoctorsRevoke;

  /// No description provided for @linkedDoctorsWaitingForDoctor.
  ///
  /// In en, this message translates to:
  /// **'Waiting for doctor'**
  String get linkedDoctorsWaitingForDoctor;

  /// No description provided for @linkedDoctorsCancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get linkedDoctorsCancelRequest;

  /// No description provided for @linkedDoctorsRevokeDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop sharing with {name}?'**
  String linkedDoctorsRevokeDialogTitle(String name);

  /// No description provided for @linkedDoctorsRevokeDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This doctor will no longer be able to see your past or future readings. You can link again any time.'**
  String get linkedDoctorsRevokeDialogBody;

  /// No description provided for @linkedDoctorsRevokeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Stop sharing'**
  String get linkedDoctorsRevokeConfirm;

  /// No description provided for @linkedDoctorsRevokeSuccess.
  ///
  /// In en, this message translates to:
  /// **'{name} can no longer see your readings.'**
  String linkedDoctorsRevokeSuccess(String name);

  /// No description provided for @linkedDoctorsRevokeReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String linkedDoctorsRevokeReasonLabel(String reason);

  /// No description provided for @adminMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminMenuTooltip;

  /// No description provided for @adminMenuDashboard.
  ///
  /// In en, this message translates to:
  /// **'Open dashboard'**
  String get adminMenuDashboard;

  /// No description provided for @adminMenuCreateUser.
  ///
  /// In en, this message translates to:
  /// **'Create user'**
  String get adminMenuCreateUser;

  /// No description provided for @linkedEmail.
  ///
  /// In en, this message translates to:
  /// **'Linked Email'**
  String get linkedEmail;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Account Password'**
  String get changePassword;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete My Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your account, all health readings, profiles, and AI insights. This action cannot be undone.'**
  String get deleteAccountConfirmMessage;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete Permanently'**
  String get deleteAccountConfirm;

  /// No description provided for @changePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePasswordTitle;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPasswordLabel;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPasswordLabel;

  /// No description provided for @confirmNewPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPasswordLabel;

  /// No description provided for @passwordMinChars.
  ///
  /// In en, this message translates to:
  /// **'Min. 6 characters'**
  String get passwordMinChars;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed!'**
  String get passwordChanged;

  /// No description provided for @enterCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter current password'**
  String get enterCurrentPassword;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Min 6 characters'**
  String get passwordTooShort;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @appLanguageSection.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get appLanguageSection;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'हिंदी'**
  String get languageHindi;

  /// No description provided for @myDoctorTitle.
  ///
  /// In en, this message translates to:
  /// **'My Doctor'**
  String get myDoctorTitle;

  /// No description provided for @contactOnWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Contact on WhatsApp'**
  String get contactOnWhatsApp;

  /// No description provided for @doctorDetailsSection.
  ///
  /// In en, this message translates to:
  /// **'Doctor Details'**
  String get doctorDetailsSection;

  /// No description provided for @doctorNameField.
  ///
  /// In en, this message translates to:
  /// **'Doctor Name'**
  String get doctorNameField;

  /// No description provided for @doctorSpecialtyField.
  ///
  /// In en, this message translates to:
  /// **'Specialty'**
  String get doctorSpecialtyField;

  /// No description provided for @doctorWhatsappField.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Number'**
  String get doctorWhatsappField;

  /// No description provided for @noDoctorLinked.
  ///
  /// In en, this message translates to:
  /// **'No doctor linked yet.'**
  String get noDoctorLinked;

  /// No description provided for @linkADoctorCta.
  ///
  /// In en, this message translates to:
  /// **'Link a doctor'**
  String get linkADoctorCta;

  /// No description provided for @doctorPendingAcceptBadge.
  ///
  /// In en, this message translates to:
  /// **'Awaiting doctor'**
  String get doctorPendingAcceptBadge;

  /// No description provided for @doctorDeclinedBadge.
  ///
  /// In en, this message translates to:
  /// **'Request declined'**
  String get doctorDeclinedBadge;

  /// No description provided for @doctorDeclineReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String doctorDeclineReason(String reason);

  /// No description provided for @addDoctor.
  ///
  /// In en, this message translates to:
  /// **'Add Doctor'**
  String get addDoctor;

  /// No description provided for @editDoctor.
  ///
  /// In en, this message translates to:
  /// **'Edit Doctor Details'**
  String get editDoctor;

  /// No description provided for @editDoctorTitle.
  ///
  /// In en, this message translates to:
  /// **'Doctor Details'**
  String get editDoctorTitle;

  /// No description provided for @doctorWhatsappHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. +917001234567'**
  String get doctorWhatsappHint;

  /// No description provided for @addHealthProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Health Profile'**
  String get addHealthProfileTitle;

  /// No description provided for @createProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a profile for someone you care for (e.g. parents, child)'**
  String get createProfileSubtitle;

  /// No description provided for @profileNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Papa, Mummy'**
  String get profileNameHint;

  /// No description provided for @createProfile.
  ///
  /// In en, this message translates to:
  /// **'Create Profile'**
  String get createProfile;

  /// No description provided for @manageAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Access'**
  String get manageAccessTitle;

  /// No description provided for @inviteSomeoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite someone to view this profile'**
  String get inviteSomeoneTitle;

  /// No description provided for @enterEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter email address'**
  String get enterEmailHint;

  /// No description provided for @notSharedYet.
  ///
  /// In en, this message translates to:
  /// **'Not shared with anyone yet.'**
  String get notSharedYet;

  /// No description provided for @inviteSentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Invite sent successfully'**
  String get inviteSentSuccess;

  /// No description provided for @revokeAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke Access?'**
  String get revokeAccessTitle;

  /// No description provided for @revokeAccessConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to stop sharing this profile with {name}?'**
  String revokeAccessConfirm(String name);

  /// No description provided for @pendingInvitesTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending Invites'**
  String get pendingInvitesTitle;

  /// No description provided for @noPendingInvites.
  ///
  /// In en, this message translates to:
  /// **'No pending invites.'**
  String get noPendingInvites;

  /// No description provided for @wantsToShare.
  ///
  /// In en, this message translates to:
  /// **'wants to share \"{profileName}\"'**
  String wantsToShare(String profileName);

  /// No description provided for @expiresInDays.
  ///
  /// In en, this message translates to:
  /// **'Expires in {days} days ({date})'**
  String expiresInDays(int days, String date);

  /// No description provided for @acceptedInvite.
  ///
  /// In en, this message translates to:
  /// **'Accepted invite for {profileName}'**
  String acceptedInvite(String profileName);

  /// No description provided for @rejectedInvite.
  ///
  /// In en, this message translates to:
  /// **'Rejected invite for {profileName}'**
  String rejectedInvite(String profileName);

  /// No description provided for @scanDevicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Swasth — Scan Devices'**
  String get scanDevicesTitle;

  /// No description provided for @pressScanToFind.
  ///
  /// In en, this message translates to:
  /// **'Press Scan to find your device'**
  String get pressScanToFind;

  /// No description provided for @scanButton.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scanButton;

  /// No description provided for @scanningButton.
  ///
  /// In en, this message translates to:
  /// **'Scanning...'**
  String get scanningButton;

  /// No description provided for @noDevicesFound.
  ///
  /// In en, this message translates to:
  /// **'No devices found yet'**
  String get noDevicesFound;

  /// No description provided for @lookingForDevices.
  ///
  /// In en, this message translates to:
  /// **'Looking for devices...'**
  String get lookingForDevices;

  /// No description provided for @noDevicesFoundAfterScan.
  ///
  /// In en, this message translates to:
  /// **'No devices found. Make sure device is powered on.'**
  String get noDevicesFoundAfterScan;

  /// No description provided for @connectButton.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectButton;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordHeadline.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPasswordHeadline;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we\'ll send you an OTP to reset your password.'**
  String get forgotPasswordSubtitle;

  /// No description provided for @sendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get sendOtp;

  /// No description provided for @otpSentSuccess.
  ///
  /// In en, this message translates to:
  /// **'OTP sent successfully! Check your email.'**
  String get otpSentSuccess;

  /// No description provided for @otpSentToPhoneSuccess.
  ///
  /// In en, this message translates to:
  /// **'OTP sent successfully! Check your messages.'**
  String get otpSentToPhoneSuccess;

  /// No description provided for @rememberPassword.
  ///
  /// In en, this message translates to:
  /// **'Remember your password?'**
  String get rememberPassword;

  /// No description provided for @verifyOtpTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify OTP'**
  String get verifyOtpTitle;

  /// No description provided for @enterOtpHeadline.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP'**
  String get enterOtpHeadline;

  /// No description provided for @otpSentToEmail.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a 6-digit OTP to\n{email}'**
  String otpSentToEmail(String email);

  /// No description provided for @otpLabel.
  ///
  /// In en, this message translates to:
  /// **'OTP'**
  String get otpLabel;

  /// No description provided for @verifyOtp.
  ///
  /// In en, this message translates to:
  /// **'Verify OTP'**
  String get verifyOtp;

  /// No description provided for @otpVerifiedSuccess.
  ///
  /// In en, this message translates to:
  /// **'OTP verified successfully!'**
  String get otpVerifiedSuccess;

  /// No description provided for @didNotReceiveOtp.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive OTP?'**
  String get didNotReceiveOtp;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String resendIn(int seconds);

  /// No description provided for @resendOtp.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP'**
  String get resendOtp;

  /// No description provided for @otpResent.
  ///
  /// In en, this message translates to:
  /// **'OTP resent successfully! Check your email.'**
  String get otpResent;

  /// No description provided for @wantToGoBack.
  ///
  /// In en, this message translates to:
  /// **'Want to go back?'**
  String get wantToGoBack;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPasswordTitle;

  /// No description provided for @createNewPasswordHeadline.
  ///
  /// In en, this message translates to:
  /// **'Create New Password'**
  String get createNewPasswordHeadline;

  /// No description provided for @createNewPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your new password must be different from your old password.'**
  String get createNewPasswordSubtitle;

  /// No description provided for @resetPasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPasswordButton;

  /// No description provided for @passwordResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password reset successfully!'**
  String get passwordResetSuccess;

  /// No description provided for @wellnessScoreSection.
  ///
  /// In en, this message translates to:
  /// **'Wellness Score'**
  String get wellnessScoreSection;

  /// No description provided for @vitalSummarySection.
  ///
  /// In en, this message translates to:
  /// **'Vital Summary'**
  String get vitalSummarySection;

  /// No description provided for @ninetyDayAvg.
  ///
  /// In en, this message translates to:
  /// **'90 Days Avg'**
  String get ninetyDayAvg;

  /// No description provided for @aiInsightSection.
  ///
  /// In en, this message translates to:
  /// **'AI Health Insight'**
  String get aiInsightSection;

  /// No description provided for @primaryPhysicianSection.
  ///
  /// In en, this message translates to:
  /// **'Primary Physician'**
  String get primaryPhysicianSection;

  /// No description provided for @individualMetricsSection.
  ///
  /// In en, this message translates to:
  /// **'Individual Metrics'**
  String get individualMetricsSection;

  /// No description provided for @vitalsSection.
  ///
  /// In en, this message translates to:
  /// **'Vitals'**
  String get vitalsSection;

  /// No description provided for @trendsSection.
  ///
  /// In en, this message translates to:
  /// **'Trends'**
  String get trendsSection;

  /// No description provided for @lastSpO2.
  ///
  /// In en, this message translates to:
  /// **'Last SpO2'**
  String get lastSpO2;

  /// No description provided for @lastSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps Today'**
  String get lastSteps;

  /// No description provided for @spO2Unit.
  ///
  /// In en, this message translates to:
  /// **'%'**
  String get spO2Unit;

  /// No description provided for @viaArmband.
  ///
  /// In en, this message translates to:
  /// **'via Armband'**
  String get viaArmband;

  /// No description provided for @viaPhone.
  ///
  /// In en, this message translates to:
  /// **'via Phone / Armband'**
  String get viaPhone;

  /// No description provided for @pairDevice.
  ///
  /// In en, this message translates to:
  /// **'Pair Device'**
  String get pairDevice;

  /// No description provided for @connectedDevices.
  ///
  /// In en, this message translates to:
  /// **'Connected Devices'**
  String get connectedDevices;

  /// No description provided for @readMore.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get readMore;

  /// No description provided for @mealSlotBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get mealSlotBreakfast;

  /// No description provided for @mealSlotLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get mealSlotLunch;

  /// No description provided for @mealSlotSnack.
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get mealSlotSnack;

  /// No description provided for @mealSlotDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get mealSlotDinner;

  /// No description provided for @mealSlotLogged.
  ///
  /// In en, this message translates to:
  /// **'Logged'**
  String get mealSlotLogged;

  /// No description provided for @mealSlotTapToLog.
  ///
  /// In en, this message translates to:
  /// **'Tap to log'**
  String get mealSlotTapToLog;

  /// No description provided for @footerDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Not a medical diagnosis. Consult your doctor for clinical advice. All AI insights are for informational purposes.'**
  String get footerDisclaimer;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning,'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon,'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening,'**
  String get goodEvening;

  /// No description provided for @hello.
  ///
  /// In en, this message translates to:
  /// **'Hello,'**
  String get hello;

  /// No description provided for @trendStable.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get trendStable;

  /// No description provided for @optimumRange.
  ///
  /// In en, this message translates to:
  /// **'Optimum Range'**
  String get optimumRange;

  /// No description provided for @physicianConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get physicianConnected;

  /// No description provided for @physicianNotLinked.
  ///
  /// In en, this message translates to:
  /// **'Not Linked'**
  String get physicianNotLinked;

  /// No description provided for @activeSync.
  ///
  /// In en, this message translates to:
  /// **'Active Sync'**
  String get activeSync;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not Connected'**
  String get notConnected;

  /// No description provided for @lastBP.
  ///
  /// In en, this message translates to:
  /// **'Last BP'**
  String get lastBP;

  /// No description provided for @lastSugar.
  ///
  /// In en, this message translates to:
  /// **'Last Sugar'**
  String get lastSugar;

  /// No description provided for @liveSteps.
  ///
  /// In en, this message translates to:
  /// **'Live Steps'**
  String get liveSteps;

  /// No description provided for @relationshipFather.
  ///
  /// In en, this message translates to:
  /// **'Father'**
  String get relationshipFather;

  /// No description provided for @relationshipMother.
  ///
  /// In en, this message translates to:
  /// **'Mother'**
  String get relationshipMother;

  /// No description provided for @relationshipSpouse.
  ///
  /// In en, this message translates to:
  /// **'Spouse'**
  String get relationshipSpouse;

  /// No description provided for @relationshipSon.
  ///
  /// In en, this message translates to:
  /// **'Son'**
  String get relationshipSon;

  /// No description provided for @relationshipDaughter.
  ///
  /// In en, this message translates to:
  /// **'Daughter'**
  String get relationshipDaughter;

  /// No description provided for @relationshipBrother.
  ///
  /// In en, this message translates to:
  /// **'Brother'**
  String get relationshipBrother;

  /// No description provided for @relationshipSister.
  ///
  /// In en, this message translates to:
  /// **'Sister'**
  String get relationshipSister;

  /// No description provided for @relationshipUncle.
  ///
  /// In en, this message translates to:
  /// **'Uncle'**
  String get relationshipUncle;

  /// No description provided for @relationshipAunt.
  ///
  /// In en, this message translates to:
  /// **'Aunt'**
  String get relationshipAunt;

  /// No description provided for @relationshipFriend.
  ///
  /// In en, this message translates to:
  /// **'Friend'**
  String get relationshipFriend;

  /// No description provided for @relationshipOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get relationshipOther;

  /// No description provided for @consentTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Consent'**
  String get consentTitle;

  /// No description provided for @consentSubject.
  ///
  /// In en, this message translates to:
  /// **'Consent for Health Data Processing'**
  String get consentSubject;

  /// No description provided for @consentIntro.
  ///
  /// In en, this message translates to:
  /// **'By using Swasth, I agree to the following:'**
  String get consentIntro;

  /// No description provided for @consentDataCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Collection'**
  String get consentDataCollectionTitle;

  /// No description provided for @consentDataCollection.
  ///
  /// In en, this message translates to:
  /// **'I allow Swasth to store my blood glucose, blood pressure, and food photos.'**
  String get consentDataCollection;

  /// No description provided for @consentFamilySharingTitle.
  ///
  /// In en, this message translates to:
  /// **'Family Sharing'**
  String get consentFamilySharingTitle;

  /// No description provided for @consentFamilySharing.
  ///
  /// In en, this message translates to:
  /// **'I understand that if I share my profile, my designated family members (e.g., son/daughter) will see my health scores and receive alerts.'**
  String get consentFamilySharing;

  /// No description provided for @consentPurposeTitle.
  ///
  /// In en, this message translates to:
  /// **'Purpose'**
  String get consentPurposeTitle;

  /// No description provided for @consentPurpose.
  ///
  /// In en, this message translates to:
  /// **'My data will be used to provide me with health insights and shared with my doctor for my treatment.'**
  String get consentPurpose;

  /// No description provided for @consentRightsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Rights'**
  String get consentRightsTitle;

  /// No description provided for @consentRights.
  ///
  /// In en, this message translates to:
  /// **'I can withdraw my consent or ask to delete my data at any time through the app settings.'**
  String get consentRights;

  /// No description provided for @consentAiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI-Powered Insights'**
  String get consentAiTitle;

  /// No description provided for @consentAiBody.
  ///
  /// In en, this message translates to:
  /// **'Swasth uses third-party AI services (Google Gemini and DeepSeek) to generate personalised health insights. A summary of my health data (not raw readings) may be sent to these services. I can opt out at any time, and rule-based insights will be used instead.\n\nAll AI-generated content is a health observation only — not medical advice. Always consult your doctor before making any changes to medication or treatment.'**
  String get consentAiBody;

  /// No description provided for @consentAccept.
  ///
  /// In en, this message translates to:
  /// **'I Accept'**
  String get consentAccept;

  /// No description provided for @consentDecline.
  ///
  /// In en, this message translates to:
  /// **'I Decline'**
  String get consentDecline;

  /// No description provided for @consentDeclineTitle.
  ///
  /// In en, this message translates to:
  /// **'Decline Consent?'**
  String get consentDeclineTitle;

  /// No description provided for @consentDeclineMessage.
  ///
  /// In en, this message translates to:
  /// **'You cannot use Swasth without accepting the privacy notice. Your registration will not be completed.'**
  String get consentDeclineMessage;

  /// No description provided for @consentDeclineConfirm.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get consentDeclineConfirm;

  /// No description provided for @consentScrollToAccept.
  ///
  /// In en, this message translates to:
  /// **'Scroll down to read the full notice'**
  String get consentScrollToAccept;

  /// No description provided for @ppDataCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Data We Collect'**
  String get ppDataCollectionTitle;

  /// No description provided for @ppDataCollection.
  ///
  /// In en, this message translates to:
  /// **'Swasth collects: blood glucose readings, blood pressure readings, pulse rate, meal notes, profile information (name, age, gender, medical conditions, medications), and photos of medical devices for automated reading capture.'**
  String get ppDataCollection;

  /// No description provided for @ppPurposeTitle.
  ///
  /// In en, this message translates to:
  /// **'Purpose of Collection'**
  String get ppPurposeTitle;

  /// No description provided for @ppPurpose.
  ///
  /// In en, this message translates to:
  /// **'Your health data is used to: display trends and health scores, generate personalised health insights, share with your designated family members, and provide information to your doctor for treatment.'**
  String get ppPurpose;

  /// No description provided for @ppAiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Processing'**
  String get ppAiTitle;

  /// No description provided for @ppAi.
  ///
  /// In en, this message translates to:
  /// **'Swasth uses third-party AI services — Google Gemini and DeepSeek — to generate health insights. A summarised version of your data (averages and ranges, not individual readings) is sent to these services. You can opt out of AI processing at any time; rule-based insights will be used instead. All AI-generated content is informational only and does not constitute medical advice.'**
  String get ppAi;

  /// No description provided for @ppSharingTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Sharing'**
  String get ppSharingTitle;

  /// No description provided for @ppSharing.
  ///
  /// In en, this message translates to:
  /// **'Your data is shared only with: family members you explicitly invite, AI services (Google Gemini, DeepSeek) for health insights if you consent, and your doctor if you choose to share. We do not sell or share your data with advertisers or any other third parties.'**
  String get ppSharing;

  /// No description provided for @ppSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Security Measures'**
  String get ppSecurityTitle;

  /// No description provided for @ppSecurity.
  ///
  /// In en, this message translates to:
  /// **'We protect your data with: AES-256 encryption for health readings stored in our database, bcrypt password hashing, JWT-based authentication with token expiration, TLS/HTTPS for all data in transit, and encrypted local storage on your device.'**
  String get ppSecurity;

  /// No description provided for @ppRetentionTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Retention'**
  String get ppRetentionTitle;

  /// No description provided for @ppRetention.
  ///
  /// In en, this message translates to:
  /// **'Your data is stored as long as your account is active. You may request deletion of all your data at any time through the app settings. Upon account deletion, all readings, profiles, AI logs, and personal information are permanently removed.'**
  String get ppRetention;

  /// No description provided for @ppRightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Rights'**
  String get ppRightsTitle;

  /// No description provided for @ppRights.
  ///
  /// In en, this message translates to:
  /// **'Under Indian data protection law (SPDI Rules 2011 and DPDP Act 2023), you have the right to: access your data, correct inaccuracies, withdraw consent, request deletion of your data, and file a grievance. To exercise these rights, use the in-app settings or contact us.'**
  String get ppRights;

  /// No description provided for @ppDoctorSharingTitle.
  ///
  /// In en, this message translates to:
  /// **'Doctor Data Sharing'**
  String get ppDoctorSharingTitle;

  /// No description provided for @ppDoctorSharing.
  ///
  /// In en, this message translates to:
  /// **'If you link a doctor to your profile, your health readings, trends, and profile information (name, age, conditions, medications) will be visible to that doctor. You control this sharing — you can revoke doctor access at any time from your profile settings. Doctors cannot modify your data.'**
  String get ppDoctorSharing;

  /// No description provided for @ppWhatsAppTitle.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Notifications'**
  String get ppWhatsAppTitle;

  /// No description provided for @ppWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Swasth uses Twilio WhatsApp Business API to send you health alerts and weekly summaries. These messages are sent to the phone number you provide. You will receive: (1) immediate alerts when a critical reading is recorded, (2) optional weekly health summaries. You can opt out of WhatsApp messages via Settings → Notifications in the app, or by contacting support@swasth.app.'**
  String get ppWhatsApp;

  /// No description provided for @ppLiabilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Limitation of Liability'**
  String get ppLiabilityTitle;

  /// No description provided for @ppLiability.
  ///
  /// In en, this message translates to:
  /// **'Swasth is a health monitoring tool, not a medical device or clinical service. The app does not provide diagnosis, treatment, or prescription. All insights are informational. Swasth is not liable for any health decisions made based on app content. Always consult a qualified doctor for medical advice. In case of emergency, call 112.'**
  String get ppLiability;

  /// No description provided for @ppContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get ppContactTitle;

  /// No description provided for @ppContact.
  ///
  /// In en, this message translates to:
  /// **'For privacy-related questions or grievances, contact our Grievance Officer: support@swasth.app. We will respond within 30 days of receiving your request.'**
  String get ppContact;

  /// No description provided for @tosTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get tosTitle;

  /// No description provided for @tosAcceptanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Acceptance of Terms'**
  String get tosAcceptanceTitle;

  /// No description provided for @tosAcceptance.
  ///
  /// In en, this message translates to:
  /// **'By using Swasth, you agree to these Terms of Service. If you do not agree, do not use the app. These terms apply to all users including patients, family members, and caregivers.'**
  String get tosAcceptance;

  /// No description provided for @tosServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Service Description'**
  String get tosServiceTitle;

  /// No description provided for @tosService.
  ///
  /// In en, this message translates to:
  /// **'Swasth is a personal health monitoring app that helps you track blood glucose, blood pressure, and related health metrics. It provides AI-generated health insights for informational purposes only. Swasth is not a clinical service, telemedicine platform, or regulated medical device.'**
  String get tosService;

  /// No description provided for @tosAiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Insights Disclaimer'**
  String get tosAiTitle;

  /// No description provided for @tosAi.
  ///
  /// In en, this message translates to:
  /// **'AI-generated content in Swasth is informational only. It is not a substitute for professional medical advice, diagnosis, or prescription. Never change medication, diet, or treatment based solely on app insights. Always consult your doctor before making health decisions.'**
  String get tosAi;

  /// No description provided for @tosDoctorTitle.
  ///
  /// In en, this message translates to:
  /// **'Doctor Data Sharing'**
  String get tosDoctorTitle;

  /// No description provided for @tosDoctor.
  ///
  /// In en, this message translates to:
  /// **'When you link a doctor to your profile, you consent to sharing your health data with that doctor. Swasth is not responsible for how doctors use the data shared with them. Doctors using the platform are independently responsible for compliance with NMC ethical guidelines. You can revoke doctor access at any time.'**
  String get tosDoctor;

  /// No description provided for @tosLiabilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Limitation of Liability'**
  String get tosLiabilityTitle;

  /// No description provided for @tosLiability.
  ///
  /// In en, this message translates to:
  /// **'To the maximum extent permitted by Indian law, Swasth and its founders, employees, and service providers shall not be liable for any health outcomes, clinical decisions, or damages arising from use of this app. The app is provided \'as is\'. Platform liability is limited to the subscription fee paid, if any.'**
  String get tosLiability;

  /// No description provided for @tosTerminationTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Termination'**
  String get tosTerminationTitle;

  /// No description provided for @tosTermination.
  ///
  /// In en, this message translates to:
  /// **'You may delete your account at any time from the app settings. All your data will be permanently deleted within 30 days. Swasth may suspend accounts that violate these terms.'**
  String get tosTermination;

  /// No description provided for @tosGoverningTitle.
  ///
  /// In en, this message translates to:
  /// **'Governing Law'**
  String get tosGoverningTitle;

  /// No description provided for @tosGoverning.
  ///
  /// In en, this message translates to:
  /// **'These terms are governed by the laws of India. Disputes shall be subject to the exclusive jurisdiction of courts in New Delhi, India. These terms comply with the Digital Personal Data Protection Act 2023 (DPDPA). Last updated: May 2026.'**
  String get tosGoverning;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Swasth AI'**
  String get chatTitle;

  /// No description provided for @chatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ONLINE & ANALYZING'**
  String get chatSubtitle;

  /// No description provided for @chatPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Ask about your health...'**
  String get chatPlaceholder;

  /// No description provided for @chatEmptyState.
  ///
  /// In en, this message translates to:
  /// **'Ask me anything about your health readings, medications, diet, or lifestyle. I have access to your health data and past conversations.'**
  String get chatEmptyState;

  /// No description provided for @chatQuotaRemaining.
  ///
  /// In en, this message translates to:
  /// **'questions remaining today'**
  String get chatQuotaRemaining;

  /// No description provided for @chatQuotaExceeded.
  ///
  /// In en, this message translates to:
  /// **'Daily question limit reached. Resets at midnight.'**
  String get chatQuotaExceeded;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Some features may be limited.'**
  String get offlineBanner;

  /// No description provided for @backOnline.
  ///
  /// In en, this message translates to:
  /// **'Back online! Syncing your data...'**
  String get backOnline;

  /// No description provided for @loggedInOffline.
  ///
  /// In en, this message translates to:
  /// **'Logged in offline'**
  String get loggedInOffline;

  /// No description provided for @readingSavedOffline.
  ///
  /// In en, this message translates to:
  /// **'Reading saved offline. Will sync when connected.'**
  String get readingSavedOffline;

  /// No description provided for @syncComplete.
  ///
  /// In en, this message translates to:
  /// **'Synced {count} readings'**
  String syncComplete(int count);

  /// No description provided for @offlineLoginExpired.
  ///
  /// In en, this message translates to:
  /// **'Please connect to the internet to log in'**
  String get offlineLoginExpired;

  /// No description provided for @heartStatusHealthy.
  ///
  /// In en, this message translates to:
  /// **'You\'re doing great'**
  String get heartStatusHealthy;

  /// No description provided for @heartStatusCaution.
  ///
  /// In en, this message translates to:
  /// **'Monitor closely today'**
  String get heartStatusCaution;

  /// No description provided for @heartStatusUrgent.
  ///
  /// In en, this message translates to:
  /// **'Call your doctor today'**
  String get heartStatusUrgent;

  /// No description provided for @heartFaceHealthy.
  ///
  /// In en, this message translates to:
  /// **'All is well'**
  String get heartFaceHealthy;

  /// No description provided for @heartFaceCaution.
  ///
  /// In en, this message translates to:
  /// **'Stay alert today'**
  String get heartFaceCaution;

  /// No description provided for @heartFaceUrgent.
  ///
  /// In en, this message translates to:
  /// **'Need doctor\'s help'**
  String get heartFaceUrgent;

  /// No description provided for @heartCallDoctor.
  ///
  /// In en, this message translates to:
  /// **'Call your doctor now'**
  String get heartCallDoctor;

  /// No description provided for @doctorContactNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'No doctor contact available. Please link a doctor first.'**
  String get doctorContactNotAvailable;

  /// No description provided for @quickSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Log Meal'**
  String get quickSelectTitle;

  /// No description provided for @mealHighCarb.
  ///
  /// In en, this message translates to:
  /// **'Heavy — Rice / Roti'**
  String get mealHighCarb;

  /// No description provided for @mealLowCarb.
  ///
  /// In en, this message translates to:
  /// **'Light — Sabzi / Dal'**
  String get mealLowCarb;

  /// No description provided for @mealSweets.
  ///
  /// In en, this message translates to:
  /// **'Sweets / Meetha'**
  String get mealSweets;

  /// No description provided for @mealHighProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein — Egg / Paneer'**
  String get mealHighProtein;

  /// No description provided for @mealModerateCarb.
  ///
  /// In en, this message translates to:
  /// **'Mixed / Balanced'**
  String get mealModerateCarb;

  /// No description provided for @mealMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get mealMoreOptions;

  /// No description provided for @mealLessOptions.
  ///
  /// In en, this message translates to:
  /// **'Less options'**
  String get mealLessOptions;

  /// No description provided for @mealSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Meal logged!'**
  String get mealSavedSuccess;

  /// Shown when a meal is saved while device is offline, queued for later sync.
  ///
  /// In en, this message translates to:
  /// **'Meal saved offline. Will sync when connected.'**
  String get mealSavedOffline;

  /// No description provided for @mealTypeBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get mealTypeBreakfast;

  /// No description provided for @mealTypeLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get mealTypeLunch;

  /// No description provided for @mealTypeSnack.
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get mealTypeSnack;

  /// No description provided for @mealTypeDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get mealTypeDinner;

  /// Section header for recent meals in doctor patient detail screen
  ///
  /// In en, this message translates to:
  /// **'Recent Meals'**
  String get sectionMeals;

  /// Empty state when no meals found in last 7 days
  ///
  /// In en, this message translates to:
  /// **'No meals logged in the last 7 days'**
  String get noMealsLast7Days;

  /// Button to show all meals
  ///
  /// In en, this message translates to:
  /// **'Show all {count} meals'**
  String showAllMeals(int count);

  /// No description provided for @mealDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'For general wellness, not medical advice'**
  String get mealDisclaimer;

  /// No description provided for @foodPhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Take Food Photo'**
  String get foodPhotoTitle;

  /// No description provided for @foodPhotoHint.
  ///
  /// In en, this message translates to:
  /// **'Point camera at your food'**
  String get foodPhotoHint;

  /// No description provided for @foodPhotoGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get foodPhotoGallery;

  /// No description provided for @foodPhotoAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing your food...'**
  String get foodPhotoAnalyzing;

  /// No description provided for @foodPhotoFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not classify food. Please select manually.'**
  String get foodPhotoFailed;

  /// Error message when device has no camera available
  ///
  /// In en, this message translates to:
  /// **'No camera found on this device.'**
  String get cameraNotFound;

  /// Generic camera error message - never leak raw exception details to user
  ///
  /// In en, this message translates to:
  /// **'Camera initialization failed. Please try again.'**
  String get cameraError;

  /// No description provided for @foodResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Meal Result'**
  String get foodResultTitle;

  /// No description provided for @foodCategoryHighCarb.
  ///
  /// In en, this message translates to:
  /// **'High Carb'**
  String get foodCategoryHighCarb;

  /// No description provided for @foodCategoryModerateCarb.
  ///
  /// In en, this message translates to:
  /// **'Moderate Carb'**
  String get foodCategoryModerateCarb;

  /// No description provided for @foodCategoryLowCarb.
  ///
  /// In en, this message translates to:
  /// **'Low Carb'**
  String get foodCategoryLowCarb;

  /// No description provided for @foodCategoryHighProtein.
  ///
  /// In en, this message translates to:
  /// **'High Protein'**
  String get foodCategoryHighProtein;

  /// No description provided for @foodCategorySweets.
  ///
  /// In en, this message translates to:
  /// **'Sweets'**
  String get foodCategorySweets;

  /// No description provided for @foodMealTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Meal Type'**
  String get foodMealTypeLabel;

  /// No description provided for @foodNotCorrectChange.
  ///
  /// In en, this message translates to:
  /// **'Not correct? Change'**
  String get foodNotCorrectChange;

  /// No description provided for @foodDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'For general wellness, not medical advice'**
  String get foodDisclaimer;

  /// No description provided for @foodPhotoSaved.
  ///
  /// In en, this message translates to:
  /// **'Meal saved!'**
  String get foodPhotoSaved;

  /// No description provided for @foodPhotoSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save meal. Please try again.'**
  String get foodPhotoSaveFailed;

  /// No description provided for @mealsTileLabel.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get mealsTileLabel;

  /// No description provided for @mealsTodayCount.
  ///
  /// In en, this message translates to:
  /// **'{count} today'**
  String mealsTodayCount(int count);

  /// No description provided for @todaysMeals.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Meals'**
  String get todaysMeals;

  /// No description provided for @noMealsToday.
  ///
  /// In en, this message translates to:
  /// **'No meals logged today'**
  String get noMealsToday;

  /// No description provided for @tapToLogMeal.
  ///
  /// In en, this message translates to:
  /// **'Tap to log'**
  String get tapToLogMeal;

  /// No description provided for @logMeal.
  ///
  /// In en, this message translates to:
  /// **'Log Meal'**
  String get logMeal;

  /// No description provided for @logMealSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How would you like to log?'**
  String get logMealSubtitle;

  /// No description provided for @quickSelectOption.
  ///
  /// In en, this message translates to:
  /// **'Quick Select'**
  String get quickSelectOption;

  /// No description provided for @scanFoodPhotoOption.
  ///
  /// In en, this message translates to:
  /// **'Scan Food Photo'**
  String get scanFoodPhotoOption;

  /// No description provided for @photoAiHint.
  ///
  /// In en, this message translates to:
  /// **'Photo lets AI detect carb level automatically'**
  String get photoAiHint;

  /// No description provided for @wellnessHubTitle.
  ///
  /// In en, this message translates to:
  /// **'{relationship}\'s Wellness Hub'**
  String wellnessHubTitle(String relationship);

  /// No description provided for @wellnessHubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{name} | {location}'**
  String wellnessHubSubtitle(String name, String location);

  /// No description provided for @caregiverStatusGreat.
  ///
  /// In en, this message translates to:
  /// **'Your {relationship} is doing great today. Vitals are stable.'**
  String caregiverStatusGreat(String relationship);

  /// No description provided for @caregiverStatusCaution.
  ///
  /// In en, this message translates to:
  /// **'Your {relationship} needs attention today. Check vitals.'**
  String caregiverStatusCaution(String relationship);

  /// No description provided for @caregiverStatusUrgent.
  ///
  /// In en, this message translates to:
  /// **'Your {relationship} needs immediate care. Call now.'**
  String caregiverStatusUrgent(String relationship);

  /// No description provided for @activityFeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity Feed'**
  String get activityFeedTitle;

  /// No description provided for @careCircleTitle.
  ///
  /// In en, this message translates to:
  /// **'Care Circle'**
  String get careCircleTitle;

  /// No description provided for @priorityCall.
  ///
  /// In en, this message translates to:
  /// **'Priority Call'**
  String get priorityCall;

  /// No description provided for @noRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'No recent activity'**
  String get noRecentActivity;

  /// No description provided for @wellnessRingTitle.
  ///
  /// In en, this message translates to:
  /// **'Wellness Ring'**
  String get wellnessRingTitle;

  /// No description provided for @takeReadings.
  ///
  /// In en, this message translates to:
  /// **'Take Readings'**
  String get takeReadings;

  /// No description provided for @backToWellnessHub.
  ///
  /// In en, this message translates to:
  /// **'Back to Wellness Hub'**
  String get backToWellnessHub;

  /// Title for glucometer prerequisites section
  ///
  /// In en, this message translates to:
  /// **'Glucometer – Prerequisites:'**
  String get glucometerPrerequisites;

  /// Status message when no device is connected
  ///
  /// In en, this message translates to:
  /// **'Tap a device icon above to connect'**
  String get tapDeviceToConnect;

  /// Instruction to tap and connect device
  ///
  /// In en, this message translates to:
  /// **'Tap to connect device'**
  String get tapToConnectDevice;

  /// Message when device is already connected
  ///
  /// In en, this message translates to:
  /// **'{deviceType} is already connected. Scan for another {deviceType}?'**
  String alreadyConnectedMessage(Object deviceType);

  /// Confirmation message to scan for device
  ///
  /// In en, this message translates to:
  /// **'Scan for {deviceType}?'**
  String scanForDeviceMessage(Object deviceType);

  /// Hint for BP device transfer mode
  ///
  /// In en, this message translates to:
  /// **'\n\nPress BT on the device once first (slow LED = transfer mode).'**
  String get bpTransferHint;

  /// Button to connect device
  ///
  /// In en, this message translates to:
  /// **'Connect {deviceType}'**
  String connectDeviceType(Object deviceType);

  /// Button to start scanning
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// Title for BP history section
  ///
  /// In en, this message translates to:
  /// **'BP History'**
  String get bpHistory;

  /// Count of records
  ///
  /// In en, this message translates to:
  /// **'{count} records'**
  String recordsCount(int count);

  /// Title for all records section
  ///
  /// In en, this message translates to:
  /// **'All Records'**
  String get allRecords;

  /// Tooltip for history button
  ///
  /// In en, this message translates to:
  /// **'View All History'**
  String get viewAllHistory;

  /// Message shown when device is disconnected
  ///
  /// In en, this message translates to:
  /// **'Device disconnected'**
  String get deviceDisconnected;

  /// Default name for unnamed BLE devices
  ///
  /// In en, this message translates to:
  /// **'Unknown Device'**
  String get unknownDevice;

  /// BLE device signal strength
  ///
  /// In en, this message translates to:
  /// **'Signal: {rssi} dBm'**
  String signalStrength(int rssi);

  /// Button to rescan for devices
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get rescan;

  /// No description provided for @linkDoctorTitle.
  ///
  /// In en, this message translates to:
  /// **'Link a Doctor'**
  String get linkDoctorTitle;

  /// No description provided for @linkDoctorHeadline.
  ///
  /// In en, this message translates to:
  /// **'Share your health readings with a doctor'**
  String get linkDoctorHeadline;

  /// No description provided for @linkDoctorCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Doctor Code'**
  String get linkDoctorCodeLabel;

  /// No description provided for @linkDoctorCodeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. DRRAJ52'**
  String get linkDoctorCodeHint;

  /// No description provided for @linkDoctorCodeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a doctor code'**
  String get linkDoctorCodeEmpty;

  /// No description provided for @linkDoctorCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Doctor code is too short'**
  String get linkDoctorCodeInvalid;

  /// No description provided for @linkDoctorLookupButton.
  ///
  /// In en, this message translates to:
  /// **'Find Doctor'**
  String get linkDoctorLookupButton;

  /// No description provided for @linkDoctorLookupFailed.
  ///
  /// In en, this message translates to:
  /// **'Doctor not found. Check the code.'**
  String get linkDoctorLookupFailed;

  /// No description provided for @linkDoctorCodeHelper.
  ///
  /// In en, this message translates to:
  /// **'Ask your doctor for their Swasth code (starts with DR)'**
  String get linkDoctorCodeHelper;

  /// No description provided for @linkDoctorPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick your doctor'**
  String get linkDoctorPickerTitle;

  /// No description provided for @linkDoctorPickerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap the doctor you want to share your readings with.'**
  String get linkDoctorPickerSubtitle;

  /// No description provided for @linkDoctorAlreadyLinked.
  ///
  /// In en, this message translates to:
  /// **'This doctor can already see this profile.'**
  String get linkDoctorAlreadyLinked;

  /// No description provided for @linkDoctorAlreadyLinkedBadge.
  ///
  /// In en, this message translates to:
  /// **'Already sharing'**
  String get linkDoctorAlreadyLinkedBadge;

  /// No description provided for @linkDoctorPreviouslyDeclinedBadge.
  ///
  /// In en, this message translates to:
  /// **'Previously declined - can request again'**
  String get linkDoctorPreviouslyDeclinedBadge;

  /// No description provided for @linkDoctorOr.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get linkDoctorOr;

  /// No description provided for @linkDoctorEnterNewCode.
  ///
  /// In en, this message translates to:
  /// **'Enter a new doctor\'s code'**
  String get linkDoctorEnterNewCode;

  /// No description provided for @linkDoctorConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'How did you meet this doctor?'**
  String get linkDoctorConsentTitle;

  /// No description provided for @linkDoctorConsentInPerson.
  ///
  /// In en, this message translates to:
  /// **'In-person visit at clinic'**
  String get linkDoctorConsentInPerson;

  /// No description provided for @linkDoctorConsentInPersonHelp.
  ///
  /// In en, this message translates to:
  /// **'I have visited this doctor at the clinic.'**
  String get linkDoctorConsentInPersonHelp;

  /// No description provided for @linkDoctorConsentVideo.
  ///
  /// In en, this message translates to:
  /// **'Video or phone consultation'**
  String get linkDoctorConsentVideo;

  /// No description provided for @linkDoctorConsentVideoHelp.
  ///
  /// In en, this message translates to:
  /// **'I have talked to this doctor over video or phone.'**
  String get linkDoctorConsentVideoHelp;

  /// No description provided for @linkDoctorNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Verification pending'**
  String get linkDoctorNotVerified;

  /// No description provided for @linkDoctorNotVerifiedHelp.
  ///
  /// In en, this message translates to:
  /// **'This doctor is registered but Swasth is still checking their NMC number. You can link once verification is complete.'**
  String get linkDoctorNotVerifiedHelp;

  /// No description provided for @linkDoctorVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified doctor'**
  String get linkDoctorVerified;

  /// No description provided for @linkDoctorConfirm.
  ///
  /// In en, this message translates to:
  /// **'Share my readings'**
  String get linkDoctorConfirm;

  /// No description provided for @linkDoctorConfirmDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Share your readings?'**
  String get linkDoctorConfirmDialogTitle;

  /// No description provided for @linkDoctorConfirmDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Dr. {name} will be able to see your past and future health readings. You can stop sharing any time from your profile.'**
  String linkDoctorConfirmDialogBody(String name);

  /// No description provided for @linkDoctorConfirmDialogShare.
  ///
  /// In en, this message translates to:
  /// **'Yes, share'**
  String get linkDoctorConfirmDialogShare;

  /// No description provided for @linkDoctorNmcDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Sharing readings does not create a doctor-patient relationship. Your doctor must confirm any treatment separately. In an emergency, call 108.'**
  String get linkDoctorNmcDisclaimer;

  /// No description provided for @linkDoctorRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent to {name}. You will get access once the doctor accepts.'**
  String linkDoctorRequestSent(String name);

  /// No description provided for @linkDoctorSuccess.
  ///
  /// In en, this message translates to:
  /// **'You are now linked to {name}.'**
  String linkDoctorSuccess(String name);

  /// No description provided for @linkDoctorRevokeHint.
  ///
  /// In en, this message translates to:
  /// **'You can stop sharing any time from your profile.'**
  String get linkDoctorRevokeHint;

  /// No description provided for @linkDoctorNoProfile.
  ///
  /// In en, this message translates to:
  /// **'Please select a profile first'**
  String get linkDoctorNoProfile;

  /// No description provided for @linkDoctorSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please log out and log in again.'**
  String get linkDoctorSessionExpired;

  /// No description provided for @linkDoctorNetworkError.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Please try again.'**
  String get linkDoctorNetworkError;

  /// No description provided for @doctorRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Doctor Sign Up'**
  String get doctorRegisterTitle;

  /// No description provided for @doctorRegisterHeadline.
  ///
  /// In en, this message translates to:
  /// **'Register as a Doctor'**
  String get doctorRegisterHeadline;

  /// No description provided for @doctorRegisterSubheadline.
  ///
  /// In en, this message translates to:
  /// **'Your NMC number will be verified by the Swasth team before you can see patients.'**
  String get doctorRegisterSubheadline;

  /// No description provided for @doctorFullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get doctorFullNameLabel;

  /// No description provided for @doctorNmcLabel.
  ///
  /// In en, this message translates to:
  /// **'NMC Registration Number'**
  String get doctorNmcLabel;

  /// No description provided for @doctorNmcHint.
  ///
  /// In en, this message translates to:
  /// **'Medical council number'**
  String get doctorNmcHint;

  /// No description provided for @doctorNmcEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your NMC number'**
  String get doctorNmcEmpty;

  /// No description provided for @doctorSpecialtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Specialty'**
  String get doctorSpecialtyLabel;

  /// No description provided for @doctorClinicLabel.
  ///
  /// In en, this message translates to:
  /// **'Clinic or Hospital Name'**
  String get doctorClinicLabel;

  /// No description provided for @doctorRegisterSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create Doctor Account'**
  String get doctorRegisterSubmit;

  /// No description provided for @doctorRegisterSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account created. A Swasth admin will verify your NMC number soon.'**
  String get doctorRegisterSuccess;

  /// No description provided for @doctorSpecialtyGeneral.
  ///
  /// In en, this message translates to:
  /// **'General Physician'**
  String get doctorSpecialtyGeneral;

  /// No description provided for @doctorSpecialtyEndocrinologist.
  ///
  /// In en, this message translates to:
  /// **'Endocrinologist'**
  String get doctorSpecialtyEndocrinologist;

  /// No description provided for @doctorSpecialtyCardiologist.
  ///
  /// In en, this message translates to:
  /// **'Cardiologist'**
  String get doctorSpecialtyCardiologist;

  /// No description provided for @doctorSpecialtyDiabetologist.
  ///
  /// In en, this message translates to:
  /// **'Diabetologist'**
  String get doctorSpecialtyDiabetologist;

  /// No description provided for @doctorSpecialtyInternal.
  ///
  /// In en, this message translates to:
  /// **'Internal Medicine'**
  String get doctorSpecialtyInternal;

  /// No description provided for @doctorSpecialtyFamily.
  ///
  /// In en, this message translates to:
  /// **'Family Medicine'**
  String get doctorSpecialtyFamily;

  /// No description provided for @doctorSpecialtyGynaecology.
  ///
  /// In en, this message translates to:
  /// **'Gynaecology'**
  String get doctorSpecialtyGynaecology;

  /// No description provided for @doctorSpecialtyPaediatrics.
  ///
  /// In en, this message translates to:
  /// **'Paediatrics'**
  String get doctorSpecialtyPaediatrics;

  /// No description provided for @doctorSpecialtyGeneralSurgery.
  ///
  /// In en, this message translates to:
  /// **'General Surgery'**
  String get doctorSpecialtyGeneralSurgery;

  /// No description provided for @doctorSpecialtyOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get doctorSpecialtyOther;

  /// No description provided for @adminCreateUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Create User'**
  String get adminCreateUserTitle;

  /// No description provided for @adminCreateUserHeadline.
  ///
  /// In en, this message translates to:
  /// **'Create a patient account'**
  String get adminCreateUserHeadline;

  /// No description provided for @adminCreateUserRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Account Type'**
  String get adminCreateUserRoleLabel;

  /// No description provided for @adminCreateUserRolePatient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get adminCreateUserRolePatient;

  /// No description provided for @adminCreateUserRoleDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor (coming soon)'**
  String get adminCreateUserRoleDoctor;

  /// No description provided for @adminCreateUserDoctorComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Doctor accounts must be created via the doctor self-signup flow for now.'**
  String get adminCreateUserDoctorComingSoon;

  /// No description provided for @adminCreateUserTempPasswordHelp.
  ///
  /// In en, this message translates to:
  /// **'Share this password securely with the user. They can change it from their Profile screen.'**
  String get adminCreateUserTempPasswordHelp;

  /// No description provided for @adminCreateUserSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get adminCreateUserSubmit;

  /// No description provided for @adminCreateUserSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account created for {email}'**
  String adminCreateUserSuccess(String email);

  /// No description provided for @adminCreateUserNmcRequired.
  ///
  /// In en, this message translates to:
  /// **'NMC number is required for doctor accounts'**
  String get adminCreateUserNmcRequired;

  /// No description provided for @emailVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Email'**
  String get emailVerificationTitle;

  /// No description provided for @emailVerificationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {email}. Enter it below to verify your email address.'**
  String emailVerificationSubtitle(String email);

  /// No description provided for @verifyEmailButton.
  ///
  /// In en, this message translates to:
  /// **'Verify Email'**
  String get verifyEmailButton;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow;

  /// No description provided for @emailNotVerifiedBanner.
  ///
  /// In en, this message translates to:
  /// **'Please verify your email address'**
  String get emailNotVerifiedBanner;

  /// No description provided for @emailVerifiedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Email verified successfully!'**
  String get emailVerifiedSuccess;

  /// No description provided for @verifyEmailDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Email'**
  String get verifyEmailDialogTitle;

  /// No description provided for @verifyEmailDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'Verify your email for account security. You can also do this later.'**
  String get verifyEmailDialogMessage;

  /// No description provided for @verifyNow.
  ///
  /// In en, this message translates to:
  /// **'Verify Now'**
  String get verifyNow;

  /// No description provided for @verifyLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get verifyLater;

  /// No description provided for @emailVerificationOtpSent.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent to your email'**
  String get emailVerificationOtpSent;

  /// No description provided for @emailVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send verification code'**
  String get emailVerificationFailed;

  /// No description provided for @otpValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter the code'**
  String get otpValidationEmpty;

  /// No description provided for @otpValidationLength.
  ///
  /// In en, this message translates to:
  /// **'Code must be 6 digits'**
  String get otpValidationLength;

  /// No description provided for @otpValidationDigitsOnly.
  ///
  /// In en, this message translates to:
  /// **'Code must contain only numbers'**
  String get otpValidationDigitsOnly;

  /// No description provided for @loginModeEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginModeEmail;

  /// No description provided for @loginModePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get loginModePhone;

  /// No description provided for @emailOrPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Email or Phone Number'**
  String get emailOrPhoneLabel;

  /// No description provided for @phoneNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumberLabel;

  /// No description provided for @phoneNumberHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 9876543210'**
  String get phoneNumberHint;

  /// No description provided for @phoneValidationInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number (10-15 digits)'**
  String get phoneValidationInvalid;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @phoneLoginNoAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Not Found'**
  String get phoneLoginNoAccountTitle;

  /// No description provided for @phoneLoginNoAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'No account found with this phone number. Would you like to create a new account?'**
  String get phoneLoginNoAccountMessage;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @verifyPhoneOTP.
  ///
  /// In en, this message translates to:
  /// **'Verify Phone OTP'**
  String get verifyPhoneOTP;

  /// No description provided for @otpSentToPhone.
  ///
  /// In en, this message translates to:
  /// **'OTP sent to {phone}'**
  String otpSentToPhone(String phone);

  /// No description provided for @nameValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get nameValidationEmpty;

  /// No description provided for @nameValidationTooShort.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get nameValidationTooShort;

  /// No description provided for @verifyOTP.
  ///
  /// In en, this message translates to:
  /// **'Verify OTP'**
  String get verifyOTP;

  /// No description provided for @didntReceiveOTP.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive code?'**
  String get didntReceiveOTP;

  /// No description provided for @resendOTP.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP'**
  String get resendOTP;

  /// No description provided for @accountCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account created successfully! Please complete your profile.'**
  String get accountCreatedSuccess;

  /// Title for the detailed nutrition analysis screen showing macros, micros, and diet flags
  ///
  /// In en, this message translates to:
  /// **'Nutrition Analysis'**
  String get nutritionAnalysisTitle;

  /// Label for carbohydrate level badge (low/medium/high) in nutrition analysis
  ///
  /// In en, this message translates to:
  /// **'Carb Level'**
  String get carbLevel;

  /// Label for sugar level badge (low/medium/high) in nutrition analysis
  ///
  /// In en, this message translates to:
  /// **'Sugar'**
  String get sugarLevel;

  /// Section header for total macronutrients summary
  ///
  /// In en, this message translates to:
  /// **'Total Nutrition'**
  String get totalNutrition;

  /// Section header for list of individual food items detected in the photo
  ///
  /// In en, this message translates to:
  /// **'Detected Foods'**
  String get detectedFoods;

  /// Empty state message when AI returns empty foods array
  ///
  /// In en, this message translates to:
  /// **'No specific foods detected. This may happen with liquid meals or unclear images.'**
  String get noFoodsDetected;

  /// Section header for micronutrients (iron, calcium, vitamin C)
  ///
  /// In en, this message translates to:
  /// **'Micronutrients'**
  String get micronutrients;

  /// Section header for diet type flags (vegan, vegetarian, gluten-free, high protein)
  ///
  /// In en, this message translates to:
  /// **'Diet Information'**
  String get dietFlags;

  /// Button text to save the analyzed meal to the meal log
  ///
  /// In en, this message translates to:
  /// **'Save Meal Log'**
  String get saveMeal;

  /// Label for the meal health score (1-10) shown in the score card
  ///
  /// In en, this message translates to:
  /// **'Meal Health Score'**
  String get mealHealthScore;

  /// Label for calories in the macronutrients grid
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get calories;

  /// Label for carbohydrates (grams) in the macronutrients grid
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get carbs;

  /// Label for protein (grams) in the macronutrients grid
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get protein;

  /// Label for fat (grams) in the macronutrients grid
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get fat;

  /// Diet flag label indicating the meal is vegan
  ///
  /// In en, this message translates to:
  /// **'Vegan'**
  String get vegan;

  /// Diet flag label indicating the meal is vegetarian
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get vegetarian;

  /// Diet flag label indicating the meal is gluten-free
  ///
  /// In en, this message translates to:
  /// **'Gluten Free'**
  String get glutenFree;

  /// Diet flag label indicating the meal is high in protein
  ///
  /// In en, this message translates to:
  /// **'High Protein'**
  String get highProtein;

  /// Title for the screen where user chooses between quick classification or detailed nutrition analysis
  ///
  /// In en, this message translates to:
  /// **'Choose Analysis Type'**
  String get analysisTypeTitle;

  /// Button text for fast carb level detection option
  ///
  /// In en, this message translates to:
  /// **'Quick Classification'**
  String get quickClassification;

  /// Description text for quick classification option
  ///
  /// In en, this message translates to:
  /// **'Carb level + health tip (fast)'**
  String get quickClassificationDesc;

  /// Button text for full nutrition analysis option with macros and micros
  ///
  /// In en, this message translates to:
  /// **'Detailed Nutrition'**
  String get detailedNutrition;

  /// Description text for detailed nutrition analysis option
  ///
  /// In en, this message translates to:
  /// **'Full macros, micros & diet flags'**
  String get detailedNutritionDesc;

  /// Loading message shown while AI analyzes the food photo for nutrition details
  ///
  /// In en, this message translates to:
  /// **'Analyzing nutrition details...'**
  String get nutritionAnalyzing;

  /// Label for iron micronutrient in mg
  ///
  /// In en, this message translates to:
  /// **'Iron'**
  String get iron;

  /// Label for calcium micronutrient in mg
  ///
  /// In en, this message translates to:
  /// **'Calcium'**
  String get calcium;

  /// Label for vitamin C micronutrient in mg
  ///
  /// In en, this message translates to:
  /// **'Vitamin C'**
  String get vitaminC;

  /// Unit abbreviation for kilocalories
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get kcalUnit;

  /// Unit abbreviation for grams
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get gramsUnit;

  /// Short label for carbohydrates in mini macro badges
  ///
  /// In en, this message translates to:
  /// **'carbs'**
  String get carbsUnit;

  /// Short label for protein in mini macro badges
  ///
  /// In en, this message translates to:
  /// **'protein'**
  String get proteinUnit;

  /// Short label for fat in mini macro badges
  ///
  /// In en, this message translates to:
  /// **'fat'**
  String get fatUnit;

  /// Button text to fallback to manual meal selection if photo analysis fails
  ///
  /// In en, this message translates to:
  /// **'Use Quick Select instead'**
  String get useQuickSelect;

  /// NMC-required disclaimer shown on all AI-generated health insights
  ///
  /// In en, this message translates to:
  /// **'This is information, not a prescription. Consult your doctor before making any changes.'**
  String get nmcDisclaimer;

  /// App name displayed on splash screen
  ///
  /// In en, this message translates to:
  /// **'Swasth'**
  String get splashAppName;

  /// Tagline displayed on splash screen below app name
  ///
  /// In en, this message translates to:
  /// **'Your Health Companion'**
  String get splashTagline;

  /// Loading message shown during app initialization on splash screen
  ///
  /// In en, this message translates to:
  /// **'Initializing...'**
  String get splashInitializing;

  /// Loading message when checking network connectivity on splash screen
  ///
  /// In en, this message translates to:
  /// **'Checking connection...'**
  String get splashCheckingConnection;

  /// Loading message when app is operating in offline mode on splash screen
  ///
  /// In en, this message translates to:
  /// **'Working offline...'**
  String get splashWorkingOffline;

  /// Loading message when fetching user profile data on splash screen
  ///
  /// In en, this message translates to:
  /// **'Loading your profile...'**
  String get splashLoadingProfile;

  /// Loading message when checking for saved login credentials on splash screen
  ///
  /// In en, this message translates to:
  /// **'Checking saved credentials...'**
  String get splashCheckingCredentials;

  /// Loading message when performing automatic sign-in on splash screen
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get splashSigningIn;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
