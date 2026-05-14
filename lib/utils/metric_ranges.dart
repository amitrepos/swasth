import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Category of a single reference band. Maps 1:1 to the four wellness levels
/// already used by `StatusInfoSheet` (Fit & Fine / Caution / At Risk / Urgent).
enum MetricCategory { fitFine, caution, atRisk, urgent }

/// One row of the reference table inside a metric info sheet.
@immutable
class MetricLevel {
  final MetricCategory category;
  final String emoji;
  final String label;
  final String range;
  final String desc;
  final Color color;

  const MetricLevel({
    required this.category,
    required this.emoji,
    required this.label,
    required this.range,
    required this.desc,
    required this.color,
  });
}

/// One clickable source citation chip.
@immutable
class SourceRef {
  final String label;
  final String url;
  const SourceRef({required this.label, required this.url});
}

/// Complete payload rendered by `MetricInfoSheet`.
@immutable
class MetricInfoSpec {
  final String title;
  final String? currentValue;
  final MetricLevel? currentLevel;
  final List<MetricLevel> levels;
  final String rangeSetLabel;
  final String? footnote;
  final List<SourceRef> sources;
  final String disclaimer;

  const MetricInfoSpec({
    required this.title,
    required this.currentValue,
    required this.currentLevel,
    required this.levels,
    required this.rangeSetLabel,
    this.footnote,
    required this.sources,
    required this.disclaimer,
  });
}

// ===========================================================================
//                              SOURCES (auditable)
// ===========================================================================

/// Source citations for the metric info sheets.
///
/// **URL policy:** point to stable institution landing pages, NOT deep PDF
/// paths. Deep PDF URLs rotate every few months and result in 404s in front
/// of users. The institution name + topic is enough for a curious user to
/// navigate to the current document from the landing page.
///
/// All URLs are verified live by `test/utils/metric_sources_live_links_test.dart`
/// (network-tagged, opt-in via `flutter test --tags live`).
class MetricSources {
  static const ihci = SourceRef(label: 'IHCI', url: 'https://www.ihci.in/');
  static const icmrHtn = SourceRef(
    label: 'ICMR',
    url: 'https://www.icmr.gov.in/',
  );
  static const rssdi = SourceRef(label: 'RSSDI', url: 'https://www.rssdi.in/');
  static const icmrDm = SourceRef(
    label: 'ICMR',
    url: 'https://www.icmr.gov.in/',
  );
  // JAPI permalink — academic-journal slugs are usually stable but the
  // `u264a4a4` segment could rotate if JAPI ever migrates. The daily
  // live-link-check workflow will catch breakage within 12 hours; if it
  // ever fails, replace with `https://www.japi.org/` (landing page).
  // Last verified: 2026-05-14.
  static const icmrBmi = SourceRef(
    label: 'JAPI / ICMR Consensus',
    url:
        'https://www.japi.org/u264a4a4/consensus-statement-for-diagnosis-of-obesity-abdominal-obesity-and-the-metabolic-syndrome-for-asian-indians',
  );
  static const who = SourceRef(
    label: 'WHO India',
    url: 'https://www.who.int/india',
  );
  static const icmrNin = SourceRef(
    label: 'ICMR-NIN',
    url: 'https://www.nin.res.in/',
  );

  /// Single list used by tests and any future audit tooling.
  static const all = <SourceRef>[
    ihci,
    icmrHtn,
    rssdi,
    icmrDm,
    icmrBmi,
    who,
    icmrNin,
  ];
}

const String _kDisclaimer =
    'Reference only. Not a substitute for your doctor\'s advice.';

// ===========================================================================
//                              MEDICAL FLAG HELPERS
// ===========================================================================

