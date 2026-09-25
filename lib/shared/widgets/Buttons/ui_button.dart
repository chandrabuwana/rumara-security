// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/styles.dart';

/// Button type enumeration untuk menentukan style button
enum UIButtonType {
  /// Button dengan background solid color
  filled,

  /// Button dengan outline/border tanpa background
  outline,

  /// Button dengan style text minimal
  text,

  /// Button dengan style elevated material design
  elevated,
}

/// Button size enumeration untuk menentukan ukuran button
enum UIButtonSize {
  /// Small button - tinggi 32.h
  small,

  /// Medium button - tinggi 48.h (default)
  medium,

  /// Large button - tinggi 56.h
  large,

  /// Extra large button - tinggi 64.h
  extraLarge,
}

/// Button variant enumeration untuk color scheme
enum UIButtonVariant {
  /// Primary color scheme (default)
  primary,

  /// Secondary color scheme
  secondary,

  /// Success color scheme (green)
  success,

  /// Error/danger color scheme (red)
  error,

  /// Warning color scheme (orange)
  warning,

  /// Info color scheme (blue)
  info,

  /// Neutral color scheme (gray)
  neutral,
}

/// Base button widget yang dapat digunakan untuk semua jenis button dalam aplikasi.
///
/// Widget ini menyediakan konsistensi design dan behavior untuk semua button,
/// dengan dukungan untuk loading state, outline style, icon, dan berbagai customization.
///
/// ## Button Types:
/// - **Filled Button**: Default style dengan background color
/// - **Outline Button**: Button dengan border tanpa background
/// - **Text Button**: Button dengan minimal styling
/// - **Icon Button**: Button dengan icon support
///
/// ## Features:
/// - ✅ Loading state dengan loading indicator
/// - ✅ Enable/disable state
/// - ✅ Outline dan filled variants
/// - ✅ Icon support (prefix dan suffix)
/// - ✅ Responsive design dengan ScreenUtil
/// - ✅ Customizable styling
/// - ✅ Consistent animations
///
/// ## Usage Examples:
/// ```dart
/// // Basic filled button
/// UIButton(
///   text: 'Save',
///   onPressed: () => print('Saved'),
/// )
///
/// // Outline button
/// UIButton(
///   text: 'Cancel',
///   buttonType: UIButtonType.outline,
///   onPressed: () => Navigator.pop(context),
/// )
///
/// // Loading button
/// UIButton(
///   text: 'Submit',
///   isLoading: true,
///   onPressed: null,
/// )
///
/// // Icon button
/// UIButton(
///   text: 'Share',
///   icon: Icon(Icons.share),
///   onPressed: () => share(),
/// )
/// ```
class UIButton extends StatelessWidget {
  const UIButton({
    Key? key,
    required this.onPressed,
    this.child,
    this.loadingColor = Colors.white,
    this.margin = EdgeInsets.zero,
    this.padding = EdgeInsets.zero,
    this.fullWidth = false,
    this.elevation = 0,
    this.isLoading = false,
    this.loadingWidget,
    this.color,
    this.textColor,
    this.icon,
    this.suffixIcon,
    this.onLongPressed,
    this.alignment,
    this.borderSide,
    this.text = 'Button',
    this.enable = true,
    this.borderRadius = 10,
    this.isOutline = false,
    this.outlineColor,
    this.textStyle,
    this.buttonType = UIButtonType.filled,
    this.size = UIButtonSize.medium,
    this.variant = UIButtonVariant.primary,
    this.loadingSize,
    this.animationDuration = const Duration(milliseconds: 200),
    this.splashColor,
    this.highlightColor,
    this.focusColor,
    this.hoverColor,
  }) : super(key: key);

  ///receive a ValueNotifier to indicate a loading widget
  final bool isLoading;
  final bool enable;

  ///
  final Widget? child;
  final String text;
  final TextStyle? textStyle;

  ///An icon to show at before [child]
  final Widget? icon;
  final Widget? suffixIcon;

  ///
  final VoidCallback? onPressed;

  ///
  final Function? onLongPressed;

  //
  final double? elevation;

  ///Button's background Color
  final Color? color;

  ///Text's color for a child that usually a Text
  final Color? textColor;

  ///Loading indicator's color, default is white
  final Color loadingColor;

  ///A widget to show when loading, if the value is null,
  ///it will use a loading widget from SuraProvider or CircularProgressIndicator
  final Widget? loadingWidget;

  ///Button's margin
  final EdgeInsets margin;

  ///Button's padding
  final EdgeInsets padding;

  ///child's alignment
  final MainAxisAlignment? alignment;

  ///if [fullWidth] is `true`, Button will take all remaining horizontal space
  final bool fullWidth;

  ///
  final BorderSide? borderSide;
  final double borderRadius;
  final bool isOutline;
  final Color? outlineColor;

  /// Button type for different styling
  final UIButtonType buttonType;

  /// Button size for different dimensions
  final UIButtonSize size;

  /// Button color variant
  final UIButtonVariant variant;

  /// Loading indicator size
  final double? loadingSize;

  /// Animation duration for state changes
  final Duration animationDuration;

  /// Splash color for tap feedback
  final Color? splashColor;

  /// Highlight color for pressed state
  final Color? highlightColor;

  /// Focus color for focus state
  final Color? focusColor;

  /// Hover color for hover state
  final Color? hoverColor;

  /// Get button height based on size
  double get _buttonHeight {
    switch (size) {
      case UIButtonSize.small:
        return 32.h;
      case UIButtonSize.medium:
        return 48.h;
      case UIButtonSize.large:
        return 56.h;
      case UIButtonSize.extraLarge:
        return 64.h;
    }
  }

