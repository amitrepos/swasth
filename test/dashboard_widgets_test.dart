/// Regression tests for all dashboard sections.
///
/// These tests verify that every widget on the home screen renders without
/// crashing, so deploying new changes never silently removes a section
/// (like the physician card disappearing).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/widgets/home/health_score_ring.dart';
import 'package:swasth_app/widgets/home/ai_insight_card.dart';
import 'package:swasth_app/widgets/home/physician_card.dart';
import 'package:swasth_app/widgets/home/vital_summary_card.dart';
import 'package:swasth_app/widgets/home/metrics_grid.dart';
import 'package:swasth_app/widgets/home/home_header.dart';
import 'package:swasth_app/models/profile_model.dart';

/// Wraps a widget with MaterialApp + localizations so l10n.* calls work.
Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

/// Test profile with doctor info.
final _testProfile = ProfileModel(
  id: 1,
  name: 'Test User',
  age: 45,
  gender: 'Male',
  accessLevel: 'owner',
  createdAt: DateTime.now(),
  doctorName: 'Dr. Sharma',
  doctorSpecialty: 'General Physician',
  doctorWhatsapp: '919876543210',
  medicalConditions: ['Diabetes'],
  medications: 'Metformin 500mg',
);

/// Health score API response (simulated).
final _healthScoreData = <String, dynamic>{
  'score': 78,
  'color': 'green',
  'streak_days': 5,
  'insight': 'Great work! 5 days of consistent monitoring.',
  'profile_name': 'Test User',
  'today_glucose_status': 'NORMAL',
  'today_bp_status': null,
  'today_glucose_value': 105.0,
  'today_bp_systolic': null,
  'today_bp_diastolic': null,
  'last_logged': DateTime.now().toIso8601String(),
  'profile_age': 45,
  'age_context_bp': null,
  'age_context_glucose': 'For age 45, glucose 105 mg/dL is within normal range.',
  'avg_glucose_90d': 118.5,
  'prev_avg_glucose_90d': 125.0,
  'avg_systolic_90d': 128.0,
  'avg_diastolic_90d': 82.0,
  'prev_avg_systolic_90d': 132.0,
  'last_glucose_value': 105.0,
  'last_glucose_status': 'NORMAL',
  'last_bp_systolic': 130.0,
  'last_bp_diastolic': 85.0,
  'last_bp_status': 'NORMAL',
  'last_weight_value': 75.0,
  'bmi': 26.6,
  'glucose_data_days': 30,
  'bp_data_days': 25,
};