// Allowed diabetes labels in ProfileResponse.medical_conditions.
// Explicit set (not startsWith) so unrelated conditions like "diabetes
// insipidus" won't accidentally trigger diabetic-target ranges.
const Set<String> _diabetesValues = {'Diabetes T1', 'Diabetes T2'};
bool _hasDiabetes(List<String> mc) => mc.any(_diabetesValues.contains);
bool _hasCkd(List<String> mc) => mc.any(
  (c) => c.toLowerCase().contains('kidney') || c.toLowerCase().contains('ckd'),
);
bool _hasCardiac(List<String> mc) =>
    mc.any((c) => c.toLowerCase().contains('heart'));

// ===========================================================================
//                              BLOOD PRESSURE
// ===========================================================================

enum BpRangeSet { general, diabeticOrCkd, senior, frailElderly }

BpRangeSet pickBpRangeSet({
  required int? age,
  required List<String> conditions,
}) {
  if (_hasDiabetes(conditions) || _hasCkd(conditions)) {
    return BpRangeSet.diabeticOrCkd;
  }
  if (age != null && age >= 80) return BpRangeSet.frailElderly;
  if (age != null && age >= 60) return BpRangeSet.senior;
  return BpRangeSet.general;
}

String _bpRangeSetLabel(BpRangeSet s) {
  switch (s) {
    case BpRangeSet.general:
      return 'Targets for: Adult (18–59)';
    case BpRangeSet.diabeticOrCkd:
      return 'Targets adjusted for: Diabetes or kidney disease';
    case BpRangeSet.senior:
      return 'Targets for: Senior adult (60–79)';
    case BpRangeSet.frailElderly:
      return 'Targets for: Frail elderly (80+)';
  }
}

List<MetricLevel> _bpLevels(BpRangeSet s) {
  switch (s) {
    case BpRangeSet.general:
      return const [
        MetricLevel(
          category: MetricCategory.fitFine,
          emoji: '🟢',
          label: 'Fit & Fine',
          range: '<120 / <80',
          desc: 'Healthy blood pressure. Keep up your habits.',
          color: AppColors.statusNormal,
        ),
        MetricLevel(
          category: MetricCategory.caution,
          emoji: '🟡',
          label: 'Caution',
          range: '120–129 / <80',
          desc: 'Slightly elevated. Reduce salt, walk daily, retest weekly.',
          color: AppColors.amber,
        ),
        MetricLevel(
          category: MetricCategory.atRisk,
          emoji: '🟠',
          label: 'At Risk',
          range: '130–139 / 80–89',
          desc: 'Higher than safe range. Consult your doctor within 7 days.',
          color: AppColors.statusElevated,
        ),
        MetricLevel(
          category: MetricCategory.urgent,
          emoji: '🚨',
          label: 'Urgent',
          range: '≥140 / ≥90 (or ≥180 / ≥120)',
          desc: 'High BP. See a doctor today. Above 180/120 — go to emergency.',
          color: AppColors.statusCritical,
        ),
      ];
    case BpRangeSet.diabeticOrCkd:
      return const [
        MetricLevel(
          category: MetricCategory.fitFine,
          emoji: '🟢',
          label: 'Fit & Fine',
          range: '<130 / <80',
          desc:
              'On target for diabetes/kidney disease (RSSDI 2022). Keep it up.',
          color: AppColors.statusNormal,
        ),
        MetricLevel(
          category: MetricCategory.caution,
          emoji: '🟡',
          label: 'Caution',
          range: '130–139 / 80–89',
          desc:
              'Above your target. Don\'t change medicines yourself — review with your doctor soon.',
          color: AppColors.amber,
        ),
        MetricLevel(
          category: MetricCategory.atRisk,
          emoji: '🟠',
          label: 'At Risk',
          range: '140–149 / 90–94',
          desc: 'Higher risk in your condition. Book a doctor visit this week.',
          color: AppColors.statusElevated,
        ),
        MetricLevel(
          category: MetricCategory.urgent,
          emoji: '🚨',
          label: 'Urgent',
          range: '≥150 / ≥95 (or ≥180 / ≥120)',
          desc: 'Call your doctor today. Above 180/120 — emergency.',
          color: AppColors.statusCritical,
        ),
      ];
    case BpRangeSet.senior:
      return const [
        MetricLevel(
          category: MetricCategory.fitFine,
          emoji: '🟢',
          label: 'Fit & Fine',
          range: '<130 / <80',
          desc: 'Healthy for your age group.',
          color: AppColors.statusNormal,
        ),
        MetricLevel(
          category: MetricCategory.caution,
          emoji: '🟡',
          label: 'Caution',
          range: '130–139 / 80–89',
          desc: 'Slightly elevated. Monitor weekly.',
          color: AppColors.amber,
        ),
        MetricLevel(
          category: MetricCategory.atRisk,
          emoji: '🟠',
          label: 'At Risk',
          range: '140–149 / 85–89',
          desc: 'Consult your doctor within 7 days.',
          color: AppColors.statusElevated,
        ),
        MetricLevel(
          category: MetricCategory.urgent,
          emoji: '🚨',
          label: 'Urgent',
          range: '≥150 / ≥90',
          desc: 'See a doctor today.',
          color: AppColors.statusCritical,
        ),
      ];
    case BpRangeSet.frailElderly:
      return const [
        MetricLevel(
          category: MetricCategory.fitFine,
          emoji: '🟢',
          label: 'Fit & Fine',
          range: '<140 / <85',
          desc: 'Good for frail elderly — avoid over-treatment.',
          color: AppColors.statusNormal,
        ),
        MetricLevel(
          category: MetricCategory.caution,
          emoji: '🟡',
          label: 'Caution',
          range: '140–149 / 85–89',
          desc: 'Borderline. Monitor and discuss with doctor.',
          color: AppColors.amber,
        ),
        MetricLevel(
          category: MetricCategory.atRisk,
          emoji: '🟠',
          label: 'At Risk',
          range: '150–159 / 90–94',
          desc: 'Higher risk. Doctor review within 7 days.',
          color: AppColors.statusElevated,
        ),
        MetricLevel(
          category: MetricCategory.urgent,
          emoji: '🚨',
          label: 'Urgent',
          range: '≥160 / ≥95',
          desc: 'See a doctor today.',
          color: AppColors.statusCritical,
        ),
      ];
  }
}

