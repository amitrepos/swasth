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
  String get rememberMe => 'मुझे याद रखें';

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
  String get phoneValidationEmpty => 'कृपया अपना फोन नंबर डालें';

  @override
  String get phoneValidationDigits => 'फोन नंबर में केवल अंक होने चाहिए';

  @override
  String get phoneValidationLength => 'फोन नंबर 10-15 अंकों का होना चाहिए';

  @override
  String get confirmPasswordLabel => 'पासवर्ड दोबारा डालें';

  @override
  String get profileNameLabel => 'प्रोफाइल नाम';

  @override
  String get relationshipLabel => 'रोगी से संबंध';

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
  String get recordNewMetrics => 'नई मेट्रिक्स रिकॉर्ड करें';

  @override
  String get flagFitFine => 'स्वस्थ';

  @override
  String get flagCaution => 'सावधानी';

  @override
  String get flagAtRisk => 'जोखिम में';

  @override
  String get flagUrgent => 'तत्काल';

  @override
  String get weeklyWinnersTitle => 'इस सप्ताह शीर्ष';

  @override
  String get weeklyWinnersSoon => 'जल्द आ रहा है';

  @override
  String pointsLabel(int pts) {
    return '$pts अंक';
  }

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
  String get healthTrends => 'स्वास्थ्य ट्रेंड';

  @override
  String get sevenDays => '7 दिन';

  @override
  String get thirtyDays => '30 दिन';

  @override
  String get ninetyDays => '90 दिन';

  @override
  String get oneYear => '1 वर्ष';

  @override
  String get glucoseTrend => 'ग्लूकोज ट्रेंड';

  @override
  String get bpTrend => 'रक्तचाप ट्रेंड';

  @override
  String get avgLabel => 'औसत';

  @override
  String get minLabel => 'न्यूनतम';

  @override
  String get maxLabel => 'अधिकतम';

  @override
  String get normalPct => 'सामान्य';

  @override
  String get noChartData => 'इस अवधि में कोई रीडिंग नहीं';

  @override
  String get tapToViewTrends => 'ट्रेंड देखने के लिए टैप करें →';

  @override
  String get viewTrends => 'ट्रेंड देखें';

  @override
  String get viewTrendsSubtitle => '7 और 30-दिन के ग्लूकोज और बीपी चार्ट';

  @override
  String get healthScore => 'स्वास्थ्य स्कोर';

  @override
  String dayStreak(int n) {
    return '$n-दिन की स्ट्रीक';
  }

  @override
  String lastLogged(String time) {
    return 'अंतिम लॉग: $time';
  }

  @override
  String get noReadingsYetScore =>
      'अपना स्कोर देखने के लिए पहली रीडिंग दर्ज करें';

  @override
  String get todayGlucose => 'ग्लूकोज';

  @override
  String get todayBP => 'बीपी';

  @override
  String get scanWithCamera => 'कैमरे से स्कैन करें';

  @override
  String get connectViaBluetooth => 'ब्लूटूथ से जोड़ें';

  @override
  String get enterManually => 'मैन्युअल दर्ज करें';

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
  String get privacyPolicy => 'गोपनीयता नीति';

  @override
  String get deleteAccount => 'मेरा खाता हटाएं';

  @override
  String get deleteAccountConfirmMessage =>
      'यह आपका खाता, सभी स्वास्थ्य रीडिंग, प्रोफाइल और AI सुझाव स्थायी रूप से हटा देगा। यह क्रिया पूर्ववत नहीं की जा सकती।';

  @override
  String get deleteAccountConfirm => 'स्थायी रूप से हटाएं';

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
  String get myDoctorTitle => 'मेरे डॉक्टर';

  @override
  String get contactOnWhatsApp => 'व्हाट्सएप पर संपर्क करें';

  @override
  String get doctorDetailsSection => 'डॉक्टर की जानकारी';

  @override
  String get doctorNameField => 'डॉक्टर का नाम';

  @override
  String get doctorSpecialtyField => 'विशेषज्ञता';

  @override
  String get doctorWhatsappField => 'व्हाट्सएप नंबर';

  @override
  String get noDoctorLinked => 'अभी तक कोई डॉक्टर नहीं जोड़ा गया।';

  @override
  String get addDoctor => 'डॉक्टर जोड़ें';

  @override
  String get editDoctor => 'डॉक्टर की जानकारी बदलें';

  @override
  String get editDoctorTitle => 'डॉक्टर की जानकारी';

  @override
  String get doctorWhatsappHint => 'जैसे +917001234567';

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

  @override
  String get wellnessScoreSection => 'स्वास्थ्य स्कोर';

  @override
  String get vitalSummarySection => 'महत्वपूर्ण सारांश';

  @override
  String get ninetyDayAvg => '90 दिन औसत';

  @override
  String get aiInsightSection => 'AI स्वास्थ्य सुझाव';

  @override
  String get primaryPhysicianSection => 'मुख्य चिकित्सक';

  @override
  String get individualMetricsSection => 'व्यक्तिगत मेट्रिक्स';

  @override
  String get footerDisclaimer =>
      'यह चिकित्सा निदान नहीं है। नैदानिक सलाह के लिए अपने डॉक्टर से परामर्श करें।';

  @override
  String get goodMorning => 'सुप्रभात,';

  @override
  String get goodAfternoon => 'नमस्कार,';

  @override
  String get goodEvening => 'शुभ संध्या,';

  @override
  String get hello => 'नमस्ते,';

  @override
  String get trendStable => 'स्थिर';

  @override
  String get optimumRange => 'सामान्य सीमा';

  @override
  String get physicianConnected => 'जुड़े हुए';

  @override
  String get physicianNotLinked => 'नहीं जुड़े';

  @override
  String get activeSync => 'सक्रिय सिंक';

  @override
  String get notConnected => 'नहीं जुड़ा';

  @override
  String get lastBP => 'पिछला BP';

  @override
  String get lastSugar => 'पिछला शुगर';

  @override
  String get liveSteps => 'कदम';

  @override
  String get relationshipFather => 'पिता';

  @override
  String get relationshipMother => 'माता';

  @override
  String get relationshipSpouse => 'पति/पत्नी';

  @override
  String get relationshipSon => 'बेटा';

  @override
  String get relationshipDaughter => 'बेटी';

  @override
  String get relationshipBrother => 'भाई';

  @override
  String get relationshipSister => 'बहन';

  @override
  String get relationshipUncle => 'चाचा/मामा';

  @override
  String get relationshipAunt => 'चाची/मामी';

  @override
  String get relationshipFriend => 'दोस्त';

  @override
  String get relationshipOther => 'अन्य';

  @override
  String get consentTitle => 'गोपनीयता और सहमति';

  @override
  String get consentSubject => 'स्वास्थ्य डेटा प्रसंस्करण के लिए सहमति';

  @override
  String get consentIntro =>
      'स्वास्थ्य ऐप का उपयोग करके, मैं निम्नलिखित से सहमत हूँ:';

  @override
  String get consentDataCollectionTitle => 'डेटा संग्रह';

  @override
  String get consentDataCollection =>
      'मैं स्वास्थ्य ऐप को मेरा ब्लड शुगर, ब्लड प्रेशर और भोजन की तस्वीरें स्टोर करने की अनुमति देता/देती हूँ।';

  @override
  String get consentFamilySharingTitle => 'परिवार के साथ साझा करना';

  @override
  String get consentFamilySharing =>
      'मैं समझता/समझती हूँ कि यदि मैं अपना प्रोफाइल साझा करता/करती हूँ, तो मेरे परिवार के सदस्य (जैसे बेटा/बेटी) मेरा स्वास्थ्य स्कोर देख पाएंगे और अलर्ट प्राप्त करेंगे।';

  @override
  String get consentPurposeTitle => 'उद्देश्य';

  @override
  String get consentPurpose =>
      'मेरे डेटा का उपयोग मुझे स्वास्थ्य संबंधी जानकारी देने और मेरे डॉक्टर के साथ इलाज के लिए साझा करने में किया जाएगा।';

  @override
  String get consentRightsTitle => 'मेरे अधिकार';

  @override
  String get consentRights =>
      'मैं किसी भी समय ऐप सेटिंग्स के माध्यम से अपनी सहमति वापस ले सकता/सकती हूँ या अपना डेटा हटाने के लिए कह सकता/सकती हूँ।';

  @override
  String get consentAiTitle => 'AI-संचालित स्वास्थ्य सुझाव';

  @override
  String get consentAiBody =>
      'स्वस्थ तीसरे पक्ष की AI सेवाओं (Google Gemini और DeepSeek) का उपयोग करके व्यक्तिगत स्वास्थ्य सुझाव तैयार करता है। मेरे स्वास्थ्य डेटा का सारांश (कच्चे रीडिंग नहीं) इन सेवाओं को भेजा जा सकता है। मैं किसी भी समय इसे बंद कर सकता/सकती हूँ, और इसके बजाय नियम-आधारित सुझाव दिए जाएँगे।';

  @override
  String get consentAccept => 'मैं सहमत हूँ';

  @override
  String get consentDecline => 'मैं सहमत नहीं हूँ';

  @override
  String get consentDeclineTitle => 'सहमति अस्वीकार करें?';

  @override
  String get consentDeclineMessage =>
      'गोपनीयता सूचना स्वीकार किए बिना आप स्वास्थ्य ऐप का उपयोग नहीं कर सकते। आपका पंजीकरण पूरा नहीं होगा।';

  @override
  String get consentDeclineConfirm => 'वापस जाएँ';

  @override
  String get consentScrollToAccept =>
      'पूरी सूचना पढ़ने के लिए नीचे स्क्रॉल करें';

  @override
  String get ppDataCollectionTitle => 'हम कौन सा डेटा एकत्र करते हैं';

  @override
  String get ppDataCollection =>
      'स्वस्थ एकत्र करता है: रक्त शर्करा रीडिंग, रक्तचाप रीडिंग, पल्स रेट, भोजन नोट्स, प्रोफ़ाइल जानकारी (नाम, आयु, लिंग, चिकित्सा स्थितियाँ, दवाइयाँ), और स्वचालित रीडिंग कैप्चर के लिए चिकित्सा उपकरणों की तस्वीरें।';

  @override
  String get ppPurposeTitle => 'संग्रह का उद्देश्य';

  @override
  String get ppPurpose =>
      'आपके स्वास्थ्य डेटा का उपयोग किया जाता है: रुझान और स्वास्थ्य स्कोर दिखाने, व्यक्तिगत स्वास्थ्य सुझाव तैयार करने, आपके निर्दिष्ट परिवार के सदस्यों के साथ साझा करने, और उपचार के लिए आपके डॉक्टर को जानकारी प्रदान करने के लिए।';

  @override
  String get ppAiTitle => 'AI प्रसंस्करण';

  @override
  String get ppAi =>
      'स्वस्थ स्वास्थ्य सुझाव तैयार करने के लिए तीसरे पक्ष की AI सेवाओं — Google Gemini और DeepSeek — का उपयोग करता है। आपके डेटा का सारांश संस्करण (औसत और सीमाएँ, व्यक्तिगत रीडिंग नहीं) इन सेवाओं को भेजा जाता है। आप किसी भी समय AI प्रसंस्करण से बाहर हो सकते हैं।';

  @override
  String get ppSharingTitle => 'डेटा साझाकरण';

  @override
  String get ppSharing =>
      'आपका डेटा केवल इनके साथ साझा किया जाता है: आपके द्वारा आमंत्रित परिवार के सदस्य, AI सेवाएँ (यदि आप सहमत हैं), और आपके डॉक्टर (यदि आप साझा करना चुनते हैं)। हम आपका डेटा विज्ञापनदाताओं या किसी अन्य तीसरे पक्ष को नहीं बेचते।';

  @override
  String get ppSecurityTitle => 'सुरक्षा उपाय';

  @override
  String get ppSecurity =>
      'हम आपके डेटा की सुरक्षा करते हैं: डेटाबेस में AES-256 एन्क्रिप्शन, bcrypt पासवर्ड हैशिंग, JWT-आधारित प्रमाणीकरण, सभी डेटा ट्रांसमिशन के लिए TLS/HTTPS, और आपके डिवाइस पर एन्क्रिप्टेड स्थानीय संग्रहण।';

  @override
  String get ppRetentionTitle => 'डेटा प्रतिधारण';

  @override
  String get ppRetention =>
      'आपका डेटा तब तक संग्रहीत रहता है जब तक आपका खाता सक्रिय है। आप ऐप सेटिंग्स के माध्यम से किसी भी समय अपने सभी डेटा को हटाने का अनुरोध कर सकते हैं।';

  @override
  String get ppRightsTitle => 'आपके अधिकार';

  @override
  String get ppRights =>
      'भारतीय डेटा संरक्षण कानून (SPDI नियम 2011 और DPDP अधिनियम 2023) के तहत, आपको अधिकार है: अपना डेटा एक्सेस करने, गलतियाँ सुधारने, सहमति वापस लेने, डेटा हटाने का अनुरोध करने और शिकायत दर्ज करने का।';

  @override
  String get ppContactTitle => 'संपर्क';

  @override
  String get ppContact =>
      'गोपनीयता संबंधी प्रश्नों या शिकायतों के लिए संपर्क करें: support@swasth.app';

  @override
  String get chatTitle => 'स्वस्थ AI';

  @override
  String get chatSubtitle => 'ऑनलाइन और विश्लेषण कर रहा है';

  @override
  String get chatPlaceholder => 'अपने स्वास्थ्य के बारे में पूछें...';

  @override
  String get chatEmptyState =>
      'अपनी स्वास्थ्य रीडिंग, दवाइयों, आहार या जीवनशैली के बारे में कुछ भी पूछें। मेरे पास आपके स्वास्थ्य डेटा और पिछली बातचीत तक पहुँच है।';

  @override
  String get chatQuotaRemaining => 'प्रश्न आज शेष हैं';

  @override
  String get chatQuotaExceeded =>
      'दैनिक प्रश्न सीमा पूरी हो गई। मध्यरात्रि में रीसेट होगी।';

  @override
  String get offlineBanner => 'आप ऑफ़लाइन हैं। कुछ सुविधाएँ सीमित हो सकती हैं।';

  @override
  String get loggedInOffline => 'ऑफ़लाइन लॉगिन हुआ';

  @override
  String get readingSavedOffline =>
      'रीडिंग ऑफ़लाइन सहेजी गई। कनेक्ट होने पर सिंक होगी।';

  @override
  String syncComplete(int count) {
    return '$count रीडिंग सिंक हुईं';
  }

  @override
  String get offlineLoginExpired => 'लॉगिन करने के लिए इंटरनेट से कनेक्ट करें';

  @override
  String get heartStatusHealthy => 'बहुत अच्छा!';

  @override
  String get heartStatusCaution => 'आज ध्यान रखें';

  @override
  String get heartStatusUrgent => 'डॉक्टर से बात करें';

  @override
  String get heartFaceHealthy => 'सब ठीक है';

  @override
  String get heartFaceCaution => 'आज ध्यान रखें';

  @override
  String get heartFaceUrgent => 'डॉक्टर की ज़रूरत';

  @override
  String get heartCallDoctor => 'अभी डॉक्टर को कॉल करें';

  @override
  String get quickSelectTitle => 'खाना दर्ज करें';

  @override
  String get mealHighCarb => 'भारी खाना — चावल / रोटी';

  @override
  String get mealLowCarb => 'हल्का खाना — सब्ज़ी / दाल';

  @override
  String get mealSweets => 'मीठा / मिठाई';

  @override
  String get mealHighProtein => 'प्रोटीन — अंडा / पनीर';

  @override
  String get mealModerateCarb => 'मिला-जुला खाना';

  @override
  String get mealMoreOptions => 'और विकल्प';

  @override
  String get mealLessOptions => 'कम विकल्प';

  @override
  String get mealSavedSuccess => 'खाना दर्ज हो गया!';

  @override
  String get mealTypeBreakfast => 'सुबह का नाश्ता';

  @override
  String get mealTypeLunch => 'दोपहर का खाना';

  @override
  String get mealTypeSnack => 'नाश्ता';

  @override
  String get mealTypeDinner => 'रात का खाना';

  @override
  String get mealDisclaimer => 'सामान्य स्वास्थ्य के लिए, चिकित्सा सलाह नहीं';

  @override
  String get foodPhotoTitle => 'खाने की फोटो लें';

  @override
  String get foodPhotoHint => 'कैमरा अपने खाने की तरफ करें';

  @override
  String get foodPhotoGallery => 'गैलरी से चुनें';

  @override
  String get foodPhotoAnalyzing => 'खाना पहचान रहे हैं...';

  @override
  String get foodPhotoFailed => 'खाना पहचान नहीं पाए। कृपया खुद चुनें।';

  @override
  String get foodResultTitle => 'खाने का नतीजा';

  @override
  String get foodCategoryHighCarb => 'ज़्यादा कार्ब';

  @override
  String get foodCategoryModerateCarb => 'सामान्य कार्ब';

  @override
  String get foodCategoryLowCarb => 'कम कार्ब';

  @override
  String get foodCategoryHighProtein => 'ज़्यादा प्रोटीन';

  @override
  String get foodCategorySweets => 'मीठा';

  @override
  String get foodMealTypeLabel => 'खाने का प्रकार';

  @override
  String get foodNotCorrectChange => 'सही नहीं? बदलें';

  @override
  String get foodDisclaimer => 'सामान्य स्वास्थ्य के लिए, चिकित्सा सलाह नहीं';

  @override
  String get foodPhotoSaved => 'खाना दर्ज हो गया!';

  @override
  String get foodPhotoSaveFailed =>
      'खाना सेव नहीं हुआ। कृपया दोबारा कोशिश करें।';

  @override
  String get mealsTileLabel => 'खाना';

  @override
  String mealsTodayCount(int count) {
    return '$count आज';
  }

  @override
  String get todaysMeals => 'आज का खाना';

  @override
  String get noMealsToday => 'आज कोई खाना दर्ज नहीं';

  @override
  String get tapToLogMeal => 'दर्ज करें';

  @override
  String get logMeal => 'खाना दर्ज करें';

  @override
  String get logMealSubtitle => 'कैसे दर्ज करें?';

  @override
  String get quickSelectOption => 'तुरंत चुनें';

  @override
  String get scanFoodPhotoOption => 'फोटो स्कैन करें';

  @override
  String get photoAiHint => 'फोटो से AI कार्ब लेवल पता करता है';
}
