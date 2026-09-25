import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/di/injection.dart';
import '../bloc/personnel_bloc.dart';
import '../bloc/personnel_event.dart';
import '../bloc/personnel_state.dart';
import 'personnel_detail_page.dart';

class PersonnelListPage extends StatelessWidget {
  const PersonnelListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<PersonnelBloc>()
        ..add(const LoadPersonnelByStatusEvent('Pending', pageSize: 50)),
      child: const _PersonnelListView(),
    );
  }
}

class _PersonnelListView extends StatefulWidget {
  const _PersonnelListView();

  @override
  State<_PersonnelListView> createState() => _PersonnelListViewState();
}

/// Mapping display label ke status API
const Map<String, String> _displayToApiStatus = {
  'Aktif': 'Active',
  'Pending': 'Pending',
  'Non Aktif': 'InActive', // API expects 'InActive'
};

class _PersonnelListViewState extends State<_PersonnelListView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final List<ScrollController> _scrollControllers = [
    ScrollController(),
    ScrollController(),
    ScrollController(),
  ];
  String _currentTab = 'Pending'; // Default tab

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1); // Start at Pending
    _tabController.addListener(_onTabChanged);
    for (final c in _scrollControllers) {
      c.addListener(_onScroll);
    }
  }

  void _onScroll() {
    if (!mounted) return;
    final idx = _tabController.index;
    if (idx < 0 || idx >= _scrollControllers.length) return;
    final c = _scrollControllers[idx];
    if (!c.hasClients) return;
    final maxScroll = c.position.maxScrollExtent;
    if (maxScroll <= 0) return;
    final currentScroll = c.offset;
    if (currentScroll >= (maxScroll * 0.9)) {
      context.read<PersonnelBloc>().add(LoadMorePersonnelEvent(_currentTab));
    }
  }

  String _getApiStatusForDisplay(String displayStatus) =>
      _displayToApiStatus[displayStatus] ?? displayStatus;

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;

    const tabApiStatus = ['Active', 'Pending', 'InActive'];
    final idx = _tabController.index;
    if (idx < 0 || idx >= tabApiStatus.length) return;

    final newTab = tabApiStatus[idx];
    setState(() => _currentTab = newTab);
    _searchController.clear();

    // Hanya hit API jika tab belum punya cache
    final state = context.read<PersonnelBloc>().state;
    if (state is PersonnelListLoaded && state.getTabData(newTab) == null) {
      context.read<PersonnelBloc>().add(LoadPersonnelByStatusEvent(newTab, pageSize: 50));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    for (final c in _scrollControllers) {
      c.dispose();
    }
    super.dispose();
  }
