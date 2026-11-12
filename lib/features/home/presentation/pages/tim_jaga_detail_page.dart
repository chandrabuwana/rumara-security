import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/user_role_helper.dart';
import '../../../chat/domain/entities/chat.dart';
import '../../../chat/presentation/bloc/chat_bloc.dart';
import '../../../chat/presentation/bloc/chat_event.dart';
import '../../../chat/presentation/pages/chat_conversation_page.dart';
import '../../../laporan_kegiatan/domain/entities/laporan_kegiatan_entity.dart';
import '../../../laporan_kegiatan/domain/repositories/laporan_kegiatan_repository.dart';
import '../../../laporan_kegiatan/presentation/bloc/laporan_kegiatan_bloc.dart';
import '../../../laporan_kegiatan/presentation/pages/laporan_kegiatan_detail_page.dart';
import '../../../schedule/domain/entities/shift_schedule.dart';
import '../../../schedule/domain/repositories/schedule_repository.dart';
import '../../../../shared/widgets/rumara_app_bar.dart';

/// Halaman Tim Jaga Hari Ini dengan 2 tab per shift (Shift Pagi, Shift Malam)
class TimJagaDetailPage extends StatefulWidget {
  const TimJagaDetailPage({super.key});

  @override
  State<TimJagaDetailPage> createState() => _TimJagaDetailPageState();
}