MetricLevel classifyBp({
  required double sys,
  required double dia,
  required BpRangeSet set,
}) {
  final levels = _bpLevels(set);
  // Hypertensive crisis trumps everything.
  if (sys >= 180 || dia >= 120) return levels[3];
  switch (set) {
    case BpRangeSet.general:
      if (sys < 120 && dia < 80) return levels[0];
      if (sys >= 140 || dia >= 90) return levels[3];
      if (sys >= 130 || dia >= 80) return levels[2];
      return levels[1];
    case BpRangeSet.diabeticOrCkd:
      // RSSDI 2022 target: <130/80 for diabetics/CKD.
      if (sys < 130 && dia < 80) return levels[0];
      if (sys >= 150 || dia >= 95) return levels[3];
      if (sys >= 140 || dia >= 90) return levels[2];
      return levels[1];
    case BpRangeSet.senior:
      if (sys < 130 && dia < 80) return levels[0];
      if (sys >= 150 || dia >= 90) return levels[3];
      if (sys >= 140 || dia >= 85) return levels[2];
      return levels[1];
    case BpRangeSet.frailElderly:
      if (sys < 140 && dia < 85) return levels[0];
      if (sys >= 160 || dia >= 95) return levels[3];
      if (sys >= 150 || dia >= 90) return levels[2];
      return levels[1];
  }
}