  /// Get button colors based on variant
  Color get _primaryColor {
    switch (variant) {
      case UIButtonVariant.primary:
        return color ?? primaryColor;
      case UIButtonVariant.secondary:
        return primaryDark;
      case UIButtonVariant.success:
        return successColor;
      case UIButtonVariant.error:
        return errorColor;
      case UIButtonVariant.warning:
        return const Color(0xFFFF9800);
      case UIButtonVariant.info:
        return const Color(0xFF2196F3);
      case UIButtonVariant.neutral:
        return Colors.grey;
    }
  }

  /// Get loading indicator size based on button size
  double get _loadingIndicatorSize {
    if (loadingSize != null) return loadingSize!;

    switch (size) {
      case UIButtonSize.small:
        return 16.w;
      case UIButtonSize.medium:
        return 20.w;
      case UIButtonSize.large:
        return 24.w;
      case UIButtonSize.extraLarge:
        return 28.w;
    }
  }

  /// Build loading widget
  Widget get _loadingIndicator {
    return loadingWidget ??
        SizedBox(
          width: _loadingIndicatorSize,
          height: _loadingIndicatorSize,
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            valueColor: AlwaysStoppedAnimation<Color>(loadingColor),
          ),
        );
  }

  /// Get text style based on size
  TextStyle get _defaultTextStyle {
    final baseStyle = textStyle ?? TS.titleSmall;

    switch (size) {
      case UIButtonSize.small:
        return baseStyle.copyWith(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
        );
      case UIButtonSize.medium:
        return baseStyle.copyWith(
          fontSize: 14.sp,
          fontWeight: FontWeight.w700,
        );
      case UIButtonSize.large:
        return baseStyle.copyWith(
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
        );
      case UIButtonSize.extraLarge:
        return baseStyle.copyWith(
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
        );
    }
  }

  /// Get button padding based on size
  EdgeInsets get _buttonPadding {
    if (padding != EdgeInsets.zero) return padding;

    switch (size) {
      case UIButtonSize.small:
        return REdgeInsets.symmetric(horizontal: 12, vertical: 6);
      case UIButtonSize.medium:
        return REdgeInsets.symmetric(horizontal: 16, vertical: 12);
      case UIButtonSize.large:
        return REdgeInsets.symmetric(horizontal: 20, vertical: 16);
      case UIButtonSize.extraLarge:
        return REdgeInsets.symmetric(horizontal: 24, vertical: 20);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine the actual button type to use
    final actualButtonType = isOutline ? UIButtonType.outline : buttonType;
    final actualColor = _primaryColor;

    return AnimatedContainer(
      duration: animationDuration,
      width: fullWidth ? double.infinity : null,
      height: _buttonHeight,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
      ),
      margin: margin,
      child: _buildButton(context, actualButtonType, actualColor),
    );
  }

  /// Build the appropriate button based on type
  Widget _buildButton(BuildContext context, UIButtonType type, Color color) {
    switch (type) {
      case UIButtonType.filled:
      case UIButtonType.elevated:
        return _buildElevatedButton(color);
      case UIButtonType.outline:
        return _buildOutlineButton(color);
      case UIButtonType.text:
        return _buildTextButton(color);
    }
  }

  /// Build elevated/filled button
  Widget _buildElevatedButton(Color color) {
    return ElevatedButton(
      onPressed: _getButtonCallback(),
      onLongPress: onLongPressed as VoidCallback?,
      style: ElevatedButton.styleFrom(
        foregroundColor: textColor ?? Colors.white,
        backgroundColor: isLoading
            ? color.withOpacity(0.4)
            : (enable ? color : Colors.grey.shade300),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        ),
        padding: _buttonPadding,
        elevation: isLoading ? 0 : elevation,
        side: borderSide,
        splashFactory: InkRipple.splashFactory,
      ),
      child: _buildButtonContent(),
    );
  }

  /// Build outline button
  Widget _buildOutlineButton(Color color) {
    return OutlinedButton(
      onPressed: _getButtonCallback(),
      onLongPress: onLongPressed as VoidCallback?,
      style: OutlinedButton.styleFrom(
        foregroundColor: textColor ?? color,
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        ),
        padding: _buttonPadding,
        side: BorderSide(
          color: outlineColor ?? color,
          width: 1.5,
        ),
        splashFactory: InkRipple.splashFactory,
      ),
      child: _buildButtonContent(),
    );
  }

  /// Build text button
  Widget _buildTextButton(Color color) {
    return TextButton(
      onPressed: _getButtonCallback(),
      onLongPress: onLongPressed as VoidCallback?,
      style: TextButton.styleFrom(
        foregroundColor: textColor ?? color,
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        ),
        padding: _buttonPadding,
        splashFactory: InkRipple.splashFactory,
      ),
      child: _buildButtonContent(),
    );
  }

  /// Get button callback
  VoidCallback? _getButtonCallback() {
    if (isLoading) return () {};
    if (!enable) return null;
    return onPressed;
  }

  /// Build button content (text, icons, loading)
  Widget _buildButtonContent() {
    if (isLoading) {
      return Padding(
        padding: REdgeInsets.all(4),
        child: _loadingIndicator,
      );
    }

    return Row(
      mainAxisAlignment: alignment ?? MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (icon != null) ...[
          icon!,
          8.horizontalSpace,
        ],
        Flexible(
          child: child ??
              Text(
                text,
                style: _defaultTextStyle.copyWith(
                  color: textColor ??
                      (buttonType == UIButtonType.outline ||
                              buttonType == UIButtonType.text
                          ? _primaryColor
                          : Colors.white),
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
        ),
        if (suffixIcon != null) ...[
          8.horizontalSpace,
          suffixIcon!,
        ],
      ],
    );
  }
}