void main() {
  // =========================================================================
  // Section 1: Health Score Ring
  // =========================================================================

  group('HealthScoreRing', () {
    testWidgets('renders score value', (tester) async {
      await tester.pumpWidget(_wrap(
        HealthScoreRing(
          data: _healthScoreData,
          isLoading: false,
          profileId: 1,
          onTap: () {},
          onInfoTap: () {},
        ),
      ));
      await tester.pump();

      expect(find.text('78'), findsOneWidget);
    });

    testWidgets('shows loading indicator when isLoading', (tester) async {
      await tester.pumpWidget(_wrap(
        HealthScoreRing(
          data: null,
          isLoading: true,
          profileId: 1,
          onTap: () {},
          onInfoTap: () {},
        ),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders with null data showing default score', (tester) async {
      await tester.pumpWidget(_wrap(
        HealthScoreRing(
          data: null,
          isLoading: false,
          profileId: 1,
          onTap: () {},
          onInfoTap: () {},
        ),
      ));
      await tester.pump();

      expect(find.text('50'), findsOneWidget);
    });

    testWidgets('urgent state shows call doctor button', (tester) async {
      await tester.pumpWidget(_wrap(
        HealthScoreRing(
          data: {'score': 25, 'insight': 'See your doctor'},
          isLoading: false,
          profileId: 1,
          onTap: () {},
          onInfoTap: () {},
          onCallDoctor: () {},
        ),
      ));
      await tester.pump();

      expect(find.text('25'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('caution state shows score without call button', (tester) async {
      await tester.pumpWidget(_wrap(
        HealthScoreRing(
          data: {'score': 55, 'insight': 'Monitor closely'},
          isLoading: false,
          profileId: 1,
          onTap: () {},
          onInfoTap: () {},
        ),
      ));
      await tester.pump();

      expect(find.text('55'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('trend arrow shows up-arrow when score improved', (tester) async {
      await tester.pumpWidget(_wrap(
        HealthScoreRing(
          data: {'score': 78, 'previous_score': 60, 'insight': ''},
          isLoading: false,
          profileId: 1,
          onTap: () {},
          onInfoTap: () {},
        ),
      ));
      await tester.pump();

      expect(find.text('↑'), findsOneWidget);
    });

    testWidgets('trend arrow shows down-arrow when score declined', (tester) async {
      await tester.pumpWidget(_wrap(
        HealthScoreRing(
          data: {'score': 50, 'previous_score': 70, 'insight': ''},
          isLoading: false,
          profileId: 1,
          onTap: () {},
          onInfoTap: () {},
        ),
      ));
      await tester.pump();

      expect(find.text('↓'), findsOneWidget);
    });

    testWidgets('no trend arrow when no previous score', (tester) async {
      await tester.pumpWidget(_wrap(
        HealthScoreRing(
          data: {'score': 78, 'insight': ''},
          isLoading: false,
          profileId: 1,
          onTap: () {},
          onInfoTap: () {},
        ),
      ));
      await tester.pump();

      expect(find.text('↑'), findsNothing);
      expect(find.text('↓'), findsNothing);
      expect(find.text('→'), findsNothing);
    });

    testWidgets('stable trend shows flat arrow', (tester) async {
      await tester.pumpWidget(_wrap(
        HealthScoreRing(
          data: {'score': 78, 'previous_score': 77, 'insight': ''},
          isLoading: false,
          profileId: 1,
          onTap: () {},
          onInfoTap: () {},
        ),
      ));
      await tester.pump();

      expect(find.text('→'), findsOneWidget);
    });

    testWidgets('info button fires onInfoTap callback', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(_wrap(
        HealthScoreRing(
          data: _healthScoreData,
          isLoading: false,
          profileId: 1,
          onTap: () {},
          onInfoTap: () => tapped = true,
        ),
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.question_mark_rounded));
      expect(tapped, isTrue);
    });

    testWidgets('call doctor button fires onCallDoctor callback', (tester) async {
      bool called = false;
      await tester.pumpWidget(_wrap(
        HealthScoreRing(
          data: {'score': 25, 'insight': ''},
          isLoading: false,
          profileId: 1,
          onTap: () {},
          onInfoTap: () {},
          onCallDoctor: () => called = true,
        ),
      ));
      await tester.pump();

      await tester.tap(find.byType(ElevatedButton));
      expect(called, isTrue);
    });
  });

  // =========================================================================
  // Unit tests for public helpers
  // =========================================================================

  group('heartColorForScore', () {
    test('green for healthy scores', () {
      expect(heartColorForScore(70), const Color(0xFF28A745));
      expect(heartColorForScore(100), const Color(0xFF28A745));
    });
    test('orange for caution scores', () {
      expect(heartColorForScore(40), const Color(0xFFFF9500));
      expect(heartColorForScore(69), const Color(0xFFFF9500));
    });
    test('red for urgent scores', () {
      expect(heartColorForScore(0), const Color(0xFFFF3B30));
      expect(heartColorForScore(39), const Color(0xFFFF3B30));
    });
  });

  group('faceStateForScore', () {
    test('happy for healthy', () => expect(faceStateForScore(80), FaceState.happy));
    test('neutral for caution', () => expect(faceStateForScore(55), FaceState.neutral));
    test('worried for urgent', () => expect(faceStateForScore(20), FaceState.worried));
  });

  group('computeTrendArrow', () {
    test('null when no previous', () => expect(computeTrendArrow(80, null), isNull));
    test('up when improved > 3', () => expect(computeTrendArrow(80, 70), '↑'));
    test('down when declined > 3', () => expect(computeTrendArrow(50, 70), '↓'));
    test('flat when within deadband', () => expect(computeTrendArrow(80, 78), '→'));
  });

  // =========================================================================
  // Section 2: AI Insight Card
  // =========================================================================

  group('AiInsightCard', () {
    testWidgets('renders insight text from resolved future', (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 500),
      );
      final animation = Tween<double>(begin: 0.3, end: 1.0).animate(controller);

      await tester.pumpWidget(_wrap(
        AiInsightCard(
          insightFuture: Future.value('Drink more water and walk daily.'),
          pulseAnimation: animation,
          isSaved: false,
          onSaveToggle: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Drink more water'), findsWidgets);

      controller.dispose();
    });

    testWidgets('renders without crashing for pending future', (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 500),
      );
      final animation = Tween<double>(begin: 0.3, end: 1.0).animate(controller);

      await tester.pumpWidget(_wrap(
        AiInsightCard(
          insightFuture: null,
          pulseAnimation: animation,
          isSaved: false,
          onSaveToggle: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(AiInsightCard), findsOneWidget);

      controller.dispose();
    });
  });

  // =========================================================================
  // Section 3: Physician Card (the one that disappeared before)
  // =========================================================================

  group('PhysicianCard', () {
    testWidgets('renders doctor name and specialty', (tester) async {
      await tester.pumpWidget(_wrap(
        PhysicianCard(
          profile: _testProfile,
          onWhatsAppTap: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Dr. Sharma'), findsOneWidget);
      expect(find.text('General Physician'), findsOneWidget);
    });

    testWidgets('renders without doctor info set', (tester) async {
      final noDocProfile = ProfileModel(
        id: 2,
        name: 'No Doctor User',
        accessLevel: 'owner',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(_wrap(
        PhysicianCard(profile: noDocProfile),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(PhysicianCard), findsOneWidget);
    });
  });

  // =========================================================================
  // Section 4: Vital Summary Card (90-day averages)
  // =========================================================================

  group('VitalSummaryCard', () {
    testWidgets('renders 90-day averages', (tester) async {
      await tester.pumpWidget(_wrap(
        VitalSummaryCard(data: _healthScoreData),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(VitalSummaryCard), findsOneWidget);
    });

    testWidgets('renders with null data showing dashes', (tester) async {
      await tester.pumpWidget(_wrap(
        const VitalSummaryCard(data: null),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(VitalSummaryCard), findsOneWidget);
      expect(find.text('—'), findsWidgets);
    });
  });

  // =========================================================================
  // Section 5: Metrics Grid (last readings)
  // =========================================================================

  group('MetricsGrid', () {
    testWidgets('renders last glucose and BP values', (tester) async {
      await tester.pumpWidget(_wrap(
        MetricsGrid(
          data: _healthScoreData,
          profileId: 1,
          onAddReading: ({required String deviceType, required String btDeviceType}) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(MetricsGrid), findsOneWidget);
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('renders weight and BMI labels', (tester) async {
      await tester.pumpWidget(_wrap(
        MetricsGrid(
          data: _healthScoreData,
          profileId: 1,
          onAddReading: ({required String deviceType, required String btDeviceType}) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('WEIGHT'), findsOneWidget);
      expect(find.textContaining('75.0 kg'), findsOneWidget);
      expect(find.textContaining('BMI'), findsOneWidget);
      expect(find.textContaining('26.6'), findsOneWidget);
    });
  });

  // =========================================================================
  // Section 6: Home Header
  // =========================================================================

  group('HomeHeader', () {
    testWidgets('renders greeting and gamification', (tester) async {
      await tester.pumpWidget(_wrap(
        HomeHeader(
          activeProfileName: 'Test User',
          activeProfileId: 1,
          streak: 5,
          pts: 250,
          onSwitchProfile: () {},
          onViewProfile: () {},
          onShareProfile: () {},
          onLanguageTap: () {},
          onLogout: () {},
        ),
      ));
      await tester.pumpAndSettle();

      // Should render SWASTH label and greeting
      expect(find.text('SWASTH'), findsOneWidget);
      expect(find.byType(HomeHeader), findsOneWidget);
    });
  });

  // =========================================================================
  // REGRESSION: all sections render together (simulates full dashboard)
  // =========================================================================

  testWidgets('ALL 6 dashboard sections render together without crashing', (tester) async {
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 500),
    );
    final animation = Tween<double>(begin: 0.3, end: 1.0).animate(controller);

    await tester.pumpWidget(_wrap(
      Column(
        children: [
          HomeHeader(
            activeProfileName: 'Test User',
            activeProfileId: 1,
            streak: 5,
            pts: 250,
            onSwitchProfile: () {},
            onViewProfile: () {},
            onShareProfile: () {},
            onLanguageTap: () {},
            onLogout: () {},
          ),
          HealthScoreRing(
            data: _healthScoreData,
            isLoading: false,
            profileId: 1,
            onTap: () {},
            onInfoTap: () {},
          ),
          AiInsightCard(
            insightFuture: Future.value('Stay hydrated.'),
            pulseAnimation: animation,
            isSaved: false,
            onSaveToggle: () {},
          ),
          PhysicianCard(profile: _testProfile),
          VitalSummaryCard(data: _healthScoreData),
          MetricsGrid(
            data: _healthScoreData,
            profileId: 1,
            onAddReading: ({required String deviceType, required String btDeviceType}) {},
            ),
        ],
      ),
    ));
    await tester.pump();

    expect(find.byType(HomeHeader), findsOneWidget);
    expect(find.byType(HealthScoreRing), findsOneWidget);
    expect(find.byType(AiInsightCard), findsOneWidget);
    expect(find.byType(PhysicianCard), findsOneWidget);
    expect(find.byType(VitalSummaryCard), findsOneWidget);
    expect(find.byType(MetricsGrid), findsOneWidget);

    controller.dispose();
  });
}
