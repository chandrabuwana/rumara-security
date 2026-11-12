import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection.dart';
import '../bloc/panic_button_bloc.dart';
import '../bloc/panic_button_event.dart';
import '../bloc/panic_button_state.dart';
import '../../domain/entities/panic_button_history_item.dart';
import 'panic_button_detail_page.dart';
import '../../../../shared/widgets/rumara_app_bar.dart';

class PanicButtonHistoryPage extends StatefulWidget {
  const PanicButtonHistoryPage({super.key});

  @override
  State<PanicButtonHistoryPage> createState() => _PanicButtonHistoryPageState();
}

class _PanicButtonHistoryPageState extends State<PanicButtonHistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  static const List<String> _statusOptions = <String>[
    'OPEN',
    'VERIFIED',
    'COMPLETED',
    'DONE',
    'CLOSED',
    'REVISI',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Load initial data after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PanicButtonBloc>().add(
              const LoadPanicButtonHistoryEvent(start: 1, length: 10),
            );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom) {
      context.read<PanicButtonBloc>().add(const LoadMorePanicButtonHistoryEvent());
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }

  void _performSearch(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      context.read<PanicButtonBloc>().add(SearchPanicButtonHistoryEvent(query));
    });
  }

  Future<void> _showFilterBottomSheet(PanicButtonState state) async {
    final parentContext = context;
    final selectedStatuses = <String>[...state.historyFilterStatuses];
    DateTime? selectedCreateDate = state.historyFilterCreateDate;
    String sortField = state.historySortField;
    int sortType = state.historySortType;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedCreateDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setModalState(() {
                  selectedCreateDate = picked;
                });
              }
            }

            final dateText = selectedCreateDate == null
                ? '-'
                : DateFormat('dd/MM/yyyy', 'id_ID').format(selectedCreateDate!);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16.w,
                  right: 16.w,
                  top: 12.h,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16.h,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filter',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context, false),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    8.verticalSpace,

                    Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    8.verticalSpace,
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[200]!),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Column(
                        children: [
                          CheckboxListTile(
                            value: selectedStatuses.isEmpty,
                            onChanged: (v) {
                              if (v == true) {
                                setModalState(() => selectedStatuses.clear());
                              }
                            },
                            title: const Text('Semua'),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          ..._statusOptions.map(
                            (s) {
                              final checked = selectedStatuses.contains(s);
                              return CheckboxListTile(
                                value: checked,
                                onChanged: (v) {
                                  setModalState(() {
                                    if (v == true) {
                                      selectedStatuses.add(s);
                                    } else {
                                      selectedStatuses.remove(s);
                                    }
                                  });
                                },
                                title: Text(s),
                                controlAffinity: ListTileControlAffinity.leading,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    12.verticalSpace,

                    // Text(
                    //   'Tanggal Dibuat',
                    //   style: TextStyle(
                    //     fontSize: 13.sp,
                    //     fontWeight: FontWeight.w700,
                    //     color: Colors.black87,
                    //   ),
                    // ),
                    // 8.verticalSpace,
                    // Row(
                    //   children: [
                    //     Expanded(
                    //       child: Container(
                    //         padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                    //         decoration: BoxDecoration(
                    //           border: Border.all(color: Colors.grey[300]!),
                    //           borderRadius: BorderRadius.circular(12.r),
                    //           color: Colors.white,
                    //         ),
                    //         child: Text(
                    //           dateText,
                    //           style: TextStyle(
                    //             fontSize: 13.sp,
                    //             fontWeight: FontWeight.w600,
                    //             color: Colors.black87,
                    //           ),
                    //         ),
                    //       ),
                    //     ),
                    //     10.horizontalSpace,
                    //     OutlinedButton(
                    //       onPressed: pickDate,
                    //       style: OutlinedButton.styleFrom(
                    //         foregroundColor: const Color(0xFFE5484D),
                    //         side: const BorderSide(color: Color(0xFFE5484D)),
                    //         shape: RoundedRectangleBorder(
                    //           borderRadius: BorderRadius.circular(12.r),
                    //         ),
                    //       ),
                    //       child: const Text('Pilih'),
                    //     ),
                    //     8.horizontalSpace,
                    //     IconButton(
                    //       onPressed: () => setModalState(() => selectedCreateDate = null),
                    //       icon: const Icon(Icons.clear),
                    //       tooltip: 'Hapus tanggal',
                    //     ),
                    //   ],
                    // ),
                    // 12.verticalSpace,

                    Text(
                      'Sort',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    8.verticalSpace,
                    DropdownButtonFormField<String>(
                      value: sortField,
                      items: const [
                        DropdownMenuItem(value: 'status', child: Text('Status')),
                        DropdownMenuItem(value: 'description', child: Text('Description')),
                        DropdownMenuItem(value: 'createDate', child: Text('Create Date')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setModalState(() => sortField = v);
                      },
                      decoration: InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                    8.verticalSpace,
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<int>(
                            value: 0,
                            groupValue: sortType,
                            onChanged: (v) => setModalState(() => sortType = v ?? 0),
                            title: const Text('Ascending'),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<int>(
                            value: 1,
                            groupValue: sortType,
                            onChanged: (v) => setModalState(() => sortType = v ?? 1),
                            title: const Text('Descending'),
                          ),
                        ),
                      ],
                    ),
                    12.verticalSpace,

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                selectedStatuses.clear();
                                selectedCreateDate = null;
                                sortField = 'createDate';
                                sortType = 1;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE5484D),
                              side: const BorderSide(color: Color(0xFFE5484D)),
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: const Text('Clear'),
                          ),
                        ),
                        12.horizontalSpace,
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              parentContext.read<PanicButtonBloc>().add(
                                    ApplyPanicButtonHistoryFilterEvent(
                                      statuses: List<String>.from(selectedStatuses),
                                      createDate: selectedCreateDate,
                                      sortField: sortField,
                                      sortType: sortType,
                                    ),
                                  );
                              Navigator.pop(sheetContext, true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE5484D),
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: const RumaraAppBar(title: 'Riwayat Tombol Darurat'),
      body: SafeArea(
        child: BlocConsumer<PanicButtonBloc, PanicButtonState>(
          listener: (context, state) {
            if (state.historyErrorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.historyErrorMessage!),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          builder: (context, state) {
            return Column(
              children: [
                // Search and Filter Bar
                Container(
                  padding: REdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      // Search Bar 0:ascending 1:descending
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE5484D)),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Cari',
                              hintStyle: TextStyle(
                                color: const Color(0xFFE5484D).withValues(alpha: 0.6),
                                fontSize: 14.sp,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: const Color(0xFFE5484D),
                                size: 20.r,
                              ),
                              border: InputBorder.none,
                              contentPadding: REdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            style: TextStyle(fontSize: 14.sp),
                            onChanged: _performSearch,
                          ),
                        ),
                      ),
                      12.horizontalSpace,
                      // Filter Button
                      Container(
                        width: 48.w,
                        height: 48.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5484D),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.filter_list, color: Colors.white),
                          onPressed: () {
                            _showFilterBottomSheet(state);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // List
                Expanded(
                  child: _buildList(state),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(PanicButtonState state) {
    if (state.isLoadingHistory && state.historyItems.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE5484D)),
      );
    }

    if (state.historyItems.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada riwayat',
          style: TextStyle(
            fontSize: 16.sp,
            color: Colors.grey[600],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<PanicButtonBloc>().add(const RefreshPanicButtonHistoryEvent());
      },
      color: const Color(0xFFE5484D),
      child: ListView.builder(
        controller: _scrollController,
        padding: REdgeInsets.all(16),
        itemCount: state.historyItems.length + (state.isLoadingMoreHistory ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.historyItems.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: Color(0xFFE5484D)),
              ),
            );
          }

          final item = state.historyItems[index];
          return _buildHistoryCard(item);
        },
      ),
    );
  }

  Widget _buildHistoryCard(PanicButtonHistoryItem item) {
    final statusColor = _getStatusColor(item.statusColor);
    final statusTextColor = _getStatusTextColor(item.statusColor);

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BlocProvider(
              create: (context) => getIt<PanicButtonBloc>(),
              child: PanicButtonDetailPage(incidentId: item.id),
            ),
          ),
        );
        // Reload list if result is true (submission successful)
        if (result == true && mounted) {
          context.read<PanicButtonBloc>().add(
                const RefreshPanicButtonHistoryEvent(),
              );
        }
      },
      child: Container(
        margin: REdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border(
            left: BorderSide(
              color: statusColor,
              width: 4.w,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: REdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ID : ${item.formattedId}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Dibuat : ${_formatDate(item.createDate)}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              12.verticalSpace,
              // Jenis Keadaan
              _buildInfoRow('Jenis Keadaan', item.incidentTypeName ?? '-'),
              8.verticalSpace,
              // Lokasi
              _buildInfoRow('Lokasi', item.areaName ?? '-'),
              8.verticalSpace,
              // Kejadian
              _buildInfoRow('Kejadian', item.description),
              8.verticalSpace,
              // Tindakan
              if (item.resolveAction != null && item.resolveAction!.isNotEmpty)
                _buildInfoRow('Tindakan', item.resolveAction!),
              if (item.resolveAction != null && item.resolveAction!.isNotEmpty) 8.verticalSpace,
              Align(
                alignment: Alignment.centerRight,
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    children: [
                      TextSpan(
                        text: 'Status : ',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      TextSpan(
                        text: item.status,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: statusTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100.w,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[600],
            ),
          ),
        ),
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(PanicButtonStatusColor statusColor) {
    switch (statusColor) {
      case PanicButtonStatusColor.red:
        return Colors.red;
      case PanicButtonStatusColor.orange:
        return Colors.orange;
      case PanicButtonStatusColor.blue:
        return Colors.blue[700]!;
      case PanicButtonStatusColor.grey:
        return Colors.grey;
    }
  }

  Color _getStatusTextColor(PanicButtonStatusColor statusColor) {
    switch (statusColor) {
      case PanicButtonStatusColor.red:
        return Colors.red;
      case PanicButtonStatusColor.orange:
        return Colors.orange;
      case PanicButtonStatusColor.blue:
        return Colors.blue[700]!;
      case PanicButtonStatusColor.grey:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final formatter = DateFormat('dd/MM/yyyy', 'id_ID');
    return formatter.format(date);
  }
}

