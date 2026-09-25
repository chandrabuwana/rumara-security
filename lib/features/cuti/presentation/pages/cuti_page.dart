import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/security/security_manager.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/Buttons/ui_button.dart';
import '../bloc/cuti_bloc.dart';
import '../bloc/cuti_event.dart';
import '../bloc/cuti_state.dart';
import '../widgets/cuti_card.dart';
import '../widgets/kuota_cuti_card.dart';
import '../widgets/kuota_cuti_grid.dart';
import '../widgets/search_filter_cuti_widget.dart';
import 'form_ajuan_cuti_page.dart';
import 'detail_cuti_page.dart';
import '../../domain/entities/cuti_entity.dart';

class CutiPage extends StatefulWidget {
  final String? userId;
  final UserRole? userRole;

  const CutiPage({
    Key? key,
    this.userId,
    this.userRole,
  }) : super(key: key);

  @override
  State<CutiPage> createState() => _CutiPageState();
}

class _CutiPageState extends State<CutiPage>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  String? _currentUserId;
  UserRole? _currentUserRole;
  late CutiBloc _cutiBloc;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    // Initialize bloc
    _cutiBloc = getIt<CutiBloc>();

    // Load user data from secure storage
    _initializeUserData();
  }

  Future<void> _initializeUserData() async {
    // Get userId from secure storage
    final userId = await SecurityManager.readSecurely(AppConstants.userIdKey);
    _currentUserId = widget.userId ?? userId ?? 'user_1';

    // Get user role from secure storage
    final roleId = await SecurityManager.readSecurely('user_role_id');
    _currentUserRole = widget.userRole ??
        (roleId != null ? UserRole.fromValue(roleId) : UserRole.anggota);

    print(
        '🔐 Initialized Cuti page with userId: $_currentUserId, role: $_currentUserRole');

    // Initialize tab controller based on user role
    _tabController = TabController(
      length: _getTabCount(),
      vsync: this,
    );

    // Listen for tab changes (handles both tap AND swipe)
    _tabController!.addListener(() {
      if (!_tabController!.indexIsChanging) {
        _onTabChanged(_tabController!.index);
      }
    });

    // Load initial data
    _loadInitialData();

    // Refresh UI after loading user data
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _cutiBloc.close();
    super.dispose();
  }

  int _getTabCount() {
    final role = _currentUserRole ?? UserRole.anggota;
    switch (role) {
      case UserRole.anggota:
      case UserRole.danton:
        return 2; // Kuota Cuti, Ajuan Cuti
      case UserRole.pjo:
      case UserRole.deputy:
        return 3; // Ajuan Anggota, Kuota Cuti, Ajuan Saya
      case UserRole.pengawas:
      case UserRole.admin:
        return 2; // Ajuan Cuti, Rekap Ajuan Cuti
    }
  }

  List<Tab> _getTabs() {
    final role = _currentUserRole ?? UserRole.anggota;
    switch (role) {
      case UserRole.anggota:
      case UserRole.danton:
        return [
          Tab(text: 'Kuota Cuti'),
          Tab(text: 'Ajuan Cuti'),
        ];
      case UserRole.pjo:
      case UserRole.deputy:
        return [
          Tab(text: 'Ajuan Anggota'),
          Tab(text: 'Kuota Cuti'),
          Tab(text: 'Ajuan Saya'),
        ];
      case UserRole.pengawas:
      case UserRole.admin:
        return [
          Tab(text: 'Ajuan Cuti'),
          Tab(text: 'Rekap Ajuan Cuti'),
        ];
    }
  }

  void _loadInitialData() {
    final role = _currentUserRole ?? UserRole.anggota;
    final userId = _currentUserId ?? 'user_1';

    switch (role) {
      case UserRole.anggota:
      case UserRole.danton:
        _cutiBloc.add(GetCutiKuotaEvent(userId));
        break;
      case UserRole.pjo:
      case UserRole.deputy:
        _cutiBloc.add(const GetDaftarCutiAnggotaEvent());
        break;
      case UserRole.pengawas:
      case UserRole.admin:
        // Untuk Pengawas, tab Ajuan Cuti default filter hanya status pending
        _cutiBloc.add(const GetDaftarCutiAnggotaEvent(status: 'pending'));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while initializing
    if (!_isInitialized || _tabController == null) {
      return AppScaffold(
        appBar: AppBar(
          title: const Text('Pengajuan Cuti'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return BlocProvider.value(
      value: _cutiBloc,
      child: AppScaffold(
        appBar: AppBar(
          title: const Text('Pengajuan Cuti'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        enableScrolling: false,
        child: Column(
          children: [
            // Tab Bar
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController!,
                labelColor: primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: primaryColor,
                indicatorWeight: 3.0,
                labelStyle: TS.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: TS.titleSmall.copyWith(
                  fontWeight: FontWeight.normal,
                ),
                tabs: _getTabs(),
              ),
            ),

            // Tab Bar View
            Expanded(
              child: TabBarView(
                controller: _tabController!,
                children: _getTabViews(),
              ),
            ),
          ],
        ),
        floatingActionButton: _shouldShowFab() ? _buildFab() : null,
      ),
    );
  }

  List<Widget> _getTabViews() {
    final role = _currentUserRole ?? UserRole.anggota;
    switch (role) {
      case UserRole.anggota:
      case UserRole.danton:
        return [
          _buildKuotaCutiTab(),
          _buildAjuanCutiTab(),
        ];
      case UserRole.pjo:
      case UserRole.deputy:
        return [
          _buildAjuanAnggotaTab(),
          _buildKuotaCutiTab(),
          _buildAjuanSayaTab(),
        ];
      case UserRole.pengawas:
      case UserRole.admin:
        return [
          _buildAjuanCutiPengawasTab(),
          _buildRekapAjuanCutiTab(),
        ];
    }
  }

  void _onTabChanged(int index) {
    final role = _currentUserRole ?? UserRole.anggota;
    final userId = _currentUserId ?? 'user_1';

    switch (role) {
      case UserRole.anggota:
      case UserRole.danton:
        if (index == 0) {
          _cutiBloc.add(GetCutiKuotaEvent(userId));
        } else if (index == 1) {
          _cutiBloc.add(GetDaftarCutiSayaEvent(userId));
        }
        break;
      case UserRole.pjo:
      case UserRole.deputy:
        if (index == 0) {
          _cutiBloc.add(const GetDaftarCutiAnggotaEvent());
        } else if (index == 1) {
          _cutiBloc.add(GetCutiKuotaEvent(userId));
        } else if (index == 2) {
          // Use UserId filter for Ajuan Saya
          _cutiBloc.add(GetDaftarCutiSayaEvent(userId));
        }
        break;
      case UserRole.pengawas:
      case UserRole.admin:
        if (index == 0) {
          // Untuk tab Ajuan Cuti Pengawas, default filter hanya status pending
          _cutiBloc.add(const GetDaftarCutiAnggotaEvent(status: 'pending'));
        } else if (index == 1) {
          // Untuk Rekap Cuti, default filter hanya approved dan rejected
          _cutiBloc.add(const GetRekapCutiEvent());
        }
        break;
    }
  }

  bool _shouldShowFab() {
    // Show FAB for anggota, danton (always), and for PJO/Deputy (for their personal leave in tab "Ajuan Saya")
    final role = _currentUserRole ?? UserRole.anggota;
    final tabIndex = _tabController?.index ?? 0;

    return role == UserRole.anggota ||
        role == UserRole.danton ||
        (role == UserRole.pjo && tabIndex == 2) ||
        (role == UserRole.deputy && tabIndex == 2);
  }

  Widget _buildFab() {
    final userId = _currentUserId ?? 'user_1';

    return FloatingActionButton(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      onPressed: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BlocProvider.value(
              value: _cutiBloc,
              child: FormAjuanCutiPage(
                userId: userId,
                userName: 'Current User', // TODO: Get from auth
              ),
            ),
          ),
        );
        
        // Reload data if ajuan was created
        if (result == true) {
          _reloadCurrentTab();
        }
      },
      child: Icon(Icons.add, size: 24.sp),
    );
  }

  // Tab view builders
  Widget _buildKuotaCutiTab() {
    return BlocBuilder<CutiBloc, CutiState>(
      builder: (context, state) {
        if (state is CutiLoading) {
          return Center(
            child: CircularProgressIndicator(color: primaryColor),
          );
        }

        if (state is CutiError) {
          return _buildErrorWidget(state.message);
        }

        if (state is CutiKuotaLoaded) {
          return SingleChildScrollView(
            padding: REdgeInsets.all(16),
            child: KuotaCutiGrid(kuotaList: state.kuotaList),
          );
        }

        return _buildEmptyState('Belum ada data kuota cuti');
      },
    );
  }

  Widget _buildAjuanCutiTab() {
    return _AjuanCutiAnggotaTabContent(
      cutiBloc: _cutiBloc,
      userId: _currentUserId ?? 'user_1',
    );
  }

  Widget _buildAjuanSayaTab() {
    return _AjuanSayaTabContent(
      cutiBloc: _cutiBloc,
      userId: _currentUserId ?? 'user_1',
    );
  }

  Widget _buildAjuanAnggotaTab() {
    return _AjuanAnggotaTabContent(
      cutiBloc: _cutiBloc,
      showActions: true,
    );
  }

  Widget _buildAjuanCutiPengawasTab() {
    // Tab Ajuan Cuti untuk pengawas: sama dengan danton, menggunakan filter bawahan
    return _buildAjuanAnggotaTab();
  }

  Widget _buildRekapAjuanCutiTab() {
    return _RekapAjuanCutiTabContent(
      cutiBloc: _cutiBloc,
    );
  }

  Widget _buildCutiList(List<CutiEntity> cutiList, bool showActions) {
    // Determine if actions should be shown in detail page based on user role
    // showActions = true untuk tab yang bisa approve/reject (Ajuan Anggota untuk PJO/Deputy, Ajuan Cuti pengawas)
    // showActions = false untuk tab rekap (hanya view)
    // Note: Danton tidak memiliki tab Ajuan Anggota, jadi tidak bisa approve/reject
    final canShowActions = showActions && 
        (_currentUserRole == UserRole.pjo || 
         _currentUserRole == UserRole.deputy ||
         _currentUserRole == UserRole.pengawas);
    
    return ListView.builder(
      padding: REdgeInsets.all(16),
      itemCount: cutiList.length,
      itemBuilder: (context, index) {
        final cuti = cutiList[index];
        // Only show actions in detail page for pending cuti and if showActions is true
        final shouldShowActions = canShowActions && cuti.status == CutiStatus.pending;
        
        return Padding(
          padding: REdgeInsets.only(bottom: 12),
          child: CutiCard(
            cuti: cuti,
            showActions: false, // Tidak tampilkan tombol di list, hanya di detail
            onTap: () async {
              // Navigate to detail page and wait for result
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlocProvider.value(
                    value: _cutiBloc,
                    child: DetailCutiPage(
                      cutiId: cuti.id,
                      showActions: shouldShowActions,
                      currentUserRole: _currentUserRole ?? UserRole.anggota,
                    ),
                  ),
                ),
              );
              
              // Reload data if status was updated, edited, or deleted
              if (result == true) {
                // Use WidgetsBinding to ensure reload happens after frame is built
                // This ensures tab index is correctly updated
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _reloadCurrentTab();
                  }
                });
              }
            },
          ),
        );
      },
    );
  }
  
  void _reloadCurrentTab() {
    final role = _currentUserRole ?? UserRole.anggota;
    final userId = _currentUserId ?? 'user_1';
    final tabIndex = _tabController?.index ?? 0;

    // Use the same logic as _onTabChanged to ensure consistency
    switch (role) {
      case UserRole.anggota:
      case UserRole.danton:
        if (tabIndex == 0) {
          _cutiBloc.add(GetCutiKuotaEvent(userId));
        } else if (tabIndex == 1) {
          _cutiBloc.add(GetDaftarCutiSayaEvent(userId));
        }
        break;
      case UserRole.pjo:
      case UserRole.deputy:
        if (tabIndex == 0) {
          _cutiBloc.add(const GetDaftarCutiAnggotaEvent());
        } else if (tabIndex == 1) {
          _cutiBloc.add(GetCutiKuotaEvent(userId));
        } else if (tabIndex == 2) {
          _cutiBloc.add(GetDaftarCutiSayaEvent(userId));
        }
        break;
      case UserRole.pengawas:
      case UserRole.admin:
        if (tabIndex == 0) {
          // Untuk tab Ajuan Cuti Pengawas, default filter hanya status pending
          _cutiBloc.add(const GetDaftarCutiAnggotaEvent(status: 'pending'));
        } else if (tabIndex == 1) {
          // Untuk Rekap Cuti, default filter hanya approved dan rejected
          _cutiBloc.add(const GetRekapCutiEvent());
        }
        break;
    }
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64.r,
            color: Colors.red,
          ),
          16.verticalSpace,
          Text(
            'Terjadi Kesalahan',
            style: TS.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          8.verticalSpace,
          Text(
            message,
            style: TS.bodyMedium.copyWith(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          24.verticalSpace,
          UIButton(
            text: 'Coba Lagi',
            onPressed: () {
              _loadInitialData();
            },
            size: UIButtonSize.medium,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 64.r,
            color: Colors.grey.shade400,
          ),
          16.verticalSpace,
          Text(
            message,
            style: TS.titleMedium.copyWith(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String text) {
    return Container(
      width: double.infinity,
      padding: REdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TS.bodyMedium.copyWith(
          color: Colors.black87,
          height: 1.4,
        ),
      ),
    );
  }

}

// Widget untuk tab Ajuan Saya dengan search dan filter
class _AjuanSayaTabContent extends StatefulWidget {
  final CutiBloc cutiBloc;
  final String userId;

  const _AjuanSayaTabContent({
    required this.cutiBloc,
    required this.userId,
  });

  @override
  State<_AjuanSayaTabContent> createState() => _AjuanSayaTabContentState();
}

class _AjuanSayaTabContentState extends State<_AjuanSayaTabContent> {
  List<CutiEntity> _allCuti = [];
  List<CutiEntity> _filteredCuti = [];
  String _searchQuery = '';
  String? _selectedStatus;
  String? _selectedTipeCuti;
  DateTime? _tanggalMulai;
  DateTime? _tanggalSelesai;
  String? _selectedSort = 'terbaru';

  @override
  Widget build(BuildContext context) {
    return BlocListener<CutiBloc, CutiState>(
      bloc: widget.cutiBloc,
      listener: (context, state) {
        // Handle state changes outside of build method
        if (state is DaftarCutiSayaLoaded) {
          // Always update when new data arrives from API (after edit/delete)
          // Use post frame callback to avoid setState during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _allCuti = List.from(state.daftarCuti); // Create new list to force update
              });
              _applyFilters();
            }
          });
        }
      },
      child: BlocBuilder<CutiBloc, CutiState>(
        bloc: widget.cutiBloc,
        builder: (context, state) {
          if (state is CutiLoading) {
            return Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          if (state is CutiError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64.r,
                    color: Colors.red,
                  ),
                  16.verticalSpace,
                  Text(
                    'Terjadi Kesalahan',
                    style: TS.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  8.verticalSpace,
                  Text(
                    state.message,
                    style: TS.bodyMedium.copyWith(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  24.verticalSpace,
                  UIButton(
                    text: 'Coba Lagi',
                    onPressed: () {
                      widget.cutiBloc.add(GetDaftarCutiSayaEvent(widget.userId));
                    },
                    size: UIButtonSize.medium,
                  ),
                ],
              ),
            );
          }

          if (state is DaftarCutiSayaLoaded) {
            return Column(
            children: [
              // Search and Filter Bar
              SearchFilterCutiWidget(
                onFilterApplied: (
                  searchQuery,
                  status,
                  tipeCuti,
                  tanggalMulai,
                  tanggalSelesai,
                  sort,
                ) {
                  setState(() {
                    if (searchQuery != null) _searchQuery = searchQuery;
                    // Handle status: null means "Semua", so reset filter
                    _selectedStatus = status;
                    // Handle tipeCuti: null means "Semua", so reset filter
                    _selectedTipeCuti = tipeCuti;
                    // Handle tanggalMulai: null means reset
                    _tanggalMulai = tanggalMulai;
                    // Handle tanggalSelesai: null means reset
                    _tanggalSelesai = tanggalSelesai;
                    if (sort != null) _selectedSort = sort;
                  });
                  _applyFilters();
                },
                onSearchChanged: (query) {
                  setState(() {
                    _searchQuery = query;
                  });
                  _applyFilters();
                },
              ),

              // List
              Expanded(
                child: _filteredCuti.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 64.r,
                              color: Colors.grey.shade400,
                            ),
                            16.verticalSpace,
                            Text(
                              _allCuti.isEmpty
                                  ? 'Belum ada ajuan cuti pribadi'
                                  : 'Tidak ada hasil yang ditemukan',
                              style: TS.titleMedium.copyWith(
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_allCuti.isEmpty) ...[
                              24.verticalSpace,
                              UIButton(
                                text: 'Buat Ajuan Cuti',
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BlocProvider.value(
                                        value: widget.cutiBloc,
                                        child: FormAjuanCutiPage(
                                          userId: widget.userId,
                                          userName: 'Current User', // TODO: Get from auth
                                        ),
                                      ),
                                    ),
                                  );
                                  
                                  // Reload data if ajuan was created
                                  if (result == true) {
                                    widget.cutiBloc.add(GetDaftarCutiSayaEvent(widget.userId));
                                  }
                                },
                                size: UIButtonSize.medium,
                              ),
                            ],
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              padding: REdgeInsets.all(16),
                              itemCount: _filteredCuti.length,
                              itemBuilder: (context, index) {
                                final cuti = _filteredCuti[index];
                                return Padding(
                                  padding: REdgeInsets.only(bottom: 12),
                                  child: CutiCard(
                                    cuti: cuti,
                                    showActions: false,
                                    onTap: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => BlocProvider.value(
                                            value: widget.cutiBloc,
                                            child: DetailCutiPage(
                                              cutiId: cuti.id,
                                              showActions: false,
                                              currentUserRole: UserRole.anggota,
                                            ),
                                          ),
                                        ),
                                      );
                                      
                                      // Reload data if cuti was edited or deleted
                                      if (result == true) {
                                        widget.cutiBloc.add(GetDaftarCutiSayaEvent(widget.userId));
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                          // Button at bottom
                          Container(
                            padding: REdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade200,
                                  blurRadius: 4,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                            child: UIButton(
                              text: 'Buat Ajuan Cuti',
                              fullWidth: true,
                              size: UIButtonSize.large,
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BlocProvider.value(
                                      value: widget.cutiBloc,
                                      child: FormAjuanCutiPage(
                                        userId: widget.userId,
                                        userName: 'Current User', // TODO: Get from auth
                                      ),
                                    ),
                                  ),
                                );
                                
                                // Reload data if ajuan was created
                                if (result == true) {
                                  widget.cutiBloc.add(GetDaftarCutiSayaEvent(widget.userId));
                                }
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ],
            );
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy,
                  size: 64.r,
                  color: Colors.grey.shade400,
                ),
                16.verticalSpace,
                Text(
                  'Belum ada ajuan cuti pribadi',
                  style: TS.titleMedium.copyWith(
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _applyFilters() {
    List<CutiEntity> filtered = List.from(_allCuti);

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((cuti) {
        final query = _searchQuery.toLowerCase();
        return cuti.id.toLowerCase().contains(query) ||
            cuti.nama.toLowerCase().contains(query) ||
            cuti.alasan.toLowerCase().contains(query) ||
            cuti.tipeCutiDisplayName.toLowerCase().contains(query);
      }).toList();
    }

    // Status filter
    if (_selectedStatus != null) {
      filtered = filtered.where((cuti) {
        switch (_selectedStatus) {
          case 'pending':
            return cuti.status == CutiStatus.pending;
          case 'approved':
            return cuti.status == CutiStatus.approved;
          case 'rejected':
            return cuti.status == CutiStatus.rejected;
          case 'cancelled':
            return cuti.status == CutiStatus.cancelled;
          default:
            return true;
        }
      }).toList();
    }

    // Tipe Cuti filter
    if (_selectedTipeCuti != null) {
      filtered = filtered.where((cuti) {
        switch (_selectedTipeCuti) {
          case 'tahunan':
            return cuti.tipeCuti == CutiType.tahunan;
          case 'sakit':
            return cuti.tipeCuti == CutiType.sakit;
          case 'melahirkan':
            return cuti.tipeCuti == CutiType.melahirkan;
          case 'menikah':
            return cuti.tipeCuti == CutiType.menikah;
          case 'keluargaMeninggal':
            return cuti.tipeCuti == CutiType.keluargaMeninggal;
          case 'lainnya':
            return cuti.tipeCuti == CutiType.lainnya;
          default:
            return true;
        }
      }).toList();
    }

    // Date range filter
    if (_tanggalMulai != null) {
      filtered = filtered.where((cuti) {
        return cuti.tanggalMulai.isAfter(_tanggalMulai!) ||
            cuti.tanggalMulai.isAtSameMomentAs(_tanggalMulai!);
      }).toList();
    }

    if (_tanggalSelesai != null) {
      filtered = filtered.where((cuti) {
        return cuti.tanggalSelesai.isBefore(_tanggalSelesai!) ||
            cuti.tanggalSelesai.isAtSameMomentAs(_tanggalSelesai!);
      }).toList();
    }

    // Sort
    if (_selectedSort == 'terbaru') {
      filtered.sort((a, b) => b.tanggalPengajuan.compareTo(a.tanggalPengajuan));
    } else if (_selectedSort == 'terlama') {
      filtered.sort((a, b) => a.tanggalPengajuan.compareTo(b.tanggalPengajuan));
    }

    setState(() {
      _filteredCuti = filtered;
    });
  }
}

// Widget untuk tab Ajuan Anggota dengan search dan filter
class _AjuanAnggotaTabContent extends StatefulWidget {
  final CutiBloc cutiBloc;
  final bool showActions;

  const _AjuanAnggotaTabContent({
    required this.cutiBloc,
    this.showActions = true,
  });

  @override
  State<_AjuanAnggotaTabContent> createState() => _AjuanAnggotaTabContentState();
}

class _AjuanAnggotaTabContentState extends State<_AjuanAnggotaTabContent> {
  List<CutiEntity> _allCuti = [];
  List<CutiEntity> _filteredCuti = [];
  String _searchQuery = '';
  String? _selectedStatus;
  String? _selectedTipeCuti;
  DateTime? _tanggalMulai;
  DateTime? _tanggalSelesai;
  String? _selectedSort = 'terbaru';

  @override
  Widget build(BuildContext context) {
    return BlocListener<CutiBloc, CutiState>(
      bloc: widget.cutiBloc,
      listenWhen: (previous, current) {
        // Always listen when DaftarCutiAnggotaLoaded state is emitted
        return current is DaftarCutiAnggotaLoaded;
      },
      listener: (context, state) {
        if (state is DaftarCutiAnggotaLoaded) {
          // Always update when new data arrives
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _allCuti = List.from(state.daftarCuti); // Create new list to force update
              });
              _applyFilters();
            }
          });
        }
      },
      child: BlocBuilder<CutiBloc, CutiState>(
        bloc: widget.cutiBloc,
        builder: (context, state) {
          if (state is CutiLoading) {
            return Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          if (state is CutiError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64.r,
                    color: Colors.red,
                  ),
                  16.verticalSpace,
                  Text(
                    'Terjadi Kesalahan',
                    style: TS.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  8.verticalSpace,
                  Text(
                    state.message,
                    style: TS.bodyMedium.copyWith(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  24.verticalSpace,
                  UIButton(
                    text: 'Coba Lagi',
                    onPressed: () {
                      widget.cutiBloc.add(const GetDaftarCutiAnggotaEvent());
                    },
                    size: UIButtonSize.medium,
                  ),
                ],
              ),
            );
          }

          if (state is DaftarCutiAnggotaLoaded) {
            return Column(
              children: [
                SearchFilterCutiWidget(
                  onFilterApplied: (
                    searchQuery,
                    status,
                    tipeCuti,
                    tanggalMulai,
                    tanggalSelesai,
                    sort,
                  ) {
                    setState(() {
                      if (searchQuery != null) _searchQuery = searchQuery;
                      _selectedStatus = status;
                      _selectedTipeCuti = tipeCuti;
                      _tanggalMulai = tanggalMulai;
                      _tanggalSelesai = tanggalSelesai;
                      if (sort != null) _selectedSort = sort;
                    });
                    // Apply API filters
                    // Untuk Pengawas, jika status null, default ke 'pending'
                    final parentState = context.findAncestorStateOfType<_CutiPageState>();
                    final currentUserRole = parentState?._currentUserRole ?? UserRole.anggota;
                    final statusFilter = (currentUserRole == UserRole.pengawas || currentUserRole == UserRole.admin) && _selectedStatus == null
                        ? 'pending'
                        : _selectedStatus;
                    
                    widget.cutiBloc.add(
                      GetDaftarCutiAnggotaEvent(
                        status: statusFilter,
                        tipeCuti: _selectedTipeCuti,
                        tanggalMulai: _tanggalMulai,
                        tanggalSelesai: _tanggalSelesai,
                      ),
                    );
                  },
                  onSearchChanged: (query) {
                    setState(() {
                      _searchQuery = query;
                    });
                    _applyFilters();
                  },
                ),
                Expanded(
                  child: _filteredCuti.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 64.r,
                                color: Colors.grey.shade400,
                              ),
                              16.verticalSpace,
                              Text(
                                _allCuti.isEmpty
                                    ? 'Belum ada ajuan cuti anggota'
                                    : 'Tidak ada hasil yang ditemukan',
                                style: TS.titleMedium.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : _buildCutiListFromState(_filteredCuti, widget.showActions),
                ),
              ],
            );
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy,
                  size: 64.r,
                  color: Colors.grey.shade400,
                ),
                16.verticalSpace,
                Text(
                  'Belum ada ajuan cuti anggota',
                  style: TS.titleMedium.copyWith(
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Helper function untuk mendapatkan urutan status
  /// Urutan: pending (0), approved (1), rejected (2), cancelled (3)
  int _getStatusOrder(CutiStatus status) {
    switch (status) {
      case CutiStatus.pending:
        return 0;
      case CutiStatus.approved:
        return 1;
      case CutiStatus.rejected:
        return 2;
      case CutiStatus.cancelled:
        return 3;
    }
  }

  void _applyFilters() {
    List<CutiEntity> filtered = List.from(_allCuti);

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((cuti) {
        final query = _searchQuery.toLowerCase();
        return cuti.id.toLowerCase().contains(query) ||
            cuti.nama.toLowerCase().contains(query) ||
            cuti.alasan.toLowerCase().contains(query) ||
            cuti.tipeCutiDisplayName.toLowerCase().contains(query);
      }).toList();
    }

    // Sort untuk PJO/Deputy: Status ASC (pending, approved, rejected) kemudian Tanggal DESC
    // Get current user role from parent
    final parentState = context.findAncestorStateOfType<_CutiPageState>();
    final currentUserRole = parentState?._currentUserRole ?? UserRole.anggota;
    
    if (currentUserRole == UserRole.pjo || currentUserRole == UserRole.deputy) {
      // Sort by status ASC, then by tanggal DESC
      filtered.sort((a, b) {
        final statusCompare = _getStatusOrder(a.status).compareTo(_getStatusOrder(b.status));
        if (statusCompare != 0) {
          return statusCompare; // Status ASC
        }
        // Jika status sama, sort by tanggal DESC (terbaru dulu)
        return b.tanggalPengajuan.compareTo(a.tanggalPengajuan);
      });
    } else {
      // Sort biasa untuk role lain
      if (_selectedSort == 'terbaru') {
        filtered.sort((a, b) => b.tanggalPengajuan.compareTo(a.tanggalPengajuan));
      } else if (_selectedSort == 'terlama') {
        filtered.sort((a, b) => a.tanggalPengajuan.compareTo(b.tanggalPengajuan));
      }
    }

    setState(() {
      _filteredCuti = filtered;
    });
  }

  Widget _buildCutiListFromState(List<CutiEntity> cutiList, bool showActions) {
    // Get current user role from parent
    final parentState = context.findAncestorStateOfType<_CutiPageState>();
    final currentUserRole = parentState?._currentUserRole ?? UserRole.anggota;
    
    // Note: Danton tidak memiliki tab Ajuan Anggota, jadi tidak bisa approve/reject
    final canShowActions = showActions && 
        (currentUserRole == UserRole.pjo || 
         currentUserRole == UserRole.deputy ||
         currentUserRole == UserRole.pengawas);
    
    return ListView.builder(
      padding: REdgeInsets.all(16),
      itemCount: cutiList.length,
      itemBuilder: (context, index) {
        final cuti = cutiList[index];
        final shouldShowActions = canShowActions && cuti.status == CutiStatus.pending;
        
        return Padding(
          padding: REdgeInsets.only(bottom: 12),
          child: CutiCard(
            cuti: cuti,
            showActions: false,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlocProvider.value(
                    value: widget.cutiBloc,
                    child: DetailCutiPage(
                      cutiId: cuti.id,
                      showActions: shouldShowActions,
                      currentUserRole: currentUserRole,
                    ),
                  ),
                ),
              );
              
              if (result == true) {
                // Reload dengan filter yang sama
                // Untuk Pengawas, tetap gunakan filter status pending
                final parentState = context.findAncestorStateOfType<_CutiPageState>();
                final currentUserRole = parentState?._currentUserRole ?? UserRole.anggota;
                if (currentUserRole == UserRole.pengawas || currentUserRole == UserRole.admin) {
                  widget.cutiBloc.add(const GetDaftarCutiAnggotaEvent(status: 'pending'));
                } else {
                  widget.cutiBloc.add(const GetDaftarCutiAnggotaEvent());
                }
              }
            },
          ),
        );
      },
    );
  }
}

