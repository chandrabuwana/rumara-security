import 'package:flutter/material.dart';
import 'package:guardify_app/core/design/colors.dart';
import 'package:guardify_app/features/home/presentation/bloc/home_state.dart';

class TaskCard extends StatelessWidget {
  final TaskItem task;
  final VoidCallback? onTap;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: primaryColor,
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task Title and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: neutral90,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: task.isCompleted ? successColor : primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(task.progress * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Task Subtitle
            Text(
              task.subtitle,
              style: TextStyle(
                fontSize: 14,
                color: neutral70,
              ),
            ),

            const SizedBox(height: 12),

            // Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${task.completedTasks}/${task.totalTasks} Selesai',
                      style: TextStyle(
                        fontSize: 12,
                        color: neutral70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${(task.progress * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: neutral70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: task.progress,
                    backgroundColor: neutral30,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      task.isCompleted ? successColor : primaryColor,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    // Wrap with GestureDetector for reliable tap detection
    if (onTap != null) {
      return GestureDetector(
        onTap: () {
          print('🖱️ TaskCard tapped! Task ID: ${task.id}, Title: ${task.title}');
          onTap?.call();
        },
        child: cardContent,
      );
    }

    return cardContent;
  }
}
