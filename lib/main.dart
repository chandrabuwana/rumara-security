import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'core/utils/logger.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_alert_window/system_alert_window.dart';
import 'dart:typed_data';
import 'features/home/presentation/pages/home_page.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/register_page.dart';
import 'features/auth/presentation/pages/reset_password_page.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/panic_button/presentation/pages/panic_verification_page.dart';
import 'features/panic_button/presentation/pages/panic_disaster_confirmation_page.dart';
import 'features/panic_button/presentation/pages/panic_disaster_selection_page.dart';
import 'features/panic_button/presentation/pages/panic_incident_form_page.dart';
import 'features/panic_button/presentation/pages/panic_security_form_page.dart';
import 'features/panic_button/presentation/pages/panic_confirmation_page.dart';
import 'features/panic_button/presentation/pages/panic_button_history_page.dart';
import 'features/panic_button/presentation/bloc/panic_button_bloc.dart';
import 'features/bmi/presentation/pages/bmi_navigation_page.dart';
import 'features/profile/presentation/pages/profile_screen.dart';
import 'features/cuti/presentation/pages/cuti_page.dart';
import 'features/cuti/presentation/pages/form_ajuan_cuti_page.dart';
import 'features/cuti/presentation/pages/detail_cuti_page.dart';
import 'features/laporan_kegiatan/presentation/pages/laporan_kegiatan_page.dart';
import 'features/laporan_kegiatan/presentation/bloc/laporan_kegiatan_bloc.dart';
import 'features/laporan_kejadian/presentation/pages/incident_list_page.dart';
import 'features/laporan_kejadian/presentation/bloc/incident_bloc.dart';
import 'features/chat/presentation/pages/chat_list_page.dart';
import 'features/chat/presentation/bloc/chat_bloc.dart';
import 'features/home/presentation/bloc/home_bloc.dart';
import 'features/news/presentation/pages/news_list_page.dart';
import 'features/news/presentation/bloc/news_bloc.dart';
import 'features/schedule/presentation/pages/schedule_page.dart';
import 'features/schedule/presentation/pages/schedule_pjo_deputy_page.dart';
import 'features/schedule/presentation/bloc/schedule_bloc.dart';
import 'features/tugas_lanjutan/presentation/pages/tugas_lanjutan_page.dart';
import 'features/tugas_lanjutan/presentation/bloc/tugas_lanjutan_bloc.dart';
import 'core/constants/enums.dart';
import 'core/constants/app_constants.dart';
import 'core/security/security_manager.dart';
import 'core/di/injection.dart';
import 'core/navigation/app_navigator_key.dart';
import 'core/design/colors.dart';
import 'core/design/branding_config.dart';
import 'core/design/theme_builder.dart';
import 'core/design/theme_controller.dart';
import 'core/services/background_location_task.dart';
import 'core/services/background_location_permission_helper.dart';
import 'core/services/push_notification_service.dart';

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(child: _PanicOverlayScreen()),
    ),
  );
}

class _PanicOverlayScreen extends StatefulWidget {
  const _PanicOverlayScreen();

  @override
  State<_PanicOverlayScreen> createState() => _PanicOverlayScreenState();
}

