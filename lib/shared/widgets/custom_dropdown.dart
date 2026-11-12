import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/styles.dart';

class CustomDropdown<T> extends StatelessWidget {
  final String label;
  final String hint;
  final T? value;
  final List<DropdownItem<T>> items;
  final Function(T?)? onChanged;
  final String? errorText;
  final bool isRequired;
  final EdgeInsets margin;
  final bool enabled;

  const CustomDropdown({
    Key? key,
    required this.label,
    required this.hint,
    required this.items,
    this.value,
    this.onChanged,
    this.errorText,
    this.isRequired = false,
    this.margin = EdgeInsets.zero,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  label,
                  style: TS.labelLarge,
                ),
                if (isRequired)
                  Text(
                    '*',
                    style: TS.bodyLarge.copyWith(color: Colors.red),
                  ),
              ],
            ),
            4.verticalSpace,
          ],
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: errorText != null ? Colors.red : rumaraBorder,
                width: 1,
              ),
              color: enabled ? inputColor : rumaraSurfaceMuted,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                hint: Padding(
                  padding: REdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Text(
                    hint,
                    style: TS.bodyLarge.copyWith(
                      color: appHintColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                selectedItemBuilder: (BuildContext context) {
                  return items.map<Widget>((item) {
                    return Padding(
                      padding: REdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Text(
                        item.text,
                        style: TS.bodyLarge,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList();
                },
                items: items.map((item) {
                  return DropdownMenuItem<T>(
                    value: item.value,
                    child: Padding(
                      padding: REdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        item.text,
                        style: TS.bodyLarge,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: enabled ? onChanged : null,
                isExpanded: true,
                icon: Padding(
                  padding: REdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color:
                        enabled ? rumaraMutedText : rumaraHintText,
                  ),
                ),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(8.r),
                elevation: 4,
              ),
            ),
          ),
          if (errorText != null) ...[
            4.verticalSpace,
            Text(
              errorText!,
              style: TS.bodySmall.copyWith(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}

class DropdownItem<T> {
  final T value;
  final String text;

  DropdownItem({
    required this.value,
    required this.text,
  });
}
