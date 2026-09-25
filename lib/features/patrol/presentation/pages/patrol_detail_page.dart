import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/security/security_manager.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/patrol_route.dart';
import '../../domain/entities/patrol_location.dart';
import '../bloc/patrol_bloc.dart';
import '../widgets/patrol_progress_widget.dart';
import '../widgets/add_patrol_location_dialog.dart';
import '../widgets/patrol_attendance_dialog.dart';
import '../../../schedule/domain/repositories/schedule_repository.dart';
import '../../../schedule/domain/usecases/get_current_task.dart';
import '../../../home/presentation/bloc/home_bloc.dart';
import '../../../home/presentation/bloc/home_event.dart';
import '../../../home/presentation/bloc/home_state.dart';

class PatrolDetailPage extends StatefulWidget {
  final PatrolRoute route;
  final PatrolBloc? bloc; // Optional bloc from parent
  final List<RouteTask>? listRoute; // Optional ListRoute data from get_current_task
  final bool? isCheckedIn; // Checkin status from get_current API
  final bool? isCheckedOut; // Checkout status from get_current API

  const PatrolDetailPage({
    super.key,
    required this.route,
    this.bloc,
    this.listRoute,
    this.isCheckedIn,
    this.isCheckedOut,
  });

  @override
  State<PatrolDetailPage> createState() => _PatrolDetailPageState();
}

class _PatrolDetailPageState extends State<PatrolDetailPage> {
  Future<void> _loadCurrentTask(PatrolBloc bloc) async {
    try {
      final shiftId = await SecurityManager.readSecurely(
        AppConstants.shiftDetailIdKey,
      );
      
      if (shiftId != null && shiftId.isNotEmpty) {
        print('🔄 [PatrolDetailPage] Loading get_current_task...');
        
        final getCurrentTask = getIt<GetCurrentTask>();
        final taskResult = await getCurrentTask.call(idShiftDetail: shiftId);
        
        if (taskResult.isSuccess && taskResult.currentTask != null) {
          final listRoute = taskResult.currentTask!.listRoute;
          print('✅ [PatrolDetailPage] get_current_task loaded: ${listRoute.length} routes');
          
          // Log all routes for debugging
          print('🔄 [PatrolDetailPage] All routes from get_current_task:');
          for (var route in listRoute) {
            print('  - ${route.areasName} (idAreas: ${route.idAreas}, Status: ${route.status})');
          }
          
          // Use ALL routes from get_current_task
          // Each RouteTask represents one patrol location, so we need all of them
          // The filtering by idAreas will be handled in the merge logic in bloc
          print('🔄 [PatrolDetailPage] Using all ${listRoute.length} routes from get_current_task');
          
          // Update bloc with fresh data - use all routes
          if (mounted) {
            bloc.add(LoadAreasByRouteId(
              widget.route.id,
              widget.route,
              listRoute, // Use all routes, not filtered
            ));
            print('✅ [PatrolDetailPage] LoadAreasByRouteId dispatched with ${listRoute.length} routes');
          }
        } else {
          print('❌ [PatrolDetailPage] get_current_task failed: ${taskResult.failure?.message ?? "Unknown error"}');
        }
      } else {
        print('⚠️ [PatrolDetailPage] Shift ID not found in storage');
      }
    } catch (e) {
      print('❌ [PatrolDetailPage] Error loading get_current_task: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🔍 [PatrolDetailPage] build called');
    debugPrint('  - widget.isCheckedIn: ${widget.isCheckedIn}');
    debugPrint('  - route.id: ${widget.route.id}');
    debugPrint('  - route.status: ${widget.route.status}');
    
    // If bloc provided from parent, use it. Otherwise create new one.
    if (widget.bloc != null) {
      // Load get_current_task after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCurrentTask(widget.bloc!);
      });
      
      return PopScope(
        onPopInvoked: (didPop) async {
          if (didPop) {
            // Reload home page data when back
            await _reloadHomeData();
          }
        },
        child: BlocProvider.value(
          value: widget.bloc!,
          child: _buildScaffold(context),
        ),
      );
    }