MetricInfoSpec buildBpSpec({
  required double? sys,
  required double? dia,
  required int? age,
  required List<String> conditions,
}) {
  final set = pickBpRangeSet(age: age, conditions: conditions);
  final levels = _bpLevels(set);
  MetricLevel? current;
  String? value;
  if (sys != null && dia != null) {
    current = classifyBp(sys: sys, dia: dia, set: set);
    value = '${sys.toStringAsFixed(0)}/${dia.toStringAsFixed(0)} mmHg';
  }
  return MetricInfoSpec(
    title: 'Blood Pressure',
    currentValue: value,
    currentLevel: current,
    levels: levels,
    rangeSetLabel: _bpRangeSetLabel(set),
    sources: const [MetricSources.ihci, MetricSources.icmrHtn],
    disclaimer: _kDisclaimer,
  );
}

// ===========================================================================
//                              FASTING GLUCOSE
// ===========================================================================

enum GlucoseRangeSet { nonDiabetic, diabeticAdult, diabeticElderly }

GlucoseRangeSet pickGlucoseRangeSet({
  required int? age,
  required List<String> conditions,
}) {
  final diabetic = _hasDiabetes(conditions);
  if (!diabetic) return GlucoseRangeSet.nonDiabetic;
  if (age != null && age >= 65) return GlucoseRangeSet.diabeticElderly;
  return GlucoseRangeSet.diabeticAdult;
}

String _glucoseSetLabel(GlucoseRangeSet s) {
  switch (s) {
    case GlucoseRangeSet.nonDiabetic:
      return 'Targets for: Non-diabetic adult (fasting)';
    case GlucoseRangeSet.diabeticAdult:
      return 'Targets adjusted for: Diabetes (under 65, pre-meal)';
    case GlucoseRangeSet.diabeticElderly:
      return 'Targets adjusted for: Diabetes (65+, relaxed)';
  }
}

List<MetricLevel> _glucoseLevels(GlucoseRangeSet s) {
  switch (s) {
    case GlucoseRangeSet.nonDiabetic:
      return const [
        MetricLevel(
          category: MetricCategory.fitFine,
          emoji: '🟢',
          label: 'Fit & Fine',
          range: '70–99 mg/dL',
          desc: 'Normal fasting glucose.',
          color: AppColors.statusNormal,
        ),
        MetricLevel(
          category: MetricCategory.caution,
          emoji: '🟡',
          label: 'Caution — prediabetes',
          range: '100–125 mg/dL',
          desc:
              'Prediabetes (early warning). Reduce sugar, walk daily, retest in 3 months.',
          color: AppColors.amber,
        ),
        MetricLevel(
          category: MetricCategory.atRisk,
          emoji: '🟠',
          label: 'At Risk — in diabetes range',
          range: '126–199 mg/dL',
          desc: 'In the diabetes range — needs confirmation by your doctor.',
          color: AppColors.statusElevated,
        ),
        MetricLevel(
          category: MetricCategory.urgent,
          emoji: '🚨',
          label: 'Urgent',
          range: '≥250 mg/dL or <70 mg/dL',
          desc:
              'Very high or very low. Contact your doctor today; if symptomatic, emergency.',
          color: AppColors.statusCritical,
        ),
      ];
    case GlucoseRangeSet.diabeticAdult:
      return const [
        MetricLevel(
          category: MetricCategory.fitFine,
          emoji: '🟢',
          label: 'Fit & Fine',
          range: '80–130 mg/dL (pre-meal)',
          desc: 'On target. Keep up medication and diet.',
          color: AppColors.statusNormal,
        ),
        MetricLevel(
          category: MetricCategory.caution,
          emoji: '🟡',
          label: 'Caution',
          range: '131–160 mg/dL',
          desc: 'Slightly above target. Review meals and medication timing.',
          color: AppColors.amber,
        ),
        MetricLevel(
          category: MetricCategory.atRisk,
          emoji: '🟠',
          label: 'At Risk',
          range: '161–200 mg/dL',
          desc: 'Persistently high — talk to your doctor about dose review.',
          color: AppColors.statusElevated,
        ),
        MetricLevel(
          category: MetricCategory.urgent,
          emoji: '🚨',
          label: 'Urgent',
          range: '≥250 mg/dL or <70 mg/dL',
          desc: 'Call your doctor today. If symptomatic, emergency.',
          color: AppColors.statusCritical,
        ),
      ];
    case GlucoseRangeSet.diabeticElderly:
      return const [
        MetricLevel(
          category: MetricCategory.fitFine,
          emoji: '🟢',
          label: 'Fit & Fine',
          range: '90–150 mg/dL (relaxed)',
          desc: 'On target for 65+ adults — relaxed to avoid hypoglycemia.',
          color: AppColors.statusNormal,
        ),
        MetricLevel(
          category: MetricCategory.caution,
          emoji: '🟡',
          label: 'Caution',
          range: '151–180 mg/dL',
          desc: 'Slightly high. Review meals and timing.',
          color: AppColors.amber,
        ),
        MetricLevel(
          category: MetricCategory.atRisk,
          emoji: '🟠',
          label: 'At Risk',
          range: '181–220 mg/dL',
          desc: 'Talk to your doctor about medication review.',
          color: AppColors.statusElevated,
        ),
        MetricLevel(
          category: MetricCategory.urgent,
          emoji: '🚨',
          label: 'Urgent',
          range: '≥250 mg/dL or <80 mg/dL',
          desc: 'Call your doctor today. If symptomatic, emergency.',
          color: AppColors.statusCritical,
        ),
      ];
  }
}

