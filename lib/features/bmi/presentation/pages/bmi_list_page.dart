import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/security/security_manager.dart';
import '../../../../shared/widgets/Buttons/ui_button.dart';
import '../../domain/entities/user_profile.dart';
import '../bloc/bmi_bloc.dart';
import 'bmi_detail_page.dart';
import '../../../../shared/widgets/rumara_app_bar.dart';

/// Page untuk role non-anggota - menampilkan daftar BMI semua user dengan fitur search dan pin
class BMIListPage extends StatefulWidget {
  final UserRole currentUserRole;

  const BMIListPage({
    Key? key,
    required this.currentUserRole,
  }) : super(key: key);

  @override
  State<BMIListPage> createState() => _BMIListPageState();
}

class _BMIListPageState extends State<BMIListPage> {
  final _searchController = TextEditingController();
  BMIBloc? _bmiBloc;
  bool _hasInitialLoad = false; // Flag untuk mencegah multiple initial loads
  Timer? _searchDebounce; // Debounce timer untuk search
  final ScrollController _scrollController = ScrollController();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadCurrentUserId();
    // Delay load data untuk memastikan widget sudah fully mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final userId = await SecurityManager.readSecurely(AppConstants.userIdKey);
      if (!mounted) return;
      setState(() {
        _currentUserId = userId;
      });

