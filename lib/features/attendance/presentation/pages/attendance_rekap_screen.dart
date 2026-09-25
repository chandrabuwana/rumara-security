// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:intl/intl.dart';
// import '../../../../core/design/colors.dart';
// import '../../../../core/design/styles.dart';
// import '../../../../core/di/injection.dart';
// import '../../../../core/security/security_manager.dart';
// import '../../../../core/constants/app_constants.dart';
// import '../../../../shared/widgets/app_scaffold.dart';
// import '../../domain/entities/attendance_rekap_entity.dart';
// import '../../domain/entities/attendance_rekap_request_entity.dart';
// import '../bloc/attendance_rekap_bloc.dart';
// import '../bloc/attendance_rekap_event.dart';
// import '../bloc/attendance_rekap_state.dart';
// import 'attendance_rekap_kehadiran_detail_screen.dart';

// class AttendanceRekapScreen extends StatefulWidget {
//   const AttendanceRekapScreen({super.key});

//   @override
//   State<AttendanceRekapScreen> createState() => _AttendanceRekapScreenState();
// }

// class _AttendanceRekapScreenState extends State<AttendanceRekapScreen> {
//   @override
//   Widget build(BuildContext context) {
//     return BlocProvider(
//       create: (context) => getIt<AttendanceRekapBloc>(),
//       child: const _AttendanceRekapScreenContent(),
//     );
//   }
// }

// class _AttendanceRekapScreenContent extends StatefulWidget {
//   const _AttendanceRekapScreenContent();

//   @override
//   State<_AttendanceRekapScreenContent> createState() =>
//       _AttendanceRekapScreenContentState();
// }

// class _AttendanceRekapScreenContentState
//     extends State<_AttendanceRekapScreenContent> {
//   final TextEditingController _searchController = TextEditingController();
//   String? _selectedStatusFilter;

//   @override
//   void initState() {
//     super.initState();
//     // Load data after widget is built and BLoC is available
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _loadAttendanceRekap();
//     });
//   }

