import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/design/colors.dart';
import '../../core/design/styles.dart';
import 'custom_dropdown.dart';

class SearchableDropdown<T> extends StatefulWidget {
  final String label;
  final String hint;
  final T? value;
  final List<DropdownItem<T>> items;
  final Function(T?)? onChanged;
  final String? errorText;
  final bool isRequired;
  final EdgeInsets margin;
  final bool enabled;

  const SearchableDropdown({
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
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  widget.label,
                  style: TS.labelLarge,
                ),
                if (widget.isRequired)
                  Text(
                    '*',
                    style: TS.bodyLarge.copyWith(color: Colors.red),
                  ),
              ],
            ),
            4.verticalSpace,
          ],
          InkWell(
            onTap: widget.enabled ? () => _showSearchDialog(context) : null,
            child: Container(
              width: double.infinity,
              padding: REdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: widget.errorText != null
                      ? Colors.red
                      : Colors.grey.shade300,
                  width: 1,
                ),
                color: widget.enabled ? inputColor : Colors.grey.shade100,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.value != null
                          ? (widget.items
                                  .where((item) => item.value == widget.value)
                                  .isNotEmpty
                                  ? widget.items
                                      .where((item) => item.value == widget.value)
                                      .first
                                      .text
                                  : widget.hint)
                          : widget.hint,
                      style: TS.bodyLarge.copyWith(
                        color: widget.value != null
                            ? Colors.black87
                            : appHintColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: widget.enabled
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
          if (widget.errorText != null) ...[
            4.verticalSpace,
            Text(
              widget.errorText!,
              style: TS.bodySmall.copyWith(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    final searchController = TextEditingController();
    List<DropdownItem<T>> filteredItems = List.from(widget.items);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            widget.label,
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search field
                TextField(
                  controller: searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Cari ${widget.label.toLowerCase()}...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    contentPadding: REdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (value.isEmpty) {
                        filteredItems = List.from(widget.items);
                      } else {
                        filteredItems = widget.items
                            .where((item) => item.text
                                .toLowerCase()
                                .contains(value.toLowerCase()))
                            .toList();
                      }
                    });
                  },
                ),
                16.verticalSpace,
                // List of items
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: filteredItems.isEmpty
                      ? Center(
                          child: Padding(
                            padding: REdgeInsets.all(16),
                            child: Text(
                              'Tidak ada data',
                              style: TS.bodyMedium.copyWith(
                                color: const Color(0xFF333333),
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final isSelected = item.value == widget.value;
                            return InkWell(
                              onTap: () {
                                widget.onChanged?.call(item.value);
                                Navigator.of(context).pop();
                              },
                              child: Container(
                                padding: REdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? primaryColor.withOpacity(0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.text,
                                        style: TS.bodyLarge.copyWith(
                                          color: isSelected
                                              ? primaryColor
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check,
                                        color: primaryColor,
                                        size: 20.r,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
          ],
        ),
      ),
    );
  }
}
