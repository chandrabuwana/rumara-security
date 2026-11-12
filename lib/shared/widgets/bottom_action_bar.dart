import 'package:flutter/material.dart';

import '../../core/design/colors.dart';

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child, this.helper});

  final Widget child;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: rumaraBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (helper != null && helper!.isNotEmpty) ...[
              Text(
                helper!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: rumaraMutedText),
              ),
              const SizedBox(height: 8),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
