import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/express/express_surface.dart';
import 'package:streak/core/database/local_store.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/minimal/minimal_kit.dart';
import 'package:streak/core/utils/amount_format.dart';
import 'package:streak/core/widgets/sheet_type.dart';
import 'package:streak/core/routing/app_navigator.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/pages/focus_page.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/habits/data/habit.dart';
import 'package:streak/features/habits/state/habits_controller.dart';
import 'package:streak/features/settings/state/settings_controller.dart';

enum FocusMode { timer, pomodoro, flow }

const focusDialMax = 120;
const focusDialStep = 5;

BoxDecoration focusPanel(BuildContext context, {Color? tint}) {
  final style = context.watch<SettingsController>();
  if (style.isExpressStyle) {
    return BoxDecoration(
      color: tint ?? expressSurface(context),
      borderRadius: BorderRadius.circular(26),
      border: expressHairline(context),
    );
  }
  if (style.isMinimalStyle) {
    return BoxDecoration(
      color: tint ?? minimalSurface(context),
      borderRadius: BorderRadius.circular(20),
    );
  }
  return BoxDecoration(
    color:
        tint ?? context.colors.surfaceContainerHighest.withValues(alpha: 0.6),
    borderRadius: BorderRadius.circular(18),
  );
}

class FocusTodayStrip extends StatelessWidget {
  const FocusTodayStrip({super.key});

