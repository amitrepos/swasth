// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'स्वस्थ हेल्थ ऐप';

  @override
  String get appName => 'स्वस्थ';

  @override
  String get loading => 'लोड हो रहा है...';

  @override
  String get retry => 'दोबारा कोशिश करें';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get save => 'सेव करें';

  @override
  String get delete => 'हटाएं';

  @override
  String get edit => 'बदलें';

  @override
  String get accept => 'स्वीकार करें';

  @override
  String get reject => 'अस्वीकार करें';

  @override
  String get invite => 'आमंत्रित करें';

  @override
  String get revoke => 'हटाएं';

  @override
  String get connect => 'जोड़ें';

  @override
  String get refresh => 'ताज़ा करें';

  @override
  String get logout => 'लॉग आउट';

  @override
  String get profile => 'प्रोफाइल';

  @override
  String get error => 'गड़बड़ी';

  @override
  String get loginTitle => 'लॉग इन';

  @override
  String get emailLabel => 'ईमेल';

  @override
  String get passwordLabel => 'पासवर्ड';

  @override
  String get forgotPassword => 'पासवर्ड भूल गए?';

  @override
  String get loginButton => 'लॉग इन करें';

  @override
  String get noAccount => 'खाता नहीं है?';

  @override
  String get register => 'रजिस्टर करें';

  @override
  String get loginSuccessful => 'लॉग इन सफल!';

  @override
  String get emailValidationEmpty => 'कृपया अपना ईमेल डालें';

  @override
  String get emailValidationInvalid => 'कृपया सही ईमेल डालें';

  @override
  String get passwordValidationEmpty => 'कृपया अपना पासवर्ड डालें';

  @override
  String get registerTitle => 'रजिस्टर';

  @override
  String get accountDetailsSection => 'खाता जानकारी';

  @override
  String get healthProfileSection => 'स्वास्थ्य प्रोफाइल';

  @override
  String get fullNameLabel => 'पूरा नाम';

  @override
  String get phoneLabel => 'फोन नंबर';

  @override
  String get confirmPasswordLabel => 'पासवर्ड दोबारा डालें';

  @override
  String get profileNameLabel => 'प्रोफाइल नाम';

  @override
  String get ageLabel => 'उम्र';

  @override
  String get genderLabel => 'लिंग';

  @override
  String get heightLabel => 'लंबाई (सेमी)';

  @override
  String get bloodGroupLabel => 'ब्लड ग्रुप';

  @override
  String get medicationsLabel => 'दवाइयां (वैकल्पिक)';

  @override
  String get medicalConditionsSection => 'बीमारियां';

  @override
  String get passwordRequirementsTitle => 'पासवर्ड की शर्तें:';

  @override
  String get passwordReqLength => 'कम से कम 8 अक्षर';

  @override
  String get passwordReqUppercase => 'एक बड़ा अक्षर';

  @override
  String get passwordReqLowercase => 'एक छोटा अक्षर';

  @override
  String get passwordReqNumber => 'एक संख्या';

  @override
  String get passwordReqSpecial => 'एक विशेष अक्षर';

  @override
  String get alreadyHaveAccount => 'पहले से खाता है?';

  @override
  String get registerSuccessful => 'रजिस्ट्रेशन सफल! कृपया लॉग इन करें।';

  @override
  String get specifyOtherCondition => 'कृपया बीमारी बताएं';

  @override
  String get selectProfileTitle => 'प्रोफाइल चुनें';

  @override
  String get myProfilesSection => 'मेरी प्रोफाइल';

  @override
  String get sharedWithMeSection => 'मेरे साथ साझा';

  @override
  String get noSharedProfiles => 'अभी कोई साझा प्रोफाइल नहीं है।';

  @override
  String get addProfile => 'प्रोफाइल जोड़ें';

  @override
  String pendingInvitesBanner(int count) {
    return 'आपके पास $count निमंत्रण हैं';
  }

  @override
  String get homeTitle => 'स्वस्थ हेल्थ ऐप';

  @override
  String viewingProfile(String name) {
    return '$name की स्वास्थ्य जानकारी';
  }

  @override
  String get switchProfile => 'बदलें';

  @override
  String get shareProfile => 'प्रोफाइल साझा करें';

  @override
  String get welcomeTitle => 'स्वस्थ में आपका स्वागत है!';

  @override
  String get welcomeSubtitle => 'आपका स्वास्थ्य साथी';

  @override
  String get selectDevice => 'डिवाइस चुनें';

  @override
  String get glucometer => 'ग्लूकोमीटर';

  @override
  String get bpMeter => 'बीपी मीटर';

  @override
  String get armband => 'आर्मबैंड';

  @override
  String get quickActions => 'त्वरित कार्य';

  @override
  String get connectNewDevice => 'नया डिवाइस जोड़ें';

  @override
  String get connectNewDeviceSubtitle => 'ब्लूटूथ डिवाइस खोजें और जोड़ें';

  @override
  String get viewHistory => 'इतिहास देखें';

  @override
  String get viewHistorySubtitle => 'पिछली रीडिंग देखें';

  @override
  String get selectProfileFirst => 'पहले प्रोफाइल चुनें';

  @override
  String logReading(String device) {
    return '$device रीडिंग दर्ज करें';
  }

  @override
  String get howToLog => 'रीडिंग कैसे दर्ज करना चाहते हैं?';

  @override
  String get scanWithCamera => 'कैमरे से स्कैन करें';

  @override
  String get connectViaBluetooth => 'ब्लूटूथ से जोड़ें';

  @override
  String scanTitle(String device) {
    return '$device स्कैन करें';
  }

  @override
  String placeDeviceInBox(String device) {
    return '$device की स्क्रीन बॉक्स में रखें';
  }

  @override
  String get toggleFlash => 'फ्लैश चालू/बंद करें';

  @override
  String get photoBlurryTitle => 'फोटो धुंधला है';

  @override
  String get photoBlurryMessage =>
      'हम स्क्रीन नहीं पढ़ सके। कृपया दोबारा फोटो लें:\n\n• कैमरा स्थिर रखें\n• डिवाइस की स्क्रीन बॉक्स में रखें\n• अच्छी रोशनी या फ्लैश चालू करें';

  @override
  String get tryAgain => 'दोबारा कोशिश करें';

  @override
  String get readingImage => 'इमेज पढ़ी जा रही है...';

  @override
  String get glucoseReadingTitle => 'ग्लूकोज रीडिंग';

  @override
  String get bpReadingTitle => 'बीपी रीडिंग';

  @override
  String get glucoseValueLabel => 'ग्लूकोज मान';

  @override
  String get systolicLabel => 'सिस्टोलिक';

  @override
  String get diastolicLabel => 'डायस्टोलिक';

  @override
  String get pulseLabel => 'पल्स (वैकल्पिक)';

  @override
  String get mealContextSection => 'खाने का समय';

  @override
  String get fasting => 'खाली पेट';

  @override
  String get beforeMeal => 'खाने से पहले';

  @override
  String get afterMeal => 'खाने के बाद';

  @override
  String get readingTime => 'रीडिंग का समय';

  @override
  String get saveReading => 'रीडिंग सेव करें';

  @override
  String get readingSavedSuccess => 'रीडिंग सफलतापूर्वक सेव हुई';

  @override
  String get ocrSuccessPrefix => 'हमने पढ़ा:';

  @override
  String get ocrEditButton => 'बदलें';

  @override
  String get ocrConfirmHint => 'क्या यह सही है? सेव करने से पहले बदल सकते हैं।';

  @override
  String get ocrFailedMessage =>
      'फोटो से मान नहीं पढ़ सके। कृपया नीचे खुद डालें।';

  @override
  String get manualEntryHint => 'डिवाइस पर दिखाया गया मान डालें।';

  @override
  String get glucoseValidation => 'सही ग्लूकोज मान डालें (20–600 mg/dL)';

  @override
  String get systolicValidation => 'सही सिस्टोलिक मान डालें (60–250 mmHg)';

  @override
  String get diastolicValidation => 'सही डायस्टोलिक मान डालें (40–150 mmHg)';

  @override
  String saveFailed(String error) {
    return 'सेव नहीं हुआ: $error';
  }

  @override
  String get historyTitle => 'रीडिंग इतिहास';

  @override
  String get filterByType => 'प्रकार से छानें';

  @override
  String get allReadings => 'सभी रीडिंग';

  @override
  String get glucoseOnly => 'केवल ग्लूकोज';

  @override
  String get bpOnly => 'केवल बीपी';

  @override
  String get noReadingsYet => 'अभी कोई रीडिंग नहीं';

  @override
  String get noReadingsSubtitle =>
      'डिवाइस जोड़ें और माप लें\nयहाँ आपका इतिहास दिखेगा';

  @override
  String get deleteReading => 'रीडिंग हटाएं';

  @override
  String get deleteReadingConfirm => 'क्या आप वाकई यह रीडिंग हटाना चाहते हैं?';

  @override
  String get readingDeleted => 'रीडिंग हटाई गई';

  @override
  String get statusNormal => 'सामान्य';

  @override
  String get statusElevated => 'थोड़ा अधिक';

  @override
  String get statusHighStage1 => 'अधिक - चरण 1';

  @override
  String get statusHighStage2 => 'अधिक - चरण 2';

  @override
  String get statusLow => 'कम';

  @override
  String get statusCritical => 'गंभीर';

  @override
  String get profileDetailsTitle => 'प्रोफाइल विवरण';

  @override
  String get manageAccess => 'पहुंच प्रबंधित करें';

  @override
  String get yourProfile => 'आपकी प्रोफाइल';

  @override
  String get sharedBySomeone => 'किसी ने साझा की';

  @override
  String get healthInfoSection => 'स्वास्थ्य जानकारी';

  @override
  String get ageField => 'उम्र';

  @override
  String ageYears(String age) {
    return '$age साल';
  }

  @override
  String get genderField => 'लिंग';

  @override
  String get bloodGroupField => 'ब्लड ग्रुप';

  @override
  String get heightField => 'लंबाई';

  @override
  String heightCm(String height) {
    return '$height सेमी';
  }

  @override
  String get medicalConditionsField => 'बीमारियां';

  @override
  String get accountSettingsSection => 'खाता सेटिंग';

  @override
  String get linkedEmail => 'लिंक ईमेल';

  @override
  String get changePassword => 'पासवर्ड बदलें';

  @override
  String get changePasswordTitle => 'पासवर्ड बदलें';

  @override
  String get currentPasswordLabel => 'मौजूदा पासवर्ड';

  @override
  String get newPasswordLabel => 'नया पासवर्ड';

  @override
  String get confirmNewPasswordLabel => 'नया पासवर्ड दोबारा डालें';

  @override
  String get passwordMinChars => 'कम से कम 6 अक्षर';

  @override
  String get passwordChanged => 'पासवर्ड बदला गया!';

  @override
  String get enterCurrentPassword => 'मौजूदा पासवर्ड डालें';

  @override
  String get passwordTooShort => 'कम से कम 6 अक्षर';

  @override
  String get passwordsDoNotMatch => 'पासवर्ड मेल नहीं खाते';

  @override
  String get appLanguageSection => 'ऐप की भाषा';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'हिंदी';

  @override
  String get addHealthProfileTitle => 'स्वास्थ्य प्रोफाइल जोड़ें';

  @override
  String get createProfileSubtitle =>
      'किसी की देखभाल के लिए प्रोफाइल बनाएं (जैसे माता-पिता, बच्चा)';

  @override
  String get profileNameHint => 'जैसे पापा, मम्मी';

  @override
  String get createProfile => 'प्रोफाइल बनाएं';

  @override
  String get manageAccessTitle => 'पहुंच प्रबंधित करें';

  @override
  String get inviteSomeoneTitle =>
      'किसी को यह प्रोफाइल देखने के लिए आमंत्रित करें';

  @override
  String get enterEmailHint => 'ईमेल पता डालें';

  @override
  String get notSharedYet => 'अभी किसी के साथ साझा नहीं।';

  @override
  String get inviteSentSuccess => 'आमंत्रण सफलतापूर्वक भेजा गया';

  @override
  String get revokeAccessTitle => 'पहुंच हटाएं?';

  @override
  String revokeAccessConfirm(String name) {
    return 'क्या आप $name के साथ यह प्रोफाइल साझा करना बंद करना चाहते हैं?';
  }

  @override
  String get pendingInvitesTitle => 'लंबित आमंत्रण';

  @override
  String get noPendingInvites => 'कोई लंबित आमंत्रण नहीं।';

  @override
  String wantsToShare(String profileName) {
    return '\"$profileName\" साझा करना चाहते हैं';
  }

  @override
  String expiresInDays(int days, String date) {
    return '$days दिन में समाप्त ($date)';
  }

  @override
  String acceptedInvite(String profileName) {
    return '$profileName का आमंत्रण स्वीकार किया';
  }

  @override
  String rejectedInvite(String profileName) {
    return '$profileName का आमंत्रण अस्वीकार किया';
  }

  @override
  String get scanDevicesTitle => 'स्वस्थ — डिवाइस खोजें';

  @override
  String get pressScanToFind => 'डिवाइस खोजने के लिए स्कैन दबाएं';

  @override
  String get scanButton => 'स्कैन';

  @override
  String get scanningButton => 'स्कैन हो रहा है...';

  @override
  String get noDevicesFound => 'अभी कोई डिवाइस नहीं मिला';

  @override
  String get lookingForDevices => 'डिवाइस खोज रहे हैं...';

  @override
  String get noDevicesFoundAfterScan =>
      'कोई डिवाइस नहीं मिला। डिवाइस चालू करें।';

  @override
  String get connectButton => 'जोड़ें';

  @override
  String get forgotPasswordTitle => 'पासवर्ड भूल गए';

  @override
  String get forgotPasswordHeadline => 'पासवर्ड भूल गए?';

  @override
  String get forgotPasswordSubtitle => 'अपना ईमेल डालें, हम आपको OTP भेजेंगे।';

  @override
  String get sendOtp => 'OTP भेजें';

  @override
  String get otpSentSuccess => 'OTP सफलतापूर्वक भेजा गया! ईमेल देखें।';

  @override
  String get rememberPassword => 'पासवर्ड याद है?';

  @override
  String get verifyOtpTitle => 'OTP सत्यापित करें';

  @override
  String get enterOtpHeadline => 'OTP डालें';

  @override
  String otpSentTo(String email) {
    return 'हमने $email पर 6 अंकों का OTP भेजा है';
  }

  @override
  String get otpLabel => 'OTP';

  @override
  String get verifyOtp => 'OTP सत्यापित करें';

  @override
  String get otpVerifiedSuccess => 'OTP सत्यापित हो गया!';

  @override
  String get didNotReceiveOtp => 'OTP नहीं मिला?';

  @override
  String resendIn(int seconds) {
    return '$seconds सेकंड में दोबारा भेजें';
  }

  @override
  String get resendOtp => 'OTP दोबारा भेजें';

  @override
  String get otpResent => 'OTP दोबारा भेजा गया! ईमेल देखें।';

  @override
  String get wantToGoBack => 'वापस जाना चाहते हैं?';

  @override
  String get resetPasswordTitle => 'पासवर्ड रीसेट';

  @override
  String get createNewPasswordHeadline => 'नया पासवर्ड बनाएं';

  @override
  String get createNewPasswordSubtitle =>
      'आपका नया पासवर्ड पुराने से अलग होना चाहिए।';

  @override
  String get resetPasswordButton => 'पासवर्ड रीसेट करें';

  @override
  String get passwordResetSuccess => 'पासवर्ड सफलतापूर्वक रीसेट हुआ!';
}
