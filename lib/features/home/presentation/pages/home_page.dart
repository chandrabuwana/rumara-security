import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:async';
import 'package:collection/collection.dart';
import '../widgets/shift_card.dart';
import '../widgets/task_card.dart';
import '../widgets/menu_grid.dart';
import 'employee_location_tracking_page.dart';
import 'tim_jaga_detail_page.dart';
import '../widgets/custom_bottom_nav.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/design/colors.dart';
import '../../../attendance/presentation/pages/check_in_page.dart';
import '../../../attendance/presentation/pages/check_out_page.dart';
import '../../../attendance/presentation/pages/attendance_rekap_screen.dart';
import '../../../bmi/presentation/pages/bmi_navigation_page.dart';
import '../../../panic_button/presentation/pages/panic_verification_page.dart';
import '../../../panic_button/presentation/pages/panic_button_history_page.dart';
import '../../../panic_button/presentation/bloc/panic_button_bloc.dart';
import '../../../company_regulations/presentation/pages/company_regulations_page.dart';
import '../../../company_regulations/presentation/bloc/document_bloc.dart';
import '../../../patrol/presentation/pages/patrol_detail_page.dart';
import '../../../patrol/presentation/pages/home_patrol_page.dart';
import '../../../patrol/domain/entities/patrol_route.dart';
import '../../../profile/presentation/pages/profile_screen.dart';
import '../../../test_result/presentation/pages/test_result_page.dart';
import '../../../chat/presentation/pages/chat_list_page.dart';
import '../../../chat/presentation/pages/chat_conversation_page.dart';
import '../../../chat/presentation/bloc/chat_bloc.dart';
import '../../../chat/presentation/bloc/chat_event.dart';
import '../../../chat/domain/entities/chat.dart';
import '../../../news/presentation/pages/news_list_page.dart';
import '../../../news/presentation/bloc/news_bloc.dart';
import '../../../personnel/presentation/pages/personnel_list_page.dart';
import '../../../tugas_lanjutan/presentation/pages/tugas_lanjutan_page.dart';
import '../../../tugas_lanjutan/presentation/bloc/tugas_lanjutan_bloc.dart';
import '../../../notification/presentation/pages/notification_list_page.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/security/security_manager.dart';
import '../../../../core/services/location_service.dart';
import '../../../shift/data/datasources/shift_remote_data_source.dart';
import '../../../schedule/data/datasources/schedule_remote_data_source.dart';
import '../../../schedule/domain/repositories/schedule_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late HomeBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<HomeBloc>();
    _bloc.add(const HomeInitialEvent());
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: const _HomePageView(),
    );
  }
}

class _HomePageView extends StatefulWidget {
  const _HomePageView();

  @override
  State<_HomePageView> createState() => __HomePageViewState();
}

