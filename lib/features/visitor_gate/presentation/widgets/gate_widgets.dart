import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/theme_controller.dart';

class GateFormat {
  const GateFormat._();

  static String time(DateTime? value) =>
      value == null ? '-' : DateFormat('HH:mm').format(value);

  static String dateTime(DateTime? value) => value == null
      ? '-'
      : DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(value);

  static String duration(int? minutes) {
    if (minutes == null) return '-';
    if (minutes < 60) return '$minutes menit';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours jam' : '$hours jam $rest menit';
  }
}

LinearGradient gateHeaderGradient() {
  final palette = ThemeController.instance.currentPalette;
  return LinearGradient(
    begin: const Alignment(-0.34, -0.94),
    end: const Alignment(0.34, 0.94),
    colors: [palette.primaryDark, palette.primary, palette.seed],
  );
}

Color get gateWarningColor => ThemeController.instance.currentPalette.warning;

class GateHeader extends StatelessWidget {
  const GateHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.child,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: gateHeaderGradient()),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              if (child != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 0, 0),
                  child: child,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum GateButtonTone { primary, success, danger }

class GateButton extends StatelessWidget {
  const GateButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = GateButtonTone.primary,
    this.outlined = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final GateButtonTone tone;
  final bool outlined;
  final bool loading;

  Color get _color {
    switch (tone) {
      case GateButtonTone.success:
        return successColor;
      case GateButtonTone.danger:
        return errorColor;
      case GateButtonTone.primary:
        return primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final content = loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: outlined ? color : Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    final action = loading ? null : onPressed;
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: outlined
          ? OutlinedButton(
              onPressed: action,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color, width: 1.4),
                shape: shape,
              ),
              child: content,
            )
          : ElevatedButton(
              onPressed: action,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                disabledBackgroundColor: color.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: shape,
              ),
              child: content,
            ),
    );
  }
}

class GateCard extends StatelessWidget {
  const GateCard({super.key, required this.child, this.padding, this.color});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class GateInfoRow extends StatelessWidget {
  const GateInfoRow({super.key, required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child:
                Text(label, style: TextStyle(fontSize: 13, color: neutral50)),
          ),
          Expanded(
            child: Text(
              (value == null || value!.trim().isEmpty) ? '-' : value!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: neutral90,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GateBanner extends StatelessWidget {
  const GateBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (message != null)
                  Text(message!,
                      style: TextStyle(color: neutral70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GateStateView extends StatelessWidget {
  const GateStateView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration:
                  BoxDecoration(color: primary10, shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: neutral90,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: neutral50),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 200,
                child: GateButton(label: actionLabel!, onPressed: onAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class GateChip extends StatelessWidget {
  const GateChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class VisitorFlowAction {
  const VisitorFlowAction._();

  static const String scan = 'scan';
  static const String manual = 'manual';
  static const String walkIn = 'walk_in';
}
