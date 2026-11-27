import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streak/features/todos/data/todo.dart';
import 'package:streak/features/todos/data/todo_chip.dart';
import 'package:streak/features/todos/data/todo_tag.dart';

void main() {
  const red = Color(0xFFE53935);
  const blue = Color(0xFF1E88E5);
  const accent = Color(0xFF7C5CFC);
  final tags = {
    'urgent': const TodoTag(id: 'urgent', name: 'Urgent', color: red),
    'residency': const TodoTag(
      id: 'residency',
      name: 'Residency',
      color: blue,
      kind: TodoTagKind.project,
    ),
  };
  TodoTag? byId(String id) => tags[id];
  Todo todo(String text, {List<String> tags = const [], String project = '', bool done = false}) =>
      Todo(
        id: text,
        text: text,
        createdAt: DateTime(2026),
        tags: tags,
        project: project,
        done: done,
      );

  test('a task takes the colour of its first known tag', () {
    final chip = TodoChip.of(
      todo('Call', tags: ['gone', 'urgent'], project: 'residency'),
      byId,
      fallback: accent,
    );
    expect(chip.color, red);
    expect(chip.title, 'Call');
  });

  test('without a tag it takes its project colour, else the fallback', () {
    expect(
      TodoChip.of(todo('Study', project: 'residency'), byId, fallback: accent).color,
      blue,
    );
    expect(TodoChip.of(todo('Shop'), byId, fallback: accent).color, accent);
  });

  test('a day lists open tasks before done ones', () {
    final chips = TodoChip.forDay(
      [todo('A', done: true), todo('B'), todo('C', done: true), todo('D')],
      byId,
      fallback: accent,
    );
    expect(chips.map((c) => c.title), ['B', 'D', 'A', 'C']);
    expect(chips.map((c) => c.done), [false, false, true, true]);
  });

  test('label text is light on dark colours and dark on light ones', () {
    expect(TodoChip.inkOn(const Color(0xFF1A237E)), Colors.white);
    expect(TodoChip.inkOn(const Color(0xFFFFF59D)), Colors.black87);
  });
}
