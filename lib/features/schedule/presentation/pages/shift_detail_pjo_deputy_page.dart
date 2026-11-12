import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/design/colors.dart';
import '../../../chat/domain/entities/chat.dart';
import '../../../chat/presentation/bloc/chat_bloc.dart';
import '../../../chat/presentation/bloc/chat_event.dart';
import '../../../chat/presentation/pages/chat_conversation_page.dart';
import '../bloc/schedule_bloc.dart';
import '../../domain/entities/shift_schedule.dart';

/// Shift Detail Page for PJO, Deputy & Pengawas
///
/// Halaman detail shift khusus untuk PJO, Deputy, dan Pengawas
/// dengan tampilan:
/// - Header dengan waktu, status icons, dan calendar icon
/// - Tab untuk Shift Pagi dan Shift Malam
/// - Total personil per shift
/// - Jam mulai dan selesai bekerja
/// - Lokasi per pos (Pos Gajah, Pos Merpati, Pos Ayam)
/// - Tim jaga dengan route assignment dalam layout 2 kolom
class ShiftDetailPJODeputyPage extends StatefulWidget {
  final String userId;
  final DateTime date;

  const ShiftDetailPJODeputyPage({
    super.key,
    required this.userId,
    required this.date,
  });

  @override
  State<ShiftDetailPJODeputyPage> createState() =>
      _ShiftDetailPJODeputyPageState();
}