// TODO
// LOGIN SEBAGAI PENGAWAS DAFTAR PERSONIL YANG STATUSNYA PENDING TRUS LIHAT DETAIL 
// Revisi g bisa ,menyetujui tidak bisa 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: neutral10,
        appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: neutral90),
              onPressed: () => Navigator.pop(context),
            ),
          title: Text(
            'Daftar Personil',
            style: TextStyle(
              color: neutral90,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(48.h),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: neutral30,
                    width: 1,
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: primaryColor,
                unselectedLabelColor: neutral50,
                labelStyle: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
                indicatorColor: primaryColor,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'Aktif'),
                  Tab(text: 'Pending'),
                  Tab(text: 'Non Aktif'),
                ],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // Search and Filter
            Container(
              color: Colors.white,
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48.h,
                      decoration: BoxDecoration(
                        color: neutral10,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: neutral30),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (query) {
                          context.read<PersonnelBloc>().add(
                                SearchPersonnelEvent(query, _currentTab),
                              );
                        },
                        decoration: InputDecoration(
                          hintText: 'Cari',
                          hintStyle: TextStyle(
                            color: neutral50,
                            fontSize: 14.sp,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: neutral50,
                            size: 20.sp,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                        ),
                      ),
                    ),
                  ),
                  12.horizontalSpace,
                  // Filter button
                  Container(
                    width: 48.w,
                    height: 48.h,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.filter_list,
                        color: Colors.white,
                        size: 20.sp,
                      ),
                      onPressed: () {
                        // TODO: Implement filter
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Filter sedang dalam pengembangan'),
                            backgroundColor: primaryColor,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Personnel List
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPersonnelList('Aktif'),
                  _buildPersonnelList('Pending'),
                  _buildPersonnelList('Non Aktif'),
                ],
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildPersonnelList(String displayStatus) {
    final apiStatus = _getApiStatusForDisplay(displayStatus);
    final tabIndex = displayStatus == 'Aktif'
        ? 0
        : displayStatus == 'Pending'
            ? 1
            : 2;
    final scrollController = _scrollControllers[tabIndex];

    return BlocBuilder<PersonnelBloc, PersonnelState>(
      builder: (context, state) {
        if (state is PersonnelLoading) {
          return Center(
            child: CircularProgressIndicator(color: primaryColor),
          );
        }

        if (state is PersonnelError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64.sp, color: neutral50),
                  16.verticalSpace,
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.sp, color: neutral70),
                  ),
                  24.verticalSpace,
                  ElevatedButton(
                    onPressed: () {
                      context.read<PersonnelBloc>().add(
                            LoadPersonnelByStatusEvent(apiStatus, pageSize: 50),
                          );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is PersonnelListLoaded) {
          if (state.isLoadingForTab == apiStatus) {
            return Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          final tab = state.getTabData(apiStatus);
          if (tab == null) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 64.sp, color: neutral50),
                    16.verticalSpace,
                    Text(
                      'Geser ke tab ini untuk memuat data',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14.sp, color: neutral70),
                    ),
                    if (apiStatus == _currentTab) ...[
                      16.verticalSpace,
                      TextButton(
                        onPressed: () {
                          context.read<PersonnelBloc>().add(
                                LoadPersonnelByStatusEvent(apiStatus, pageSize: 50),
                              );
                        },
                        child: const Text('Muat data'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          final displayList = state.getDisplayList(apiStatus);
          if (displayList.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 64.sp, color: neutral50),
                    16.verticalSpace,
                    Text(
                      state.isSearching
                          ? 'Tidak ada hasil untuk "${state.searchQuery}"'
                          : 'Belum ada personil dengan status $displayStatus',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14.sp, color: neutral70),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            controller: scrollController,
            padding: EdgeInsets.all(16.w),
            itemCount: displayList.length + (tab.hasReachedMax ? 0 : 1),
            itemBuilder: (context, index) {
              if (index >= displayList.length) {
                return Container(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  alignment: Alignment.center,
                  child: tab.isLoadingMore
                      ? CircularProgressIndicator(color: primaryColor)
                      : const SizedBox.shrink(),
                );
              }
              final personnel = displayList[index];
              return _buildPersonnelCard(personnel);
            },
          );
        }

        return const SizedBox();
      },
    );
  }

  Widget _buildPersonnelCard(personnel) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: babyBlueColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 30.r,
              backgroundColor: neutral30,
              backgroundImage: personnel.photoUrl != null && personnel.photoUrl!.isNotEmpty
                  ? NetworkImage(personnel.photoUrl!)
                  : null,
              child: personnel.photoUrl == null || personnel.photoUrl!.isEmpty
                  ? Icon(
                      Icons.person,
                      size: 30.sp,
                      color: neutral50,
                    )
                  : null,
            ),
            16.horizontalSpace,
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    personnel.name,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: neutral90,
                    ),
                  ),
                  4.verticalSpace,
                  Text(
                    personnel.role,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            // Lihat Detail button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BlocProvider(
                      create: (context) => getIt<PersonnelBloc>()
                        ..add(LoadPersonnelDetailEvent(personnel.id)),
                      child: PersonnelDetailPage(personnelId: personnel.id),
                    ),
                  ),
                ).then((_) {
                  // Refresh list after returning from detail page
                  context.read<PersonnelBloc>().add(
                        LoadPersonnelByStatusEvent(_currentTab, pageSize: 50),
                      );
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text(
                'Lihat Detail',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