//   void _syncSearchController(String? searchQuery) {
//     if (_searchController.text != (searchQuery ?? '')) {
//       _searchController.text = searchQuery ?? '';
//     }
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadAttendanceRekap() async {
//     final userId = await SecurityManager.readSecurely(AppConstants.userIdKey);
//     if (userId != null && mounted) {
//       final request = AttendanceRekapRequestEntity(
//         idUser: userId,
//         withSubordinate: false,
//         status: '',
//         search: '',
//         start: 0,
//         length: 0,
//       );
//       context.read<AttendanceRekapBloc>().add(LoadAttendanceRekapEvent(request));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AppScaffold(
//         backgroundColor: const Color(0xFFF8F9FA),
//         enableScrolling: false,
//         appBar: AppBar(
//           backgroundColor: primaryColor,
//           foregroundColor: Colors.white,
//           elevation: 0,
//           leading: IconButton(
//             icon: const Icon(Icons.arrow_back),
//             onPressed: () => Navigator.of(context).pop(),
//           ),
//           title: Text(
//             'Rekapitulasi Kehadiran',
//             style: TS.titleLarge.copyWith(color: Colors.white),
//           ),
//           centerTitle: true,
//         ),
//         child: Column(
//           children: [
//             // Search and Filter Bar
//             Container(
//               padding: REdgeInsets.all(16),
//               color: Colors.white,
//               child: Row(
//                 children: [
//                   // Search Bar
//                   Expanded(
//                     child: Container(
//                       decoration: BoxDecoration(
//                         border: Border.all(color: primaryColor, width: 1),
//                         borderRadius: BorderRadius.circular(8.r),
//                       ),
//                       child: TextField(
//                         controller: _searchController,
//                         decoration: InputDecoration(
//                           hintText: 'Cari',
//                           hintStyle: TextStyle(
//                             color: neutral50,
//                             fontSize: 14.sp,
//                           ),
//                           prefixIcon: Icon(
//                             Icons.search,
//                             color: primaryColor,
//                             size: 20.sp,
//                           ),
//                           border: InputBorder.none,
//                           contentPadding: EdgeInsets.symmetric(
//                             horizontal: 16.w,
//                             vertical: 12.h,
//                           ),
//                         ),
//                         onChanged: (value) {
//                           context.read<AttendanceRekapBloc>().add(
//                                 SearchAttendanceRekapEvent(value),
//                               );
//                         },
//                       ),
//                     ),
//                   ),

//                   12.horizontalSpace,

//                   // Filter Button
//                   Container(
//                     width: 48.w,
//                     height: 48.h,
//                     decoration: BoxDecoration(
//                       color: primaryColor,
//                       borderRadius: BorderRadius.circular(8.r),
//                     ),
//                     child: IconButton(
//                       icon: Icon(
//                         Icons.filter_list,
//                         color: Colors.white,
//                         size: 20.sp,
//                       ),
//                       onPressed: () {
//                         _showFilterDialog();
//                       },
//                     ),
//                   ),
//                 ],
//               ),
//             ),

//             // Attendance List
//             Expanded(
//               child: BlocConsumer<AttendanceRekapBloc, AttendanceRekapState>(
//                 listener: (context, state) {
//                   if (state is AttendanceRekapFailure) {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(
//                         content: Text(state.message),
//                         backgroundColor: Colors.red,
//                       ),
//                     );
//                   }
//                   if (state is AttendanceRekapLoaded) {
//                     _syncSearchController(state.searchQuery);
//                   }
//                 },
//                 builder: (context, state) {
//                   if (state is AttendanceRekapLoading) {
//                     return const Center(
//                       child: CircularProgressIndicator(color: primaryColor),
//                     );
//                   }

//                   if (state is AttendanceRekapLoaded) {
//                     if (state.filteredItems.isEmpty) {
//                       return _buildEmptyState();
//                     }

//                     return RefreshIndicator(
//                       onRefresh: () async {
//                         await _loadAttendanceRekap();
//                       },
//                       color: primaryColor,
//                       child: ListView.builder(
//                         padding: REdgeInsets.all(16),
//                         itemCount: state.filteredItems.length,
//                         itemBuilder: (context, index) {
//                           final item = state.filteredItems[index];
//                           return _buildAttendanceCard(item);
//                         },
//                       ),
//                     );
//                   }

//                   if (state is AttendanceRekapFailure) {
//                     return _buildErrorState(state.message);
//                   }

//                   return const SizedBox.shrink();
//                 },
//               ),
//             ),
//           ],
//         ),
//     );
//   }

//   Widget _buildAttendanceCard(AttendanceRekapEntity item) {
//     final borderColor = _getBorderColor(item.borderColor);
//     final statusColor = _getStatusColor(item.statusBadgeColor);
//     final attendanceColor = _getAttendanceColor(item.statusAttendance);
//     final hasCheckInOrCheckOut = item.checkIn != null || item.checkOut != null;
//     final canOpenDetail = item.idAttendance != null;

//     return GestureDetector(
//       onTap: canOpenDetail
//           ? () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) => AttendanceRekapDetailScreen(
//                     idAttendance: item.idAttendance!,
//                     isAttendanceDetail: true,
//                   ),
//                 ),
//               );
//             }
//           : null,
//       child: Opacity(
//         opacity: hasCheckInOrCheckOut ? 1.0 : 0.6,
//         child: Container(
//           margin: EdgeInsets.only(bottom: 12.h),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(8.r),
//             border: Border.all(
//               color: Colors.grey.shade200,
//               width: 1,
//             ),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.grey.withOpacity(0.1),
//                 spreadRadius: 1,
//                 blurRadius: 4,
//                 offset: const Offset(0, 2),
//               ),
//             ],
//           ),
//           child: Stack(
//             children: [
//               // Left border dengan warna khusus
//               Positioned(
//                 left: 0,
//                 top: 0,
//                 bottom: 0,
//                 child: Container(
//                   width: 4.w,
//                   decoration: BoxDecoration(
//                     color: borderColor,
//                     borderRadius: BorderRadius.only(
//                       topLeft: Radius.circular(8.r),
//                       bottomLeft: Radius.circular(8.r),
//                     ),
//                   ),
//                 ),
//               ),
//               // Content
//               Padding(
//                 padding: EdgeInsets.only(left: 4.w),
//                 child: Container(
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.only(
//                       topRight: Radius.circular(8.r),
//                       bottomRight: Radius.circular(8.r),
//                     ),
//                   ),
//                   child: Padding(
//                     padding: REdgeInsets.all(16),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         // Header: Date, Shift, and Status
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     '${_formatDate(item.shiftDate)} - ${item.shiftName}',
//                                     style: TS.bodyLarge.copyWith(
//                                       fontWeight: FontWeight.w600,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             Container(
//                               padding: EdgeInsets.symmetric(
//                                 horizontal: 8.w,
//                                 vertical: 4.h,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: statusColor.withOpacity(0.1),
//                                 borderRadius: BorderRadius.circular(4.r),
//                               ),
//                               child: Text(
//                                 item.statusBadgeText,
//                                 style: TS.bodySmall.copyWith(
//                                   color: statusColor,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),

//                         16.verticalSpace,

//                         // Details
//                         _buildDetailRow('Jam Kerja', item.workHours),
//                         8.verticalSpace,
//                         _buildDetailRow('Tugas Tertunda', item.pendingTasksStatus),
//                         8.verticalSpace,
//                         _buildDetailRow('Patroli', item.patrolStatus),
//                         8.verticalSpace,
//                         _buildDetailRow('Lembur', item.overtimeStatus),

//                         16.verticalSpace,

//                         // Attendance Status
//                         Align(
//                           alignment: Alignment.centerRight,
//                           child: Text(
//                             'Kehadiran : ${item.statusAttendance}',
//                             style: TS.bodyMedium.copyWith(
//                               color: attendanceColor,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildDetailRow(String label, String value) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(
//           width: 120.w,
//           child: Text(
//             label,
//             style: TS.bodyMedium.copyWith(
//               color: Colors.grey.shade600,
//             ),
//           ),
//         ),
//         Expanded(
//           child: Text(
//             value,
//             style: TS.bodyMedium.copyWith(
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             Icons.calendar_today_outlined,
//             size: 64.sp,
//             color: neutral50,
//           ),
//           16.verticalSpace,
//           Text(
//             'Tidak ada data kehadiran',
//             style: TS.titleMedium.copyWith(
//               color: neutral50,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildErrorState(String message) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             Icons.error_outline,
//             size: 64.sp,
//             color: Colors.red,
//           ),
//           16.verticalSpace,
//           Text(
//             'Terjadi Kesalahan',
//             style: TS.titleMedium.copyWith(
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           8.verticalSpace,
//           Text(
//             message,
//             style: TS.bodyMedium.copyWith(
//               color: Colors.grey.shade600,
//             ),
//             textAlign: TextAlign.center,
//           ),
//           24.verticalSpace,
//           ElevatedButton(
//             onPressed: () {
//               _loadAttendanceRekap();
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: primaryColor,
//               foregroundColor: Colors.white,
//             ),
//             child: const Text('Coba Lagi'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showFilterDialog() {
//     final parentContext = context; // Store parent context that has access to BLoC
    
//     showDialog(
//       context: context,
//       builder: (dialogContext) => _FilterDialog(
//         initialValue: _selectedStatusFilter,
//         onApply: (selectedValue) {
//           setState(() {
//             _selectedStatusFilter = selectedValue;
//           });
//           // Apply filter using parent context that has access to BLoC
//           final filterValue = selectedValue ?? '';
//           parentContext.read<AttendanceRekapBloc>().add(
//                 FilterAttendanceRekapEvent(filterValue),
//               );
//         },
//       ),
//     );
//   }

//   Color _getBorderColor(String colorName) {
//     switch (colorName.toLowerCase()) {
//       case 'red':
//         return Colors.red;
//       case 'orange':
//         return Colors.orange;
//       case 'blue':
//         return Colors.blue;
//       case 'gray':
//       case 'grey':
//         return Colors.grey.shade300;
//       default:
//         return Colors.grey.shade300;
//     }
//   }

//   Color _getStatusColor(String colorName) {
//     switch (colorName.toLowerCase()) {
//       case 'waiting':
//         return Colors.blue;
//       case 'revision':
//         return Colors.orange;
//       case 'verified':
//         return Colors.lightBlue;
//       case 'checkin':
//       case 'check_in':
//         return Colors.blue; // Same as waiting
//       default:
//         return Colors.blue;
//     }
//   }

//   Color _getAttendanceColor(String status) {
//     switch (status) {
//       case 'Masuk':
//         return Colors.blue;
//       case 'Terlambat':
//         return Colors.orange;
//       case 'Tidak Masuk':
//         return Colors.red;
//       default:
//         return Colors.grey;
//     }
//   }

//   String _formatDate(DateTime date) {
//     try {
//       final formatter = DateFormat('d MMMM yyyy', 'id_ID');
//       return formatter.format(date);
//     } catch (e) {
//       // Fallback to default locale if id_ID is not available
//       final formatter = DateFormat('d MMMM yyyy');
//       return formatter.format(date);
//     }
//   }
// }

// class _FilterDialog extends StatefulWidget {
//   final String? initialValue;
//   final Function(String?) onApply;

//   const _FilterDialog({
//     required this.initialValue,
//     required this.onApply,
//   });

//   @override
//   State<_FilterDialog> createState() => _FilterDialogState();
// }

// class _FilterDialogState extends State<_FilterDialog> {
//   late String? _selectedFilter;

//   @override
//   void initState() {
//     super.initState();
//     _selectedFilter = widget.initialValue;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: Text(
//         'Filter Status Kehadiran',
//         style: TS.titleMedium,
//       ),
//       content: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           RadioListTile<String>(
//             title: const Text('Semua'),
//             value: '',
//             groupValue: _selectedFilter ?? '',
//             onChanged: (value) {
//               setState(() {
//                 _selectedFilter = value;
//               });
//             },
//           ),
//           RadioListTile<String>(
//             title: const Text('Masuk'),
//             value: 'Masuk',
//             groupValue: _selectedFilter ?? '',
//             onChanged: (value) {
//               setState(() {
//                 _selectedFilter = value;
//               });
//             },
//           ),
//           RadioListTile<String>(
//             title: const Text('Terlambat'),
//             value: 'Terlambat',
//             groupValue: _selectedFilter ?? '',
//             onChanged: (value) {
//               setState(() {
//                 _selectedFilter = value;
//               });
//             },
//           ),
//           RadioListTile<String>(
//             title: const Text('Tidak Masuk'),
//             value: 'Tidak Masuk',
//             groupValue: _selectedFilter ?? '',
//             onChanged: (value) {
//               setState(() {
//                 _selectedFilter = value;
//               });
//             },
//           ),
//         ],
//       ),
//       actions: [
//         TextButton(
//           onPressed: () {
//             Navigator.pop(context);
//           },
//           child: const Text('Batal'),
//         ),
//         ElevatedButton(
//           onPressed: () {
//             Navigator.pop(context);
//             widget.onApply(_selectedFilter);
//           },
//           style: ElevatedButton.styleFrom(
//             backgroundColor: primaryColor,
//             foregroundColor: Colors.white,
//           ),
//           child: const Text('Terapkan'),
//         ),
//       ],
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/security/security_manager.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/utils/user_role_helper.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../domain/entities/attendance_rekap_entity.dart';
import '../../domain/entities/attendance_rekap_request_entity.dart';
import '../bloc/attendance_rekap_bloc.dart';
import '../bloc/attendance_rekap_event.dart';
import '../bloc/attendance_rekap_state.dart';
import 'attendance_rekap_kehadiran_detail_screen.dart';

class AttendanceRekapScreen extends StatefulWidget {
  const AttendanceRekapScreen({super.key});

  @override
  State<AttendanceRekapScreen> createState() => _AttendanceRekapScreenState();
}

class _AttendanceRekapScreenState extends State<AttendanceRekapScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<AttendanceRekapBloc>(),
      child: const _AttendanceRekapScreenContent(),
    );
  }
}