// Widget untuk tab Rekap Ajuan Cuti dengan search dan filter
class _RekapAjuanCutiTabContent extends StatefulWidget {
  final CutiBloc cutiBloc;

  const _RekapAjuanCutiTabContent({
    required this.cutiBloc,
  });

  @override
  State<_RekapAjuanCutiTabContent> createState() => _RekapAjuanCutiTabContentState();
}

class _RekapAjuanCutiTabContentState extends State<_RekapAjuanCutiTabContent> {
  List<CutiEntity> _allCuti = [];
  List<CutiEntity> _filteredCuti = [];
  String _searchQuery = '';
  String? _selectedStatus;
  String? _selectedTipeCuti;
  DateTime? _tanggalMulai;
  DateTime? _tanggalSelesai;
  String? _selectedSort = 'terbaru';
  
  @override
  void initState() {
    super.initState();
    // Default filter untuk Rekap: hanya tampilkan approved dan rejected
    // Tidak set _selectedStatus karena kita akan filter di _applyFilters
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CutiBloc, CutiState>(
      bloc: widget.cutiBloc,
      listenWhen: (previous, current) {
        // Always listen when RekapCutiLoaded state is emitted
        return current is RekapCutiLoaded;
      },
      listener: (context, state) {
        if (state is RekapCutiLoaded) {
          // Always update when new data arrives
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _allCuti = List.from(state.rekapCuti); // Create new list to force update
              });
              _applyFilters();
            }
          });
        }
      },
      child: BlocBuilder<CutiBloc, CutiState>(
        bloc: widget.cutiBloc,
        builder: (context, state) {
          if (state is CutiLoading) {
            return Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          if (state is CutiError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64.r,
                    color: Colors.red,
                  ),
                  16.verticalSpace,
                  Text(
                    'Terjadi Kesalahan',
                    style: TS.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  8.verticalSpace,
                  Text(
                    state.message,
                    style: TS.bodyMedium.copyWith(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  24.verticalSpace,
                  UIButton(
                    text: 'Coba Lagi',
                    onPressed: () {
                      widget.cutiBloc.add(const GetRekapCutiEvent());
                    },
                    size: UIButtonSize.medium,
                  ),
                ],
              ),
            );
          }

          if (state is RekapCutiLoaded) {
            return Column(
              children: [
                SearchFilterCutiWidget(
                  onFilterApplied: (
                    searchQuery,
                    status,
                    tipeCuti,
                    tanggalMulai,
                    tanggalSelesai,
                    sort,
                  ) {
                    setState(() {
                      if (searchQuery != null) _searchQuery = searchQuery;
                      _selectedStatus = status;
                      _selectedTipeCuti = tipeCuti;
                      _tanggalMulai = tanggalMulai;
                      _tanggalSelesai = tanggalSelesai;
                      if (sort != null) _selectedSort = sort;
                    });
                    // Apply API filters
                    widget.cutiBloc.add(
                      GetRekapCutiEvent(
                        status: _selectedStatus,
                        tipeCuti: _selectedTipeCuti,
                        tanggalMulai: _tanggalMulai,
                        tanggalSelesai: _tanggalSelesai,
                      ),
                    );
                  },
                  onSearchChanged: (query) {
                    setState(() {
                      _searchQuery = query;
                    });
                    _applyFilters();
                  },
                ),
                Expanded(
                  child: _filteredCuti.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 64.r,
                                color: Colors.grey.shade400,
                              ),
                              16.verticalSpace,
                              Text(
                                _allCuti.isEmpty
                                    ? 'Belum ada data rekap cuti'
                                    : 'Tidak ada hasil yang ditemukan',
                                style: TS.titleMedium.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : _buildCutiListFromState(_filteredCuti, false),
                ),
              ],
            );
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy,
                  size: 64.r,
                  color: Colors.grey.shade400,
                ),
                16.verticalSpace,
                Text(
                  'Belum ada data rekap cuti',
                  style: TS.titleMedium.copyWith(
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _applyFilters() {
    List<CutiEntity> filtered = List.from(_allCuti);

    // Default filter untuk Rekap: hanya tampilkan approved dan rejected
    // Kecuali jika user memilih status filter lain
    if (_selectedStatus == null) {
      // Default: hanya approved dan rejected
      filtered = filtered.where((cuti) {
        return cuti.status == CutiStatus.approved || 
               cuti.status == CutiStatus.rejected;
      }).toList();
    } else {
      // Jika user memilih status filter, gunakan filter tersebut
      filtered = filtered.where((cuti) {
        switch (_selectedStatus) {
          case 'pending':
            return cuti.status == CutiStatus.pending;
          case 'approved':
            return cuti.status == CutiStatus.approved;
          case 'rejected':
            return cuti.status == CutiStatus.rejected;
          case 'cancelled':
            return cuti.status == CutiStatus.cancelled;
          default:
            return true;
        }
      }).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((cuti) {
        final query = _searchQuery.toLowerCase();
        return cuti.id.toLowerCase().contains(query) ||
            cuti.nama.toLowerCase().contains(query) ||
            cuti.alasan.toLowerCase().contains(query) ||
            cuti.tipeCutiDisplayName.toLowerCase().contains(query);
      }).toList();
    }

    // Tipe Cuti filter
    if (_selectedTipeCuti != null) {
      filtered = filtered.where((cuti) {
        switch (_selectedTipeCuti) {
          case 'tahunan':
            return cuti.tipeCuti == CutiType.tahunan;
          case 'sakit':
            return cuti.tipeCuti == CutiType.sakit;
          case 'melahirkan':
            return cuti.tipeCuti == CutiType.melahirkan;
          case 'menikah':
            return cuti.tipeCuti == CutiType.menikah;
          case 'keluargaMeninggal':
            return cuti.tipeCuti == CutiType.keluargaMeninggal;
          case 'lainnya':
            return cuti.tipeCuti == CutiType.lainnya;
          default:
            return true;
        }
      }).toList();
    }

    // Date range filter
    if (_tanggalMulai != null) {
      filtered = filtered.where((cuti) {
        return cuti.tanggalMulai.isAfter(_tanggalMulai!) ||
            cuti.tanggalMulai.isAtSameMomentAs(_tanggalMulai!);
      }).toList();
    }

    if (_tanggalSelesai != null) {
      filtered = filtered.where((cuti) {
        return cuti.tanggalSelesai.isBefore(_tanggalSelesai!) ||
            cuti.tanggalSelesai.isAtSameMomentAs(_tanggalSelesai!);
      }).toList();
    }

    // Sort
    if (_selectedSort == 'terbaru') {
      filtered.sort((a, b) => b.tanggalPengajuan.compareTo(a.tanggalPengajuan));
    } else if (_selectedSort == 'terlama') {
      filtered.sort((a, b) => a.tanggalPengajuan.compareTo(b.tanggalPengajuan));
    }

    setState(() {
      _filteredCuti = filtered;
    });
  }

  Widget _buildCutiListFromState(List<CutiEntity> cutiList, bool showActions) {
    // Get current user role from parent
    final parentState = context.findAncestorStateOfType<_CutiPageState>();
    final currentUserRole = parentState?._currentUserRole ?? UserRole.anggota;
    
    return ListView.builder(
      padding: REdgeInsets.all(16),
      itemCount: cutiList.length,
      itemBuilder: (context, index) {
        final cuti = cutiList[index];
        
        return Padding(
          padding: REdgeInsets.only(bottom: 12),
          child: CutiCard(
            cuti: cuti,
            showActions: false,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlocProvider.value(
                    value: widget.cutiBloc,
                    child: DetailCutiPage(
                      cutiId: cuti.id,
                      showActions: false, // Rekap tidak bisa approve/reject
                      currentUserRole: currentUserRole,
                    ),
                  ),
                ),
              );
              
              if (result == true) {
                widget.cutiBloc.add(const GetRekapCutiEvent());
              }
            },
          ),
        );
      },
    );
  }
}