class __HomePageViewState extends State<_HomePageView> {
  Timer? _timer;
  String _currentTime = '';
  Future<Map<String, String>>? _cachedAreaMapFuture;
  Map<String, String>? _cachedAreaMap;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeBloc, HomeState>(
      listener: (context, state) {
        if (state is HomeLoaded) {
          // Handle navigation
          if (state.navigationRoute != null &&
              state.navigationRoute!.isNotEmpty) {
            switch (state.navigationRoute) {
              case '/attendance':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CheckInPage(
                      userId: state.navigationArguments?['userId'] ?? '1',
                      namaPersonil:
                          state.navigationArguments?['userName'] ?? 'User',
                      prefillCurrentLocation: state
                          .navigationArguments?['currentLocation'] as String?,
                      prefillRouteName:
                          state.navigationArguments?['routeName'] as String?,
                      prefillLocation:
                          state.navigationArguments?['locationName'] as String?,
                      prefillShiftDetailId: state
                          .navigationArguments?['shiftDetailId'] as String?,
                    ),
                  ),
                ).then((_) {
                  context
                      .read<HomeBloc>()
                      .add(const BottomNavigationTappedEvent(0));
                });
                context.read<HomeBloc>().add(const ClearNavigationEvent());
                break;
              case '/attendance-recap':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AttendanceRekapScreen(),
                  ),
                ).then((_) {
                  context
                      .read<HomeBloc>()
                      .add(const BottomNavigationTappedEvent(0));
                });
                context.read<HomeBloc>().add(const ClearNavigationEvent());
                break;
              case '/bmi':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BMINavigationPage(),
                    settings: RouteSettings(
                      arguments: {
                        'userId': state.navigationArguments?['userId'] ?? '2',
                        'userRole':
                            state.navigationArguments?['userRole'] ?? 'danton',
                      },
                    ),
                  ),
                ).then((_) {
                  context
                      .read<HomeBloc>()
                      .add(const BottomNavigationTappedEvent(0));
                });
                // Clear navigation route after navigation
                context.read<HomeBloc>().add(const ClearNavigationEvent());
                break;
              case '/panic-verification':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BlocProvider(
                      create: (context) => getIt<PanicButtonBloc>(),
                      child: const PanicVerificationPage(),
                    ),
                  ),
                ).then((_) {
                  context
                      .read<HomeBloc>()
                      .add(const BottomNavigationTappedEvent(0));
                });
                context.read<HomeBloc>().add(const ClearNavigationEvent());
                break;
              case '/regulations':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BlocProvider(
                      create: (context) => getIt<DocumentBloc>(),
                      child: const CompanyRegulationsPage(),
                    ),
                  ),
                ).then((_) {
                  context
                      .read<HomeBloc>()
                      .add(const BottomNavigationTappedEvent(0));
                });
                context.read<HomeBloc>().add(const ClearNavigationEvent());
                break;
              case '/patrol':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HomePatrolPage(),
                  ),
                ).then((_) {
                  context
                      .read<HomeBloc>()
                      .add(const BottomNavigationTappedEvent(0));
                });
                context.read<HomeBloc>().add(const ClearNavigationEvent());
                break;
              case '/cuti':
                Navigator.pushNamed(context, '/cuti').then((_) {
                  context
                      .read<HomeBloc>()
                      .add(const BottomNavigationTappedEvent(0));
                });
                context.read<HomeBloc>().add(const ClearNavigationEvent());
                break;
              case '/laporan-kegiatan':
                Navigator.pushNamed(
                  context,
                  '/laporan-kegiatan',
                  arguments: {
                    'userId': state.navigationArguments?['userId'] ?? 'user_1',
                    'userRole':
                        state.navigationArguments?['userRole'] ?? 'anggota',
                  },
                ).then((_) {
                  context
                      .read<HomeBloc>()
                      .add(const BottomNavigationTappedEvent(0));
                });
                context.read<HomeBloc>().add(const ClearNavigationEvent());
                break;
              case '/test-result':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TestResultPage(
                      userId: state.navigationArguments?[
                          'userId'], // Null jika tidak ada, akan dibaca dari secure storage
                      userRole:
                          state.navigationArguments?['userRole'] as UserRole? ??
                              UserRole.anggota,
                    ),
                  ),
                ).then((_) {
                  context
                      .read<HomeBloc>()
                      .add(const BottomNavigationTappedEvent(0));
                });
                context.read<HomeBloc>().add(const ClearNavigationEvent());
                break;
              case '/chat':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BlocProvider(
                      create: (context) => getIt<ChatBloc>(),
                      child: const ChatListPage(),
                    ),
                  ),
                ).then((_) {
                  context
                      .read<HomeBloc>()
                      .add(const BottomNavigationTappedEvent(0));
                });
                // Clear navigation route after navigation
                context.read<HomeBloc>().add(const ClearNavigationEvent());
                break;
              case '/news':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BlocProvider(
                      create: (context) => getIt<NewsBloc>(),
                      child: const NewsListPage(),
                    ),
                  ),
                ).then((_) {
                  context
                      .read<HomeBloc>()
                      .add(const BottomNavigationTappedEvent(0));
                });
                // Clear navigation route after navigation
                context.read<HomeBloc>().add(const ClearNavigationEvent());
                break;
              case '/schedule':
                // Navigate to Schedule feature via named route
                Navigator.pushNamed(context, '/schedule').then((_) {
                  // After returning from schedule, reset bottom nav to home
                  context
                      .read<HomeBloc>()
                      .add(const BottomNavigationTappedEvent(0));
                });
                // Clear navigation route after navigation
                context.read<HomeBloc>().add(const ClearNavigationEvent());
                break;
              case '/emergency-history':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BlocProvider(
                      create: (context) => getIt<PanicButtonBloc>(),
                      child: const PanicButtonHistoryPage(),
                    ),
                  ),
                ).then((_) {
                  context
                      .read<HomeBloc>()
                      .add(const BottomNavigationTappedEvent(0));
                });
                context.read<HomeBloc>().add(const ClearNavigationEvent());
                break;
              case '/notification':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationListPage(),
                  ),
                ).then((_) {
                  context
                      .read<HomeBloc>()
                      .add(const BottomNavigationTappedEvent(0));
                });
                context.read<HomeBloc>().add(const ClearNavigationEvent());
                break;
              case '/incident-report':
              case '/laporan-kejadian':
                Navigator.pushNamed(context, '/laporan-kejadian').then((_) {
                  context
                      .read<HomeBloc>()
                      .add(const BottomNavigationTappedEvent(0));
                });
                context.read<HomeBloc>().add(const ClearNavigationEvent());
                break;
              default:
                // For other routes, do nothing
                break;
            }
          }

          // Handle panic dialog
          if (state.showPanicDialog) {
            _showPanicDialog();
          }
        }
      },
      builder: (context, state) {
        if (state is HomeLoading) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: primaryColor),
            ),
          );
        }

        if (state is HomeError) {
          return Scaffold(
            body: Center(
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
                    'Terjadi kesalahan',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  8.verticalSpace,
                  Text(
                    state.message,
                    style: TextStyle(fontSize: 14.sp),
                    textAlign: TextAlign.center,
                  ),
                  24.verticalSpace,
                  ElevatedButton(
                    onPressed: () {
                      context.read<HomeBloc>().add(const HomeInitialEvent());
                    },
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is! HomeLoaded) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: primaryColor),
            ),
          );
        }

        return Scaffold(
          backgroundColor: neutral10,
          body: SafeArea(
            bottom: false, // Let bottomNavigationBar handle bottom padding
            child: Column(
              children: [
                // App Header
                _buildAppHeader(state.userProfile),

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        20.verticalSpace,

                        // Shift Card
                        ShiftCard(
                          attendanceInfo: state.attendanceInfo,
                          teamMembersImages: _getTeamMembersImages(state),
                          userRole: state.userRole,
                          totalPersonil: state.userRole == UserRole.pengawas
                              ? state.shiftNow?.totalPersonel
                              : state.currentShift?.listPersonel.length,
                          hadirCount: state.userRole == UserRole.pengawas
                              ? state.shiftNow?.totalAttendance
                              : state.currentShift?.listPersonel.length, // Semua personil di list sudah di-assign (hadir)
                          location: state.userRole == UserRole.pengawas
                              ? null
                              : state.currentShift?.location,
                          onWorkButtonPressed: () {
                            unawaited(
                              _handleWorkButtonPressed(context, state),
                            );
                          },
                          onTrackLocationPressed:
                              state.userRole == UserRole.pengawas
                                  ? () {
                                      // Navigasi ke halaman lacak lokasi yang akan fetch data dari API
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const EmployeeLocationTrackingPage(),
                                        ),
                                      );
                                    }
                                  : null,
                          onCardTap: state.userRole == UserRole.pengawas
                              ? () {
                                  // Navigasi ke halaman Tim Jaga Hari Ini dengan 2 tab per shift
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const TimJagaDetailPage(),
                                    ),
                                  );
                                }
                              : null,
                        ),

                        24.verticalSpace,

                        // Komponen khusus untuk role Pengawas
                        if (state.userRole == UserRole.pengawas)
                          Column(
                            children: [
                              // Tim Jaga Hari Ini (khusus Pengawas)
                              _buildTimJagaSection(state),
                              24.verticalSpace,
                              // Tugas Hari Ini untuk Pengawas
                              _buildTodayTasksSection(state.todayTasks),
                              24.verticalSpace,
                            ],
                          )
                        else
                          // Today's Tasks Section untuk role lain
                          Column(
                            children: [
                              _buildTodayTasksSection(state.todayTasks),
                              24.verticalSpace,
                            ],
                          ),

                        // Menu Grid
                        MenuGrid(
                          menuItems: _buildMenuItems(state.userRole),
                        ),

                        24.verticalSpace,
                        100.verticalSpace, // Bottom padding for bottom nav with emergency button
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: CustomBottomNav(
            currentIndex: state.currentBottomNavIndex,
            onTap: (index) {
              context.read<HomeBloc>().add(BottomNavigationTappedEvent(index));
            },
            onEmergencyPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlocProvider(
                    create: (context) => getIt<PanicButtonBloc>(),
                    child: const PanicVerificationPage(),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _handleWorkButtonPressed(
    BuildContext context,
    HomeLoaded state,
  ) async {
    if (!state.attendanceInfo.isCheckedIn) {
      await _startCheckInFlow(context, state);
    } else {
      await _startCheckOutFlow(context, state);
    }
  }

  Future<void> _startCheckInFlow(
    BuildContext context,
    HomeLoaded state,
  ) async {
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    bool loadingShown = false;

    void closeLoading() {
      if (loadingShown && navigator.canPop()) {
        navigator.pop();
        loadingShown = false;
      }
    }

    // Get userId first before try-catch so it's available in catch block
    final userId =
        await SecurityManager.readSecurely(AppConstants.userIdKey) ?? '1';

    try {
      loadingShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final locService = getIt<LocationService>();
      final shiftDs = getIt<ShiftRemoteDataSource>();

      final pos = await locService.getCurrentLatLng();
      final lat = pos?.lat ?? 0;
      final lng = pos?.lng ?? 0;
      final resp = await shiftDs.getCurrentLocation(
        latitude: lat,
        longitude: lng,
      );
      final data = resp.data;
      
      // Debug: Log carryOverTasks
      if (data != null) {
        final carryOverTasks = data.carryOverTasks;
        print('📋 CheckIn Flow - carryOverTasks from getCurrentLocation: $carryOverTasks');
      }
      
      // Ambil IdShiftDetail dari /Shift/get_current (gunakan field Id dari response)
      String? shiftDetailId;
      try {
        final scheduleDs = getIt<ScheduleRemoteDataSource>();
        final body = {'IdUser': userId};
        final currentShiftResp = await scheduleDs.getCurrentShift(body);
        // Gunakan field Id dari response sebagai IdShiftDetail
        shiftDetailId = currentShiftResp.data?.id;
        
        // Simpan IdShiftDetail ke storage jika ada
        if (shiftDetailId != null && shiftDetailId.isNotEmpty) {
          await SecurityManager.storeSecurely(
            AppConstants.shiftDetailIdKey,
            shiftDetailId,
          );
        }
      } catch (e) {
        print('Error getting IdShiftDetail from /Shift/get_current: $e');
      }
      
      closeLoading();
      if (!mounted) return;
      
      final checkInResult = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => CheckInPage(
            userId: userId,
            namaPersonil: state.userProfile.name,
            prefillFullname: data?.fullname,
            prefillLocation: data?.location,
            prefillCurrentLocation: data?.currentLocation,
            prefillRouteName: data?.routeName,
            prefillShiftDetailId: shiftDetailId,
            prefillTugasLanjutan: data?.carryOverTasks, // Tugas lanjutan dari ListCarryOver
          ),
        ),
      );

      // Reload data setelah check-in berhasil
      if (checkInResult == true && mounted) {
        print('🔄 Reloading home data after successful check-in...');
        // Reload get_current (current shift) dan get_current_task (patrol tasks)
        context.read<HomeBloc>().add(const HomeInitialEvent());
      }
    } catch (e) {
      closeLoading();
      if (!mounted) return;
      
      // Tetap navigasi ke CheckInPage meskipun ada error
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CheckInPage(
            userId: userId,
            namaPersonil: state.userProfile.name,
          ),
        ),
      );
    }
  }

  Future<void> _startCheckOutFlow(
    BuildContext context,
    HomeLoaded state,
  ) async {
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    bool loadingShown = false;

    void closeLoading() {
      if (loadingShown && navigator.canPop()) {
        navigator.pop();
        loadingShown = false;
      }
    }

    try {
      loadingShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      print('🚀 CheckOut Flow - Starting...');
      final userId =
          await SecurityManager.readSecurely(AppConstants.userIdKey) ?? '1';
      print('🚀 CheckOut Flow - userId: $userId');

      // Ambil IdShiftDetail dari /Shift/get_current (gunakan field Id dari response)
      // Ini juga untuk validasi bahwa Checkin: true dan Checkout: false
      String? shiftDetailId;
      try {
        final scheduleDs = getIt<ScheduleRemoteDataSource>();
        final body = {'IdUser': userId};
        final currentShiftResp = await scheduleDs.getCurrentShift(body);
        print('📋 CheckOut Flow - Response from /Shift/get_current:');
        print('  - succeeded: ${currentShiftResp.succeeded}');
        print('  - checkin: ${currentShiftResp.data?.checkin}');
        print('  - checkout: ${currentShiftResp.data?.checkout}');
        print('  - data.id: ${currentShiftResp.data?.id}');
        
        // Validasi: harus Checkin: true dan Checkout: false
        if (currentShiftResp.data == null) {
          throw Exception('Data shift tidak ditemukan');
        }
        
        if (currentShiftResp.data!.checkin != true) {
          throw Exception('Anda belum melakukan check-in. Silakan check-in terlebih dahulu.');
        }
        
        if (currentShiftResp.data!.checkout == true) {
          throw Exception('Anda sudah melakukan check-out hari ini.');
        }
        
        // Gunakan field Id dari response sebagai IdShiftDetail
        shiftDetailId = currentShiftResp.data?.id;
        print('✅ CheckOut Flow - shiftDetailId from API: $shiftDetailId');
        
        // Simpan IdShiftDetail ke storage jika ada
        if (shiftDetailId != null && shiftDetailId.isNotEmpty) {
          await SecurityManager.storeSecurely(
            AppConstants.shiftDetailIdKey,
            shiftDetailId,
          );
          print('💾 CheckOut Flow - shiftDetailId saved to storage');
        }
      } catch (e) {
        print('❌ CheckOut Flow - Error getting shiftDetailId from /Shift/get_current: $e');
        throw Exception('Gagal mendapatkan data shift: $e');
      }

      if (shiftDetailId == null || shiftDetailId.isEmpty) {
        print('❌ CheckOut Flow - shiftDetailId still empty after all attempts');
        throw Exception('Shift detail tidak ditemukan. Silakan coba lagi.');
      }

      // Get current location (untuk logging saja, lat/lng akan di-hardcode di API call)
      final locService = getIt<LocationService>();
      final position = await locService.getCurrentLatLng();
      final lat = position?.lat ?? 0;
      final lng = position?.lng ?? 0;
      print('📍 CheckOut Flow - Location: lat=$lat, lng=$lng (akan di-hardcode di API)');

      print('📤 CheckOut Flow - Calling getCheckoutDetail API...');
      print('  - shiftDetailId: $shiftDetailId');
      print('  - latitude: $lat');
      print('  - longitude: $lng');

      final shiftDs = getIt<ShiftRemoteDataSource>();

      final checkoutResp = await shiftDs.getCheckoutDetail(
        shiftDetailId: shiftDetailId,
        latitude: lat,
        longitude: lng,
      );

      print('✅ CheckOut Flow - getCheckoutDetail response received');
      print('  - succeeded: ${checkoutResp.succeeded}');
      print('  - data: ${checkoutResp.data}');

      closeLoading();
      if (!mounted) return;

      print('✅ CheckOut Flow - Navigating to CheckOutPage');
      // attendanceId tidak diperlukan untuk checkout flow, bisa dikosongkan
      final checkoutResult = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => CheckOutPage(
            userId: userId,
            attendanceId: '', // Tidak diperlukan untuk checkout flow
            checkoutDetail: checkoutResp.data,
          ),
        ),
      );

      // Reload data setelah checkout berhasil
      if (checkoutResult == true && mounted) {
        print('🔄 Reloading home data after successful checkout...');
        // Reload get_current (current shift) dan get_current_task (patrol tasks)
        context.read<HomeBloc>().add(const HomeInitialEvent());
      }
    } catch (e, stackTrace) {
      print('❌ CheckOut Flow - Error caught: $e');
      print('❌ CheckOut Flow - Stack trace: $stackTrace');
      closeLoading();
      if (!mounted) return;
      
      String errorMessage = 'Gagal membuka form check out';
      if (e is Exception) {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      } else {
        errorMessage = e.toString();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Widget _buildAppHeader(UserProfile userProfile) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24.r),
          bottomRight: Radius.circular(24.r),
        ),
      ),
      child: Column(
        children: [
          // Time and Profile Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Time
              Text(
                _currentTime,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),

              Row(
                children: [
                  // Debug: Refresh button untuk reload role
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20.r),
                      onTap: () {
                        context.read<HomeBloc>().add(const HomeInitialEvent());
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Reloading home page...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.all(8.r),
                        child: Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 24.sp,
                        ),
                      ),
                    ),
                  ),
                  8.horizontalSpace,
                  // Profile Avatar
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20.r),
                      onTap: () => _navigateToProfile(context, userProfile),
                      child: Container(
                        padding: EdgeInsets.all(2.r),
                        child: CircleAvatar(
                          radius: 20.r,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          backgroundImage: userProfile.profileImageUrl != null
                              ? NetworkImage(userProfile.profileImageUrl!)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          16.verticalSpace,
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userProfile.greeting,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                4.verticalSpace,
                Text(
                  userProfile.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimJagaSection(HomeLoaded state) {
    // Jika tidak ada data shiftNow, tampilkan empty state
    if (state.shiftNow == null || state.shiftNow!.listPersonel.isEmpty) {
      return const SizedBox.shrink();
    }

    // Jika sudah ada cached data, langsung gunakan tanpa FutureBuilder
    if (_cachedAreaMap != null) {
      return _buildTimJagaContent(state, _cachedAreaMap!);
    }

    // Cache future untuk menghindari multiple API calls
    if (_cachedAreaMapFuture == null) {
      _cachedAreaMapFuture = _getUserIdToAreaMap(state).then((data) {
        if (mounted) {
          setState(() {
            _cachedAreaMap = data;
          });
        }
        return data;
      });
    }

    // Gunakan FutureBuilder hanya jika belum ada cached data
    return FutureBuilder<Map<String, String>>(
      future: _cachedAreaMapFuture,
      builder: (context, snapshot) {
        // Gunakan cached data jika ada, atau data dari snapshot
        final Map<String, String> userIdToAreaMap = _cachedAreaMap ?? snapshot.data ?? {};
        
        return _buildTimJagaContent(state, userIdToAreaMap);
      },
    );
  }

  Widget _buildTimJagaContent(HomeLoaded state, Map<String, String> userIdToAreaMap) {
    // Gunakan data dari state.shiftNow.listPersonel (sama dengan card Tim Jaga)
    final List<Map<String, String>> timJaga = [];
    
    for (final personnel in state.shiftNow!.listPersonel) {
      timJaga.add({
        'userId': personnel.userId,
        'nama': personnel.fullname,
        'posisi': userIdToAreaMap[personnel.userId] ?? 'Pos', // Default jika tidak ada
        'image': personnel.images ?? '',
      });
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tim Jaga Hari Ini',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: neutral90,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TimJagaDetailPage(),
                    ),
                  );
                },
                child: Text(
                  'Lihat Detail',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          12.verticalSpace,

          // Horizontal scrollable list of team members
          SizedBox(
            height: 200.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: timJaga.length,
              itemBuilder: (context, index) {
                final member = timJaga[index];
                return Container(
                  width: 120.w,
                  margin: EdgeInsets.only(right: 12.w),
                  decoration: BoxDecoration(
                    color: babyBlueColor,
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(12.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Avatar with larger size
                      CircleAvatar(
                        radius: 35.r,
                        backgroundColor: neutral30,
                        backgroundImage: member['image']!.isNotEmpty
                            ? NetworkImage(member['image']!)
                            : null,
                        child: member['image']!.isEmpty
                            ? Icon(
                                Icons.person,
                                size: 35.sp,
                                color: neutral50,
                              )
                            : null,
                      ),
                      10.verticalSpace,

                      // Nama
                      Text(
                        member['nama']!,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: neutral90,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      6.verticalSpace,

                      // Posisi Badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          member['posisi']!,
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      10.verticalSpace,

                      // Kirim Pesan button (solid filled) - navigasi ke chat
                      SizedBox(
                        width: double.infinity,
                        height: 32.h,
                        child: ElevatedButton(
                          onPressed: () {
                            _navigateToChat(
                              member['userId'] ?? '',
                              member['nama'] ?? 'Anggota Tim',
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          child: Text(
                            'Kirim Pesan',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Memanggil get_schedule_pengawas untuk mendapatkan mapping userId -> areaName
  Future<Map<String, String>> _getUserIdToAreaMap(HomeLoaded state) async {
    final Map<String, String> userIdToAreaMap = {};
    
    try {
      final scheduleRepository = getIt<ScheduleRepository>();
      final today = DateTime.now();
      
      // Panggil get_schedule_pengawas untuk mendapatkan informasi area
      final result = await scheduleRepository.getSchedulePengawas(date: today);
      
      if (result.isSuccess && result.shiftDetail != null) {
        final shiftDetail = result.shiftDetail!;
        
        // Loop melalui team members untuk mendapatkan mapping userId -> position (area)
        for (final member in shiftDetail.teamMembers) {
          // Position field contains "AreaName|ShiftName" format for pengawas schedule
          // Extract area name (before |)
          final areaName = member.position.contains('|') 
              ? member.position.split('|')[0] 
              : member.position;
          
          // Jika sudah ada mapping untuk userId ini, gabungkan area names
          if (userIdToAreaMap.containsKey(member.id)) {
            final existingAreas = userIdToAreaMap[member.id]!.split(', ');
            if (!existingAreas.contains(areaName)) {
              userIdToAreaMap[member.id] = '${userIdToAreaMap[member.id]}, $areaName';
            }
          } else {
            userIdToAreaMap[member.id] = areaName;
          }
        }
      }
    } catch (e) {
      print('⚠️ Error getting schedule pengawas for area mapping: $e');
    }
    
    return userIdToAreaMap;
  }

  Widget _buildTodayTasksSection(List<TaskItem> tasks) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tugas Hari Ini',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: neutral90,
            ),
          ),
          16.verticalSpace,
          BlocBuilder<HomeBloc, HomeState>(
            builder: (context, state) {
              if (state is HomeLoaded && state.isLoadingPatrolTasks) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.h),
                    child: CircularProgressIndicator(color: primaryColor),
                  ),
                );
              }

              if (tasks.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.h),
                    child: Text(
                      'Tidak ada tugas hari ini',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: neutral70,
                      ),
                    ),
                  ),
                );
              }

              final isShiftFinished = state is HomeLoaded &&
                  state.currentShift?.checkin == true &&
                  state.currentShift?.checkout == true;
              
              final isNotCheckedIn = state is HomeLoaded &&
                  state.currentShift?.checkin != true;

              return Column(
                children: tasks
                    .map((task) {
                      final isPatrolOrTugasLanjutanCard =
                          task.id == 'patrol_summary' || task.id == 'patrol_continue';

                      return TaskCard(
                          task: task,
                          onTap: () async {
                            print('🖱️ Task card tapped! Task ID: ${task.id}, Title: ${task.title}');

                            // Navigate to Tugas Lanjutan page first (before patrol check)
                            if (task.id == 'patrol_continue') {
                              final userId = await SecurityManager.readSecurely(
                                    AppConstants.userIdKey,
                                  ) ??
                                  'user_1';
                              final isCheckedIn = state is HomeLoaded ? state.currentShift?.checkin : null;
                              final isCheckedOut = state is HomeLoaded ? (state.currentShift?.checkin == true && state.currentShift?.checkout == true) : null;
                              debugPrint('🔍 [HOME] Navigating to TugasLanjutanPage');
                              debugPrint('  - isCheckedIn: $isCheckedIn');
                              debugPrint('  - isCheckedOut: $isCheckedOut');
                              debugPrint('  - currentShift.checkin: ${state is HomeLoaded ? state.currentShift?.checkin : "N/A"}');
                              debugPrint('  - currentShift.checkout: ${state is HomeLoaded ? state.currentShift?.checkout : "N/A"}');
                              
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BlocProvider(
                                    create: (context) => getIt<TugasLanjutanBloc>(),
                                    child: TugasLanjutanPage(
                                      userId: userId,
                                      isCheckedIn: isCheckedIn,
                                      isCheckedOut: isCheckedOut,
                                    ),
                                  ),
                                ),
                              ).then((_) async {
                                final homeBloc = context.read<HomeBloc>();
                                final shiftId = await SecurityManager.readSecurely(
                                  AppConstants.shiftDetailIdKey,
                                );
                                if (shiftId != null && shiftId.isNotEmpty) {
                                  homeBloc.add(LoadCurrentTaskEvent(idShiftDetail: shiftId));
                                } else {
                                  homeBloc.add(const HomeInitialEvent());
                                }

                                homeBloc.add(const BottomNavigationTappedEvent(0));
                              });
                            } else if (task.id == 'patrol_summary') {
                              // Navigate directly to patrol detail page using data from get_current_task
                              print('🚀 Navigating to patrol detail page from patrol_summary task');
                              final homeState = context.read<HomeBloc>().state;
                              if (homeState is HomeLoaded && homeState.currentTask != null) {
                                final currentTask = homeState.currentTask!;
                                
                                // Get first route from listRoute
                                if (currentTask.listRoute.isNotEmpty) {
                                  final firstRoute = currentTask.listRoute.first;
                                  final idAreas = firstRoute.idAreas;
                                  
                                  // Create PatrolRoute with empty locations - will be loaded from ListRoute
                                  final patrolRoute = PatrolRoute(
                                    id: idAreas,
                                    name: firstRoute.areasName,
                                    description: 'Status: ${firstRoute.status}',
                                    locations: [], // Empty - will be loaded from ListRoute by bloc
                                    additionalLocations: const [],
                                    date: DateTime.now(),
                                    status: firstRoute.status.toUpperCase() == 'SELESAI' || 
                                            firstRoute.status.toUpperCase() == 'DONE'
                                        ? PatrolRouteStatus.completed
                                        : firstRoute.status.toUpperCase() == 'BELUM'
                                            ? PatrolRouteStatus.pending
                                            : PatrolRouteStatus.inProgress,
                                  );

                                  // Navigate with ListRoute data - bloc will use it instead of calling API
                                  final isCheckedOut = homeState.currentShift?.checkin == true && homeState.currentShift?.checkout == true;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PatrolDetailPage(
                                        route: patrolRoute,
                                        listRoute: currentTask.listRoute, // Pass ListRoute data
                                        isCheckedIn: homeState.currentShift?.checkin,
                                        isCheckedOut: isCheckedOut,
                                      ),
                                    ),
                                  ).then((shouldReload) async {
                                    // Always reload data when returning from patrol detail to ensure fresh data
                                    final homeBloc = context.read<HomeBloc>();
                                    final shiftId = await SecurityManager.readSecurely(
                                      AppConstants.shiftDetailIdKey,
                                    );
                                    if (shiftId != null && shiftId.isNotEmpty) {
                                      print('🔄 Reloading home data after returning from patrol detail');
                                      print('🔄 Shift ID: $shiftId');
                                      // Force reload by dispatching LoadCurrentTaskEvent
                                      homeBloc.add(LoadCurrentTaskEvent(idShiftDetail: shiftId));
                                      // Wait a bit to ensure the event is processed
                                      await Future.delayed(const Duration(milliseconds: 100));
                                    }
                                    context
                                        .read<HomeBloc>()
                                        .add(const BottomNavigationTappedEvent(0));
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Tidak ada rute patroli yang tersedia'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Data patroli tidak tersedia'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } else if (task.id.startsWith('patrol_')) {
                              // Navigate to patrol detail page for specific patrol tasks
                              // Get the route ID from task ID (format: patrol_xxx)
                              final routeId =
                                  task.id.replaceFirst('patrol_', '');

                              // Get the patrol route from state
                              final homeState = context.read<HomeBloc>().state;
                              if (homeState is HomeLoaded) {
                                // Use currentTask data if available for more accurate routing
                                if (homeState.currentTask != null) {
                                  final currentTask = homeState.currentTask!;
                                  final matchingRoute = currentTask.listRoute
                                      .where((route) => route.idAreas == routeId)
                                      .firstOrNull;
                                  
                                  if (matchingRoute != null) {
                                    // Create PatrolRoute from RouteTask and navigate
                                    final patrolRoute = PatrolRoute(
                                      id: matchingRoute.idAreas,
                                      name: matchingRoute.areasName,
                                      description: 'Status: ${matchingRoute.status}',
                                      locations: [], // Empty - will be loaded from ListRoute by bloc
                                      additionalLocations: const [],
                                      date: DateTime.now(),
                                      status: matchingRoute.status.toUpperCase() == 'SELESAI' || 
                                              matchingRoute.status.toUpperCase() == 'DONE'
                                          ? PatrolRouteStatus.completed
                                          : matchingRoute.status.toUpperCase() == 'BELUM'
                                              ? PatrolRouteStatus.pending
                                              : PatrolRouteStatus.inProgress,
                                    );

                                    // Navigate with ListRoute data - bloc will use it instead of calling API
                                    final isCheckedOut = homeState.currentShift?.checkin == true && homeState.currentShift?.checkout == true;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            PatrolDetailPage(
                                              route: patrolRoute,
                                              listRoute: currentTask.listRoute, // Pass ListRoute data
                                              isCheckedIn: homeState.currentShift?.checkin,
                                              isCheckedOut: isCheckedOut,
                                            ),
                                      ),
                                    ).then((shouldReload) async {
                                      // Always reload data when returning from patrol detail
                                      final homeBloc = context.read<HomeBloc>();
                                      final shiftId = await SecurityManager.readSecurely(
                                        AppConstants.shiftDetailIdKey,
                                      );
                                      if (shiftId != null && shiftId.isNotEmpty) {
                                        print('🔄 Reloading home data after returning from patrol detail');
                                        homeBloc.add(LoadCurrentTaskEvent(idShiftDetail: shiftId));
                                        await Future.delayed(const Duration(milliseconds: 100));
                                      }
                                      context
                                          .read<HomeBloc>()
                                          .add(const BottomNavigationTappedEvent(0));
                                    });
                                    return;
                                  }
                                }

                                // Fallback to existing patrol routes
                                if (homeState.patrolRoutes.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Data rute patroli tidak tersedia'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                // Find route by ID
                                final routeIndex =
                                    homeState.patrolRoutes.indexWhere(
                                  (r) => r.id == routeId,
                                );

                                // If route not found, use first route
                                final route = routeIndex != -1
                                    ? homeState.patrolRoutes[routeIndex]
                                    : homeState.patrolRoutes.first;

                                final isCheckedOut = homeState.currentShift?.checkin == true && homeState.currentShift?.checkout == true;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PatrolDetailPage(
                                          route: route,
                                          isCheckedIn: homeState.currentShift?.checkin,
                                          isCheckedOut: isCheckedOut,
                                        ),
                                  ),
                                ).then((shouldReload) async {
                                  // Always reload data when returning from patrol detail
                                  final homeBloc = context.read<HomeBloc>();
                                  final shiftId = await SecurityManager.readSecurely(
                                    AppConstants.shiftDetailIdKey,
                                  );
                                  if (shiftId != null && shiftId.isNotEmpty) {
                                    print('🔄 Reloading home data after returning from patrol detail');
                                    homeBloc.add(LoadCurrentTaskEvent(idShiftDetail: shiftId));
                                    await Future.delayed(const Duration(milliseconds: 100));
                                  }
                                  context
                                      .read<HomeBloc>()
                                      .add(const BottomNavigationTappedEvent(0));
                                });
                              }
                            } else {
                              context.read<HomeBloc>().add(
                                    ShowSnackbarEvent('Tugas: ${task.title}'),
                                  );
                            }
                          },
                        );
                    })
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  List<MenuItem> _buildMenuItems(UserRole userRole) {
    // Menu khusus untuk role Pengawas
    if (userRole == UserRole.pengawas) {
      return [
        MenuItem(
          id: 'incident',
          title: 'Insiden Kejadian',
          icon: Icons.report_problem,
          hasNotification: true,
          onTap: () => context
              .read<HomeBloc>()
              .add(const NavigateToIncidentReportEvent()),
        ),
        MenuItem(
          id: 'personnel_list',
          title: 'Daftar Personil',
          icon: Icons.people,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PersonnelListPage(),
              ),
            ).then((_) {
              context
                  .read<HomeBloc>()
                  .add(const BottomNavigationTappedEvent(0));
            });
          },
        ),
        MenuItem(
          id: 'activity_report',
          title: 'Laporan Kegiatan',
          icon: Icons.description,
          onTap: () => context
              .read<HomeBloc>()
              .add(const NavigateToActivityReportEvent()),
        ),
        MenuItem(
          id: 'bmi',
          title: 'Body Mass Index (BMI)',
          icon: Icons.monitor_weight,
          onTap: () => context.read<HomeBloc>().add(const NavigateToBMIEvent()),
        ),
        MenuItem(
          id: 'test_result',
          title: 'Hasil Ujian',
          icon: Icons.quiz,
          hasNotification: true,
          onTap: () =>
              context.read<HomeBloc>().add(const NavigateToTestResultEvent()),
        ),
        MenuItem(
          id: 'leave_request',
          title: 'Pengajuan Cuti',
          icon: Icons.calendar_month,
          onTap: () =>
              context.read<HomeBloc>().add(const NavigateToLeaveRequestEvent()),
        ),
        MenuItem(
          id: 'regulations',
          title: 'Peraturan Perusahaan',
          icon: Icons.gavel,
          onTap: () =>
              context.read<HomeBloc>().add(const NavigateToRegulationsEvent()),
        ),
        MenuItem(
          id: 'emergency_history',
          title: 'Riwayat Tombol Darurat',
          icon: Icons.history,
          onTap: () => context
              .read<HomeBloc>()
              .add(const NavigateToEmergencyHistoryEvent()),
        ),
        MenuItem(
          id: 'disaster_info',
          title: 'Informasi Bencana',
          icon: Icons.info,
          onTap: () =>
              context.read<HomeBloc>().add(const NavigateToDisasterInfoEvent()),
        ),
      ];
    }

    // Menu default untuk role lainnya (Anggota, Danton, PJO, Deputy, Admin)
    // print('✅ BUILDING DEFAULT MENU (With Rekapitulasi Kehadiran)');
    final menuItems = <MenuItem>[
      MenuItem(
        id: 'incident',
        title: 'Insiden Kejadian',
        icon: Icons.report_problem,
        hasNotification: true,
        onTap: () =>
            context.read<HomeBloc>().add(const NavigateToIncidentReportEvent()),
      ),
      MenuItem(
        id: 'attendance_recap',
        title: 'Rekapitulasi Kehadiran',
        icon: Icons.assignment,
        onTap: () => context
            .read<HomeBloc>()
            .add(const NavigateToAttendanceRecapEvent()),
      ),
    ];

    // Laporan Kegiatan hanya untuk role selain anggota
    if (userRole != UserRole.anggota) {
      menuItems.add(
        MenuItem(
          id: 'activity_report',
          title: 'Laporan Kegiatan',
          icon: Icons.description,
          onTap: () =>
              context.read<HomeBloc>().add(const NavigateToActivityReportEvent()),
        ),
      );
    }

    menuItems.addAll([
      MenuItem(
        id: 'bmi',
        title: 'Body Mass Index (BMI)',
        icon: Icons.monitor_weight,
        onTap: () => context.read<HomeBloc>().add(const NavigateToBMIEvent()),
      ),
      MenuItem(
        id: 'test_result',
        title: 'Hasil Ujian',
        icon: Icons.quiz,
        hasNotification: true,
        onTap: () =>
            context.read<HomeBloc>().add(const NavigateToTestResultEvent()),
      ),
      MenuItem(
        id: 'leave_request',
        title: 'Pengajuan Cuti',
        icon: Icons.calendar_month,
        onTap: () =>
            context.read<HomeBloc>().add(const NavigateToLeaveRequestEvent()),
      ),
      MenuItem(
        id: 'regulations',
        title: 'Peraturan Perusahaan',
        icon: Icons.gavel,
        onTap: () =>
            context.read<HomeBloc>().add(const NavigateToRegulationsEvent()),
      ),
      MenuItem(
        id: 'emergency_history',
        title: 'Riwayat Tombol Darurat',
        icon: Icons.history,
        onTap: () => context
            .read<HomeBloc>()
            .add(const NavigateToEmergencyHistoryEvent()),
      ),
      MenuItem(
        id: 'disaster_info',
        title: 'Informasi Bencana',
        icon: Icons.info,
        onTap: () =>
            context.read<HomeBloc>().add(const NavigateToDisasterInfoEvent()),
      ),
    ]);

    return menuItems;
  }

  List<String> _getTeamMembersImages(HomeLoaded state) {
    // For pengawas, use shiftNow data
    if (state.userRole == UserRole.pengawas) {
      if (state.shiftNow != null && state.shiftNow!.listPersonel.isNotEmpty) {
        return state.shiftNow!.listPersonel
            .map((personnel) => (personnel.images != null && personnel.images!.isNotEmpty) 
                ? personnel.images! 
                : '')
            .toList();
      }
    } else {
      // For other roles, use currentShift data
      if (state.currentShift != null && state.currentShift!.listPersonel.isNotEmpty) {
        return state.currentShift!.listPersonel
            .map((personnel) => (personnel.images != null && personnel.images!.isNotEmpty) 
                ? personnel.images! 
                : '')
            .toList();
      }
    }
    // Fallback to empty list
    return [
      '', // Empty for default avatar
      '', // Empty for default avatar
      '', // Empty for default avatar
      '', // Empty for default avatar
    ];
  }


  /// Navigate to chat with a specific user (create conversation and open chat)
  Future<void> _navigateToChat(String userId, String userName) async {
    if (userId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ID pengguna tidak valid'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Get current user ID to verify
    final currentUserId = await SecurityManager.readSecurely(AppConstants.userIdKey);
    if (currentUserId == null || currentUserId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mendapatkan ID pengguna saat ini'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Don't create conversation if trying to chat with self
    if (userId == currentUserId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat mengirim pesan ke diri sendiri'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // Create ChatBloc instance
      final chatBloc = getIt<ChatBloc>();

      // Create conversation with the user
      chatBloc.add(ChatCreateConversation(memberUserIds: [userId]));

      // Wait for conversation to be created
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      final currentState = chatBloc.state;
      if (currentState.selectedChatId != null) {
        // Find the chat that was just created
        final newChat = currentState.chats.firstWhere(
          (chat) => chat.id == currentState.selectedChatId,
          orElse: () => Chat(
            id: currentState.selectedChatId!,
            name: userName.isNotEmpty ? userName : 'Anggota Tim',
            type: ChatType.direct,
            participantIds: [userId],
            unreadCount: 0,
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BlocProvider.value(
              value: chatBloc,
              child: ChatConversationPage(chat: newChat),
            ),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal membuka chat'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error navigating to chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka chat: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPanicDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          content: SizedBox(
            width: 300.w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning Icon
                Container(
                  width: 80.w,
                  height: 80.h,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning,
                    color: Colors.white,
                    size: 45.r,
                  ),
                ),
                20.verticalSpace,

                Text(
                  'TOMBOL DARURAT',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                8.verticalSpace,
                Text(
                  'Apakah anda yakin ingin mengaktifkan Panic Button? Pastikan situasi darurat yang terjadi valid',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: neutral70,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                24.verticalSpace,

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          'Batal',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ),
                    12.horizontalSpace,
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.read<HomeBloc>().add(
                                const ShowSnackbarEvent(
                                    'Tombol darurat telah diaktifkan!'),
                              );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          'Ya, Aktifkan',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
  }

  /// Navigate to Profile screen when profile avatar is tapped
  void _navigateToProfile(BuildContext context, UserProfile userProfile) async {
    // Get user ID from secure storage
    final userId = await SecurityManager.readSecurely(AppConstants.userIdKey);

    if (!context.mounted) return;

    if (userId == null || userId.isEmpty) {
      // If no user ID, show error and logout
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User ID tidak ditemukan. Silakan login kembali.'),
          backgroundColor: Colors.red,
        ),
      );
      // Navigate to login
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          userId: userId, // Real user ID from secure storage
        ),
      ),
    );
  }
}
