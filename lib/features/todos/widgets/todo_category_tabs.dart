import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/features/todos/data/todo_chip.dart';
import 'package:streak/features/todos/state/todo_tags_controller.dart';
import 'package:streak/features/todos/state/todos_controller.dart';
import 'package:streak/features/todos/widgets/todo_tag_sheet.dart';

/// The row of category tabs on top of the task list: All, then each
/// category (a project), then + to make a new one. One tap switches the
/// list; a long press edits or deletes a category.
class TodoCategoryTabs extends StatelessWidget {
  const TodoCategoryTabs({
    super.key,
    required this.selected,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  /// The chosen category's id, or null for All.
  final String? selected;
  final ValueChanged<String?> onSelected;
  final EdgeInsets padding;

  Future<void> _create(BuildContext context) async {
    final tags = context.read<TodoTagsController>();
    final before = {for (final tag in tags.projects) tag.id};
    await createProject(context);
    for (final tag in tags.projects) {
      if (!before.contains(tag.id)) return onSelected(tag.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = context.watch<TodoTagsController>().projects;
    final todos = context.watch<TodosController>();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        children: [
          _Tab(
            label: context.l10n.todo_category_all,
            count: todos.pendingCount,
            color: context.colors.primary,
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final project in projects)
            _Tab(
              label: project.name,
              count: todos.projectCount(project.id),
              color: project.color,
              dot: true,
              selected: selected == project.id,
              onTap: () => onSelected(project.id),
              onLongPress: () => editOrDeleteTag(context, project),
            ),
          _AddTab(onTap: () => _create(context)),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.dot = false,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final bool dot;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? TodoChip.inkOn(color) : context.colors.onSurface;
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? color
                  : context.colors.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dot && !selected) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 7),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? ink.withValues(alpha: 0.75)
                          : context.tokens.muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTab extends StatelessWidget {
  const _AddTab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: context.l10n.todo_project_new,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: context.colors.onSurface.withValues(alpha: 0.18),
              ),
            ),
            child: Icon(LucideIcons.plus, size: 18, color: context.tokens.muted),
          ),
        ),
      ),
    );
  }
}
