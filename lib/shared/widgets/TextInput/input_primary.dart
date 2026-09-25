import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/styles.dart';
import '../../../core/utils/app_utils.dart';

enum TextFieldShape { box, line }

enum TextFieldState { focus, error, disabled, none }

class InputPrimary extends StatefulWidget {
  const InputPrimary({
    Key? key,
    this.label = '',
    this.prefixIcon,
    this.suffixIcon,
    this.color,
    this.textColor,
    this.margin = EdgeInsets.zero,
    this.padding = EdgeInsets.zero,
    this.contentPadding,
    this.enable = true,
    this.controller,
    this.validation,
    this.inputFormatters,
    this.hint = '',
    this.textStyle,
    this.hintStyle,
    this.errorTextStyle,
    this.keyboardType = TextInputType.text,
    this.maxLength = 30,
    this.onChanged,
    this.textCapitalization = TextCapitalization.sentences,
    this.obscureText = false,
    this.inputShape = TextFieldShape.box,
    this.cursorColor,
    this.textAlign = TextAlign.start,
    this.isRequired = false,
    this.requiredText = 'Required',
    this.showRequiredText = false,
    this.requiredTextStyle,
    this.isOptional = false,
    this.optionalText = 'Optional',
    this.optionalTextStyle,
    this.labelTextStyle,
    this.outlineColor,
    this.focusedBorderColor,
    this.errorBorderColor,
    this.disabledBorderColor,
    this.borderRadius = 10,
    this.borderWidth = 1.0,
    this.focusedBorderWidth = 2.0,
    this.hintColor,
    this.maxLines = 1,
    this.minLines,
    this.action = TextInputAction.done,
    this.readOnly = false,
    this.onTap,
    this.onFieldSubmitted,
    this.onEditingComplete,
    this.errorMessage,
    this.autofocus = false,
    this.expands = false,
    this.textInputAction,
    this.focusNode,
    this.scrollController,
    this.enableInteractiveSelection = true,
    this.buildCounter,
    this.autofillHints,
    this.restorationId,
  }) : super(key: key);

  final String label;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Color? color;
  final Color? textColor;
  final EdgeInsets margin;
  final EdgeInsets padding;
  final EdgeInsets? contentPadding;
  final bool enable;
  final TextEditingController? controller;
  final String? Function(String? value)? validation;
  final List<TextInputFormatter>? inputFormatters;
  final String hint;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final TextStyle? errorTextStyle;
  final TextInputType keyboardType;
  final int maxLength;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final TextFieldShape inputShape;
  final Color? cursorColor;
  final TextAlign textAlign;
  final bool isRequired;
  final String requiredText;
  final TextStyle? requiredTextStyle;
  final bool showRequiredText;
  final bool isOptional;
  final String optionalText;
  final TextStyle? optionalTextStyle;
  final TextStyle? labelTextStyle;
  final Color? outlineColor;
  final Color? focusedBorderColor;
  final Color? errorBorderColor;
  final Color? disabledBorderColor;
  final double borderRadius;
  final double borderWidth;
  final double focusedBorderWidth;
  final Color? hintColor;
  final int maxLines;
  final int? minLines;
  final TextInputAction action;
  final bool readOnly;
  final Function()? onTap;
  final Function(String)? onFieldSubmitted;
  final Function()? onEditingComplete;
  final String? errorMessage;
  final bool autofocus;
  final bool expands;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final ScrollController? scrollController;
  final bool enableInteractiveSelection;
  final Widget? Function(BuildContext,
      {required int currentLength,
      required bool isFocused,
      required int? maxLength})? buildCounter;
  final Iterable<String>? autofillHints;
  final String? restorationId;

  @override
  State<InputPrimary> createState() => _InputPrimaryState();
}

