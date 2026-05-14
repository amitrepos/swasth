import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/utils/metric_ranges.dart';

void main() {
  group('pickBpRangeSet', () {
    test('general adult, no conditions', () {
      expect(pickBpRangeSet(age: 35, conditions: []), BpRangeSet.general);
    });
    test('diabetic of any age uses tighter target', () {
      expect(
        pickBpRangeSet(age: 35, conditions: ['Diabetes T2']),
        BpRangeSet.diabeticOrCkd,
      );
    });
    test('senior 60-79 without DM/CKD uses senior set', () {
      expect(pickBpRangeSet(age: 65, conditions: []), BpRangeSet.senior);
    });
    test('frail elderly 80+ uses relaxed set', () {
      expect(pickBpRangeSet(age: 82, conditions: []), BpRangeSet.frailElderly);
    });
    test('diabetic + senior → still diabeticOrCkd (tighter target wins)', () {
      expect(
        pickBpRangeSet(age: 70, conditions: ['Diabetes T1']),
        BpRangeSet.diabeticOrCkd,
      );
    });
    test('null age defaults to general', () {
      expect(pickBpRangeSet(age: null, conditions: []), BpRangeSet.general);
    });
  });

  group('classifyBp', () {
    test('120/80 is fit-fine for general adult', () {
      final level = classifyBp(sys: 118, dia: 78, set: BpRangeSet.general);
      expect(level.category, MetricCategory.fitFine);
    });
    test('146/96 is urgent for general adult', () {
      final level = classifyBp(sys: 146, dia: 96, set: BpRangeSet.general);
      expect(level.category, MetricCategory.urgent);
    });
    test('hypertensive crisis 185/125 is urgent', () {
      final level = classifyBp(sys: 185, dia: 125, set: BpRangeSet.general);
      expect(level.category, MetricCategory.urgent);
    });
    test('135/85 is at risk for general adult (Stage 1)', () {
      final level = classifyBp(sys: 135, dia: 85, set: BpRangeSet.general);
      expect(level.category, MetricCategory.atRisk);
    });
    test('125/78 is caution for general adult (Elevated)', () {
      final level = classifyBp(sys: 125, dia: 78, set: BpRangeSet.general);
      expect(level.category, MetricCategory.caution);
    });
    test('125/78 is fit for diabetic (RSSDI 2022 target <130/<80)', () {
      final level = classifyBp(
        sys: 125,
        dia: 78,
        set: BpRangeSet.diabeticOrCkd,
      );
      expect(level.category, MetricCategory.fitFine);
    });
    test('135/85 is caution for diabetic (above target)', () {
      final level = classifyBp(
        sys: 135,
        dia: 85,
        set: BpRangeSet.diabeticOrCkd,
      );
      expect(level.category, MetricCategory.caution);
    });
    test('145/92 is at risk for diabetic', () {
      final level = classifyBp(
        sys: 145,
        dia: 92,
        set: BpRangeSet.diabeticOrCkd,
      );
      expect(level.category, MetricCategory.atRisk);
    });
    test('140/85 is at risk for senior (relaxed)', () {
      final level = classifyBp(sys: 140, dia: 85, set: BpRangeSet.senior);
      expect(level.category, MetricCategory.atRisk);
    });
  });

  group('pickGlucoseRangeSet', () {
    test('non-diabetic uses general', () {
      expect(
        pickGlucoseRangeSet(age: 40, conditions: []),
        GlucoseRangeSet.nonDiabetic,
      );
    });
    test('known diabetic <65 uses controlled target', () {
      expect(
        pickGlucoseRangeSet(age: 50, conditions: ['Diabetes T2']),
        GlucoseRangeSet.diabeticAdult,
      );
    });
    test('diabetic ≥65 uses relaxed target', () {
      expect(
        pickGlucoseRangeSet(age: 70, conditions: ['Diabetes T1']),
        GlucoseRangeSet.diabeticElderly,
      );
    });
  });

  group('classifyGlucose', () {
    test('85 mg/dL is fit-fine for non-diabetic', () {
      final l = classifyGlucose(mgdl: 85, set: GlucoseRangeSet.nonDiabetic);
      expect(l.category, MetricCategory.fitFine);
    });
    test('110 mg/dL is caution for non-diabetic (prediabetes)', () {
      final l = classifyGlucose(mgdl: 110, set: GlucoseRangeSet.nonDiabetic);
      expect(l.category, MetricCategory.caution);
    });
    test('140 mg/dL is at risk for non-diabetic', () {
      final l = classifyGlucose(mgdl: 140, set: GlucoseRangeSet.nonDiabetic);
      expect(l.category, MetricCategory.atRisk);
    });
    test('300 mg/dL is urgent for anyone', () {
      final l = classifyGlucose(mgdl: 300, set: GlucoseRangeSet.diabeticAdult);
      expect(l.category, MetricCategory.urgent);
    });
    test('hypoglycemia <70 is urgent', () {
      final l = classifyGlucose(mgdl: 55, set: GlucoseRangeSet.nonDiabetic);
      expect(l.category, MetricCategory.urgent);
    });
  });

  group('pickBmiRangeSet + classifyBmi', () {
    test('adult uses general Asian-Indian cutoffs', () {
      expect(pickBmiRangeSet(age: 35), BmiRangeSet.adult);
    });
    test('senior ≥65 uses protective range', () {
      expect(pickBmiRangeSet(age: 70), BmiRangeSet.senior);
    });
    test('22 is fit-fine for adult', () {
      expect(
        classifyBmi(bmi: 22, set: BmiRangeSet.adult).category,
        MetricCategory.fitFine,
      );
    });
    test('25.8 is at risk for adult (Asian-Indian obese I)', () {
      expect(
        classifyBmi(bmi: 25.8, set: BmiRangeSet.adult).category,
        MetricCategory.atRisk,
      );
    });
    test('31 is urgent for adult', () {
      expect(
        classifyBmi(bmi: 31, set: BmiRangeSet.adult).category,
        MetricCategory.urgent,
      );
    });
    test(
      '17 is at risk (underweight) for adult — not urgent per Dr. Rajesh',
      () {
        expect(
          classifyBmi(bmi: 17, set: BmiRangeSet.adult).category,
          MetricCategory.atRisk,
        );
      },
    );
    test('25 is fit-fine for senior (protective 22-27)', () {
      expect(
        classifyBmi(bmi: 25, set: BmiRangeSet.senior).category,
        MetricCategory.fitFine,
      );
    });
    test('31 stays urgent (≥30) for adult', () {
      expect(
        classifyBmi(bmi: 31, set: BmiRangeSet.adult).category,
        MetricCategory.urgent,
      );
    });
  });

  group('Priya — boundary + safety sweep', () {
    test(
      'hypertensive crisis ≥180/120 short-circuits in EVERY BP range set',
      () {
        for (final set in BpRangeSet.values) {
          expect(
            classifyBp(sys: 185, dia: 125, set: set).category,
            MetricCategory.urgent,
            reason: 'crisis at 185/125 must be urgent for $set',
          );
          // Crisis with only diastolic elevated.
          expect(
            classifyBp(sys: 175, dia: 121, set: set).category,
            MetricCategory.urgent,
            reason: 'crisis at 175/121 must be urgent for $set',
          );
        }
      },
    );

    test('classifyBp general boundaries (every transition pinned)', () {
      const s = BpRangeSet.general;
      // 119/79 → Fit (both under 120/80)
      expect(
        classifyBp(sys: 119, dia: 79, set: s).category,
        MetricCategory.fitFine,
      );
      // 120/79 → Caution (sys at 120 exactly)
      expect(
        classifyBp(sys: 120, dia: 79, set: s).category,
        MetricCategory.caution,
      );
      // 129/79 → Caution (still under At Risk)
      expect(
        classifyBp(sys: 129, dia: 79, set: s).category,
        MetricCategory.caution,
      );
      // 130/79 → At Risk
      expect(
        classifyBp(sys: 130, dia: 79, set: s).category,
        MetricCategory.atRisk,
      );
      // 139/89 → At Risk
      expect(
        classifyBp(sys: 139, dia: 89, set: s).category,
        MetricCategory.atRisk,
      );
      // 140/89 → Urgent (sys at urgent threshold)
      expect(
        classifyBp(sys: 140, dia: 89, set: s).category,
        MetricCategory.urgent,
      );
      // 139/90 → Urgent (dia at urgent threshold)
      expect(
        classifyBp(sys: 139, dia: 90, set: s).category,
        MetricCategory.urgent,
      );
      // 179/119 → Urgent (under crisis but in stage-2)
      expect(
        classifyBp(sys: 179, dia: 119, set: s).category,
        MetricCategory.urgent,
      );
      // 180/119 → Urgent (crisis short-circuit on systolic)
      expect(
        classifyBp(sys: 180, dia: 119, set: s).category,
        MetricCategory.urgent,
      );
    });

    test('classifyBp diabetic boundary 129/79 vs 130/80 (RSSDI target)', () {
      const s = BpRangeSet.diabeticOrCkd;
      expect(
        classifyBp(sys: 129, dia: 79, set: s).category,
        MetricCategory.fitFine,
      );
      // 130 systolic → Caution (above target)
      expect(
        classifyBp(sys: 130, dia: 79, set: s).category,
        MetricCategory.caution,
      );
      // Diastolic exactly 80 → Caution (Fit requires <80)
      expect(
        classifyBp(sys: 125, dia: 80, set: s).category,
        MetricCategory.caution,
      );
    });

    test('classifyBmi adult boundaries', () {
      const s = BmiRangeSet.adult;
      expect(classifyBmi(bmi: 18.4, set: s).category, MetricCategory.atRisk);
      expect(classifyBmi(bmi: 18.5, set: s).category, MetricCategory.fitFine);
      expect(classifyBmi(bmi: 22.9, set: s).category, MetricCategory.fitFine);
      expect(classifyBmi(bmi: 23.0, set: s).category, MetricCategory.caution);
      expect(classifyBmi(bmi: 24.9, set: s).category, MetricCategory.caution);
      expect(classifyBmi(bmi: 25.0, set: s).category, MetricCategory.atRisk);
      expect(classifyBmi(bmi: 29.9, set: s).category, MetricCategory.atRisk);
      expect(classifyBmi(bmi: 30.0, set: s).category, MetricCategory.urgent);
    });

    test('classifyGlucose non-diabetic boundaries', () {
      const s = GlucoseRangeSet.nonDiabetic;
      expect(classifyGlucose(mgdl: 69, set: s).category, MetricCategory.urgent);
      expect(
        classifyGlucose(mgdl: 70, set: s).category,
        MetricCategory.fitFine,
      );
      expect(
        classifyGlucose(mgdl: 99, set: s).category,
        MetricCategory.fitFine,
      );
      expect(
        classifyGlucose(mgdl: 100, set: s).category,
        MetricCategory.caution,
      );
      expect(
        classifyGlucose(mgdl: 125, set: s).category,
        MetricCategory.caution,
      );
      expect(
        classifyGlucose(mgdl: 126, set: s).category,
        MetricCategory.atRisk,
      );
      expect(
        classifyGlucose(mgdl: 199, set: s).category,
        MetricCategory.atRisk,
      );
      expect(
        classifyGlucose(mgdl: 200, set: s).category,
        MetricCategory.atRisk,
      );
      expect(
        classifyGlucose(mgdl: 250, set: s).category,
        MetricCategory.urgent,
      );
    });

    test('classifySteps boundaries at 25% / 50% / 100%', () {
      // pct = count/goal, goal=100 makes arithmetic trivial.
      expect(
        classifySteps(count: 24, goal: 100).category,
        MetricCategory.urgent,
      );
      expect(
        classifySteps(count: 25, goal: 100).category,
        MetricCategory.atRisk,
      );
      expect(
        classifySteps(count: 49, goal: 100).category,
        MetricCategory.atRisk,
      );
      expect(
        classifySteps(count: 50, goal: 100).category,
        MetricCategory.caution,
      );
      expect(
        classifySteps(count: 99, goal: 100).category,
        MetricCategory.caution,
      );
      expect(
        classifySteps(count: 100, goal: 100).category,
        MetricCategory.fitFine,
      );
    });

    test('cardiac AND age≥70 still returns 5000 goal (no compound bug)', () {
      expect(pickStepsGoal(age: 75, conditions: const ['Heart Disease']), 5000);
    });

    test(
      'empty medical_conditions list returns general / non-diabetic sets',
      () {
        expect(
          pickBpRangeSet(age: 35, conditions: const []),
          BpRangeSet.general,
        );
        expect(
          pickGlucoseRangeSet(age: 35, conditions: const []),
          GlucoseRangeSet.nonDiabetic,
        );
      },
    );

    test('every source URL parses as a valid https Uri', () {
      for (final s in MetricSources.all) {
        final uri = Uri.tryParse(s.url);
        expect(uri, isNotNull, reason: '${s.label}: ${s.url} did not parse');
        expect(uri!.scheme, 'https', reason: '${s.label}: must be https');
        expect(uri.host, isNotEmpty, reason: '${s.label}: empty host');
      }
    });

    test('classifyBp senior 60-79 full boundary sweep', () {
      // Senior bands:
      //  Fit    <130/<80
      //  Caution 130-139 / 80-84  (dia <85)
      //  At Risk 140-149 / 85-89  (dia ≥85 OR sys ≥140)
      //  Urgent  ≥150 / ≥90
      const s = BpRangeSet.senior;
      expect(
        classifyBp(sys: 129, dia: 79, set: s).category,
        MetricCategory.fitFine,
      );
      expect(
        classifyBp(sys: 130, dia: 79, set: s).category,
        MetricCategory.caution,
      );
      expect(
        classifyBp(sys: 139, dia: 84, set: s).category,
        MetricCategory.caution,
      );
      // dia ≥85 promotes to At Risk even if sys still in caution band.
      expect(
        classifyBp(sys: 135, dia: 85, set: s).category,
        MetricCategory.atRisk,
      );
      expect(
        classifyBp(sys: 140, dia: 85, set: s).category,
        MetricCategory.atRisk,
      );
      expect(
        classifyBp(sys: 149, dia: 89, set: s).category,
        MetricCategory.atRisk,
      );
      expect(
        classifyBp(sys: 150, dia: 89, set: s).category,
        MetricCategory.urgent,
      );
      expect(
        classifyBp(sys: 145, dia: 90, set: s).category,
        MetricCategory.urgent,
      );
    });

    test('classifyBp frail elderly 80+ full boundary sweep', () {
      const s = BpRangeSet.frailElderly;
      expect(
        classifyBp(sys: 139, dia: 84, set: s).category,
        MetricCategory.fitFine,
      );
      expect(
        classifyBp(sys: 140, dia: 84, set: s).category,
        MetricCategory.caution,
      );
      expect(
        classifyBp(sys: 149, dia: 89, set: s).category,
        MetricCategory.caution,
      );
      expect(
        classifyBp(sys: 150, dia: 90, set: s).category,
        MetricCategory.atRisk,
      );
      expect(
        classifyBp(sys: 159, dia: 94, set: s).category,
        MetricCategory.atRisk,
      );
      expect(
        classifyBp(sys: 160, dia: 94, set: s).category,
        MetricCategory.urgent,
      );
      expect(
        classifyBp(sys: 145, dia: 95, set: s).category,
        MetricCategory.urgent,
      );
    });

    test('classifyGlucose diabeticAdult full boundary sweep', () {
      const s = GlucoseRangeSet.diabeticAdult;
      expect(classifyGlucose(mgdl: 69, set: s).category, MetricCategory.urgent);
      expect(
        classifyGlucose(mgdl: 70, set: s).category,
        MetricCategory.fitFine,
      );
      expect(
        classifyGlucose(mgdl: 130, set: s).category,
        MetricCategory.fitFine,
      );
      expect(
        classifyGlucose(mgdl: 131, set: s).category,
        MetricCategory.caution,
      );
      expect(
        classifyGlucose(mgdl: 160, set: s).category,
        MetricCategory.caution,
      );
      expect(
        classifyGlucose(mgdl: 161, set: s).category,
        MetricCategory.atRisk,
      );
      expect(
        classifyGlucose(mgdl: 249, set: s).category,
        MetricCategory.atRisk,
      );
      expect(
        classifyGlucose(mgdl: 250, set: s).category,
        MetricCategory.urgent,
      );
    });

    test('classifyGlucose diabeticElderly boundary sweep (relaxed)', () {
      const s = GlucoseRangeSet.diabeticElderly;
      expect(classifyGlucose(mgdl: 79, set: s).category, MetricCategory.urgent);
      expect(
        classifyGlucose(mgdl: 80, set: s).category,
        MetricCategory.fitFine,
      );
      expect(
        classifyGlucose(mgdl: 150, set: s).category,
        MetricCategory.fitFine,
      );
      expect(
        classifyGlucose(mgdl: 151, set: s).category,
        MetricCategory.caution,
      );
      expect(
        classifyGlucose(mgdl: 180, set: s).category,
        MetricCategory.caution,
      );
      expect(
        classifyGlucose(mgdl: 181, set: s).category,
        MetricCategory.atRisk,
      );
      expect(
        classifyGlucose(mgdl: 249, set: s).category,
        MetricCategory.atRisk,
      );
      expect(
        classifyGlucose(mgdl: 250, set: s).category,
        MetricCategory.urgent,
      );
    });

    test('classifyBmi senior 65+ full boundary sweep (protective)', () {
      const s = BmiRangeSet.senior;
      expect(classifyBmi(bmi: 18.4, set: s).category, MetricCategory.urgent);
      expect(classifyBmi(bmi: 18.5, set: s).category, MetricCategory.atRisk);
      expect(classifyBmi(bmi: 19.9, set: s).category, MetricCategory.atRisk);
      expect(classifyBmi(bmi: 20, set: s).category, MetricCategory.caution);
      expect(classifyBmi(bmi: 21.9, set: s).category, MetricCategory.caution);
      expect(classifyBmi(bmi: 22, set: s).category, MetricCategory.fitFine);
      expect(classifyBmi(bmi: 27, set: s).category, MetricCategory.fitFine);
      expect(classifyBmi(bmi: 27.1, set: s).category, MetricCategory.caution);
      expect(classifyBmi(bmi: 29.9, set: s).category, MetricCategory.caution);
      expect(classifyBmi(bmi: 30, set: s).category, MetricCategory.atRisk);
      expect(classifyBmi(bmi: 34.9, set: s).category, MetricCategory.atRisk);
      expect(classifyBmi(bmi: 35, set: s).category, MetricCategory.urgent);
    });

    test('buildStepsSpec — cardiac patient: lowest band wording softened', () {
      final spec = buildStepsSpec(
        count: 100,
        age: 50,
        conditions: const ['Heart Disease'],
      );
      expect(spec.levels.length, 4);
      expect(spec.levels[3].label.toLowerCase(), contains('low movement'));
      expect(
        spec.levels[3].desc.toLowerCase(),
        contains('rest if your doctor'),
      );
      // rangeSetLabel should mention adjustment.
      expect(spec.rangeSetLabel.toLowerCase(), contains('cardiac'));
    });

    test(
      'buildStepsSpec — goal=0 edge: still returns fit (no divide-by-zero)',
      () {
        expect(
          classifySteps(count: 0, goal: 0).category,
          MetricCategory.fitFine,
        );
      },
    );

    test('buildBpSpec senior label + diabeticOrCkd label distinct', () {
      final senior = buildBpSpec(
        sys: 130,
        dia: 80,
        age: 65,
        conditions: const [],
      );
      final diabetic = buildBpSpec(
        sys: 130,
        dia: 80,
        age: 65,
        conditions: const ['Diabetes T2'],
      );
      // Diabetes wins over age — both ≥60 but conditions force diabetic set.
      expect(senior.rangeSetLabel.toLowerCase(), contains('senior'));
      expect(diabetic.rangeSetLabel.toLowerCase(), contains('diabet'));
      expect(senior.rangeSetLabel, isNot(diabetic.rangeSetLabel));
    });

    test('buildGlucoseSpec — non-diabetic returns nonDiabetic set label', () {
      final spec = buildGlucoseSpec(mgdl: 95, age: 30, conditions: const []);
      expect(spec.rangeSetLabel.toLowerCase(), contains('non-diabetic'));
      expect(spec.footnote, isNotNull);
    });

    test(
      'pickGlucoseRangeSet — post-meal context routes to post-meal sets',
      () {
        // Non-diabetic.
        expect(
          pickGlucoseRangeSet(
            age: 40,
            conditions: const [],
            mealContext: GlucoseMealContext.postMeal,
          ),
          GlucoseRangeSet.nonDiabeticPostMeal,
        );
        // Diabetic adult.
        expect(
          pickGlucoseRangeSet(
            age: 50,
            conditions: const ['Diabetes T2'],
            mealContext: GlucoseMealContext.postMeal,
          ),
          GlucoseRangeSet.diabeticAdultPostMeal,
        );
        // Diabetic elderly.
        expect(
          pickGlucoseRangeSet(
            age: 70,
            conditions: const ['Diabetes T2'],
            mealContext: GlucoseMealContext.postMeal,
          ),
          GlucoseRangeSet.diabeticElderlyPostMeal,
        );
      },
    );

    test('pickGlucoseRangeSet — fasting + unknown both use pre-meal sets', () {
      for (final c in [
        GlucoseMealContext.fasting,
        GlucoseMealContext.beforeMeal,
        GlucoseMealContext.unknown,
        GlucoseMealContext.random,
      ]) {
        expect(
          pickGlucoseRangeSet(age: 40, conditions: const [], mealContext: c),
          GlucoseRangeSet.nonDiabetic,
          reason: 'context $c should map to nonDiabetic',
        );
      }
    });

    test('classifyGlucose nonDiabeticPostMeal boundaries', () {
      const s = GlucoseRangeSet.nonDiabeticPostMeal;
      expect(classifyGlucose(mgdl: 69, set: s).category, MetricCategory.urgent);
      expect(
        classifyGlucose(mgdl: 70, set: s).category,
        MetricCategory.fitFine,
      );
      expect(
        classifyGlucose(mgdl: 139, set: s).category,
        MetricCategory.fitFine,
      );
      expect(
        classifyGlucose(mgdl: 140, set: s).category,
        MetricCategory.caution,
      );
      expect(
        classifyGlucose(mgdl: 179, set: s).category,
        MetricCategory.caution,
      );
      expect(
        classifyGlucose(mgdl: 180, set: s).category,
        MetricCategory.atRisk,
      );
      expect(
        classifyGlucose(mgdl: 199, set: s).category,
        MetricCategory.atRisk,
      );
      expect(
        classifyGlucose(mgdl: 200, set: s).category,
        MetricCategory.urgent,
      );
    });

    test('classifyGlucose diabeticAdultPostMeal boundaries', () {
      const s = GlucoseRangeSet.diabeticAdultPostMeal;
      expect(classifyGlucose(mgdl: 69, set: s).category, MetricCategory.urgent);
      expect(
        classifyGlucose(mgdl: 70, set: s).category,
        MetricCategory.fitFine,
      );
      expect(
        classifyGlucose(mgdl: 179, set: s).category,
        MetricCategory.fitFine,
      );
      expect(
        classifyGlucose(mgdl: 180, set: s).category,
        MetricCategory.caution,
      );
      expect(
        classifyGlucose(mgdl: 220, set: s).category,
        MetricCategory.caution,
      );
      expect(
        classifyGlucose(mgdl: 221, set: s).category,
        MetricCategory.atRisk,
      );
      expect(
        classifyGlucose(mgdl: 249, set: s).category,
        MetricCategory.atRisk,
      );
      expect(
        classifyGlucose(mgdl: 250, set: s).category,
        MetricCategory.urgent,
      );
    });

    test('classifyGlucose diabeticElderlyPostMeal boundaries (relaxed)', () {
      const s = GlucoseRangeSet.diabeticElderlyPostMeal;
      expect(classifyGlucose(mgdl: 79, set: s).category, MetricCategory.urgent);
      expect(
        classifyGlucose(mgdl: 80, set: s).category,
        MetricCategory.fitFine,
      );
      expect(
        classifyGlucose(mgdl: 199, set: s).category,
        MetricCategory.fitFine,
      );
      expect(
        classifyGlucose(mgdl: 200, set: s).category,
        MetricCategory.caution,
      );
      expect(
        classifyGlucose(mgdl: 229, set: s).category,
        MetricCategory.caution,
      );
      expect(
        classifyGlucose(mgdl: 230, set: s).category,
        MetricCategory.atRisk,
      );
      expect(
        classifyGlucose(mgdl: 249, set: s).category,
        MetricCategory.atRisk,
      );
      expect(
        classifyGlucose(mgdl: 250, set: s).category,
        MetricCategory.urgent,
      );
    });

    test('buildGlucoseSpec — consolidated message disambiguates context', () {
      // 145 fasting non-diabetic → At Risk (in diabetes range)
      final fasting = buildGlucoseSpec(
        mgdl: 145,
        age: 40,
        conditions: const [],
        mealContext: GlucoseMealContext.fasting,
      );
      expect(fasting.currentLevel?.category, MetricCategory.atRisk);
      expect(fasting.consolidatedMessage, contains('Fasting'));
      expect(fasting.consolidatedMessage, contains('At Risk'));

      // 145 post-meal non-diabetic → Caution (NOT in diabetes range)
      final postMeal = buildGlucoseSpec(
        mgdl: 145,
        age: 40,
        conditions: const [],
        mealContext: GlucoseMealContext.postMeal,
      );
      expect(postMeal.currentLevel?.category, MetricCategory.caution);
      expect(postMeal.consolidatedMessage, contains('Post-meal'));
      expect(postMeal.consolidatedMessage, contains('Caution'));
    });

    test('buildGlucoseSpec — unknown context surfaces ambiguous CTA', () {
      final spec = buildGlucoseSpec(
        mgdl: 145,
        age: 40,
        conditions: const [],
        mealContext: GlucoseMealContext.unknown,
      );
      expect(spec.ambiguousCta, isNotNull);
      expect(spec.ambiguousCta!.toLowerCase(), contains('tag this reading'));
    });

    test('buildGlucoseSpec — diabetic 145 fasting vs post-meal flip', () {
      // 145 fasting for diabetic <65 → Caution (above <130 target).
      final fasting = buildGlucoseSpec(
        mgdl: 145,
        age: 50,
        conditions: const ['Diabetes T2'],
        mealContext: GlucoseMealContext.fasting,
      );
      expect(fasting.currentLevel?.category, MetricCategory.caution);
      // 145 post-meal for diabetic <65 → Fit & Fine (within <180 target).
      final postMeal = buildGlucoseSpec(
        mgdl: 145,
        age: 50,
        conditions: const ['Diabetes T2'],
        mealContext: GlucoseMealContext.postMeal,
      );
      expect(postMeal.currentLevel?.category, MetricCategory.fitFine);
    });

    test('glucoseMealContextFromString — round-trip', () {
      expect(
        glucoseMealContextFromString('fasting'),
        GlucoseMealContext.fasting,
      );
      expect(
        glucoseMealContextFromString('post_meal'),
        GlucoseMealContext.postMeal,
      );
      expect(glucoseMealContextFromString('random'), GlucoseMealContext.random);
      expect(glucoseMealContextFromString(null), GlucoseMealContext.unknown);
      expect(
        glucoseMealContextFromString('garbage'),
        GlucoseMealContext.unknown,
      );
    });

    test('every source URL is a stable landing page (no deep PDF paths)', () {
      // Policy: deep PDF paths (e.g. `/sites/default/files/.../guidelines.pdf`)
      // rotate every few months on Indian gov sites and embarrass us with
      // 404s. JAPI is an exception — academic-journal permalinks are stable.
      for (final s in MetricSources.all) {
        final uri = Uri.parse(s.url);
        final isPdf = uri.path.toLowerCase().endsWith('.pdf');
        expect(
          isPdf,
          isFalse,
          reason:
              '${s.label} points to a deep PDF (${s.url}). Use the '
              'institution landing page instead — PDFs move.',
        );
      }
    });
  });

  group('Dr. Rajesh clinical fixes', () {
    test('glucose spec footnote mentions fasting', () {
      final spec = buildGlucoseSpec(mgdl: 110, age: 40, conditions: const []);
      expect(spec.footnote, isNotNull);
      expect(spec.footnote!.toLowerCase(), contains('fasting'));
      expect(spec.footnote!.toLowerCase(), contains('post-meal'));
    });
    test('cardiac patient steps lowest band wording is softened', () {
      final spec = buildStepsSpec(
        count: 70,
        age: 50,
        conditions: const ['Heart Disease'],
      );
      final urgent = spec.levels.last;
      expect(urgent.label.toLowerCase(), isNot(contains('sedentary')));
      expect(urgent.desc.toLowerCase(), contains('rest if your doctor'));
    });
    test('non-cardiac patient steps keeps standard wording', () {
      final spec = buildStepsSpec(count: 70, age: 35, conditions: const []);
      final urgent = spec.levels.last;
      expect(urgent.desc.toLowerCase(), contains('very low movement'));
    });
  });

  group('classifySteps', () {
    test('100% of goal is fit-fine', () {
      expect(
        classifySteps(count: 7500, goal: 7500).category,
        MetricCategory.fitFine,
      );
    });
    test('70% of goal is caution', () {
      expect(
        classifySteps(count: 5250, goal: 7500).category,
        MetricCategory.caution,
      );
    });
    test('30% of goal is at risk', () {
      expect(
        classifySteps(count: 2250, goal: 7500).category,
        MetricCategory.atRisk,
      );
    });
    test('15% of goal is urgent', () {
      expect(
        classifySteps(count: 1125, goal: 7500).category,
        MetricCategory.urgent,
      );
    });
  });

  group('pickStepsGoal', () {
    test('default 7500', () {
      expect(pickStepsGoal(age: 40, conditions: []), 7500);
    });
    test('age ≥70 lowered to 5000', () {
      expect(pickStepsGoal(age: 72, conditions: []), 5000);
    });
    test('heart disease lowered to 5000', () {
      expect(pickStepsGoal(age: 50, conditions: ['Heart Disease']), 5000);
    });
  });

  group('buildBpSpec — end-to-end', () {
    test('produces 4 levels + populates current reading', () {
      final spec = buildBpSpec(
        sys: 146,
        dia: 96,
        age: 35,
        conditions: const [],
      );
      expect(spec.levels.length, 4);
      expect(spec.currentValue, '146/96 mmHg');
      expect(spec.currentLevel?.category, MetricCategory.urgent);
      expect(spec.sources, isNotEmpty);
      expect(spec.sources.first.url, startsWith('https://'));
    });
    test('null inputs → null currentLevel, levels still returned', () {
      final spec = buildBpSpec(
        sys: null,
        dia: null,
        age: 35,
        conditions: const [],
      );
      expect(spec.currentLevel, isNull);
      expect(spec.currentValue, isNull);
      expect(spec.levels.length, 4);
    });
  });

  group('rangeSetLabel — human readable', () {
    test('diabetic profile shows reason', () {
      final spec = buildBpSpec(
        sys: 120,
        dia: 80,
        age: 67,
        conditions: const ['Diabetes T2'],
      );
      expect(spec.rangeSetLabel.toLowerCase(), contains('diabet'));
    });
    test('general adult shows neutral label', () {
      final spec = buildBpSpec(
        sys: 120,
        dia: 80,
        age: 35,
        conditions: const [],
      );
      expect(spec.rangeSetLabel.toLowerCase(), contains('adult'));
    });
  });
}