class _PanicOverlayScreenState extends State<_PanicOverlayScreen> {
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    SystemAlertWindow.overlayListener.listen((event) {
      if (event is Map) {
        setState(() {
          _data = Map<String, dynamic>.from(event);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final incident = data?['IncidentName']?.toString() ??
        data?['incidentName']?.toString() ??
        'Panic';
    final area =
        data?['AreasName']?.toString() ?? data?['areasName']?.toString();
    final reporter =
        data?['Reporter']?.toString() ?? data?['reporter']?.toString();
    final status = data?['Status']?.toString() ?? data?['status']?.toString();
    final description =
        data?['Description']?.toString() ?? data?['description']?.toString();

    return SafeArea(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PANIC - $incident',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.red,
              ),
            ),
            if (area != null && area.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(area),
            ],
            if (reporter != null && reporter.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Pelapor: $reporter'),
            ],
            if (status != null && status.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Status: $status'),
            ],
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(description),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await SystemAlertWindow.closeSystemWindow();
                    },
                    child: const Text('Tutup'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showBackgroundPanicNotification(
  Map<String, dynamic> rawData,
) async {
  final localNotifications = FlutterLocalNotificationsPlugin();

  const initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/launcher_icon'),
  );

  await localNotifications.initialize(initializationSettings);

  // Android notification channels are sticky: once created, sound/vibration cannot be
  // changed programmatically for the same channel id. Use a new id when adjusting
  // vibration behavior.
  // Use Android system alarm URI for reliable alarm sound (no custom file needed)
  final panicChannel = AndroidNotificationChannel(
    'guardify_panic_v4', // New channel ID to force recreation with alarm sound
    'Guardify Panic Alerts',
    description: 'Panic button emergency alerts',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    sound: const UriAndroidNotificationSound(
      'android.resource://android/raw/alarm',
    ), // System alarm sound
    vibrationPattern: Int64List.fromList(<int>[
      0,
      1000,
      500,
      1000,
      500,
      1000,
      500,
      1000,
      500,
      1000,
      500,
      1000,
      500,
      1000,
      500,
      1000,
    ]),
  );

  final androidPlugin =
      localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(panicChannel);

  Map<String, dynamic> panicData;
  if (rawData.containsKey('data')) {
    final dataField = rawData['data'];
    if (dataField is Map) {
      panicData = Map<String, dynamic>.from(dataField);
    } else {
      panicData = Map<String, dynamic>.from(rawData);
    }
  } else {
    panicData = Map<String, dynamic>.from(rawData);
  }

  final incident = panicData['IncidentName']?.toString() ??
      panicData['incidentName']?.toString() ??
      'Panic';
  final area =
      panicData['AreasName']?.toString() ?? panicData['areasName']?.toString();
  final reporter =
      panicData['Reporter']?.toString() ?? panicData['reporter']?.toString();
  final status =
      panicData['Status']?.toString() ?? panicData['status']?.toString();

  final title = 'PANIC - $incident';
  final bodyParts = <String>[];
  if (area != null && area.isNotEmpty) bodyParts.add(area);
  if (reporter != null && reporter.isNotEmpty)
    bodyParts.add('Pelapor: $reporter');
  if (status != null && status.isNotEmpty) bodyParts.add('Status: $status');
  final body =
      bodyParts.isNotEmpty ? bodyParts.join(' • ') : 'Ada situasi darurat';

  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      panicChannel.id,
      panicChannel.name,
      channelDescription: panicChannel.description,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      playSound: true,
      sound: const UriAndroidNotificationSound(
        'android.resource://android/raw/alarm',
      ), // System alarm sound
      enableVibration: true,
      visibility: NotificationVisibility.public,
      // Pattern is set at channel-level (Android 8+). Kept here for completeness.
      vibrationPattern: panicChannel.vibrationPattern,
    ),
  );

  await localNotifications.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    details,
  );
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  // Debug prints disabled
  // print('🚨 [BackgroundHandler] Received message: ${message.data}');

  // Check if this is a panic button notification
  final type = message.data['type']?.toString();

  if (type == 'panic_button') {
    // Debug prints disabled
    // print('🚨 [BackgroundHandler] Panic button notification received in background');
    try {
      await _showBackgroundPanicNotification(message.data);
    } catch (e) {
      // Debug prints disabled
      // print('⚠️ [BackgroundHandler] Failed to show panic notification: $e');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('✅ [Main] App starting...');
  AppLogger.info('✅ [Main] App starting...');

  // Filter out S3 image loading errors to reduce console noise
  FlutterError.onError = (FlutterErrorDetails details) {
    final errorString = details.exceptionAsString();
    if (errorString.contains('HTTP request failed, statusCode: 403') &&
        errorString.contains('bnp-s3-abb.s3')) {
      // Suppress S3 image loading errors - don't print anything
      return;
    }
    FlutterError.presentError(details);
  };

  final isMobile = Platform.isAndroid || Platform.isIOS;
  if (isMobile) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await PushNotificationService.instance.initialize();
    } catch (e) {
      debugPrint('⚠️ [Main] Firebase init failed: $e');
    }
  }

  // Initialize date formatting for Indonesian locale
  await initializeDateFormatting('id_ID', null);

  // Safety: clear corrupted SharedPreferences data before DI init
  // SharedPreferences.getInstance() loads ALL keys into memory
  // If api_logs key is corrupted (>2MB), it causes OOM crash
  try {
    final prefs = await SharedPreferences.getInstance();
    final logsData = prefs.getString('api_logs');
    if (logsData != null && logsData.length > 2 * 1024 * 1024) {
      debugPrint(
        '⚠️ [Main] Clearing corrupted api_logs (${logsData.length} bytes)',
      );
      await prefs.remove('api_logs');
    }
  } catch (e) {
    debugPrint('⚠️ [Main] Error checking SharedPreferences: $e');
  }

  await configureDependencies();

  // Load the white-label branding config (palette, brightness, app name, logo,
  // api base) BEFORE the app builds. It drives the ThemeController, so the
  // MaterialApp starts with the configured company's theme.
  try {
    await BrandingController.instance.loadFromAsset(rootBundle);
  } catch (e) {
    debugPrint('⚠️ [Main] Failed to load branding config: $e');
  }

  // Override with the user's persisted theme choice if present (falls back to
  // the branding config values when nothing saved).
  try {
    final prefs = await SharedPreferences.getInstance();
    await ThemeController.instance.loadFrom(prefs);
  } catch (e) {
    debugPrint('⚠️ [Main] Failed to load theme prefs: $e');
  }

  runApp(const GuardifyApp());

  // Show prominent background location disclosure and initialize the tracking
  // service only after the user explicitly consents. Google Play requires this
  // disclosure to be shown before the app accesses background location.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final hasAccepted =
        await BackgroundLocationPermissionHelper.hasAcceptedDisclosure();
    if (!hasAccepted) {
      final accepted = await BackgroundLocationPermissionHelper
          .showDisclosureWithNavigatorKey(
        AppNavigatorKey.navigatorKey,
      );
      if (!accepted) return;
    }

    try {
      await BackgroundLocationTaskManager.initialize();
      await BackgroundLocationTaskManager.registerPeriodicTask();
    } catch (e) {
      debugPrint('⚠️ [Main] Failed to initialize workmanager: $e');
      debugPrint('⚠️ [Main] Background location updates will be disabled');
    }
  });
}