class _ShiftDetailPJODeputyPageState extends State<ShiftDetailPJODeputyPage>
    with SingleTickerProviderStateMixin {
  bool _hasLoadedData = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<ScheduleBloc, ScheduleState>(
        builder: (context, state) {
          // Load shift detail when first built
          if (!_hasLoadedData && !state.isLoadingDetail) {
            _hasLoadedData = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<ScheduleBloc>().add(LoadScheduleDetail(
                    userId: widget.userId,
                    date: widget.date,
                  ));
            });
          }

          if (state.isLoadingDetail) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.selectedShift == null) {
            return _buildEmptyState();
          }

          return _buildContent(state.selectedShift!);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(gradient: rumaraHeaderGradient),
      child: SafeArea(
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Jadwal Kerja',
                style: TextStyle(color: Colors.white),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today,
                        size: 64.r, color: Colors.white70),
                    SizedBox(height: 16.h),
                    Text(
                      'Tidak ada jadwal shift',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ShiftSchedule shift) {
    return Container(
      decoration: BoxDecoration(gradient: rumaraHeaderGradient),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            SizedBox(height: 16.h),

            // Date Display
            _buildDateDisplay(),
            SizedBox(height: 24.h),

            // Content Card
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(32.r),
                  ),
                ),
                child: Column(
                  children: [
                    // Tabs
                    _buildTabs(),

                    // Tab Content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildShiftContent(shift, 'Pagi'),
                          _buildShiftContent(shift, 'Malam'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // Get current time
    final now = DateTime.now();
    final timeString = DateFormat('HH:mm').format(now);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Column(
        children: [
          // Top row: Time, title, status icons
          Row(
            children: [
              // Time
              Text(
                timeString,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              // Status icons (Network signal and Battery)
              Row(
                children: [
                  Icon(Icons.signal_cellular_alt, 
                    color: Colors.white, 
                    size: 18.r),
                  SizedBox(width: 8.w),
                  Icon(Icons.battery_full, 
                    color: Colors.white, 
                    size: 18.r),
                ],
              ),
            ],
          ),
          SizedBox(height: 12.h),
          // Second row: Back button and title
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.pop(context),
              ),
              SizedBox(width: 8.w),
              Text(
                'Jadwal Kerja',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateDisplay() {
    return Column(
      children: [
        Icon(
          Icons.calendar_month,
          color: Colors.white,
          size: 48.r,
        ),
        SizedBox(height: 8.h),
        Text(
          DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(widget.date),
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
      child: TabBar(
        controller: _tabController,
        labelColor: primaryColor,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: primaryColor,
        indicatorWeight: 3,
        labelStyle: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(text: 'Shift Pagi'),
          Tab(text: 'Shift Malam'),
        ],
      ),
    );
  }

  Widget _buildShiftContent(ShiftSchedule shift, String shiftType) {
    // Filter team members by shift type
    // Position field contains "AreaName|ShiftName" format for pengawas schedule
    final filteredMembers = shift.teamMembers.where((member) {
      // Check if position contains shift information
      if (member.position.contains('|')) {
        final parts = member.position.split('|');
        if (parts.length >= 2) {
          final memberShiftName = parts[1].toLowerCase();
          // Match shift type
          if (shiftType == 'Pagi') {
            return memberShiftName.contains('pagi');
          } else if (shiftType == 'Malam') {
            return memberShiftName.contains('malam');
          }
        }
      }
      // If no shift info in position, include in both (backward compatibility)
      return true;
    }).toList();
    
    final totalPersonil = filteredMembers.length;
    final jamMulai = shiftType == 'Pagi' ? '07.00 WIB' : '19.00 WIB';
    final jamSelesai = shiftType == 'Pagi' ? '19.00 WIB' : '07.00 WIB';

    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shift Info - Inline text style matching the image
          _buildShiftInfo('Total Personil', '$totalPersonil Orang'),
          SizedBox(height: 12.h),
          _buildShiftInfo('Jam Mulai Bekerja', jamMulai),
          SizedBox(height: 12.h),
          _buildShiftInfo('Jam Selesai Bekerja', jamSelesai),
          
          SizedBox(height: 24.h),

          // Lokasi Sections
          ...shift.patrolLocations.map((location) {
            return Padding(
              padding: EdgeInsets.only(bottom: 24.h),
              child: _buildLocationSection(location, filteredMembers, shiftType),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildShiftInfo(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: primaryColor,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          ': $value',
          style: TextStyle(
            color: primaryColor,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection(
      PatrolLocation location, List<TeamMember> allMembers, String shiftType) {
    // Filter team members untuk lokasi ini
    // Position field contains "AreaName|ShiftName" format for pengawas schedule
    final locationMembers = allMembers.where((member) {
      // Extract area name from position (before |)
      final areaName = member.position.contains('|') 
          ? member.position.split('|')[0] 
          : member.position;
      return areaName == location.name;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lokasi: ${location.name}',
          style: TextStyle(
            color: primaryColor,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12.h),

        Text(
          'Tim Jaga',
          style: TextStyle(
            color: primaryColor,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12.h),

        // Team Grid - 2 columns as per image
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
          ),
          itemCount: locationMembers.length,
          itemBuilder: (context, index) {
            final member = locationMembers[index];
            // Simulate route assignment - in real app, this should come from API
            final route = _getRouteForMember(member, index);
            return _buildTeamMemberCard(member, route);
          },
        ),
      ],
    );
  }

  Widget _buildTeamMemberCard(TeamMember member, String route) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Profile Picture
          CircleAvatar(
            radius: 30.r,
            backgroundImage:
                member.photoUrl != null ? NetworkImage(member.photoUrl!) : null,
            backgroundColor: Colors.grey.shade300,
            child: member.photoUrl == null
                ? Icon(Icons.person, size: 30.r, color: Colors.grey.shade600)
                : null,
          ),
          SizedBox(height: 8.h),
          
          // Name
          Text(
            member.name,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4.h),
          
          // Route
          Text(
            route,
            style: TextStyle(
              fontSize: 12.sp,
              color: primaryColor,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4.h),
          
          // Status
          Text(
            'Masuk',
            style: TextStyle(
              fontSize: 12.sp,
              color: primaryColor,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          
          // Kirim Pesan Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                // Get or create ChatBloc
                ChatBloc chatBloc;
                try {
                  chatBloc = context.read<ChatBloc>();
                } catch (e) {
                  // If ChatBloc is not available in context, create new one
                  chatBloc = getIt<ChatBloc>();
                }

                // Create conversation with the team member
                chatBloc.add(ChatCreateConversation(memberUserIds: [member.id], name: member.name));

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
                        name: member.name,
                        type: ChatType.direct,
                        participantIds: [member.id],
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
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: EdgeInsets.symmetric(vertical: 8.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                elevation: 0,
              ),
              child: Text(
                'Kirim Pesan',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper method to simulate route assignment
  // In real implementation, this should come from API data
  String _getRouteForMember(TeamMember member, int index) {
    final routes = ['Rute A', 'Rute B', 'Rute BB', 'Rute AN', 'Rute C', 
                    'Rute D', 'Rute N', 'Rute M', 'Rute P', 'Rute L', 
                    'Rute J', 'Rute Y'];
    return routes[index % routes.length];
  }
}