// Widget untuk tab Ajuan Cuti anggota dengan search dan filter
class _AjuanCutiAnggotaTabContent extends StatefulWidget {
  final CutiBloc cutiBloc;
  final String userId;

  const _AjuanCutiAnggotaTabContent({
    required this.cutiBloc,
    required this.userId,
  });

  @override
  State<_AjuanCutiAnggotaTabContent> createState() => _AjuanCutiAnggotaTabContentState();
}

class _AjuanCutiAnggotaTabContentState extends State<_AjuanCutiAnggotaTabContent> {
  List<CutiEntity> _allCuti = [];
  List<CutiEntity> _filteredCuti = [];
  String _searchQuery = '';
  String? _selectedStatus;
  String? _selectedTipeCuti;
  DateTime? _tanggalMulai;
  DateTime? _tanggalSelesai;
  String? _selectedSort = 'terbaru';

  @override
  Widget build(BuildContext context) {
    return BlocListener<CutiBloc, CutiState>(
      bloc: widget.cutiBloc,
      listenWhen: (previous, current) {
        // Always listen when DaftarCutiSayaLoaded state is emitted
        return current is DaftarCutiSayaLoaded;
      },
      listener: (context, state) {
        if (state is DaftarCutiSayaLoaded) {
          // Always update when new data arrives
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _allCuti = List.from(state.daftarCuti); // Create new list to force update
              });
              _applyFilters();
            }
          });
        }
      },
      child: BlocBuilder<CutiBloc, CutiState>(
        bloc: widget.cutiBloc,
        builder: (context, state) {
          if (state is CutiLoading) {
            return Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          if (state is CutiError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64.r,
                    color: Colors.red,
                  ),
                  16.verticalSpace,
                  Text(
                    'Terjadi Kesalahan',
                    style: TS.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  8.verticalSpace,
                  Text(
                    state.message,
                    style: TS.bodyMedium.copyWith(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  24.verticalSpace,
                  UIButton(
                    text: 'Coba Lagi',
                    onPressed: () {
                      widget.cutiBloc.add(GetDaftarCutiSayaEvent(widget.userId));
                    },
                    size: UIButtonSize.medium,
                  ),
                ],
              ),
            );
          }

          if (state is DaftarCutiSayaLoaded) {
            return Column(
              children: [
                SearchFilterCutiWidget(
                  onFilterApplied: (
                    searchQuery,
                    status,
                    tipeCuti,
                    tanggalMulai,
                    tanggalSelesai,
                    sort,
                  ) {
                    setState(() {
                      if (searchQuery != null) _searchQuery = searchQuery;
                      _selectedStatus = status;
                      _selectedTipeCuti = tipeCuti;
                      _tanggalMulai = tanggalMulai;
                      _tanggalSelesai = tanggalSelesai;
                      if (sort != null) _selectedSort = sort;
                    });
                    _applyFilters();
                  },
                  onSearchChanged: (query) {
                    setState(() {
                      _searchQuery = query;
                    });
                    _applyFilters();
                  },
                ),
                Expanded(
                  child: _filteredCuti.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 64.r,
                                color: Colors.grey.shade400,
                              ),
                              16.verticalSpace,
                              Text(
                                _allCuti.isEmpty
                                    ? 'Belum ada ajuan cuti'
                                    : 'Tidak ada hasil yang ditemukan',
                                style: TS.titleMedium.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : _buildCutiListFromState(_filteredCuti, false),
                ),
              ],
            );
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy,
                  size: 64.r,
                  color: Colors.grey.shade400,
                ),
                16.verticalSpace,
                Text(
                  'Belum ada ajuan cuti',
                  style: TS.titleMedium.copyWith(
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _applyFilters() {
    List<CutiEntity> filtered = List.from(_allCuti);

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((cuti) {
        final query = _searchQuery.toLowerCase();
        return cuti.id.toLowerCase().contains(query) ||
            cuti.nama.toLowerCase().contains(query) ||
            cuti.alasan.toLowerCase().contains(query) ||
            cuti.tipeCutiDisplayName.toLowerCase().contains(query);
      }).toList();
    }

    // Status filter
    if (_selectedStatus != null) {
      filtered = filtered.where((cuti) {
        switch (_selectedStatus) {
          case 'pending':
            return cuti.status == CutiStatus.pending;
          case 'approved':
            return cuti.status == CutiStatus.approved;
          case 'rejected':
            return cuti.status == CutiStatus.rejected;
          case 'cancelled':
            return cuti.status == CutiStatus.cancelled;
          default:
            return true;
        }
      }).toList();
    }

    // Tipe Cuti filter
    if (_selectedTipeCuti != null) {
      filtered = filtered.where((cuti) {
        switch (_selectedTipeCuti) {
          case 'tahunan':
            return cuti.tipeCuti == CutiType.tahunan;
          case 'sakit':
            return cuti.tipeCuti == CutiType.sakit;
          case 'melahirkan':
            return cuti.tipeCuti == CutiType.melahirkan;
          case 'menikah':
            return cuti.tipeCuti == CutiType.menikah;
          case 'keluargaMeninggal':
            return cuti.tipeCuti == CutiType.keluargaMeninggal;
          case 'lainnya':
            return cuti.tipeCuti == CutiType.lainnya;
          default:
            return true;
        }
      }).toList();
    }

    // Date range filter
    if (_tanggalMulai != null) {
      filtered = filtered.where((cuti) {
        return cuti.tanggalMulai.isAfter(_tanggalMulai!) ||
            cuti.tanggalMulai.isAtSameMomentAs(_tanggalMulai!);
      }).toList();
    }

    if (_tanggalSelesai != null) {
      filtered = filtered.where((cuti) {
        return cuti.tanggalSelesai.isBefore(_tanggalSelesai!) ||
            cuti.tanggalSelesai.isAtSameMomentAs(_tanggalSelesai!);
      }).toList();
    }

    // Sort
    if (_selectedSort == 'terbaru') {
      filtered.sort((a, b) => b.tanggalPengajuan.compareTo(a.tanggalPengajuan));
    } else if (_selectedSort == 'terlama') {
      filtered.sort((a, b) => a.tanggalPengajuan.compareTo(b.tanggalPengajuan));
    }

    setState(() {
      _filteredCuti = filtered;
    });
  }

  Widget _buildCutiListFromState(List<CutiEntity> cutiList, bool showActions) {
    // Get current user role from parent
    final parentState = context.findAncestorStateOfType<_CutiPageState>();
    final currentUserRole = parentState?._currentUserRole ?? UserRole.anggota;
    
    return ListView.builder(
      padding: REdgeInsets.all(16),
      itemCount: cutiList.length,
      itemBuilder: (context, index) {
        final cuti = cutiList[index];
        
        return Padding(
          padding: REdgeInsets.only(bottom: 12),
          child: CutiCard(
            cuti: cuti,
            showActions: false,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlocProvider.value(
                    value: widget.cutiBloc,
                    child: DetailCutiPage(
                      cutiId: cuti.id,
                      showActions: false,
                      currentUserRole: currentUserRole,
                    ),
                  ),
                ),
              );
              
              // Reload data if cuti was edited or deleted
              if (result == true) {
                widget.cutiBloc.add(GetDaftarCutiSayaEvent(widget.userId));
              }
            },
          ),
        );
      },
    );
  }
}
