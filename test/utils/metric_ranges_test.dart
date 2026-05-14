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
      const sources = <SourceRef>[
        MetricSources.ihci,
        MetricSources.icmrHtn,
        MetricSources.rssdi,
        MetricSources.icmrDm,
        MetricSources.icmrBmi,
        MetricSources.who,
        MetricSources.icmrNin,
      ];
      for (final s in sources) {
        final uri = Uri.tryParse(s.url);
        expect(uri, isNotNull, reason: '${s.label}: ${s.url} did not parse');
        expect(uri!.scheme, 'https', reason: '${s.label}: must be https');
        expect(uri.host, isNotEmpty, reason: '${s.label}: empty host');
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
