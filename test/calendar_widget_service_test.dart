import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/features/todos/data/todo.dart';
import 'package:streak/features/todos/data/todo_tag.dart';
import 'package:streak/services/calendar_widget_service.dart';

void main() {
  const green = Color(0xFF34C759);
  final tags = [const TodoTag(id: 'errands', name: 'Errands', color: green)];
  final today = DateTime(2026, 9, 7);

  Todo todo(String text, DateTime? day, {List<String> tags = const [], bool done = false}) =>
      Todo(
        id: text,
        text: text,
        createdAt: DateTime(2026),
        date: day?.dayKey ?? '',
        tags: tags,
        done: done,
      );

  Map<String, dynamic> encode(List<Todo> todos) => json.decode(
        CalendarWidgetService.encode(todos, tags, weekStart: 7, today: today),
      ) as Map<String, dynamic>;

  test('each day lists its tasks with their colour, open ones first', () {
    final data = encode([
      todo('Done one', today, done: true),
      todo('Groceries', today, tags: ['errands']),
      todo('No date', null),
    ]);
    expect(data['today'], today.epochDay);
    expect(data['weekStart'], 7);
    final day = (data['days'] as Map)['${today.epochDay}'] as Map;
    expect(day['n'], 2);
    expect(day['c'], [
      ['Groceries', green.toARGB32(), 0],
      ['Done one', CalendarWidgetService.fallback.toARGB32(), 1],
    ]);
    expect((data['days'] as Map).length, 1, reason: 'undated tasks are left out');
  });

  test('a busy day keeps a few labels and the full count', () {
    final data = encode([for (var i = 0; i < 9; i++) todo('Task $i', today)]);
    final day = (data['days'] as Map)['${today.epochDay}'] as Map;
    expect(day['n'], 9);
    expect((day['c'] as List).length, 6);
  });

  test('only the months around today are sent', () {
    final data = encode([
      todo('Too old', DateTime(2026, 6, 30)),
      todo('Oldest kept', DateTime(2026, 7, 1)),
      todo('Furthest kept', DateTime(2027, 3, 31)),
      todo('Too far', DateTime(2027, 4, 1)),
    ]);
    final days = (data['days'] as Map).keys.toSet();
    expect(days, {
      '${DateTime(2026, 7, 1).epochDay}',
      '${DateTime(2027, 3, 31).epochDay}',
    });
  });
}