  static int streakOf(FocusController focus) {
    var day = AppClock.today();
    if (focus.secondsForDay(day) <= 0) day = day.addDays(-1);
    var count = 0;
    while (count < 366 && focus.secondsForDay(day) > 0) {
      count++;
      day = day.addDays(-1);
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final focus = context.read<FocusController>();
    final goal = context.watch<SettingsController>().focusDailyGoal;
    final done = focus.secondsForDay(AppClock.now());
    final streak = streakOf(focus);

    final pills = <Widget>[
      if (goal > 0)
        _Pill(
          leading: _GoalRing(progress: done / (goal * 60)),
          text: context.l10n.focus_goal_today(
            done < 60 ? formatMinutes(0) : formatHoursShort(done),
            formatHoursShort(goal * 60),
          ),
        )
      else if (done > 0)
        _Pill(
          leading: Icon(
            LucideIcons.timer,
            size: 14,
            color: context.colors.primary,
          ),
          text: '${context.l10n.today} · ${formatHoursShort(done)}',
        ),
      if (streak > 1)
        _Pill(
          leading: Icon(
            LucideIcons.flame,
            size: 14,
            color: context.tokens.warning,
          ),
          text: context.l10n.focus_days_row(streak),
        ),
    ];
    if (pills.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: pills,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.leading, required this.text});

  final Widget leading;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: focusPanel(context).copyWith(
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 7),
          Text(
            text,
            style: sheetLabelStyle(
              context,
              size: 12.5,
              color: context.colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalRing extends StatelessWidget {
  const _GoalRing({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final done = progress >= 1;
    return SizedBox.square(
      dimension: 15,
      child: done
          ? Icon(
              LucideIcons.circleCheck,
              size: 15,
              color: context.tokens.success,
            )
          : CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: 2.4,
              color: context.tokens.success,
              backgroundColor: context.colors.onSurface.withValues(alpha: 0.12),
            ),
    );
  }
}

class FocusTimer {
  const FocusTimer(
    this.minutes,
    this.breakMinutes, {
    this.longBreak = 0,
    this.every = 0,
  });

  /// The timer as set up right now: for a Pomodoro, the global long-break
  /// length and rounds-before-long-break go with it, so a saved preset
  /// restores the whole cycle.
  factory FocusTimer.withCycle(
    int minutes,
    int breakMinutes,
    SettingsController settings,
  ) {
    final pomodoro = minutes > 0 && breakMinutes > 0;
    final long = pomodoro ? settings.focusLongBreak : 0;
    return FocusTimer(
      minutes,
      breakMinutes,
      longBreak: long,
      every: long > 0 ? settings.focusLongBreakEvery : 0,
    );
  }

  static const limit = 10;

  final int minutes;
  final int breakMinutes;
  final int longBreak;
  final int every;

  FocusMode get mode => minutes <= 0
      ? FocusMode.flow
      : breakMinutes > 0
      ? FocusMode.pomodoro
      : FocusMode.timer;

  bool get hasLongBreak => mode == FocusMode.pomodoro && longBreak > 0 && every > 0;

  String get key => hasLongBreak
      ? '$minutes:$breakMinutes:$longBreak:$every'
      : '$minutes:$breakMinutes';

  /// Puts this preset's long-break cycle into the settings the timer runs on.
  Future<void> applyCycle(SettingsController settings) async {
    if (mode != FocusMode.pomodoro) return;
    await settings.setFocusLongBreak(hasLongBreak ? longBreak : 0);
    if (hasLongBreak) await settings.setFocusLongBreakEvery(every);
  }

  static FocusTimer? parse(Object? raw) {
    if (raw is! String) return null;
    final parts = raw.split(':');
    if (parts.length != 2 && parts.length != 4) return null;
    final numbers = parts.map(int.tryParse).toList();
    if (numbers.contains(null)) return null;
    final minutes = numbers[0]!;
    final rest = minutes <= 0 ? 0 : numbers[1]!;
    if (parts.length == 2) return FocusTimer(minutes, rest);
    return FocusTimer(minutes, rest, longBreak: numbers[2]!, every: numbers[3]!);
  }

  static List<FocusTimer> load() => [
    for (final raw in LocalStore.setting<List>('focusProfiles', const []))
      ?parse(raw),
  ];

  static Future<void> store(List<FocusTimer> timers) =>
      LocalStore.writeSetting('focusProfiles', [for (final t in timers) t.key]);

  String text(BuildContext context) => switch (mode) {
    FocusMode.flow => context.l10n.focus_flowtime,
    FocusMode.pomodoro =>
      '$minutes + ${context.l10n.minutes_short('$breakMinutes')}'
          '${hasLongBreak ? '  ·  ${context.l10n.focus_preset_long('$every', '$longBreak')}' : ''}',
    FocusMode.timer => context.l10n.minutes_short('$minutes'),
  };

  String short(BuildContext context) => switch (mode) {
    FocusMode.flow => '',
    FocusMode.pomodoro => '$minutes/$breakMinutes',
    FocusMode.timer => context.l10n.minutes_short('$minutes'),
  };

  @override
  bool operator ==(Object other) => other is FocusTimer && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

const focusModeIcons = {
  FocusMode.timer: LucideIcons.timer,
  FocusMode.pomodoro: LucideIcons.repeat,
  FocusMode.flow: LucideIcons.infinity,
};

class FocusSavedTimers extends StatelessWidget {
  const FocusSavedTimers({
    super.key,
    required this.timers,
    required this.current,
    required this.onApply,
    required this.onSave,
    required this.onRemove,
  });

  final List<FocusTimer> timers;
  final FocusTimer current;
  final ValueChanged<FocusTimer> onApply;
  final VoidCallback onSave;
  final ValueChanged<FocusTimer> onRemove;

  @override
  Widget build(BuildContext context) {
    final canSave =
        !timers.contains(current) && timers.length < FocusTimer.limit;
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              [
                    for (final timer in timers)
                      _TimerPill(
                        icon: focusModeIcons[timer.mode]!,
                        label: timer.text(context),
                        selected: timer == current,
                        onTap: () => onApply(timer),
                        onLongPress: () => onRemove(timer),
                        onRemove: () => onRemove(timer),
                      ),
                    if (canSave)
                      _TimerPill(
                        icon: LucideIcons.bookmarkPlus,
                        label: context.l10n.focus_save_timer,
                        selected: false,
                        dashed: true,
                        onTap: onSave,
                      ),
                  ]
                  .map(
                    (pill) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: pill,
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }
}

class _TimerPill extends StatelessWidget {
  const _TimerPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.onRemove,
    this.dashed = false,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onRemove;
  final bool dashed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.primary;
    final tone = selected
        ? accent
        : dashed
        ? context.tokens.muted
        : context.colors.onSurface.withValues(alpha: 0.8);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: compact
              ? EdgeInsets.fromLTRB(7, 6, label.isEmpty ? 7 : 9, 6)
              : const EdgeInsets.fromLTRB(10, 7, 12, 7),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.14)
                : dashed
                ? Colors.transparent
                : compact
                ? context.colors.onSurface.withValues(alpha: 0.06)
                : focusPanel(context).color,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected
                  ? accent
                  : context.colors.onSurface.withValues(
                      alpha: dashed ? 0.18 : 0,
                    ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: tone),
              if (label.isNotEmpty) ...[
                SizedBox(width: compact ? 5 : 6),
                Text(
                  label,
                  style: sheetLabelStyle(context, size: 12.5, color: tone),
                ),
              ],
              if (selected && onRemove != null)
                Semantics(
                  button: true,
                  label: context.l10n.focus_remove_timer,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onRemove,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(LucideIcons.x, size: 14, color: tone),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void startFocusTimer(BuildContext context, Habit habit, FocusTimer timer) {
  final focus = context.read<FocusController>();
  if (!focus.isActive && timer.every > 0) {
    timer.applyCycle(context.read<SettingsController>());
  }
  if (!focus.isActive &&
      (habit.focusMinutes != timer.minutes ||
          habit.focusBreakMinutes != timer.breakMinutes)) {
    context.read<HabitsController>().update(
      habit.copyWith(
        focusMinutes: timer.minutes,
        focusBreakMinutes: timer.breakMinutes,
      ),
    );
  }
  AppNavigator.push(
    focus.isActive
        ? const FocusPage()
        : FocusPage(
            startHabitId: habit.id,
            startMinutes: timer.minutes,
            breakMinutes: timer.breakMinutes,
          ),
    fade: true,
    name: FocusPage.routeName,
  );
}

class FocusQuickTimers extends StatelessWidget {
  const FocusQuickTimers({
    super.key,
    required this.habit,
    this.padding = EdgeInsets.zero,
  });

  final Habit habit;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final saved = FocusTimer.load();
    if (saved.isEmpty) return const SizedBox.shrink();
    final current = FocusTimer.withCycle(
      habit.focusMinutes,
      habit.focusBreakMinutes,
      context.watch<SettingsController>(),
    );
    final timers = saved.contains(current) ? saved : [current, ...saved];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final timer in timers)
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: _TimerPill(
                compact: true,
                icon: focusModeIcons[timer.mode]!,
                label: timer.short(context),
                selected: timer == current,
                onTap: () => startFocusTimer(context, habit, timer),
              ),
            ),
        ],
      ),
    );
  }
}

class FocusSwap extends StatelessWidget {
  const FocusSwap({super.key, required this.child, this.size = true});

  final Widget child;
  final bool size;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final swap = AnimatedSwitcher(
      duration: still ? Duration.zero : const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
    if (!size) return swap;
    return AnimatedSize(
      duration: still ? Duration.zero : const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: swap,
    );
  }
}
