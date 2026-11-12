import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../chat/domain/entities/chat.dart';
import '../../../chat/presentation/bloc/chat_bloc.dart';
import '../../../chat/presentation/bloc/chat_event.dart';
import '../../../chat/presentation/pages/chat_conversation_page.dart';
import '../../../schedule/domain/repositories/schedule_repository.dart';
import '../../../../shared/widgets/rumara_app_bar.dart';

/// Model untuk personil dengan lokasi
class PersonnelLocation {
  final String userId;
  final String fullname;
  final String? images;
  final double latitude;
  final double longitude;
  final String? locationName; // Nama lokasi seperti "Pos Gajah"
  final bool isCheckedIn;
  final String? checkinTime;

  const PersonnelLocation({
    required this.userId,
    required this.fullname,
    this.images,
    required this.latitude,
    required this.longitude,
    this.locationName,
    this.isCheckedIn = false,
    this.checkinTime,
  });
}

class LocationTrackingPage extends StatefulWidget {
  final List<CurrentShiftPersonnel> personnelList;

  const LocationTrackingPage({
    super.key,
    required this.personnelList,
  });

  @override
  State<LocationTrackingPage> createState() => _LocationTrackingPageState();
}

class _LocationTrackingPageState extends State<LocationTrackingPage> {
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  List<PersonnelLocation> _personnelLocations = [];
  List<PersonnelLocation> _filteredLocations = [];
  String? _selectedLocationFilter;