class _TimJagaDetailPageState extends State<TimJagaDetailPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedAreaFilter;
  ShiftSchedule? _shiftDetail;
  bool _isLoading = true;
  String? _errorMessage;
  late TabController _tabController;
  Map<String, String> _namaToLaporanId = {};
  UserRole _userRole = UserRole.pengawas;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() => _selectedAreaFilter = null);
      }
    });
    _loadSchedule();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      _userRole = await UserRoleHelper.getUserRole();

      final scheduleRepository = getIt<ScheduleRepository>();
      final laporanRepository = getIt<LaporanKegiatanRepository>();
      final today = DateTime.now();

      final scheduleResult =
          await scheduleRepository.getSchedulePengawas(date: today);

      final laporanMap = <String, String>{};
      // Tim Jaga Hari Ini hanya menampilkan laporan dengan status WAITING (Menunggu Verifikasi)
      final laporanResult = await laporanRepository.getLaporanList(
        status: LaporanStatus.waiting,
        start: 1,
        length: 100,
      );
      laporanResult.fold(
        (_) => {},
        (list) {
          for (final l in list) {
            if (l.id.isNotEmpty && l.namaPersonil.isNotEmpty) {
              laporanMap[l.namaPersonil.trim()] = l.id;
            }
          }
        },
      );

      if (mounted) {
        if (scheduleResult.isSuccess && scheduleResult.shiftDetail != null) {
          setState(() {
            _shiftDetail = scheduleResult.shiftDetail;
            _namaToLaporanId = laporanMap;
            _isLoading = false;
          });
        } else {
          setState(() {
            _shiftDetail = null;
            _namaToLaporanId = laporanMap;
            _isLoading = false;
            _errorMessage = 'Tidak ada jadwal tersedia';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat data';
        });
      }
    }
  }

  /// Filter team members by shift (position contains "|Shift Pagi" or "|Shift Malam")
  List<TeamMember> _getTeamMembersForShift(String shiftName) {
    if (_shiftDetail == null) return [];
    return _shiftDetail!.teamMembers
        .where((m) => m.position.endsWith('|$shiftName'))
        .toList();
  }

  /// Get area name from position (format: "AreaName|ShiftName")
  String _getAreaName(TeamMember member) {
    return member.position.contains('|')
        ? member.position.split('|')[0]
        : member.position;
  }

  /// Get all unique areas for a shift
  List<String> _getAllAreasForShift(String shiftName) {
    final members = _getTeamMembersForShift(shiftName);
    final areas = <String>{};
    for (final m in members) {
      areas.add(_getAreaName(m));
    }
    return areas.toList()..sort();
  }

  /// Filter and group personnel by area for a shift
  Map<String, List<TeamMember>> _getFilteredGroupedPersonnel(String shiftName) {
    final members = _getTeamMembersForShift(shiftName);
    final query = _searchController.text.toLowerCase().trim();
    final grouped = <String, List<TeamMember>>{};

    for (final member in members) {
      final area = _getAreaName(member);
      final matchesSearch = query.isEmpty ||
          member.name.toLowerCase().contains(query) ||
          area.toLowerCase().contains(query);
      final matchesArea = _selectedAreaFilter == null ||
          _selectedAreaFilter!.isEmpty ||
          area == _selectedAreaFilter;

      if (matchesSearch && matchesArea) {
        grouped.putIfAbsent(area, () => []).add(member);
      }
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: RumaraAppBar(title: 'Tim Jaga Hari Ini', bottom: PreferredSize(
          preferredSize: Size.fromHeight(48.h),
          child: _shiftDetail != null
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelStyle: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.normal,
                    ),
                    tabs: const [
                      Tab(text: 'Shift Pagi'),
                      Tab(text: 'Shift Malam'),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        )),
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
                      border: Border.all(color: primaryColor),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
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
                Container(
                  width: 48.w,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: PopupMenuButton<String>(
                    icon: Icon(Icons.filter_list,
                        color: Colors.white, size: 20.sp),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    onOpened: () {
                      setState(() {});
                    },
                    itemBuilder: (context) {
                      final shiftName = _tabController.index == 0
                          ? 'Shift Pagi'
                          : 'Shift Malam';
                      final allAreas = _getAllAreasForShift(shiftName);
                      return [
                        PopupMenuItem(
                          value: null,
                          child: Text(
                            'Semua',
                            style: TS.bodyMedium.copyWith(
                              color: _selectedAreaFilter == null
                                  ? primaryColor
                                  : neutral90,
                              fontWeight: _selectedAreaFilter == null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        ...allAreas.map((area) => PopupMenuItem(
                              value: area,
                              child: Text(
                                area,
                                style: TS.bodyMedium.copyWith(
                                  color: _selectedAreaFilter == area
                                      ? primaryColor
                                      : neutral90,
                                  fontWeight: _selectedAreaFilter == area
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            )),
                      ];
                    },
                    onSelected: (value) {
                      setState(() {
                        _selectedAreaFilter = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline,
                                size: 64.sp, color: neutral50),
                            16.verticalSpace,
                            Text(
                              _errorMessage!,
                              style: TS.bodyMedium.copyWith(color: neutral70),
                            ),
                          ],
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildShiftContent('Shift Pagi'),
                          _buildShiftContent('Shift Malam'),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftContent(String shiftName) {
    final grouped = _getFilteredGroupedPersonnel(shiftName);

    if (grouped.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64.sp, color: neutral50),
            16.verticalSpace,
            Text(
              'Tidak ada personil di $shiftName',
              style: TS.bodyMedium.copyWith(color: neutral70),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final area = grouped.keys.toList()[index];
        final personnelList = grouped[area]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(
                  top: index > 0 ? 16.h : 0, bottom: 8.h),
              child: Text(
                area,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: neutral90,
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8.w,
                mainAxisSpacing: 8.h,
                childAspectRatio: 0.7,
              ),
              itemCount: personnelList.length,
              itemBuilder: (context, idx) {
                final member = personnelList[idx];
                return _buildPersonnelCard(member, area);
              },
            ),
          ],
        );
      },
    );
  }

  void _onPersonnelCardTap(TeamMember member) {
    final nameKey = member.name.trim();
    String? laporanId = _namaToLaporanId[nameKey];
    if (laporanId == null) {
      for (final e in _namaToLaporanId.entries) {
        if (e.key.toLowerCase() == nameKey.toLowerCase()) {
          laporanId = e.value;
          break;
        }
      }
    }
    final id = laporanId;
    if (id != null && id.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BlocProvider(
            create: (context) => getIt<LaporanKegiatanBloc>(),
            child: LaporanKegiatanDetailPage(
              laporanId: id,
              userRole: _userRole,
            ),
          ),
        ),
      ).then((_) => _loadSchedule());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Detail laporan kegiatan untuk ${member.name} belum tersedia'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Widget _buildPersonnelCard(TeamMember member, String area) {
    return GestureDetector(
      onTap: () => _onPersonnelCardTap(member),
      child: Container(
      decoration: BoxDecoration(
        color: babyBlueColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(8.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28.r,
            backgroundColor: neutral30,
            backgroundImage: member.photoUrl != null && member.photoUrl!.isNotEmpty
                ? NetworkImage(member.photoUrl!)
                : null,
            child: member.photoUrl == null || member.photoUrl!.isEmpty
                ? Icon(Icons.person, size: 28.sp, color: neutral50)
                : null,
          ),
          6.verticalSpace,
          Flexible(
            child: Text(
              member.name,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: neutral90,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          4.verticalSpace,
          Text(
            '$area',
            style: TextStyle(
              fontSize: 10.sp,
              color: neutral70,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          6.verticalSpace,
          SizedBox(
            width: double.infinity,
            height: 28.h,
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
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6.r),
                ),
              ),
              child: Text(
                'Kirim Pesan',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
