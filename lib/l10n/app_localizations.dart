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

  /// No description provided for @otpSentTo.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a 6-digit OTP to\n{email}'**
  String otpSentTo(String email);

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