    // Create new bloc if not provided (e.g., from dashboard)
    return PopScope(
      onPopInvoked: (didPop) async {
        if (didPop) {
          // Reload home page data when back
          await _reloadHomeData();
        }
      },
      child: BlocProvider(
        create: (context) {
          final newBloc = getIt<PatrolBloc>();
          // Load get_current_task after build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadCurrentTask(newBloc);
          });
          return newBloc;
        },
        child: _buildScaffold(context),
      ),
    );
  }

  Future<void> _reloadHomeData() async {
    try {
      final shiftId = await SecurityManager.readSecurely(
        AppConstants.shiftDetailIdKey,
      );
      
      if (shiftId != null && shiftId.isNotEmpty) {
        print('🔄 [PatrolDetailPage] Reloading home data on back...');
        try {
          final homeBloc = getIt<HomeBloc>();
          if (homeBloc.state is HomeLoaded) {
            homeBloc.add(LoadCurrentTaskEvent(idShiftDetail: shiftId));
            print('✅ [PatrolDetailPage] Home data reload triggered');
          }
        } catch (e) {
          print('⚠️ [PatrolDetailPage] Could not reload home data: $e');
        }
      }
    } catch (e) {
      print('❌ [PatrolDetailPage] Error reloading home data: $e');
    }
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Patroli Hari Ini',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: BlocBuilder<PatrolBloc, PatrolState>(
        builder: (context, state) {
          if (state is PatrolLoading) {
            return Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            );
          }

          if (state is PatrolError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${state.message}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Use route from state if available, otherwise use the prop route
          final currentRoute = (state is PatrolLoaded && state.selectedRoute != null)
              ? state.selectedRoute!
              : widget.route;

          final completedCount = currentRoute.locations
              .where((loc) => loc.status == PatrolLocationStatus.completed)
              .length;
          final totalCount = currentRoute.locations.length;

          // Prefer RouteName from get_current_task API if available
          final effectiveListRoute = (state is PatrolLoaded && state.listRoute != null)
              ? state.listRoute
              : widget.listRoute;

          RouteTask? matchedRoute;
          final listRoute = effectiveListRoute;
          if (listRoute != null && listRoute.isNotEmpty) {
            for (final r in listRoute) {
              if (r.idAreas == currentRoute.id) {
                matchedRoute = r;
                break;
              }
            }
            matchedRoute ??= listRoute.first;
          }

          final routeNameFromApi = matchedRoute?.routeName;
          final routeDisplayName =
              routeNameFromApi != null ? routeNameFromApi : currentRoute.name;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Progress Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      PatrolProgressWidget(
                        completedCount: completedCount,
                        totalCount: totalCount,
                        size: 120,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        completedCount == totalCount && totalCount > 0
                            ? 'Patroli Selesai'
                            : 'Patroli Selesai',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Route Title
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$routeDisplayName (${currentRoute.locations.length} Lokasi)*',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Location List
                ...currentRoute.locations.asMap().entries.map((entry) {
                  final index = entry.key;
                  final location = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _LocationCard(
                      location: location,
                      locationNumber: index + 1,
                      isCheckedIn: widget.isCheckedIn,
                      isCheckedOut: widget.isCheckedOut,
                      onAbsenTap: () async {
                        final result = await showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (dialogContext) => BlocProvider.value(
                            value: context.read<PatrolBloc>(),
                            child: PatrolAttendanceDialog(
                              routeId: currentRoute.id,
                              locations: currentRoute.locations,
                              currentLocation: location,
                              listRoute: widget.listRoute,
                            ),
                          ),
                        );
                        
                        // If success, show success dialog and reload
                        if (result == true) {
                          // Reload get_current_task to refresh list data (same as add location)
                          print('🔄 [PatrolDetailPage] Check point submitted successfully, reloading get_current_task...');
                          final bloc = widget.bloc ?? context.read<PatrolBloc>();
                          await _loadCurrentTask(bloc);
                          
                          // Show success dialog
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (dialogContext) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF8B0000),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.thumb_up,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Absen Patroli Berhasil',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Terima Kasih',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(dialogContext).pop();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF8B0000),
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text(
                                        'OK',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // Additional Patrol Section
                if (currentRoute.additionalLocations.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Patroli Tambahan (${currentRoute.additionalLocations.length} Lokasi)*',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...currentRoute.additionalLocations.asMap().entries.map((entry) {
                    final location = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _LocationCard(
                        location: location,
                        locationNumber: currentRoute.locations.length + entry.key + 1,
                        isCheckedIn: widget.isCheckedIn,
                        isCheckedOut: widget.isCheckedOut,
                        onAbsenTap: () async {
                          final result = await showDialog<bool>(
                            context: context,
                            barrierDismissible: false,
                            builder: (dialogContext) => BlocProvider.value(
                              value: context.read<PatrolBloc>(),
                              child: PatrolAttendanceDialog(
                                routeId: currentRoute.id,
                                locations:
                                    currentRoute.locations + currentRoute.additionalLocations,
                                currentLocation: location,
                                listRoute: widget.listRoute,
                              ),
                            ),
                          );
                          
                          // If success, reload get_current_task to refresh list data
                          if (result == true) {
                            print('🔄 [PatrolDetailPage] Check point submitted successfully (additional), reloading get_current_task...');
                            final bloc = widget.bloc ?? context.read<PatrolBloc>();
                            await _loadCurrentTask(bloc);
                            
                            // Show success dialog
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (dialogContext) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF8B0000),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.thumb_up,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    const Text(
                                      'Absen Patroli Berhasil',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Terima Kasih',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.of(dialogContext).pop();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF8B0000),
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: const Text(
                                          'OK',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  }),
                ],

                // Add Location Button
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  child: ElevatedButton(
                    onPressed: (widget.isCheckedIn != true || (widget.isCheckedOut ?? false) || (currentRoute.status == PatrolRouteStatus.completed)) ? null : () async {
                      debugPrint('🔍 [PatrolDetailPage] Tambah Lokasi Patroli button pressed');
                      debugPrint('  - widget.isCheckedIn: ${widget.isCheckedIn}');
                      debugPrint('  - widget.isCheckedOut: ${widget.isCheckedOut}');
                      debugPrint('  - currentRoute.status: ${currentRoute.status}');
                      final patrolBloc = context.read<PatrolBloc>();
                      final result = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => BlocProvider.value(
                          value: patrolBloc,
                          child: AddPatrolLocationDialog(
                            routeId: currentRoute.id,
                            existingLocations:
                                currentRoute.locations.map((loc) => loc.name).toList(),
                            onLocationAdded: () {
                              // Data already reloaded by BLoC
                              // No need to do anything here
                            },
                            listRoute: widget.listRoute,
                          ),
                        ),
                      );
                      
                      // If insert was successful, reload get_current_task in patrol page
                      if (result == true) {
                        print('🔄 [PatrolDetailPage] Location added successfully, reloading get_current_task...');
                        // Reload get_current_task for patrol page
                        final bloc = widget.bloc ?? context.read<PatrolBloc>();
                        await _loadCurrentTask(bloc);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '+ Tambah Lokasi Patroli',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 80), // Bottom padding
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final PatrolLocation location;
  final int locationNumber;
  final VoidCallback onAbsenTap;
  final bool? isCheckedIn; // Checkin status from get_current API
  final bool? isCheckedOut; // Checkout status from get_current API

  const _LocationCard({
    required this.location,
    required this.locationNumber,
    required this.onAbsenTap,
    this.isCheckedIn,
    this.isCheckedOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with location and status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lokasi $locationNumber',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      location.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              // Status indicator
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: location.status == PatrolLocationStatus.completed
                      ? const Color(0xFFE8EAF6)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  location.status == PatrolLocationStatus.completed
                      ? 'Selesai'
                      : 'Belum',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: location.status == PatrolLocationStatus.completed
                        ? const Color(0xFF5C6BC0)
                        : const Color(0xFFE57373),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Info and Button Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Jam Patroli',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                location.completedAt != null
                                    ? '${location.completedAt!.hour.toString().padLeft(2, '0')}.${location.completedAt!.minute.toString().padLeft(2, '0')} WIB'
                                    : '-',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bukti Patroli',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (location.proofImagePath != null)
                                ElevatedButton(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => Dialog(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            AppBar(
                                              title: const Text('Bukti Patroli'),
                                              leading: IconButton(
                                                icon: const Icon(Icons.close),
                                                onPressed: () => Navigator.pop(context),
                                              ),
                                            ),
                                            Image.network(
                                              location.proofImagePath!,
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) {
                                                return const Padding(
                                                  padding: EdgeInsets.all(16.0),
                                                  child: Text('Gagal memuat gambar'),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: const Text(
                                    'Lihat',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              else
                                const Text(
                                  '-',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Absen Button - disabled jika belum check in atau sudah check out
              ElevatedButton(
                onPressed: (location.status == PatrolLocationStatus.completed || 
                           isCheckedIn != true ||
                           (isCheckedOut ?? false))
                    ? null
                    : () {
                      debugPrint('🔍 [PatrolDetailPage] Absen button pressed');
                      debugPrint('  - isCheckedIn: $isCheckedIn');
                      debugPrint('  - isCheckedOut: $isCheckedOut');
                      debugPrint('  - location.status: ${location.status}');
                      onAbsenTap();
                    },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      (location.status == PatrolLocationStatus.completed || 
                       isCheckedIn != true ||
                       (isCheckedOut ?? false))
                          ? Colors.grey[400]
                          : primaryColor,
                  disabledBackgroundColor: Colors.grey[400],
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Absen',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
