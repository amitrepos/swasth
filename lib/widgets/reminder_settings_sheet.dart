import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../services/reminder_service.dart';
import '../theme/app_theme.dart';

@visibleForTesting
Future<TimeOfDay?> Function(
  BuildContext context, {
  required TimeOfDay initialTime,
  String? helpText,
})?
reminderTimePickerOverride;

Future<TimeOfDay?> pickReminderTimeForSheet(
  BuildContext context, {
  required TimeOfDay initialTime,
  String? helpText,
}) {
  final override = reminderTimePickerOverride;
  if (override != null) {
    return override(context, initialTime: initialTime, helpText: helpText);
  }
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    helpText: helpText,
  );
}

@visibleForTesting
String reminderWeekdayLabel(BuildContext ctx, int day0Sunday) {
  final locale = Localizations.localeOf(ctx).toString();
  return DateFormat.EEEE(locale).format(DateTime(2024, 1, 7 + day0Sunday));
}

Future<void> showReminderSettingsSheet(
  BuildContext ctx, {
  required bool Function() isParentMounted,
}) async {
  final reminder = ReminderService();
  final l10n = AppLocalizations.of(ctx)!;

  var dailyEnabled = await reminder.isEnabled();
  var dailyHour = await reminder.getHour();
  var dailyMinute = await reminder.getMinute();
  var weightEnabled = await reminder.weightReminderEnabled();
  var weightDay = await reminder.weightReminderDay();
  var weightHour = await reminder.weightReminderHour();
  var weightMinute = await reminder.weightReminderMinute();

  if (!isParentMounted()) return;

  await showModalBottomSheet<void>(
    context: ctx,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final dailyTime = TimeOfDay(hour: dailyHour, minute: dailyMinute);
          final weightTime = TimeOfDay(hour: weightHour, minute: weightMinute);

          Future<void> showPermissionDialog() async {
            if (!isParentMounted()) return;
            if (!sheetCtx.mounted) return;
            await showDialog<void>(
              context: sheetCtx,
              builder: (dialogCtx) => AlertDialog(
                content: Text(l10n.notificationPermissionRequired),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    child: Text(l10n.cancel),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.of(dialogCtx).pop();
                      await openAppSettings();
                    },
                    child: Text(l10n.reminderOpenSettings),
                  ),
                ],
              ),
            );
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                16 + MediaQuery.of(sheetCtx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.35,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const SizedBox(width: 56),
                        Expanded(
                          child: Text(
                            l10n.reminderSettingsTitle,
                            style: Theme.of(sheetCtx).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                          child: Text(l10n.reminderSheetDone),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Daily reading reminder ──────────────────────────
                    Text(
                      l10n.dailyReminderSection,
                      style: Theme.of(sheetCtx).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.dailyReminderEnableLabel),
                      value: dailyEnabled,
                      onChanged: (on) async {
                        if (on) {
                          final time = await pickReminderTimeForSheet(
                            sheetCtx,
                            initialTime: dailyTime,
                            helpText: l10n.reminderSetTime,
                          );
                          if (time == null) {
                            setSheetState(() {});
                            return;
                          }
                          final ok = await reminder.enableReminder(
                            time.hour,
                            time.minute,
                          );
                          if (!ok) {
                            await showPermissionDialog();
                            setSheetState(() {});
                            return;
                          }
                          setSheetState(() {
                            dailyEnabled = true;
                            dailyHour = time.hour;
                            dailyMinute = time.minute;
                          });
                          if (isParentMounted()) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.reminderSetFor(time.format(ctx)),
                                ),
                              ),
                            );
                          }
                        } else {
                          await reminder.disableReminder();
                          setSheetState(() => dailyEnabled = false);
                          if (isParentMounted()) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(l10n.reminderDisabled)),
                            );
                          }
                        }
                      },
                    ),
                    if (dailyEnabled)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.reminderChangeTime),
                        trailing: Text(dailyTime.format(sheetCtx)),
                        onTap: () async {
                          final time = await pickReminderTimeForSheet(
                            sheetCtx,
                            initialTime: dailyTime,
                            helpText: l10n.reminderChangeTime,
                          );
                          if (time == null) {
                            setSheetState(() {});
                            return;
                          }
                          final ok = await reminder.enableReminder(
                            time.hour,
                            time.minute,
                          );
                          if (!ok) {
                            await showPermissionDialog();
                            setSheetState(() {});
                            return;
                          }
                          setSheetState(() {
                            dailyHour = time.hour;
                            dailyMinute = time.minute;
                          });
                          if (isParentMounted()) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.reminderSetFor(time.format(ctx)),
                                ),
                              ),
                            );
                          }
                        },
                      ),

                    const Divider(height: 32),

                    // ── Weekly weight reminder ──────────────────────────
                    Text(
                      l10n.weeklyWeightReminderSection,
                      style: Theme.of(sheetCtx).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      key: const Key('weight-reminder-switch'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.weightReminderEnableLabel),
                      subtitle: weightEnabled
                          ? Text(
                              l10n.weightReminderSetFor(
                                reminderWeekdayLabel(sheetCtx, weightDay),
                                weightTime.format(sheetCtx),
                              ),
                            )
                          : null,
                      value: weightEnabled,
                      onChanged: (on) async {
                        if (on) {
                          final time = await pickReminderTimeForSheet(
                            sheetCtx,
                            initialTime: weightTime,
                            helpText: l10n.weightReminderSetTime,
                          );
                          if (time == null) {
                            setSheetState(() {});
                            return;
                          }
                          final ok = await reminder.enableWeightReminder(
                            weightDay,
                            time.hour,
                            time.minute,
                            notificationTitle:
                                l10n.weightReminderNotificationTitle,
                            notificationBody:
                                l10n.weightReminderNotificationBody,
                          );
                          if (!ok) {
                            await showPermissionDialog();
                            setSheetState(() {});
                            return;
                          }
                          setSheetState(() {
                            weightEnabled = true;
                            weightHour = time.hour;
                            weightMinute = time.minute;
                          });
                          if (isParentMounted()) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.weightReminderSetFor(
                                    reminderWeekdayLabel(ctx, weightDay),
                                    time.format(ctx),
                                  ),
                                ),
                              ),
                            );
                          }
                        } else {
                          await reminder.disableWeightReminder();
                          setSheetState(() => weightEnabled = false);
                          if (isParentMounted()) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(l10n.weightReminderDisabled),
                              ),
                            );
                          }
                        }
                      },
                    ),
                    if (weightEnabled) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.weightReminderDayLabel),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(reminderWeekdayLabel(sheetCtx, weightDay)),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                        onTap: () async {
                          final day = await showModalBottomSheet<int>(
                            context: sheetCtx,
                            builder: (pickerCtx) {
                              return SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        16,
                                        20,
                                        8,
                                      ),
                                      child: Text(
                                        l10n.weightReminderPickDayTitle,
                                        style: Theme.of(pickerCtx)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    ...List.generate(
                                      7,
                                      (i) => ListTile(
                                        title: Text(
                                          reminderWeekdayLabel(pickerCtx, i),
                                        ),
                                        trailing: i == weightDay
                                            ? const Icon(
                                                Icons.check,
                                                color: AppColors.primary,
                                              )
                                            : null,
                                        onTap: () =>
                                            Navigator.of(pickerCtx).pop(i),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                          if (day == null) return;
                          final ok = await reminder.enableWeightReminder(
                            day,
                            weightHour,
                            weightMinute,
                            notificationTitle:
                                l10n.weightReminderNotificationTitle,
                            notificationBody:
                                l10n.weightReminderNotificationBody,
                          );
                          if (!ok) {
                            await showPermissionDialog();
                            setSheetState(() {});
                            return;
                          }
                          setSheetState(() => weightDay = day);
                          if (isParentMounted()) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.weightReminderSetFor(
                                    reminderWeekdayLabel(ctx, day),
                                    weightTime.format(ctx),
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.weightReminderTimeLabel),
                        trailing: Text(weightTime.format(sheetCtx)),
                        onTap: () async {
                          final time = await pickReminderTimeForSheet(
                            sheetCtx,
                            initialTime: weightTime,
                            helpText: l10n.weightReminderChangeTime,
                          );
                          if (time == null) {
                            setSheetState(() {});
                            return;
                          }
                          final ok = await reminder.enableWeightReminder(
                            weightDay,
                            time.hour,
                            time.minute,
                            notificationTitle:
                                l10n.weightReminderNotificationTitle,
                            notificationBody:
                                l10n.weightReminderNotificationBody,
                          );
                          if (!ok) {
                            await showPermissionDialog();
                            setSheetState(() {});
                            return;
                          }
                          setSheetState(() {
                            weightHour = time.hour;
                            weightMinute = time.minute;
                          });
                          if (isParentMounted()) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.weightReminderSetFor(
                                    reminderWeekdayLabel(ctx, weightDay),
                                    time.format(ctx),
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
