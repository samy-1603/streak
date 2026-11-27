import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:streak/core/database/local_store.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/utils/app_dirs.dart';
import 'package:streak/features/todos/data/todo.dart';
import 'package:streak/features/todos/data/todo_chip.dart';
import 'package:streak/features/todos/data/todo_tag.dart';
import 'package:streak/services/home_widget_service.dart';

/// Feeds the home-screen calendar widget: for each day around today, the
/// tasks due that day as coloured labels.
class CalendarWidgetService {
  const CalendarWidgetService._();

  static const _provider = 'CalendarWidgetProvider';

  /// Labels kept per day; the widget shows what fits and "+n" for the rest.
  static const _perDay = 6;

  /// Months kept before and after the current one, for paging the widget.
  static const _monthsBack = 2;
  static const _monthsAhead = 6;

  /// Colour for tasks without a tag or project.
  static const fallback = Color(0xFF4F7DF3);

  static Future<void> sync(List<Todo> todos) async {
    if (!hasHomeWidgets) return;
    try {
      await HomeWidgetService.prepare();
      await HomeWidget.saveWidgetData<String>(
        'calendar_data',
        encode(
          todos,
          LocalStore.readTodoTags(),
          weekStart: LocalStore.setting('weekStart', 1),
        ),
      );
      await HomeWidget.updateWidget(androidName: _provider, iOSName: _provider);
    } catch (e) {
      debugPrint('Calendar widget sync failed: $e');
    }
  }

  /// The widget's data as JSON: today, the first weekday (1 = Monday …
  /// 7 = Sunday) and, per epoch day, the label count and the first labels
  /// as [title, ARGB colour, done].
  @visibleForTesting
  static String encode(
    List<Todo> todos,
    List<TodoTag> tags, {
    required int weekStart,
    DateTime? today,
  }) {
    final now = today ?? AppClock.today();
    final from = DateTime(now.year, now.month - _monthsBack).epochDay;
    final to = DateTime(now.year, now.month + _monthsAhead + 1, 0).epochDay;
    final byId = {for (final tag in tags) tag.id: tag};

    final perDay = <int, List<Todo>>{};
    for (final todo in todos) {
      final due = todo.due;
      if (due == null) continue;
      final day = due.epochDay;
      if (day < from || day > to) continue;
      (perDay[day] ??= []).add(todo);
    }

    return json.encode({
      'today': now.epochDay,
      'weekStart': weekStart,
      'days': {
        for (final MapEntry(key: day, value: list) in perDay.entries)
          '$day': {
            'n': list.length,
            'c': [
              for (final chip in TodoChip.forDay(
                list,
                (id) => byId[id],
                fallback: fallback,
              ).take(_perDay))
                [chip.title, chip.color.toARGB32(), if (chip.done) 1 else 0],
            ],
          },
      },
    });
  }
}