      if (userId != null && userId.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          bmiBloc.add(BMIGetUserProfile(userId));
        });
      }
    } catch (_) {
      // ignore
    }
  }

  List<UserProfile> _prioritizeCurrentUser(List<UserProfile> users) {
    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) return users;

    final currentIndex = users.indexWhere((u) => u.id == currentUserId);
    if (currentIndex <= 0) return users;

    final reordered = List<UserProfile>.from(users);
    final me = reordered.removeAt(currentIndex);
    reordered.insert(0, me);
    return reordered;
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ambil bloc dari context sekali
    if (_bmiBloc == null) {
      _bmiBloc = context.read<BMIBloc>();
      print('🔄 BMIListPage: Bloc obtained from context');
    }
    // Jangan load data di sini - hanya di initState sekali
  }
  
  BMIBloc get bmiBloc {
    _bmiBloc ??= context.read<BMIBloc>();
    return _bmiBloc!;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;

    final state = bmiBloc.state;
    if (state.isLoadingMore || !state.hasMoreData) return;

    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;

    // Trigger before reaching the end
    const triggerOffset = 200.0;
    if (position.pixels >= (position.maxScrollExtent - triggerOffset)) {
      bmiBloc.add(BMILoadMoreUsers());
    }
  }

  void _loadData() {
    // Hanya load data sekali saat pertama kali buka halaman
    // JANGAN PERNAH reload otomatis
    if (_hasInitialLoad) {
      print('⏭️ BMI List: Skip _loadData - _hasInitialLoad=$_hasInitialLoad (ALREADY LOADED)');
      return; // Skip jika sudah pernah load - TIDAK ADA RELOAD
    }
    
    // Set flag SEBELUM apapun untuk mencegah multiple calls
    _hasInitialLoad = true;
    
    print('🔄 BMI List: _loadData called - checking state...');
    
    // Gunakan Future.microtask untuk memastikan state sudah stabil
    Future.microtask(() {
      if (!mounted) {
        print('⏭️ BMI List: Skip - widget not mounted');
        return;
      }
      
      final state = bmiBloc.state;
      print('📊 BMI List: Current state - isLoading=${state.isLoading}, isSearching=${state.isSearching}, hasLoadedEmpty=${state.hasLoadedEmpty}, hasInitialLoadAttempted=${state.hasInitialLoadAttempted}, searchResults.length=${state.searchResults.length}');
      
      // PRIORITAS 1: Jika sudah pernah attempt load, JANGAN HIT API LAGI (PENTING!)
      if (state.hasInitialLoadAttempted) {
        if (state.hasLoadedEmpty) {
          print('⏭️ BMI List: Skip API call - hasInitialLoadAttempted=true, hasLoadedEmpty=true (data already loaded and empty)');
        } else if (state.searchResults.isNotEmpty) {
          print('⏭️ BMI List: Skip API call - hasInitialLoadAttempted=true, already has data (${state.searchResults.length} items)');
        } else {
          print('⏭️ BMI List: Skip API call - hasInitialLoadAttempted=true (already attempted, no need to retry)');
        }
        return;
      }
      
      // PRIORITAS 2: Jika sudah ada data, skip API call
      if (state.searchResults.isNotEmpty) {
        print('⏭️ BMI List: Skip API call - searchResults is not empty (${state.searchResults.length} items)');
        return;
      }
      
      // PRIORITAS 3: Jika sedang loading atau searching, tunggu sampai selesai
      if (state.isLoading || state.isSearching) {
        print('⏭️ BMI List: Skip API call - already loading or searching');
        return;
      }
      
      // Hanya load jika belum pernah attempt load
      print('🔄 BMI List: Loading all users... (first time, hasInitialLoadAttempted=${state.hasInitialLoadAttempted})');
      bmiBloc.add(BMILoadAllUsers());
      
      // Load pinned users hanya jika belum ada dan tidak sedang loading
      // Dan tidak sedang dalam state empty
      if (state.pinnedUsers.isEmpty && 
          !state.isLoading && 
          !state.isSearching &&
          !state.hasLoadedEmpty) {
        print('🔄 BMI List: Loading pinned users...');
        bmiBloc.add(BMILoadPinnedUsers());
      }
    });
  }

  void _performSearch(String query) {
    // Cancel previous debounce timer
    _searchDebounce?.cancel();
    
    // If query is empty, jangan hit API - biarkan data yang sudah ada tetap ditampilkan
    if (query.trim().isEmpty) {
      // Jangan hit API jika query kosong, biarkan data yang sudah ada
      // Hanya clear search results jika user memang clear search
      return;
    }
    
    // Debounce search to avoid too many API calls
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        bmiBloc.add(BMISearchUsers(query));
      }
    });
  }

  void _navigateToDetail(dynamic userProfile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: bmiBloc,
          child: BMIDetailPage(
            userProfile: userProfile,
            currentUserRole: widget.currentUserRole,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: white,
      appBar: const RumaraAppBar(title: 'Body Mass Index'),
      body: BlocBuilder<BMIBloc, BMIState>(
        buildWhen: (previous, current) {
          // Hanya rebuild jika state yang relevan berubah
          // Jangan rebuild jika hanya isLoading yang berubah dari false ke false (tidak ada perubahan)
          if (previous.isLoading == current.isLoading &&
              previous.isSearching == current.isSearching &&
              previous.currentUserProfile?.id == current.currentUserProfile?.id &&
              previous.searchResults.length == current.searchResults.length &&
              previous.pinnedUsers.length == current.pinnedUsers.length &&
              previous.hasError == current.hasError &&
              previous.error == current.error &&
              previous.hasLoadedEmpty == current.hasLoadedEmpty &&
              previous.hasInitialLoadAttempted == current.hasInitialLoadAttempted) {
            return false; // Tidak ada perubahan yang relevan
          }
          return true;
        },
        builder: (context, state) {
          return Column(
            children: [
              // Search Section
              _buildSearchSection(),

              16.verticalSpace,

              // Content
              Expanded(
                child: _buildContent(state),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: REdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 52.h,
              decoration: BoxDecoration(
                color: white,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {});
                  _performSearch(value);
                },
                style: TS.bodyMedium.copyWith(
                  color: neutral90,
                  fontSize: 14.sp,
                ),
                decoration: InputDecoration(
                  hintText: 'Cari',
                  hintStyle: TS.bodyMedium.copyWith(
                    color: primaryColor.withValues(alpha: 0.6),
                    fontSize: 14.sp,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: primaryColor,
                    size: 22.w,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                            // Saat clear search, kembalikan ke list semua anggota
                            bmiBloc.add(BMIReset());
                            bmiBloc.add(BMILoadAllUsers());
                            bmiBloc.add(BMILoadPinnedUsers());
                          },
                          icon: Icon(
                            Icons.clear,
                            color: neutral50,
                            size: 20.w,
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: REdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),
          12.horizontalSpace,
          Container(
            width: 52.w,
            height: 52.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor,
                  const Color(0xFFD32F2F),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14.r),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showFilterDialog,
                borderRadius: BorderRadius.circular(14.r),
                child: Center(
                  child: Icon(
                    Icons.filter_list,
                    color: white,
                    size: 24.w,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BMIState state) {
    // Show loading if:
    // 1. Not yet attempted initial load (prevent flash of wrong empty state)
    // 2. Currently loading/searching AND no data yet
    if (!state.hasInitialLoadAttempted ||
        ((state.isLoading || state.isSearching) &&
        state.searchResults.isEmpty &&
        !state.hasError)) {
      return const _BMIListSkeleton();
    }

    // Show error state only if we have error, no data, and not loading
    if (state.hasError && state.searchResults.isEmpty && !state.isLoading && !state.isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64.w,
              color: neutral50,
            ),
            16.verticalSpace,
            Text(
              state.error!,
              style: TS.bodyLarge.copyWith(color: neutral70),
              textAlign: TextAlign.center,
            ),
            24.verticalSpace,
            UIButton(
              text: 'Coba Lagi',
              onPressed: () {
                // Reset flag untuk allow retry
                _hasInitialLoad = false;
                // Clear error dan retry load
                bmiBloc.add(BMIClearError());
                // Force reload dengan reset hasInitialLoadAttempted
                final currentState = bmiBloc.state;
                if (currentState.hasInitialLoadAttempted) {
                  // Reset state untuk allow retry
                  bmiBloc.add(BMIReset());
                }
                bmiBloc.add(BMILoadAllUsers());
              },
            ),
          ],
        ),
      );
    }

    final combinedList = (() {
      final list = List<UserProfile>.from(state.combinedUserList);

      // Jika API list tidak menyertakan user yang sedang login (misal PJO/Danton),
      // tetap tampilkan "me" di urutan paling atas untuk normal list.
      final currentUserId = _currentUserId;
      final me = state.currentUserProfile;
      final isNormalList = _searchController.text.trim().isEmpty;
      if (isNormalList && currentUserId != null && currentUserId.isNotEmpty) {
        // If we already have the real profile, ensure it's the one shown at the top
        // (replace any placeholder/older entry with the same id).
        if (me != null && me.id == currentUserId) {
          list.removeWhere((u) => u.id == currentUserId);
          list.insert(0, me);
        } else {
          // Otherwise show a placeholder card so "me" is always first.
          final hasMe = list.any((u) => u.id == currentUserId);
          if (!hasMe) {
            list.insert(
              0,
              UserProfile(
                id: currentUserId,
                name: 'Saya',
                role: widget.currentUserRole,
              ),
            );
          }
        }
      }

      final filtered = list.where((u) => u.role != UserRole.pengawas).toList();
      return isNormalList ? _prioritizeCurrentUser(filtered) : filtered;
    })();

    // Show empty state if not loading and not searching
    // Differentiate between search empty and initial empty
    if (combinedList.isEmpty && !state.isLoading && !state.isSearching) {
      // If search query is empty and hasLoadedEmpty, show initial empty state
      if (_searchController.text.trim().isEmpty && state.hasLoadedEmpty) {
        return _buildEmptyState();
      }
      
      // Otherwise show search empty state
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 64.w,
              color: neutral50,
            ),
            16.verticalSpace,
            Text(
              'Tidak ada hasil ditemukan',
              style: TS.bodyLarge.copyWith(color: neutral70),
            ),
            8.verticalSpace,
            Text(
              'Coba gunakan kata kunci lain',
              style: TS.bodyMedium.copyWith(color: neutral50),
            ),
          ],
        ),
      );
    }

    // Tidak ada RefreshIndicator - data hanya di-load sekali saat pertama kali buka
    return GridView.builder(
        key: const PageStorageKey('bmi_list_grid'),
        controller: _scrollController,
        padding: REdgeInsets.symmetric(horizontal: 16, vertical: 8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 12.h,
          childAspectRatio: 0.62,
        ),
        itemCount: combinedList.length + (state.isLoadingMore ? 2 : 0),
        itemBuilder: (context, index) {
          if (index >= combinedList.length) {
            return _buildLoadingCard();
          }
          final userProfile = combinedList[index];
          // Use key to ensure unique widgets and proper rebuild
          return _buildUserProfileCard(
            userProfile, 
            key: ValueKey('user_${userProfile.id}_$index'),
          );
        },
      );
  }

  Widget _buildLoadingCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            white,
            const Color(0xFFFFF9F9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: CircularProgressIndicator(
          color: primaryColor,
          strokeWidth: 2.5,
        ),
      ),
    );
  }

  Widget _buildUserProfileCard(dynamic userProfile, {Key? key}) {
    final hasData = userProfile.currentBMI != null;
    final bmiStatus = userProfile.currentBMIStatus;

    return Container(
      key: key,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToDetail(userProfile),
          borderRadius: BorderRadius.circular(18.r),
          child: Container(
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: hasData
                  ? LinearGradient(
                      colors: [
                        white,
                        const Color(0xFFFFF9F9),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: hasData ? null : white,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: hasData
                    ? primaryColor.withValues(alpha: 0.1)
                    : neutral20,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: hasData
                      ? primaryColor.withValues(alpha: 0.1)
                      : neutral50.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: neutral50.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
            ),
        child: Stack(
          children: [
            Padding(
              padding: REdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile Photo
                  Center(
                    child: Container(
                    width: 75.w,
                    height: 75.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: neutral20,
                      border: Border.all(
                        color: hasData
                            ? primaryColor.withValues(alpha: 0.2)
                            : neutral30,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: hasData
                              ? primaryColor.withValues(alpha: 0.15)
                              : neutral50.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: userProfile.profileImageUrl != null
                        ? ClipOval(
                            child: Image.network(
                              userProfile.profileImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.person,
                                  size: 35.w,
                                  color: neutral50,
                                );
                              },
                            ),
                          )
                        : Icon(
                            Icons.person,
                            size: 35.w,
                            color: neutral50,
                          ),
                    ),
                  ),

                  6.verticalSpace,

                  // Name
                  Center(
                    child: Text(
                      userProfile.name,
                      style: TS.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: neutral90,
                        fontSize: 15.sp,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  if (hasData) ...[
                    8.verticalSpace,

                    // BMI Value with Status Badge
                    Center(
                      child: Container(
                      padding: REdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withValues(alpha: 0.1),
                            primaryColor.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${userProfile.currentBMI!.toStringAsFixed(1).replaceAll('.', ',')} Kg/m2',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              fontSize: 16.sp,
                            ),
                          ),
                          if (userProfile.bmiCategory != null) ...[
                            4.verticalSpace,
                            Text(
                              userProfile.bmiCategory!,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2C5F7C),
                                fontSize: 11.sp,
                              ),
                            ),
                          ],
                        ],
                      ),
                      ),
                    ),

                    8.verticalSpace,

                    // Weight and Height Info
                    Center(
                      child: Container(
                        width: double.infinity,
                        padding:
                            REdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFFF5F5),
                              const Color(0xFFFFF9F9),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Berat',
                                  style: TextStyle(
                                    color: const Color(0xFF2C5F7C),
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                2.verticalSpace,
                                Text(
                                  '${userProfile.currentWeight!.toStringAsFixed(1).replaceAll('.', ',')} KG',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                    fontSize: 11.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1.5,
                            height: 24.h,
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Tinggi',
                                  style: TextStyle(
                                    color: const Color(0xFF2C5F7C),
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                2.verticalSpace,
                                Text(
                                  '${userProfile.height!.toStringAsFixed(1).replaceAll('.', ',')} CM',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                    fontSize: 11.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      ),
                    ),
                  ] else ...[
                    8.verticalSpace,
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.scale_outlined,
                            size: 24.w,
                            color: neutral50,
                          ),
                          4.verticalSpace,
                          Text(
                            'Belum ada data',
                            style: TS.bodySmall.copyWith(
                              color: neutral50,
                              fontSize: 11.sp,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Pin icon at top left (not shown for pengawas)
            if (userProfile.isPinned && userProfile.role != UserRole.pengawas)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: REdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor,
                        const Color(0xFFD32F2F),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.push_pin,
                    size: 16.w,
                    color: white,
                  ),
                ),
              ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: REdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Triple ring illustration
              SizedBox(
                width: 200.w,
                height: 200.w,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 200.w,
                      height: 200.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withValues(alpha: 0.04),
                      ),
                    ),
                    Container(
                      width: 158.w,
                      height: 158.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withValues(alpha: 0.07),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.1),
                          width: 1.5,
                        ),
                      ),
                    ),
                    Container(
                      width: 118.w,
                      height: 118.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFF0F0), Color(0xFFFFF8F8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.18),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.12),
                            blurRadius: 24,
                            spreadRadius: 4,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.people_outline,
                        size: 56.w,
                        color: primaryColor.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),

              28.verticalSpace,

              Text(
                'Belum Ada Data BMI',
                style: TS.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: neutral90,
                  fontSize: 22.sp,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),

              10.verticalSpace,

              Text(
                'Data akan tampil setelah pengguna\nmelakukan pengukuran Body Mass Index',
                style: TS.bodyMedium.copyWith(
                  color: neutral50,
                  height: 1.6,
                  fontSize: 13.sp,
                ),
                textAlign: TextAlign.center,
              ),

              28.verticalSpace,

              // BMI Category chips
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                alignment: WrapAlignment.center,
                children: [
                  _buildBMICategoryChip('Underweight', const Color(0xFF42A5F5)),
                  _buildBMICategoryChip('Normal', const Color(0xFF66BB6A)),
                  _buildBMICategoryChip('Overweight', const Color(0xFFFFA726)),
                  _buildBMICategoryChip('Obesity I', const Color(0xFFFF7043)),
                  _buildBMICategoryChip('Obesity II', const Color(0xFFF4511E)),
                  _buildBMICategoryChip('Obesity III', const Color(0xFFEF5350)),
                ],
              ),

              28.verticalSpace,

              // Info card
              Container(
                width: double.infinity,
                padding: REdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: neutral20, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: neutral50.withOpacity(0.07),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46.w,
                      height: 46.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C5F7C).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        Icons.health_and_safety_outlined,
                        color: const Color(0xFF2C5F7C),
                        size: 24.w,
                      ),
                    ),
                    16.horizontalSpace,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Apa itu BMI?',
                            style: TS.titleSmall.copyWith(
                              color: neutral90,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.sp,
                            ),
                          ),
                          6.verticalSpace,
                          Text(
                            'Indeks Massa Tubuh dihitung dari berat dan tinggi badan untuk menilai status gizi seseorang.',
                            style: TS.bodySmall.copyWith(
                              color: neutral50,
                              height: 1.55,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBMICategoryChip(String label, Color color) {
    return Container(
      padding: REdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7.w,
            height: 7.w,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          6.horizontalSpace,
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.85),
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    const categories = [
      'Underweight',
      'Normal',
      'Overweight',
      'Obesity I',
      'Obesity II',
      'Obesity III',
    ];

    const jabatans = [
      'Anggota',
      'Pengawas',
      'Admin',
      'Deputy',
      'PJO',
      'Danton',
    ];

    String? selectedCategory;
    String? selectedJabatan;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Filter BMI',
            style: TS.titleLarge.copyWith(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kategori BMI',
                style: TS.bodyMedium.copyWith(color: neutral70),
              ),
              8.verticalSpace,
              DropdownButtonFormField<String>(
                value: selectedCategory,
                hint: const Text('Semua Kategori'),
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  contentPadding: REdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: categories.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (value) {
                  setDialogState(() => selectedCategory = value);
                },
              ),
              16.verticalSpace,
              Text(
                'Jabatan',
                style: TS.bodyMedium.copyWith(color: neutral70),
              ),
              8.verticalSpace,
              DropdownButtonFormField<String>(
                value: selectedJabatan,
                hint: const Text('Semua Jabatan'),
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  contentPadding: REdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: jabatans.map((jab) {
                  return DropdownMenuItem(value: jab, child: Text(jab));
                }).toList(),
                onChanged: (value) {
                  setDialogState(() => selectedJabatan = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                bmiBloc.add(BMILoadAllUsers());
              },
              child: const Text('Reset'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              onPressed: selectedCategory == null && selectedJabatan == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      if (selectedCategory != null) {
                        bmiBloc.add(BMIFilterByCategory(selectedCategory!));
                      }
                      if (selectedJabatan != null) {
                        bmiBloc.add(BMIFilterByJabatan(selectedJabatan!));
                      }
                    },
              child: const Text('Terapkan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BMIListSkeleton extends StatefulWidget {
  const _BMIListSkeleton();

  @override
  State<_BMIListSkeleton> createState() => _BMIListSkeletonState();
}

class _BMIListSkeletonState extends State<_BMIListSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final shimmer = Color.lerp(
          const Color(0xFFECECEC),
          const Color(0xFFF6F6F6),
          _ctrl.value,
        )!;
        return GridView.builder(
          padding: REdgeInsets.symmetric(horizontal: 16, vertical: 8),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            childAspectRatio: 0.62,
          ),
          itemCount: 6,
          itemBuilder: (_, __) => _SkeletonCard(shimmer: shimmer),
        );
      },
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final Color shimmer;

  const _SkeletonCard({required this.shimmer});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFEEEEEE), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: REdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar circle
          Container(
            width: 72.w,
            height: 72.w,
            decoration: BoxDecoration(
              color: shimmer,
              shape: BoxShape.circle,
            ),
          ),
          14.verticalSpace,
          // Name lines
          Container(
            width: 80.w,
            height: 11.h,
            decoration: BoxDecoration(
              color: shimmer,
              borderRadius: BorderRadius.circular(6.r),
            ),
          ),
          6.verticalSpace,
          Container(
            width: 55.w,
            height: 9.h,
            decoration: BoxDecoration(
              color: shimmer,
              borderRadius: BorderRadius.circular(5.r),
            ),
          ),
          18.verticalSpace,
          // BMI info box
          Container(
            width: double.infinity,
            height: 52.h,
            decoration: BoxDecoration(
              color: shimmer,
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
          8.verticalSpace,
          Container(
            width: double.infinity,
            height: 36.h,
            decoration: BoxDecoration(
              color: shimmer,
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        ],
      ),
    );
  }
}
