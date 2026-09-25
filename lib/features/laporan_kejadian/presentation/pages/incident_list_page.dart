import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/utils/user_role_helper.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/di/injection.dart';
import '../bloc/incident_bloc.dart';
import '../bloc/incident_event.dart';
import '../bloc/incident_state.dart';
import '../../domain/entities/incident_entity.dart';
import '../../data/datasources/incident_remote_datasource.dart';
import 'incident_report_form_page.dart';
import 'incident_detail_page.dart';

class IncidentListPage extends StatefulWidget {
  const IncidentListPage({super.key});

  @override
  State<IncidentListPage> createState() => _IncidentListPageState();
}

class _IncidentListPageState extends State<IncidentListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  bool _isPengawas = false;
  
  // Filter state
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  IncidentStatus? _filterStatus;
  String? _filterPicId;
  String? _filterIncidentTypeId;
  String? _filterLocationId;

  @override
  void initState() {
    super.initState();
    // Initialize tab controller with default 2 tabs first
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    
    // Load user role and update tab controller if needed
    _loadUserRole();
    
    // Load initial data after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final bloc = context.read<IncidentBloc>();
        final state = bloc.state;
        
        // Sync local filter state with bloc state
        setState(() {
          _filterStartDate = state.filterStartDate;
          _filterEndDate = state.filterEndDate;
          _filterStatus = state.filterStatus;
          _filterPicId = state.filterPicId;
          _filterIncidentTypeId = state.filterIncidentTypeId;
          _filterLocationId = state.filterLocationId;
          if (state.searchQuery != null && state.searchQuery!.isNotEmpty) {
            _searchController.text = state.searchQuery!;
          }
        });
        
        if (!mounted) return;
        
        // Load locations and types first
        bloc.add(const LoadIncidentLocationsEvent());
        bloc.add(const LoadIncidentTypesEvent());
        // Load incident list with any existing filters from state
        bloc.add(
          LoadIncidentListEvent(
            searchQuery: _searchController.text.trim().isEmpty
                ? null
                : _searchController.text.trim(),
            startDate: _filterStartDate,
            endDate: _filterEndDate,
            status: _filterStatus,
            picId: _filterPicId,
            incidentTypeId: _filterIncidentTypeId,
            locationId: _filterLocationId,
          ),
        );
      } catch (e) {
        debugPrint('Error loading initial data: $e');
      }
    });
  }

  Future<void> _loadUserRole() async {
    final role = await UserRoleHelper.getUserRole();
    final isPengawas = role == UserRole.pengawas;
    
    setState(() {
      _isPengawas = isPengawas;
    });
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && mounted) {
      try {
        if (!mounted) return;
        if (_tabController.index == 0) {
          // Preserve filters when switching to incident list tab
          final bloc = context.read<IncidentBloc>();
          final state = bloc.state;
          bloc.add(
            LoadIncidentListEvent(
              searchQuery: _searchController.text.trim().isEmpty
                  ? null
                  : _searchController.text.trim(),
              startDate: _filterStartDate ?? state.filterStartDate,
              endDate: _filterEndDate ?? state.filterEndDate,
              status: _filterStatus ?? state.filterStatus,
              picId: _filterPicId ?? state.filterPicId,
              incidentTypeId: _filterIncidentTypeId ?? state.filterIncidentTypeId,
              locationId: _filterLocationId ?? state.filterLocationId,
            ),
          );
        } else {
          if (mounted) {
            final state = context.read<IncidentBloc>().state;
            context.read<IncidentBloc>().add(
              LoadMyTasksEvent(
                startDate: _filterStartDate ?? state.filterStartDate,
                endDate: _filterEndDate ?? state.filterEndDate,
                searchQuery: _searchController.text.trim().isEmpty
                    ? null
                    : _searchController.text.trim(),
                status: _filterStatus ?? state.filterStatus,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error loading tab data: $e');
      }
    }
  }

  void _onScroll() {
    if (_isBottom) {
      if (!mounted) return;
      try {
        // Untuk pengawas, selalu load more incident list
        if (_isPengawas) {
          context.read<IncidentBloc>().add(const LoadMoreIncidentListEvent());
        } else {
          if (_tabController.index == 0) {
            context.read<IncidentBloc>().add(const LoadMoreIncidentListEvent());
          } else {
            context.read<IncidentBloc>().add(const LoadMoreMyTasksEvent());
          }
        }
      } catch (e) {
        debugPrint('Error loading more incidents: $e');
      }
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
      if (!mounted) return;
      try {
        if (!mounted) return;
        final bloc = context.read<IncidentBloc>();
        // Untuk pengawas, selalu search incident list
        if (_isPengawas) {
          bloc.add(
            SearchIncidentListEvent(
              query,
              startDate: _filterStartDate,
              endDate: _filterEndDate,
              status: _filterStatus,
              picId: _filterPicId,
              incidentTypeId: _filterIncidentTypeId,
              locationId: _filterLocationId,
            ),
          );
        } else {
          if (_tabController.index == 0) {
            bloc.add(
              SearchIncidentListEvent(
                query,
                startDate: _filterStartDate,
                endDate: _filterEndDate,
                status: _filterStatus,
                picId: _filterPicId,
                incidentTypeId: _filterIncidentTypeId,
                locationId: _filterLocationId,
              ),
            );
          } else {
            bloc.add(SearchMyTasksEvent(query));
          }
        }
      } catch (e) {
        debugPrint('Error searching incidents: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Insiden Kejadian',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.download, color: primaryColor, size: 24.r),
              onPressed: () {
                // TODO: Implement download functionality
              },
            ),
          ],
          bottom: _isPengawas
              ? null // Pengawas tidak punya tab bar
              : TabBar(
                  controller: _tabController,
                  indicatorColor: primaryColor,
                  indicatorWeight: 3,
                  labelColor: primaryColor,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.normal,
                  ),
                  tabs: const [
                    Tab(text: 'Daftar Insiden'),
                    Tab(text: 'Tugas Saya'),
                  ],
                ),
        ),
        body: SafeArea(
          child: BlocConsumer<IncidentBloc, IncidentState>(
            listener: (context, state) {
              if (state.errorMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.errorMessage!),
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
                        // Search Bar
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: primaryColor),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Cari',
                                hintStyle: TextStyle(
                                  color: primaryColor.withOpacity(0.6),
                                  fontSize: 14.sp,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: primaryColor,
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
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.filter_list, color: Colors.white),
                            onPressed: () {
                              _showFilterDialog(context);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tab View (untuk pengawas hanya tampilkan list semua)
                  Expanded(
                    child: _isPengawas
                        ? _buildIncidentListTab() // Pengawas hanya lihat semua insiden
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildIncidentListTab(),
                              _buildMyTasksTab(),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (newContext) => IncidentReportFormPage.wrapped(context),
              ),
            );
            if (result == true && mounted) {
              // Refresh list after creating incident
              try {
                if (!mounted) return;
                final bloc = context.read<IncidentBloc>();
                final state = bloc.state;
                
                // Untuk pengawas, selalu refresh incident list
                if (_isPengawas) {
                  bloc.add(
                    LoadIncidentListEvent(
                      searchQuery: _searchController.text.trim().isEmpty
                          ? null
                          : _searchController.text.trim(),
                      startDate: _filterStartDate ?? state.filterStartDate,
                      endDate: _filterEndDate ?? state.filterEndDate,
                      status: _filterStatus ?? state.filterStatus,
                      picId: _filterPicId ?? state.filterPicId,
                      incidentTypeId: _filterIncidentTypeId ?? state.filterIncidentTypeId,
                      locationId: _filterLocationId ?? state.filterLocationId,
                    ),
                  );
                } else {
                  if (_tabController.index == 0) {
                    bloc.add(
                      LoadIncidentListEvent(
                        searchQuery: _searchController.text.trim().isEmpty
                            ? null
                            : _searchController.text.trim(),
                        startDate: _filterStartDate ?? state.filterStartDate,
                        endDate: _filterEndDate ?? state.filterEndDate,
                        status: _filterStatus ?? state.filterStatus,
                        picId: _filterPicId ?? state.filterPicId,
                        incidentTypeId: _filterIncidentTypeId ?? state.filterIncidentTypeId,
                        locationId: _filterLocationId ?? state.filterLocationId,
                      ),
                    );
                  } else {
                    bloc.add(const RefreshMyTasksEvent());
                  }
                }
              } catch (e) {
                debugPrint('Error refreshing list after creating incident: $e');
              }
            }
          },
          backgroundColor: primaryColor,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(
            'Laporkan Insiden',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
    );
  }

  Widget _buildIncidentListTab() {
    return BlocBuilder<IncidentBloc, IncidentState>(
      // Remove buildWhen to ensure it always rebuilds on state changes
      builder: (context, state) {
        if (state.isLoading && state.incidentList.isEmpty) {
          return Center(
            child: CircularProgressIndicator(color: primaryColor),
          );
        }

        if (state.incidentList.isEmpty && !state.isLoading) {
          return RefreshIndicator(
            onRefresh: () async {
              if (!mounted) return;
              try {
                if (!mounted) return;
                final bloc = context.read<IncidentBloc>();
                final state = bloc.state;
                // Preserve filters when refreshing
                bloc.add(
                  LoadIncidentListEvent(
                    searchQuery: _searchController.text.trim().isEmpty
                        ? null
                        : _searchController.text.trim(),
                    startDate: _filterStartDate ?? state.filterStartDate,
                    endDate: _filterEndDate ?? state.filterEndDate,
                    status: _filterStatus ?? state.filterStatus,
                    picId: _filterPicId ?? state.filterPicId,
                    incidentTypeId: _filterIncidentTypeId ?? state.filterIncidentTypeId,
                    locationId: _filterLocationId ?? state.filterLocationId,
                  ),
                );
              } catch (e) {
                debugPrint('Error refreshing incident list: $e');
              }
            },
            color: primaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64.r,
                        color: Colors.grey[400],
                      ),
                      16.verticalSpace,
                      Text(
                        'Tidak ada insiden',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (state.errorMessage != null) ...[
                        8.verticalSpace,
                        Padding(
                          padding: REdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            state.errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.red,
                            ),
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

        return RefreshIndicator(
          onRefresh: () async {
            if (!mounted) return;
            try {
              if (!mounted) return;
              final bloc = context.read<IncidentBloc>();
              final state = bloc.state;
              // Preserve filters when refreshing
              bloc.add(
                LoadIncidentListEvent(
                  searchQuery: _searchController.text.trim().isEmpty
                      ? null
                      : _searchController.text.trim(),
                  startDate: _filterStartDate ?? state.filterStartDate,
                  endDate: _filterEndDate ?? state.filterEndDate,
                  status: _filterStatus ?? state.filterStatus,
                  picId: _filterPicId ?? state.filterPicId,
                  incidentTypeId: _filterIncidentTypeId ?? state.filterIncidentTypeId,
                  locationId: _filterLocationId ?? state.filterLocationId,
                ),
              );
            } catch (e) {
              debugPrint('Error refreshing incident list: $e');
            }
          },
          color: primaryColor,
          child: ListView.builder(
            controller: _scrollController,
            padding: REdgeInsets.all(16),
            itemCount: state.incidentList.length + (state.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= state.incidentList.length) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(color: primaryColor),
                  ),
                );
              }

              final incident = state.incidentList[index];
              return _buildIncidentCard(incident);
            },
          ),
        );
      },
    );
  }

  Widget _buildMyTasksTab() {
    return BlocBuilder<IncidentBloc, IncidentState>(
      builder: (context, state) {
        
        if (state.isLoading && state.myTasks.isEmpty) {
          return Center(
            child: CircularProgressIndicator(color: primaryColor),
          );
        }

        if (state.myTasks.isEmpty) {
          return Center(
            child: Text(
              'Tidak ada tugas',
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.grey[600],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            if (!mounted) return;
            try {
              context.read<IncidentBloc>().add(const RefreshMyTasksEvent());
            } catch (e) {
              debugPrint('Error refreshing my tasks: $e');
            }
          },
          color: primaryColor,
          child: ListView.builder(
            controller: _scrollController,
            padding: REdgeInsets.all(16),
            itemCount: state.myTasks.length + (state.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= state.myTasks.length) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(color: primaryColor),
                  ),
                );
              }

              final incident = state.myTasks[index];
              return _buildIncidentCard(incident);
            },
          ),
        );
      },
    );
  }

  Widget _buildIncidentCard(IncidentEntity incident) {
    final statusColor = _getStatusColor(incident.statusColor);
    final statusTextColor = _getStatusTextColor(incident.statusColor);
    // Untuk pengawas, selalu false (tidak ada tab "Tugas Saya")
    final isFromMyTasks = !_isPengawas && _tabController.index == 1;

    return InkWell(
      onTap: () {
        // Check if context is still mounted before accessing bloc
        if (!mounted) return;
        
        try {
          // Get bloc from parent context before navigation
          final bloc = context.read<IncidentBloc>();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BlocProvider.value(
                value: bloc,
                child: IncidentDetailPage(
                  incident: incident, 
                  isFromMyTasks: isFromMyTasks,
                ),
              ),
            ),
          ).then((result) {
            if (result == true && mounted) {
              // Refresh list after update
              try {
                if (!mounted) return;
                final bloc = context.read<IncidentBloc>();
                final state = bloc.state;
                
                // Untuk pengawas, selalu refresh incident list
                if (_isPengawas) {
                  bloc.add(
                    LoadIncidentListEvent(
                      searchQuery: _searchController.text.trim().isEmpty
                          ? null
                          : _searchController.text.trim(),
                      startDate: _filterStartDate ?? state.filterStartDate,
                      endDate: _filterEndDate ?? state.filterEndDate,
                      status: _filterStatus ?? state.filterStatus,
                      picId: _filterPicId ?? state.filterPicId,
                      incidentTypeId: _filterIncidentTypeId ?? state.filterIncidentTypeId,
                      locationId: _filterLocationId ?? state.filterLocationId,
                    ),
                  );
                } else {
                  if (_tabController.index == 0) {
                    bloc.add(
                      LoadIncidentListEvent(
                        searchQuery: _searchController.text.trim().isEmpty
                            ? null
                            : _searchController.text.trim(),
                        startDate: _filterStartDate ?? state.filterStartDate,
                        endDate: _filterEndDate ?? state.filterEndDate,
                        status: _filterStatus ?? state.filterStatus,
                        picId: _filterPicId ?? state.filterPicId,
                        incidentTypeId: _filterIncidentTypeId ?? state.filterIncidentTypeId,
                        locationId: _filterLocationId ?? state.filterLocationId,
                      ),
                    );
                  } else {
                    bloc.add(const RefreshMyTasksEvent());
                  }
                }
              } catch (e) {
                // Bloc might not be available, ignore
                debugPrint('Error refreshing incident list: $e');
              }
            }
          });
        } catch (e) {
          // Bloc might not be available, show error or ignore
          debugPrint('Error accessing IncidentBloc: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Terjadi kesalahan saat membuka detail insiden'),
                backgroundColor: Colors.red,
              ),
            );
          }
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
              // ID and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    incident.formattedId,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Container(
                    padding: REdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      incident.statusDisplayName,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: statusTextColor,
                      ),
                    ),
                  ),
                ],
              ),
              12.verticalSpace,
              // Tipe Insiden
              _buildInfoRow('Tipe Insiden', incident.tipeInsidenDisplayName),
              8.verticalSpace,
              // Role Pelapor
              _buildInfoRow(
                'Role Pelapor',
                incident.reporterRole != null && incident.reporterRole!.isNotEmpty
                    ? UserRole.fromValue(incident.reporterRole!).displayName
                    : '-',
              ),
              8.verticalSpace,
              // Lokasi
              _buildInfoRow('Lokasi', incident.lokasiInsiden ?? '-'),
              8.verticalSpace,
              // Kejadian
              _buildInfoRow('Kejadian', incident.deskripsiInsiden ?? '-'),
              8.verticalSpace,
              // PIC
              _buildInfoRow('PIC', incident.pic ?? '-'),
              8.verticalSpace,
              // Dibuat
              _buildInfoRow(
                'dibuat',
                incident.createDate != null
                    ? _formatDate(incident.createDate!)
                    : '-',
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

  Color _getStatusColor(IncidentStatusColor statusColor) {
    switch (statusColor) {
      case IncidentStatusColor.red:
        return Colors.red;
      case IncidentStatusColor.orange:
        return Colors.orange;
      case IncidentStatusColor.yellow:
        return Colors.amber;
      case IncidentStatusColor.blue:
        return Colors.blue;
      case IncidentStatusColor.purple:
        return Colors.purple;
      case IncidentStatusColor.green:
        return Colors.green;
      case IncidentStatusColor.lightYellow:
        return Colors.yellow[300]!;
    }
  }

  Color _getStatusTextColor(IncidentStatusColor statusColor) {
    switch (statusColor) {
      case IncidentStatusColor.red:
        return Colors.red;
      case IncidentStatusColor.orange:
        return Colors.orange;
      case IncidentStatusColor.yellow:
        return Colors.amber[700]!;
      case IncidentStatusColor.blue:
        return Colors.blue;
      case IncidentStatusColor.purple:
        return Colors.purple;
      case IncidentStatusColor.green:
        return Colors.green;
      case IncidentStatusColor.lightYellow:
        return Colors.yellow[700]!;
    }
  }

  String _formatDate(DateTime date) {
    final formatter = DateFormat('dd/MM/yyyy', 'id_ID');
    return formatter.format(date);
  }

  Future<void> _showFilterDialog(BuildContext context) async {
    if (!mounted) return;
    
    // Get bloc before showing dialog
    final bloc = context.read<IncidentBloc>();
    final blocState = bloc.state;
    
    // Sync local state with bloc state (without setState to avoid rebuild issues)
    _filterStartDate = _filterStartDate ?? blocState.filterStartDate;
    _filterEndDate = _filterEndDate ?? blocState.filterEndDate;
    _filterStatus = _filterStatus ?? blocState.filterStatus;
    _filterPicId = _filterPicId ?? blocState.filterPicId;
    _filterIncidentTypeId = _filterIncidentTypeId ?? blocState.filterIncidentTypeId;
    _filterLocationId = _filterLocationId ?? blocState.filterLocationId;
    
    // Use the most up-to-date filter values (prefer local state, fallback to bloc state)
    DateTime? tempStartDate = _filterStartDate ?? blocState.filterStartDate;
    DateTime? tempEndDate = _filterEndDate ?? blocState.filterEndDate;
    IncidentStatus? tempStatus = _filterStatus ?? blocState.filterStatus;
    String? tempPicId = _filterPicId ?? blocState.filterPicId;
    String? tempIncidentTypeId = _filterIncidentTypeId ?? blocState.filterIncidentTypeId;
    String? tempLocationId = _filterLocationId ?? blocState.filterLocationId;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: bloc,
        child: StatefulBuilder(
          builder: (context, setState) {
          return AlertDialog(
            title: const Text('Filter Insiden'),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            content: SizedBox(
              width: double.maxFinite,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                // Range Tanggal
                const Text(
                  'Range Tanggal',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: tempStartDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              tempStartDate = date;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tempStartDate != null
                                ? DateFormat('dd/MM/yyyy').format(tempStartDate!)
                                : 'Tanggal Mulai',
                            style: TextStyle(
                              color: tempStartDate != null
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: tempEndDate ?? DateTime.now(),
                            firstDate: tempStartDate ?? DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              tempEndDate = date;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tempEndDate != null
                                ? DateFormat('dd/MM/yyyy').format(tempEndDate!)
                                : 'Tanggal Akhir',
                            style: TextStyle(
                              color: tempEndDate != null
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Status
                const Text(
                  'Status',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                BlocBuilder<IncidentBloc, IncidentState>(
                  builder: (context, state) {
                    return DropdownButtonFormField<IncidentStatus?>(
                      value: tempStatus,
                      isExpanded: true,
                      menuMaxHeight: MediaQuery.of(context).size.height * 0.4,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        isDense: true,
                      ),
                      hint: const Text('Pilih Status'),
                      items: [
                        const DropdownMenuItem<IncidentStatus?>(
                          value: null,
                          child: Text(
                            'Semua Status',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...IncidentStatus.values.map((status) {
                          return DropdownMenuItem<IncidentStatus?>(
                            value: status,
                            child: Text(
                              _getStatusDisplayName(status),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          tempStatus = value;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                
                // PIC
                const Text(
                  'PIC',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<Map<String, String>>>(
                  future: _getUserList(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }
                    final users = snapshot.data!;
                    return DropdownButtonFormField<String?>(
                      value: tempPicId,
                      isExpanded: true,
                      menuMaxHeight: MediaQuery.of(context).size.height * 0.4,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        isDense: true,
                      ),
                      hint: const Text('Pilih PIC'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'Semua PIC',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...users.map((user) {
                          return DropdownMenuItem<String?>(
                            value: user['id'],
                            child: Text(
                              user['name'] ?? '',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          tempPicId = value;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                
                // Tipe Insiden
                const Text(
                  'Tipe Insiden',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                BlocBuilder<IncidentBloc, IncidentState>(
                  builder: (context, state) {
                    return DropdownButtonFormField<String?>(
                      value: tempIncidentTypeId,
                      isExpanded: true,
                      menuMaxHeight: MediaQuery.of(context).size.height * 0.4,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        isDense: true,
                      ),
                      hint: const Text('Pilih Tipe Insiden'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'Semua Tipe',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...state.types.map((type) {
                          return DropdownMenuItem<String?>(
                            value: type.id,
                            child: Text(
                              type.name,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          tempIncidentTypeId = value;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                
                // Lokasi Insiden
                const Text(
                  'Lokasi Insiden',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                BlocBuilder<IncidentBloc, IncidentState>(
                  builder: (context, state) {
                    return DropdownButtonFormField<String?>(
                      value: tempLocationId,
                      isExpanded: true,
                      menuMaxHeight: MediaQuery.of(context).size.height * 0.4,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        isDense: true,
                      ),
                      hint: const Text('Pilih Lokasi'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'Semua Lokasi',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...state.locations.map((location) {
                          return DropdownMenuItem<String?>(
                            value: location.id,
                            child: Text(
                              location.name,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          tempLocationId = value;
                        });
                      },
                    );
                  },
                ),
              ],
                    ),
                  ),
                ),
              ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            actions: [
            TextButton(
                onPressed: () {
                  // Reset filters
                  setState(() {
                    tempStartDate = null;
                    tempEndDate = null;
                    tempStatus = null;
                    tempPicId = null;
                    tempIncidentTypeId = null;
                    tempLocationId = null;
                  });
                },
                child: const Text('Reset'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop({
                  'startDate': tempStartDate,
                  'endDate': tempEndDate,
                  'status': tempStatus,
                  'picId': tempPicId,
                  'incidentTypeId': tempIncidentTypeId,
                  'locationId': tempLocationId,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Terapkan'),
            ),
          ],
          );
        },
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _filterStartDate = result['startDate'] as DateTime?;
        _filterEndDate = result['endDate'] as DateTime?;
        _filterStatus = result['status'] as IncidentStatus?;
        _filterPicId = result['picId'] as String?;
        _filterIncidentTypeId = result['incidentTypeId'] as String?;
        _filterLocationId = result['locationId'] as String?;
      });

      // Apply filter
      if (mounted) {
        try {
          final bloc = context.read<IncidentBloc>();
          if (_isPengawas || _tabController.index == 0) {
            bloc.add(
              LoadIncidentListEvent(
                searchQuery: _searchController.text.trim().isEmpty
                    ? null
                    : _searchController.text.trim(),
                startDate: _filterStartDate,
                endDate: _filterEndDate,
                status: _filterStatus,
                picId: _filterPicId,
                incidentTypeId: _filterIncidentTypeId,
                locationId: _filterLocationId,
              ),
            );
          } else {
            bloc.add(
              LoadMyTasksEvent(
                startDate: _filterStartDate,
                endDate: _filterEndDate,
                searchQuery: _searchController.text.trim().isEmpty
                    ? null
                    : _searchController.text.trim(),
                status: _filterStatus,
              ),
            );
          }
        } catch (e) {
          debugPrint('Error applying filter: $e');
        }
      }
    }
  }

  Future<List<Map<String, String>>> _getUserList() async {
    try {
      final datasource = getIt<IncidentRemoteDataSource>();
      final users = await datasource.getUserList();
      // Sort by name
      users.sort((a, b) {
        final nameA = (a['name'] ?? '').toLowerCase();
        final nameB = (b['name'] ?? '').toLowerCase();
        return nameA.compareTo(nameB);
      });
      return users;
    } catch (e) {
      return [];
    }
  }

  String _getStatusDisplayName(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.menunggu:
        return 'Menunggu';
      case IncidentStatus.revisi:
        return 'Revisi';
      case IncidentStatus.diterima:
        return 'Diterima';
      case IncidentStatus.ditugaskan:
        return 'Ditugaskan';
      case IncidentStatus.proses:
        return 'Proses';
      case IncidentStatus.eskalasi:
        return 'Eskalasi';
      case IncidentStatus.selesai:
        return 'Selesai';
      case IncidentStatus.terverifikasi:
        return 'Terverifikasi';
      case IncidentStatus.tidakValid:
        return 'Tidak Valid';
    }
  }
}