MetricLevel classifyGlucose({
  required double mgdl,
  required GlucoseRangeSet set,
}) {
  final levels = _glucoseLevels(set);
  switch (set) {
    case GlucoseRangeSet.nonDiabetic:
      if (mgdl < 70 || mgdl >= 250) return levels[3];
      if (mgdl <= 99) return levels[0];
      if (mgdl <= 125) return levels[1];
      return levels[2];
    case GlucoseRangeSet.diabeticAdult:
      if (mgdl < 70 || mgdl >= 250) return levels[3];
      if (mgdl <= 130) return levels[0];
      if (mgdl <= 160) return levels[1];
      return levels[2];
    case GlucoseRangeSet.diabeticElderly:
      if (mgdl < 80 || mgdl >= 250) return levels[3];
      if (mgdl <= 150) return levels[0];
      if (mgdl <= 180) return levels[1];
      return levels[2];
  }
}

MetricInfoSpec buildGlucoseSpec({
  required double? mgdl,
  required int? age,
  required List<String> conditions,
}) {
  final set = pickGlucoseRangeSet(age: age, conditions: conditions);
  final levels = _glucoseLevels(set);
  MetricLevel? current;
  String? value;
  if (mgdl != null) {
    current = classifyGlucose(mgdl: mgdl, set: set);
    value = '${mgdl.toStringAsFixed(0)} mg/dL';
  }
  return MetricInfoSpec(
    title: 'Blood Sugar',
    currentValue: value,
    currentLevel: current,
    levels: levels,
    rangeSetLabel: _glucoseSetLabel(set),
    footnote:
        'These ranges assume FASTING (more than 8 hours since your last meal). '
        'Post-meal targets are different — ask your doctor. '
        'HbA1c target: <7% (general) or <8% (elderly/frail).',
    sources: const [MetricSources.rssdi, MetricSources.icmrDm],
    disclaimer: _kDisclaimer,
  );
}

// ===========================================================================
//                              BMI (Asian-Indian cutoffs)
// ===========================================================================

enum BmiRangeSet { adult, senior }

BmiRangeSet pickBmiRangeSet({required int? age}) {
  if (age != null && age >= 65) return BmiRangeSet.senior;
  return BmiRangeSet.adult;
}