class _InputPrimaryState extends State<InputPrimary> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  Color _getBorderColor() {
    if (!widget.enable) {
      return widget.disabledBorderColor ?? Colors.grey.shade300;
    }
    if (widget.errorMessage != null && widget.errorMessage!.isNotEmpty) {
      return widget.errorBorderColor ?? Colors.red;
    }
    if (_isFocused) {
      return widget.focusedBorderColor ?? widget.cursorColor ?? primaryColor;
    }
    return widget.outlineColor ?? Colors.grey.shade300;
  }

  double _getBorderWidth() {
    if (_isFocused) {
      return widget.focusedBorderWidth;
    }
    return widget.borderWidth;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label.isNotEmpty ||
              widget.isRequired ||
              widget.isOptional) ...[
            Row(
              children: [
                if (widget.label.isNotEmpty)
                  Text(
                    widget.label,
                    style: widget.labelTextStyle ?? TS.labelLarge,
                  ),
                if (widget.isRequired)
                  Text(
                    '*',
                    style: TS.bodyLarge.copyWith(color: Colors.red),
                  ),
                const Spacer(),
                if (widget.showRequiredText)
                  Text(
                    widget.requiredText,
                    style: widget.requiredTextStyle,
                  ),
                if (widget.isOptional)
                  Text(
                    widget.optionalText,
                    style: widget.optionalTextStyle,
                  ),
              ],
            ),
            4.verticalSpace,
          ],
          TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enable,
            readOnly: widget.readOnly,
            autofocus: widget.autofocus,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction ?? widget.action,
            textCapitalization: widget.textCapitalization,
            textAlign: widget.textAlign,
            maxLines: widget.expands ? null : widget.maxLines,
            minLines: widget.minLines,
            expands: widget.expands,
            maxLength: widget.maxLength,
            cursorColor: widget.cursorColor ?? primaryColor,
            enableInteractiveSelection: widget.enableInteractiveSelection,
            scrollController: widget.scrollController,
            autofillHints: widget.autofillHints,
            restorationId: widget.restorationId,
            style: widget.textStyle ?? TS.labelLarge,
            scrollPadding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16 * 4,
            ),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              border: widget.inputShape == TextFieldShape.box
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.all(
                          Radius.circular(widget.borderRadius)),
                      borderSide: BorderSide(
                        color: _getBorderColor(),
                        width: _getBorderWidth(),
                      ),
                    )
                  : UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: _getBorderColor(),
                        width: _getBorderWidth(),
                      ),
                    ),
              enabledBorder: widget.inputShape == TextFieldShape.box
                  ? OutlineInputBorder(
                      borderSide: BorderSide(
                        color: _getBorderColor(),
                        width: widget.borderWidth,
                      ),
                      borderRadius: BorderRadius.all(
                          Radius.circular(widget.borderRadius)),
                    )
                  : UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: _getBorderColor(),
                        width: widget.borderWidth,
                      ),
                    ),
              focusedBorder: widget.inputShape == TextFieldShape.box
                  ? OutlineInputBorder(
                      borderSide: BorderSide(
                        color: widget.focusedBorderColor ?? widget.cursorColor ?? primaryColor,
                        width: widget.focusedBorderWidth,
                      ),
                      borderRadius: BorderRadius.all(
                          Radius.circular(widget.borderRadius)),
                    )
                  : UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: widget.focusedBorderColor ?? widget.cursorColor ?? primaryColor,
                        width: widget.focusedBorderWidth,
                      ),
                    ),
              errorBorder: widget.inputShape == TextFieldShape.box
                  ? OutlineInputBorder(
                      borderSide: BorderSide(
                        color: widget.errorBorderColor ?? Colors.red,
                        width: widget.borderWidth,
                      ),
                      borderRadius: BorderRadius.all(
                          Radius.circular(widget.borderRadius)),
                    )
                  : UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: widget.errorBorderColor ?? Colors.red,
                        width: widget.borderWidth,
                      ),
                    ),
              focusedErrorBorder: widget.inputShape == TextFieldShape.box
                  ? OutlineInputBorder(
                      borderSide: BorderSide(
                        color: widget.errorBorderColor ?? Colors.red,
                        width: widget.focusedBorderWidth,
                      ),
                      borderRadius: BorderRadius.all(
                          Radius.circular(widget.borderRadius)),
                    )
                  : UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: widget.errorBorderColor ?? Colors.red,
                        width: widget.focusedBorderWidth,
                      ),
                    ),
              disabledBorder: widget.inputShape == TextFieldShape.box
                  ? OutlineInputBorder(
                      borderSide: BorderSide(
                        color:
                            widget.disabledBorderColor ?? Colors.grey.shade300,
                        width: widget.borderWidth,
                      ),
                      borderRadius: BorderRadius.all(
                          Radius.circular(widget.borderRadius)),
                    )
                  : UnderlineInputBorder(
                      borderSide: BorderSide(
                        color:
                            widget.disabledBorderColor ?? Colors.grey.shade300,
                        width: widget.borderWidth,
                      ),
                    ),
              contentPadding: widget.contentPadding ??
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              fillColor: widget.color ?? inputColor,
              filled: true,
              prefixIcon: widget.prefixIcon,
              suffixIcon: widget.suffixIcon,
              hoverColor: widget.outlineColor,
              hintText: widget.hint,
              hintStyle: widget.hintStyle ??
                  TS.bodyLarge.copyWith(color: widget.hintColor ?? appHintColor),
              errorMaxLines: 2,
              errorStyle: widget.errorTextStyle,
              errorText: widget.errorMessage,
              prefixIconConstraints:
                  const BoxConstraints(maxHeight: 42, maxWidth: 56),
              counterText:
                  widget.maxLength == TextField.noMaxLength ? null : '',
              counterStyle: const TextStyle(fontSize: 0),
            ),
            onChanged: widget.onChanged,
            onTap: widget.onTap,
            onFieldSubmitted: widget.onFieldSubmitted,
            onEditingComplete: widget.onEditingComplete,
            onTapOutside: (event) => AppUtils.dismissKeyboard(),
            validator: widget.validation,
            inputFormatters: [
              if (widget.maxLength != TextField.noMaxLength)
                LengthLimitingTextInputFormatter(widget.maxLength),
              if (widget.inputFormatters != null) ...widget.inputFormatters!,
            ],
            buildCounter: widget.buildCounter,
          ),
        ],
      ),
    );
  }
}