class GuardifyApp extends StatefulWidget {
  const GuardifyApp({super.key});

  @override
  State<GuardifyApp> createState() => _GuardifyAppState();
}

class _GuardifyAppState extends State<GuardifyApp> {
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812), // iPhone 11 Pro design size
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return ListenableBuilder(
          listenable: Listenable.merge([
            ThemeController.instance.palette,
            ThemeController.instance.brightness,
          ]),
          builder: (context, _) {
            final controller = ThemeController.instance;
            return MaterialApp(
              navigatorKey: AppNavigatorKey.navigatorKey,
              title: BrandingController.instance.appTitle,
              debugShowCheckedModeBanner: false,
              theme: ThemeBuilder.lightOf(
                controller.currentPalette,
                seed: controller.currentSeed,
              ),
              darkTheme: ThemeBuilder.darkOf(
                controller.currentPalette,
                seed: controller.currentSeed,
              ),
              themeMode: _toThemeMode(controller.brightness.value),
              builder: (context, child) {
                return Stack(children: [child ?? const SizedBox.shrink()]);
              },
              routes: {
                '/': (context) => const _AuthGate(),
                '/home': (context) => const HomePage(),
                '/login': (context) => BlocProvider(
                      create: (context) => getIt<AuthBloc>(),
                      child: const LoginPage(),
                    ),
                '/register': (context) => BlocProvider(
                      create: (context) => getIt<AuthBloc>(),
                      child: const RegisterPage(),
                    ),
                '/reset-password': (context) => BlocProvider(
                      create: (context) => getIt<AuthBloc>(),
                      child: const ResetPasswordPage(),
                    ),
                '/bmi': (context) => const BMINavigationPage(),
                '/panic-verification': (context) => BlocProvider(
                      create: (context) => getIt<PanicButtonBloc>(),
                      child: const PanicVerificationPage(),
                    ),
                '/panic-disaster-confirmation': (context) =>
                    const PanicDisasterConfirmationPage(),
                '/panic-disaster-selection': (context) =>
                    const PanicDisasterSelectionPage(),
                '/panic-incident-form': (context) => BlocProvider(
                      create: (context) => getIt<PanicButtonBloc>(),
                      child: const PanicIncidentFormPage(),
                    ),
                '/panic-security-form': (context) => BlocProvider(
                      create: (context) => getIt<PanicButtonBloc>(),
                      child: const PanicSecurityFormPage(),
                    ),
                '/panic-confirmation': (context) => BlocProvider(
                      create: (context) => getIt<PanicButtonBloc>(),
                      child: const PanicConfirmationPage(),
                    ),
                '/panic-button-history': (context) => BlocProvider(
                      create: (context) => getIt<PanicButtonBloc>(),
                      child: const PanicButtonHistoryPage(),
                    ),
                '/profile': (context) {
                  // Get user ID from arguments or secure storage
                  final arguments = ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?;
                  final String userId = arguments?['userId'] ?? 'current_user';

                  return ProfileScreen(userId: userId);
                },
                '/cuti': (context) => const CutiPage(),
                '/cuti/form': (context) {
                  final arguments = ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?;
                  return FormAjuanCutiPage(
                    userId: arguments?['userId'] ?? 'current_user',
                    userName: arguments?['userName'] ?? 'User',
                  );
                },
                '/laporan-kegiatan': (context) {
                  return FutureBuilder<String?>(
                    future: SecurityManager.readSecurely('user_role_id'),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final roleId = snapshot.data ?? 'AGT';
                      final userRole = UserRole.fromValue(roleId);

                      // Check if user has access (semua role selain anggota)
                      if (userRole == UserRole.anggota) {
                        return Scaffold(
                          appBar: AppBar(
                            title: const Text('Akses Ditolak'),
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          body: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.block, size: 64, color: errorColor),
                                const SizedBox(height: 16),
                                Text(
                                  'Akses Ditolak',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Anda tidak memiliki akses ke halaman ini.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                  ),
                                  child: const Text('Kembali'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final arguments = ModalRoute.of(context)
                          ?.settings
                          .arguments as Map<String, dynamic>?;
                      final String userId = arguments?['userId'] ??
                          (snapshot.data != null
                              ? snapshot.data!
                              : 'current_user');

                      return BlocProvider(
                        create: (context) => getIt<LaporanKegiatanBloc>(),
                        child: LaporanKegiatanPage(
                          userId: userId,
                          userRole: userRole,
                        ),
                      );
                    },
                  );
                },
                '/cuti/detail': (context) {
                  final arguments = ModalRoute.of(context)!.settings.arguments
                      as Map<String, dynamic>;
                  return DetailCutiPage(
                    cutiId: arguments['cutiId'] as String,
                    currentUserRole:
                        arguments['currentUserRole'] as UserRole? ??
                            UserRole.anggota,
                    showActions: arguments['showActions'] as bool? ?? false,
                  );
                },
                '/chat': (context) => BlocProvider(
                      create: (context) => getIt<ChatBloc>(),
                      child: const ChatListPage(),
                    ),
                '/news': (context) => BlocProvider(
                      create: (context) => getIt<NewsBloc>(),
                      child: const NewsListPage(),
                    ),
                '/schedule': (context) {
                  return BlocProvider(
                    create: (context) => getIt<ScheduleBloc>(),
                    child: FutureBuilder<String?>(
                      future: SecurityManager.readSecurely('user_role_id'),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Scaffold(
                            body: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final roleId = snapshot.data ?? 'AGT';

                        // PJO, Deputy, dan Pengawas menggunakan halaman schedule khusus
                        if (roleId == 'PJO' ||
                            roleId == 'DPT' ||
                            roleId == 'PGW') {
                          return const SchedulePJODeputyPage();
                        }

                        // Anggota dan Danton menggunakan halaman schedule asli
                        return const SchedulePage();
                      },
                    ),
                  );
                },
                '/tugas-lanjutan': (context) {
                  final arguments = ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?;
                  final String userId = arguments?['userId'] ?? 'current_user';

                  return BlocProvider(
                    create: (context) => getIt<TugasLanjutanBloc>(),
                    child: TugasLanjutanPage(userId: userId),
                  );
                },
                '/laporan-kejadian': (context) => BlocProvider(
                      create: (context) => getIt<IncidentBloc>(),
                      child: const IncidentListPage(),
                    ),
              },
              initialRoute: '/',
            );
          },
        );
      },
    );
  }
}

ThemeMode _toThemeMode(ThemeBrightness brightness) {
  switch (brightness) {
    case ThemeBrightness.dark:
      return ThemeMode.dark;
    case ThemeBrightness.light:
      return ThemeMode.light;
    case ThemeBrightness.system:
      return ThemeMode.system;
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: SecurityManager.readSecurely(AppConstants.tokenKey),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final token = snapshot.data;
        final hasToken = token != null && token.trim().isNotEmpty;

        if (hasToken) {
          return BlocProvider(
            create: (context) => getIt<HomeBloc>(),
            child: const HomePage(),
          );
        }

        return BlocProvider(
          create: (context) => getIt<AuthBloc>(),
          child: const LoginPage(),
        );
      },
    );
  }
}