String _bmiSetLabel(BmiRangeSet s) {
  switch (s) {
    case BmiRangeSet.adult:
      return 'Targets for: Adult (Asian-Indian, 18–64)';
    case BmiRangeSet.senior:
      return 'Targets adjusted for: Senior 65+ (slightly higher protective)';
  }
}

List<MetricLevel> _bmiLevels(BmiRangeSet s) {
  switch (s) {
    case BmiRangeSet.adult:
      return const [
        MetricLevel(
          category: MetricCategory.fitFine,
          emoji: '🟢',
          label: 'Fit & Fine',
          range: '18.5–22.9',
          desc: 'Healthy weight for Asian Indians.',
          color: AppColors.statusNormal,
        ),
        MetricLevel(
          category: MetricCategory.caution,
          emoji: '🟡',
          label: 'Caution — slightly over',
          range: '23.0–24.9',
          desc: 'Slightly over — increase activity, cut sugar/refined carbs.',
          color: AppColors.amber,
        ),
        MetricLevel(
          category: MetricCategory.atRisk,
          emoji: '🟠',
          label: 'At Risk — higher or low weight',
          range: '25.0–29.9 or <18.5',
          desc:
              'Higher risk of diabetes/heart disease, or underweight needing nutrition support. Talk to your doctor.',
          color: AppColors.statusElevated,
        ),
        MetricLevel(
          category: MetricCategory.urgent,
          emoji: '🚨',
          label: 'Urgent — very high weight',
          range: '≥30',
          desc:
              'Significant risk of diabetes, heart disease, joint problems. Doctor consultation recommended.',
          color: AppColors.statusCritical,
        ),
      ];
    case BmiRangeSet.senior:
      return const [
        MetricLevel(
          category: MetricCategory.fitFine,
          emoji: '🟢',
          label: 'Fit & Fine',
          range: '22.0–27.0 (protective)',
          desc: 'Slightly higher BMI is protective for seniors.',
          color: AppColors.statusNormal,
        ),
        MetricLevel(
          category: MetricCategory.caution,
          emoji: '🟡',
          label: 'Caution',
          range: '27.1–29.9 or 20.0–21.9',
          desc: 'Borderline. Watch trend over months.',
          color: AppColors.amber,
        ),
        MetricLevel(
          category: MetricCategory.atRisk,
          emoji: '🟠',
          label: 'At Risk',
          range: '30.0–34.9 or 18.5–19.9',
          desc: 'Higher risk in seniors. Discuss with your doctor.',
          color: AppColors.statusElevated,
        ),
        MetricLevel(
          category: MetricCategory.urgent,
          emoji: '🚨',
          label: 'Urgent',
          range: '≥35 or <18.5',
          desc: 'Significant risk. Doctor consultation recommended.',
          color: AppColors.statusCritical,
        ),
      ];
  }
}

MetricLevel classifyBmi({required double bmi, required BmiRangeSet set}) {
  final levels = _bmiLevels(set);
  switch (set) {
    case BmiRangeSet.adult:
      // Underweight is At Risk (per Dr. Rajesh review — too alarming as Urgent),
      // not Urgent. Only ≥30 is Urgent.
      if (bmi >= 30) return levels[3];
      if (bmi < 18.5) return levels[2];
      if (bmi < 23) return levels[0];
      if (bmi < 25) return levels[1];
      return levels[2];
    case BmiRangeSet.senior:
      if (bmi < 18.5 || bmi >= 35) return levels[3];
      if (bmi >= 30 || bmi < 20) return levels[2];
      if (bmi >= 27.1 || bmi < 22) return levels[1];
      return levels[0];
  }
}

MetricInfoSpec buildBmiSpec({required double? bmi, required int? age}) {
  final set = pickBmiRangeSet(age: age);
  final levels = _bmiLevels(set);
  MetricLevel? current;
  String? value;
  if (bmi != null) {
    current = classifyBmi(bmi: bmi, set: set);
    value = bmi.toStringAsFixed(1);
  }
  return MetricInfoSpec(
    title: 'BMI',
    currentValue: value,
    currentLevel: current,
    levels: levels,
    rangeSetLabel: _bmiSetLabel(set),
    sources: const [MetricSources.icmrBmi],
    disclaimer: _kDisclaimer,
  );
}

