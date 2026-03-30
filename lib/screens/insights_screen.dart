// Context: Insights tab — wraps TrendChartScreen for the bottom nav shell.
// Related: trend_chart_screen.dart, shell_screen.dart

import 'package:flutter/material.dart';
import 'trend_chart_screen.dart';

class InsightsScreen extends StatelessWidget {
  final int profileId;
  const InsightsScreen({super.key, required this.profileId});

  @override
  Widget build(BuildContext context) {
    return TrendChartScreen(profileId: profileId);
  }
}