class _AttendanceRekapScreenContent extends StatefulWidget {
  const _AttendanceRekapScreenContent();

  @override
  State<_AttendanceRekapScreenContent> createState() =>
      _AttendanceRekapScreenContentState();
}

class _AttendanceRekapScreenContentState
    extends State<_AttendanceRekapScreenContent> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _selectedStatusFilter;

  @override
  void initState() {
    super.initState();
    // Load data after widget is built and BLoC is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAttendanceRekap();
    });
    _scrollController.addListener(_onScroll);
  }

  void _syncSearchController(String? searchQuery) {
    if (_searchController.text != (searchQuery ?? '')) {
      _searchController.text = searchQuery ?? '';
    }
  }

  void _onScroll() {
    if (_isNearBottom) {
      _loadMoreData();
    }
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }

  Future<void> _loadMoreData() async {
    final state = context.read<AttendanceRekapBloc>().state;
    if (state is! AttendanceRekapLoaded) return;
    if (state.isLoadingMore || !state.hasMoreData) return;

    final userId = await SecurityManager.readSecurely(AppConstants.userIdKey);
    if (userId != null && mounted) {
      final userRole = await UserRoleHelper.getUserRole();
      final isPengawas = userRole == UserRole.pengawas;

      final nextStart = state.currentStart + 1;

      final request = AttendanceRekapRequestEntity(
        idUser: userId,
        withSubordinate: isPengawas,
        isAdmin: false,
        status: state.statusFilter ?? '',
        search: state.searchQuery ?? '',
        startDate: null,
        endDate: null,
        start: nextStart,
        length: 10,
        shiftName: '',
        jabatan: '',
        isOvertime: false,
      );
      context.read<AttendanceRekapBloc>().add(LoadMoreAttendanceRekapEvent(request));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAttendanceRekap({String? status}) async {
    final userId = await SecurityManager.readSecurely(AppConstants.userIdKey);
    if (userId != null && mounted) {
      final userRole = await UserRoleHelper.getUserRole();
      final isPengawas = userRole == UserRole.pengawas;

      final searchQuery = _searchController.text.trim();
      final statusValue = (status ?? '').trim();

      final request = AttendanceRekapRequestEntity(
        idUser: userId,
        withSubordinate: isPengawas,
        isAdmin: false,
        status: statusValue,
        search: searchQuery,
        startDate: null,
        endDate: null,
        start: 1,
        length: 10,
        shiftName: '',
        jabatan: '',
        isOvertime: false,
      );
      context.read<AttendanceRekapBloc>().add(LoadAttendanceRekapEvent(request));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        enableScrolling: false,
        appBar: AppBar(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Rekapitulasi Kehadiran',
            style: TS.titleLarge.copyWith(color: Colors.white),
          ),
          centerTitle: true,
        ),
        child: Column(
          children: [
            // Search and Filter Bar
            Container(
              padding: REdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  // Search Bar
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: primaryColor, width: 1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Cari',
                          hintStyle: TextStyle(
                            color: neutral50,
                            fontSize: 14.sp,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: primaryColor,
                            size: 20.sp,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                        ),
                        onChanged: (value) {
                          // Debounce search to avoid too many API calls
                          Future.delayed(const Duration(milliseconds: 500), () {
                            if (mounted && _searchController.text == value) {
                              _loadAttendanceRekap();
                            }
                          });
                        },
                      ),
                    ),
                  ),

                  12.horizontalSpace,

                  // Filter Button
                  Container(
                    width: 48.w,
                    height: 48.h,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.filter_list,
                        color: Colors.white,
                        size: 20.sp,
                      ),
                      onPressed: () {
                        _showFilterDialog();
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Attendance List
            Expanded(
              child: BlocConsumer<AttendanceRekapBloc, AttendanceRekapState>(
                listener: (context, state) {
                  if (state is AttendanceRekapFailure) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  if (state is AttendanceRekapLoaded) {
                    _syncSearchController(state.searchQuery);
                  }
                },
                builder: (context, state) {
                  if (state is AttendanceRekapLoading) {
                    return Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    );
                  }

                  if (state is AttendanceRekapLoaded) {
                    if (state.filteredItems.isEmpty && !state.isLoadingMore) {
                      return _buildEmptyState(
                        showTryAnotherFilterHint:
                            _selectedStatusFilter?.trim().isNotEmpty == true,
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        await _loadAttendanceRekap();
                      },
                      color: primaryColor,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: REdgeInsets.all(16),
                        itemCount: state.filteredItems.length + (state.isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == state.filteredItems.length) {
                            // Loading indicator at bottom
                            return Container(
                              padding: REdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: CircularProgressIndicator(color: primaryColor),
                              ),
                            );
                          }
                          final item = state.filteredItems[index];
                          return _buildAttendanceCard(item);
                        },
                      ),
                    );
                  }

                  if (state is AttendanceRekapFailure) {
                    return _buildErrorState(state.message);
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildAttendanceCard(AttendanceRekapEntity item) {
    final borderColor = _getBorderColor(item.borderColor);
    final statusColor = _getStatusColor(item.statusBadgeColor);
    final attendanceColor = _getAttendanceColor(item.statusAttendance);
    final hasCheckInOrCheckOut = item.checkIn != null || item.checkOut != null;
    final canOpenDetail = item.idAttendance != null;

    return GestureDetector(
      onTap: canOpenDetail
          ? () {
              () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AttendanceRekapKehadiranDetailScreen(
                      idAttendance: item.idAttendance!,
                    ),
                  ),
                );

                if (result == true && mounted) {
                  await _loadAttendanceRekap();
                }
              }();
            }
          : null,
      child: Opacity(
        opacity: hasCheckInOrCheckOut ? 1.0 : 0.6,
        child: Container(
          margin: EdgeInsets.only(bottom: 12.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Left border dengan warna khusus
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4.w,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8.r),
                      bottomLeft: Radius.circular(8.r),
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: EdgeInsets.only(left: 4.w),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(8.r),
                      bottomRight: Radius.circular(8.r),
                    ),
                  ),
                  child: Padding(
                    padding: REdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Date, Shift, and Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_formatDate(item.shiftDate)} - ${item.shiftName}',
                                    style: TS.bodyLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                item.statusBadgeText,
                                style: TS.bodySmall.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        16.verticalSpace,

                        // Details
                        _buildDetailRow('Jam Kerja', item.workHours),
                        8.verticalSpace,
                        _buildDetailRow('Tugas Tertunda', item.pendingTasksStatus),
                        8.verticalSpace,
                        _buildDetailRow('Patroli', item.patrolStatus),
                        8.verticalSpace,
                        _buildDetailRow('Lembur', item.overtimeStatus),

                        16.verticalSpace,

                        // Attendance Status
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Kehadiran : ${item.formattedStatusAttendance}',
                            style: TS.bodyMedium.copyWith(
                              color: attendanceColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120.w,
          child: Text(
            label,
            style: TS.bodyMedium.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TS.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({required bool showTryAnotherFilterHint}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 64.sp,
            color: neutral50,
          ),
          16.verticalSpace,
          Text(
            'Tidak ada data kehadiran',
            style: TS.titleMedium.copyWith(
              color: neutral50,
            ),
          ),
          if (showTryAnotherFilterHint) ...[
            8.verticalSpace,
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Text(
                'Silakan coba gunakan filter lain',
                style: TS.bodyMedium.copyWith(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64.sp,
            color: Colors.red,
          ),
          16.verticalSpace,
          Text(
            'Terjadi Kesalahan',
            style: TS.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          8.verticalSpace,
          Text(
            message,
            style: TS.bodyMedium.copyWith(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          24.verticalSpace,
          ElevatedButton(
            onPressed: () {
              _loadAttendanceRekap();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    final parentContext = context; // Store parent context that has access to BLoC
    
    showDialog(
      context: context,
      builder: (dialogContext) => _FilterDialog(
        initialValue: _selectedStatusFilter,
        onApply: (selectedValue) {
          setState(() {
            _selectedStatusFilter = selectedValue;
          });
          final filterValue = (selectedValue ?? '').trim();

          const serverStatuses = {
            'CHECKIN',
            'CHECKOUT',
            'WAITING',
            'REVISI',
            'VERIFIKASI',
          };

          if (filterValue.isEmpty) {
            parentContext.read<AttendanceRekapBloc>().add(
                  FilterAttendanceRekapEvent(''),
                );
            _loadAttendanceRekap(status: '');
            return;
          }

          if (serverStatuses.contains(filterValue)) {
            // Clear local filter to avoid double-filtering UI
            parentContext.read<AttendanceRekapBloc>().add(
                  FilterAttendanceRekapEvent(''),
                );
            _loadAttendanceRekap(status: filterValue);
            return;
          }

          // Client-side filtering (Masuk/Terlambat/Tidak Masuk)
          parentContext.read<AttendanceRekapBloc>().add(
                FilterAttendanceRekapEvent(filterValue),
              );
        },
      ),
    );
  }

  Color _getBorderColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'orange':
        return Colors.orange;
      case 'blue':
        return Colors.blue;
      case 'gray':
      case 'grey':
        return Colors.grey.shade300;
      default:
        return Colors.grey.shade300;
    }
  }

  Color _getStatusColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'waiting':
        return Colors.blue;
      case 'revision':
        return Colors.orange;
      case 'verified':
        return Colors.lightBlue;
      case 'checkin':
      case 'check_in':
        return Colors.blue; // Same as waiting
      default:
        return Colors.blue;
    }
  }

  Color _getAttendanceColor(String status) {
    // Handle both Indonesian and English status
    final normalizedStatus = status.toLowerCase();
    if (normalizedStatus == 'masuk' || normalizedStatus == 'present') {
      return Colors.blue;
    }
    if (normalizedStatus == 'terlambat' || normalizedStatus == 'late') {
      return Colors.orange;
    }
    if (normalizedStatus == 'tidak masuk' || normalizedStatus == 'absent') {
      return Colors.red;
    }
    if (normalizedStatus == 'izin' || normalizedStatus == 'leave') {
      return Colors.purple;
    }
    if (normalizedStatus == 'sakit' || normalizedStatus == 'sick') {
      return Colors.orange.shade700;
    }
    return Colors.grey;
  }

  String _formatDate(DateTime date) {
    try {
      final formatter = DateFormat('d MMMM yyyy', 'id_ID');
      return formatter.format(date);
    } catch (e) {
      // Fallback to default locale if id_ID is not available
      final formatter = DateFormat('d MMMM yyyy');
      return formatter.format(date);
    }
  }
}

class _FilterDialog extends StatefulWidget {
  final String? initialValue;
  final Function(String?) onApply;

  const _FilterDialog({
    required this.initialValue,
    required this.onApply,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late String? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Filter Status Kehadiran',
        style: TS.titleMedium,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<String>(
            title: const Text('Semua'),
            value: '',
            groupValue: _selectedFilter ?? '',
            onChanged: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
          ),          
          RadioListTile<String>(
            title: const Text('Check In'),
            value: 'CHECKIN',
            groupValue: _selectedFilter ?? '',
            onChanged: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
          ),
          RadioListTile<String>(
            title: const Text('Waiting'),
            value: 'WAITING',
            groupValue: _selectedFilter ?? '',
            onChanged: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
          ),
          RadioListTile<String>(
            title: const Text('Revisi'),
            value: 'REVISI',
            groupValue: _selectedFilter ?? '',
            onChanged: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
          ),
          RadioListTile<String>(
            title: const Text('Verifikasi'),
            value: 'VERIFIKASI',
            groupValue: _selectedFilter ?? '',
            onChanged: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onApply(_selectedFilter);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Terapkan'),
        ),
      ],
    );
  }
}