// ===========================================================================
//                              STEPS
// ===========================================================================

int pickStepsGoal({required int? age, required List<String> conditions}) {
  if ((age != null && age >= 70) || _hasCardiac(conditions)) return 5000;
  return 7500;
}

List<MetricLevel> _stepsLevels(int goal) {
  return [
    MetricLevel(
      category: MetricCategory.fitFine,
      emoji: '🟢',
      label: 'Fit & Fine',
      range: '≥100% of your goal ($goal)',
      desc: 'You hit your daily target. Excellent.',
      color: AppColors.statusNormal,
    ),
    MetricLevel(
      category: MetricCategory.caution,
      emoji: '🟡',
      label: 'Caution',
      range: '50–99% of goal',
      desc: 'Close but not there. Try a 15-minute walk to close the gap.',
      color: AppColors.amber,
    ),
    MetricLevel(
      category: MetricCategory.atRisk,
      emoji: '🟠',
      label: 'At Risk',
      range: '25–49% of goal',
      desc: 'Mostly sedentary today. Aim for short walks every hour.',
      color: AppColors.statusElevated,
    ),
    MetricLevel(
      category: MetricCategory.urgent,
      emoji: '🚨',
      label: 'Urgent — very low movement',
      range: '<25% of goal',
      desc:
          'Very low movement. Sustained inactivity worsens BP, sugar and mood.',
      color: AppColors.statusCritical,
    ),
  ];
}

MetricLevel classifySteps({required int count, required int goal}) {
  final levels = _stepsLevels(goal);
  if (goal <= 0) return levels[0];
  final pct = count / goal;
  if (pct >= 1.0) return levels[0];
  if (pct >= 0.5) return levels[1];
  if (pct >= 0.25) return levels[2];
  return levels[3];
}

MetricInfoSpec buildStepsSpec({
  required int count,
  required int? age,
  required List<String> conditions,
}) {
  final goal = pickStepsGoal(age: age, conditions: conditions);
  final isCardiac = _hasCardiac(conditions);
  var levels = _stepsLevels(goal);

  // Cardiac patients may be on doctor-prescribed rest after MI/stroke.
  // Don't alarm them for following medical advice — soften the bottom band
  // wording (the classification stays the same so callers can still tell).
  if (isCardiac) {
    final softened = MetricLevel(
      category: levels[3].category,
      emoji: levels[3].emoji,
      label: 'Low movement',
      range: levels[3].range,
      desc:
          'Take rest if your doctor advised it after a heart event. '
          'Otherwise, try a short walk when you feel up to it.',
      color: levels[3].color,
    );
    levels = [levels[0], levels[1], levels[2], softened];
  }

  // Recompute current using possibly-softened levels (label/desc only changed).
  MetricLevel current;
  if (goal <= 0) {
    current = levels[0];
  } else {
    final pct = count / goal;
    if (pct >= 1.0) {
      current = levels[0];
    } else if (pct >= 0.5) {
      current = levels[1];
    } else if (pct >= 0.25) {
      current = levels[2];
    } else {
      current = levels[3];
    }
  }

  final label = (age != null && age >= 70) || isCardiac
      ? 'Targets adjusted for: Senior or cardiac condition (lower goal)'
      : 'Targets for: Adult (general)';
  return MetricInfoSpec(
    title: 'Daily Steps',
    currentValue: '$count steps',
    currentLevel: current,
    levels: levels,
    rangeSetLabel: label,
    sources: const [MetricSources.who, MetricSources.icmrNin],
    disclaimer: _kDisclaimer,
  );
}