  @override
  void initState() {
    super.initState();
    _loadPersonnelLocations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Load lokasi personil (untuk sekarang menggunakan mock data)
  /// Nanti bisa diintegrasikan dengan API yang menyediakan lokasi real-time
  void _loadPersonnelLocations() {
    // Mock data lokasi personil
    // Nanti bisa diganti dengan API call untuk mendapatkan lokasi real-time
    final mockLocations = <PersonnelLocation>[];
    
    // Jika tidak ada personil, set default location
    if (widget.personnelList.isEmpty) {
      setState(() {
        _personnelLocations = mockLocations;
        _filteredLocations = mockLocations;
      });
      return;
    }
    
    // Generate mock locations untuk setiap personil
    for (int i = 0; i < widget.personnelList.length; i++) {
      final personnel = widget.personnelList[i];
      // Mock coordinates (Jakarta area)
      final baseLat = -6.200000;
      final baseLng = 106.816666;
      final latOffset = (i * 0.01) % 0.1; // Spread locations
      final lngOffset = (i * 0.01) % 0.1;
      
      // Mock location names
      final locationNames = ['Pos Gajah', 'Pos Merpati', 'Pos Macan', 'Pos Merak', 'Pos Utama'];
      final locationName = locationNames[i % locationNames.length];
      
      mockLocations.add(
        PersonnelLocation(
          userId: personnel.userId,
          fullname: personnel.fullname,
          images: personnel.images,
          latitude: baseLat + latOffset,
          longitude: baseLng + lngOffset,
          locationName: locationName,
          isCheckedIn: i % 3 != 0, // Mock: some are checked in
          checkinTime: i % 3 != 0 ? '08:00' : null,
        ),
      );
    }
    
    setState(() {
      _personnelLocations = mockLocations;
      _filteredLocations = mockLocations;
    });
    
    // Zoom ke lokasi setelah data dimuat
    if (mockLocations.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _zoomToPersonnel();
      });
    }
  }

  void _filterLocations() {
    final query = _searchController.text.toLowerCase().trim();
    final locationFilter = _selectedLocationFilter;
    
    setState(() {
      _filteredLocations = _personnelLocations.where((personnel) {
        // Filter by search query
        final matchesSearch = query.isEmpty ||
            personnel.fullname.toLowerCase().contains(query) ||
            (personnel.locationName?.toLowerCase().contains(query) ?? false);
        
        // Filter by location
        final matchesLocation = locationFilter == null ||
            locationFilter.isEmpty ||
            personnel.locationName == locationFilter;
        
        return matchesSearch && matchesLocation;
      }).toList();
    });
    
    // Zoom ke lokasi personil yang terfilter (jika ada)
    if (_filteredLocations.isNotEmpty) {
      _zoomToPersonnel();
    }
  }

  void _zoomToPersonnel() {
    if (_filteredLocations.isEmpty) return;
    
    // Calculate bounds untuk semua personil yang terfilter
    final lats = _filteredLocations.map((p) => p.latitude).toList();
    final lngs = _filteredLocations.map((p) => p.longitude).toList();
    
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);
    
    // Calculate center
    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    
    // Calculate zoom level based on bounds
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    
    double zoom = 15.0;
    if (maxDiff > 0.1) {
      zoom = 12.0;
    } else if (maxDiff > 0.05) {
      zoom = 13.0;
    } else if (maxDiff > 0.01) {
      zoom = 14.0;
    }
    
    // Animate to center
    _mapController.move(
      LatLng(centerLat, centerLng),
      zoom,
    );
  }

  /// Zoom map ke marker personil tertentu
  void _zoomToMarker(PersonnelLocation personnel) {
    final lat = personnel.latitude;
    final lng = personnel.longitude;
    
    // Validasi koordinat
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      print('⚠️ [LocationTracking] Invalid coordinates for marker zoom: $lat, $lng');
      return;
    }
    
    // Zoom level untuk fokus ke marker individual
    const double zoom = 16.0;
    
    print('📍 [LocationTracking] Zooming to marker: ${personnel.fullname} at ($lat, $lng)');
    
    try {
      _mapController.move(
        LatLng(lat, lng),
        zoom,
      );
    } catch (e) {
      print('❌ [LocationTracking] Error zooming to marker: $e');
    }
  }

  void _showPersonnelDetail(PersonnelLocation personnel) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => Container(
        padding: REdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 30.r,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: personnel.images != null && personnel.images!.isNotEmpty
                      ? NetworkImage(personnel.images!)
                      : null,
                  child: personnel.images == null || personnel.images!.isEmpty
                      ? Icon(Icons.person, size: 30.sp, color: Colors.grey[600])
                      : null,
                ),
                16.horizontalSpace,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        personnel.fullname,
                        style: TS.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      4.verticalSpace,
                      if (personnel.locationName != null)
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16.sp, color: primaryColor),
                            4.horizontalSpace,
                            Text(
                              personnel.locationName!,
                              style: TS.bodySmall.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey[600]),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            24.verticalSpace,
            
            // Detail Information
            _buildDetailRow('Status', personnel.isCheckedIn ? 'Masuk' : 'Belum Masuk',
                personnel.isCheckedIn ? successColor : errorColor),
            if (personnel.checkinTime != null)
              _buildDetailRow('Jam Masuk', personnel.checkinTime!),
            _buildDetailRow('Lokasi', 
                '${personnel.latitude.toStringAsFixed(6)}, ${personnel.longitude.toStringAsFixed(6)}'),
            
            24.verticalSpace,
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      // Get or create ChatBloc
                      ChatBloc chatBloc;
                      try {
                        chatBloc = context.read<ChatBloc>();
                      } catch (e) {
                        // If ChatBloc is not available in context, create new one
                        chatBloc = getIt<ChatBloc>();
                      }

                      Navigator.pop(context);

                      // Create conversation with the personnel
                      chatBloc.add(ChatCreateConversation(memberUserIds: [personnel.userId], name: personnel.fullname));

                      // Wait for conversation to be created
                      await Future.delayed(const Duration(milliseconds: 500));

                      // Navigate to conversation page
                      if (mounted) {
                        final currentState = chatBloc.state;
                        if (currentState.selectedChatId != null) {
                          // Find the chat that was just created
                          final newChat = currentState.chats.firstWhere(
                            (chat) => chat.id == currentState.selectedChatId,
                            orElse: () => Chat(
                              id: currentState.selectedChatId!,
                              name: personnel.fullname,
                              type: ChatType.direct,
                              participantIds: [personnel.userId],
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
                        }
                      }
                    },
                    icon: Icon(Icons.message, size: 20.sp),
                    label: Text('Kirim Pesan', style: TS.bodyMedium),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor),
                      padding: REdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                12.horizontalSpace,
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Implement view detail
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Fitur detail personil sedang dalam pengembangan')),
                      );
                    },
                    icon: Icon(Icons.visibility, size: 20.sp, color: Colors.white),
                    label: Text('Lihat Detail', style: TS.bodyMedium.copyWith(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: REdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            
            16.verticalSpace,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: REdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100.w,
            child: Text(
              label,
              style: TS.bodyMedium.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TS.bodyMedium.copyWith(
                color: valueColor ?? Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const RumaraAppBar(title: 'Lacak Lokasi'),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: REdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Ketik nama personil / nama lokasi',
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onChanged: (_) => _filterLocations(),
            ),
          ),
          
          // Filter Chips
          SizedBox(
            height: 50.h,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: REdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('Semua', null),
                8.horizontalSpace,
                _buildFilterChip('Pos Gajah', 'Pos Gajah'),
                8.horizontalSpace,
                _buildFilterChip('Pos Merpati', 'Pos Merpati'),
                8.horizontalSpace,
                _buildFilterChip('Pos Macan', 'Pos Macan'),
                8.horizontalSpace,
                _buildFilterChip('Pos Merak', 'Pos Merak'),
              ],
            ),
          ),
          
          16.verticalSpace,
          
          // Map dengan flutter_map (OpenStreetMap)
          Expanded(
            child: Container(
              margin: REdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _filteredLocations.isNotEmpty
                            ? LatLng(
                                _filteredLocations.first.latitude,
                                _filteredLocations.first.longitude,
                              )
                            : const LatLng(-6.200000, 106.816666), // Default Jakarta
                        initialZoom: 15.0,
                        minZoom: 10.0,
                        maxZoom: 18.0,
                        onTap: (tapPosition, point) {
                          // Handle tap on map (optional)
                        },
                      ),
                      children: [
                        // OpenStreetMap Tile Layer
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.rumarasecurity.app',
                          maxZoom: 19,
                          tileProvider: NetworkTileProvider(),
                        ),
                        
                        // Markers untuk personil (hanya jika ada)
                        if (_filteredLocations.isNotEmpty)
                          MarkerLayer(
                            markers: _filteredLocations.map((personnel) {
                              return Marker(
                                point: LatLng(
                                  personnel.latitude,
                                  personnel.longitude,
                                ),
                                width: 60,
                                height: 60,
                                alignment: Alignment.center,
                                child: GestureDetector(
                                  onTap: () {
                                    _zoomToMarker(personnel);
                                    _showPersonnelDetail(personnel);
                                  },
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Outer circle (status indicator)
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: personnel.isCheckedIn 
                                              ? successColor.withOpacity(0.2)
                                              : errorColor.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: personnel.isCheckedIn 
                                                ? successColor
                                                : errorColor,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      // Avatar atau icon
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ClipOval(
                                          child: personnel.images != null && 
                                                 personnel.images!.isNotEmpty
                                              ? Image.network(
                                                  personnel.images!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      color: primaryColor,
                                                      child: Icon(
                                                        Icons.person,
                                                        size: 24,
                                                        color: Colors.white,
                                                      ),
                                                    );
                                                  },
                                                )
                                              : Container(
                                                  color: primaryColor,
                                                  child: Icon(
                                                    Icons.person,
                                                    size: 24,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                    
                    // Empty state overlay (jika tidak ada personil)
                    if (_filteredLocations.isEmpty)
                      Container(
                        color: Colors.white.withOpacity(0.9),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_off,
                                size: 64.sp,
                                color: Colors.grey[400],
                              ),
                              16.verticalSpace,
                              Text(
                                'Tidak ada personil ditemukan',
                                style: TS.bodyMedium.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // Tombol zoom in/out
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Column(
                        children: [
                          // Zoom In
                          FloatingActionButton(
                            onPressed: () {
                              try {
                                final currentZoom = _mapController.camera.zoom;
                                final currentCenter = _mapController.camera.center;
                                final newZoom = (currentZoom + 1).clamp(10.0, 18.0);
                                _mapController.move(currentCenter, newZoom);
                              } catch (e) {
                                print('⚠️ [LocationTracking] Error zooming in: $e');
                              }
                            },
                            backgroundColor: Colors.white,
                            mini: true,
                            heroTag: 'zoom_in',
                            child: Icon(Icons.add, color: primaryColor),
                          ),
                          8.verticalSpace,
                          // Zoom Out
                          FloatingActionButton(
                            onPressed: () {
                              try {
                                final currentZoom = _mapController.camera.zoom;
                                final currentCenter = _mapController.camera.center;
                                final newZoom = (currentZoom - 1).clamp(10.0, 18.0);
                                _mapController.move(currentCenter, newZoom);
                              } catch (e) {
                                print('⚠️ [LocationTracking] Error zooming out: $e');
                              }
                            },
                            backgroundColor: Colors.white,
                            mini: true,
                            heroTag: 'zoom_out',
                            child: Icon(Icons.remove, color: primaryColor),
                          ),
                        ],
                      ),
                    ),
                    
                    // Floating action button untuk zoom ke semua personil
                    if (_filteredLocations.isNotEmpty)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: FloatingActionButton(
                          onPressed: _zoomToPersonnel,
                          backgroundColor: primaryColor,
                          child: Icon(Icons.my_location, color: Colors.white),
                          mini: true,
                          heroTag: 'my_location',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          
          16.verticalSpace,
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value) {
    final isSelected = _selectedLocationFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedLocationFilter = isSelected ? null : value;
        });
        _filterLocations();
      },
      selectedColor: primaryColor.withOpacity(0.2),
      checkmarkColor: primaryColor,
      labelStyle: TS.bodyMedium.copyWith(
        color: isSelected ? primaryColor : Colors.black87,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

