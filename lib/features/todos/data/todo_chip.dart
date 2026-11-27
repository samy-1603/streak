import 'package:flutter/material.dart';
import 'package:streak/features/todos/data/todo.dart';
import 'package:streak/features/todos/data/todo_tag.dart';

/// A task as shown on a calendar day: its title, a colour and whether it is
/// done. Used by the in-app month calendar and the home-screen widget.
@immutable
class TodoChip {
  const TodoChip({required this.title, required this.color, required this.done});

  final String title;
  final Color color;
  final bool done;

  /// The chip for [todo]: the colour of its first tag, else of its project,
  /// else [fallback].
  factory TodoChip.of(
    Todo todo,
    TodoTag? Function(String id) tagById, {
    required Color fallback,
  }) {
    Color? color;
    for (final id in todo.tags) {
      final tag = tagById(id);
      if (tag != null) {
        color = tag.color;
        break;
      }
    }
    if (color == null && todo.project.isNotEmpty) {
      color = tagById(todo.project)?.color;
    }
    return TodoChip(
      title: todo.title,
      color: color ?? fallback,
      done: todo.done,
    );
  }

  /// Chips for a day's tasks, open ones first.
  static List<TodoChip> forDay(
    Iterable<Todo> todos,
    TodoTag? Function(String id) tagById, {
    required Color fallback,
  }) {
    final sorted = todos.toList()
      ..sort((a, b) => a.done == b.done ? 0 : (a.done ? 1 : -1));
    return [
      for (final todo in sorted) TodoChip.of(todo, tagById, fallback: fallback),
    ];
  }

  /// Black or white text, whichever reads better on [color].
  static Color inkOn(Color color) =>
      ThemeData.estimateBrightnessForColor(color) == Brightness.dark
          ? Colors.white
          : Colors.black87;
}
