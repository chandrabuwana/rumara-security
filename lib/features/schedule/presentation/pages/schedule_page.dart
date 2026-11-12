import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/security/security_manager.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/design/colors.dart';
import '../../domain/entities/shift_schedule.dart';
import '../bloc/schedule_bloc.dart';
import 'shift_detail_page.dart';
import '../../../home/presentation/widgets/custom_bottom_nav.dart';
import '../../../../shared/widgets/rumara_app_bar.dart';

/// Schedule Page - Jadwal Kerja (Untuk Anggota & Danton)
///
/// Fitur ini menampilkan jadwal kerja shift untuk security personnel
/// dengan dua tab: "Jadwal Saya" dan "Jadwal Anggota"
///
/// **Accessible by roles:**
/// - Anggota (AGT): Dapat melihat jadwal shift pribadi
/// - Danton: Dapat melihat jadwal shift pribadi dan anggota tim
///
/// **Note**: PJO dan Deputy menggunakan `SchedulePJODeputyPage` dengan UI berbeda
///
/// **Features:**
/// - Calendar view dengan informasi shift per hari
/// - Detail shift dengan lokasi patroli dan tim jaga
/// - Agenda esok hari untuk persiapan
class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _hasLoadedInitialData = false;

  void _loadSchedule(BuildContext context) async {
    final userId =
        await SecurityManager.readSecurely(AppConstants.userIdKey) ?? '';

    if (!mounted) return;

    context.read<ScheduleBloc>().add(LoadDailyAgenda(
          userId: userId,
          year: _focusedDay.year,
          month: _focusedDay.month,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const RumaraAppBar(title: 'Jadwal Kerja'),
      body: Builder(
        builder: (builderContext) {
          return BlocBuilder<ScheduleBloc, ScheduleState>(
            builder: (context, state) {
              // Load schedule when first built
              if (!_hasLoadedInitialData && !state.isLoading) {
                _hasLoadedInitialData = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _loadSchedule(context);
                });
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Agenda Esok Hari Section
                    Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Agenda Esok Hari',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          _buildAgendaCard(state),
                        ],
                      ),
                    ),

                    // Calendar Section
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 16.w),
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildCalendarHeader(state),
                          SizedBox(height: 16.h),
                          _buildCalendar(state),
                        ],
                      ),
                    ),

                    SizedBox(height: 100.h),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 1,
        onTap: (index) {
          switch (index) {
            case 0:
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Navigator.pushReplacementNamed(context, '/home');
              }
              break;
            case 1:
              // Already on schedule
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/chat');
              break;
            case 3:
              // Notifikasi page is not wired as a named route yet
              break;
          }
        },
        onEmergencyPressed: () {
          Navigator.pushNamed(context, '/panic-verification');
        },
      ),
    );
  }

  Widget _buildAgendaCard(ScheduleState state) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final agenda = state.dailyAgendas.firstWhere(
      (a) =>
          a.date.day == tomorrow.day &&
          a.date.month == tomorrow.month &&
          a.date.year == tomorrow.year,
      orElse: () => DailyAgenda(
        date: tomorrow,
        shiftType: '',
        position: '',
      ),
    );

    // Jika tidak ada agenda besok
    if (agenda.shiftType.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            // Calendar Icon
            Container(
              width: 48.w,
              height: 48.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                Icons.event_busy,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(width: 12.w),

            // No Agenda Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Besok Tidak Ada Agenda',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    DateFormat('dd MMMM yyyy', 'id_ID').format(tomorrow),
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Jika ada agenda besok
    return GestureDetector(
      onTap: () async {
        final userId =
            await SecurityManager.readSecurely(AppConstants.userIdKey) ?? '';
        if (!mounted) return;

        final scheduleBloc = context.read<ScheduleBloc>();

        // Use new API to load schedule detail
        scheduleBloc.add(LoadScheduleDetail(
          userId: userId,
          date: agenda.date,
        ));

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BlocProvider.value(
              value: scheduleBloc,
              child: ShiftDetailPage(
                userId: userId,
                date: agenda.date,
              ),
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            // Calendar Icon
            Container(
              width: 48.w,
              height: 48.h,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                Icons.calendar_today,
                color: primaryColor,
              ),
            ),
            SizedBox(width: 12.w),

            // Shift Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    agenda.shiftType,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    DateFormat('dd MMMM yyyy', 'id_ID').format(tomorrow),
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Position Info
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  agenda.position,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Lokasi Jaga',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarHeader(ScheduleState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            setState(() {
              _focusedDay = DateTime(
                _focusedDay.year,
                _focusedDay.month - 1,
              );
            });
            _loadSchedule(context);
          },
        ),
        Text(
          DateFormat('MMMM yyyy', 'id_ID').format(_focusedDay),
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            setState(() {
              _focusedDay = DateTime(
                _focusedDay.year,
                _focusedDay.month + 1,
              );
            });
            _loadSchedule(context);
          },
        ),
      ],
    );
  }

  Widget _buildCalendar(ScheduleState state) {
    final today = DateTime.now();

    return TableCalendar(
      firstDay: DateTime(2020),
      lastDay: DateTime(2030),
      focusedDay: _focusedDay,
      currentDay: today,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      availableGestures: AvailableGestures.none,
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.sunday,
      headerVisible: false,
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
        });
        _loadSchedule(context);
      },
      daysOfWeekHeight: 20.h,
      rowHeight: 70.h,
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        todayDecoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(12.r),
        ),
        selectedDecoration: BoxDecoration(
          color: primaryColor.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12.r),
        ),
        defaultTextStyle: TextStyle(fontSize: 16.sp),
        weekendTextStyle: TextStyle(fontSize: 16.sp),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
        ),
        weekendStyle: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
        ),
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          return _buildDayCell(day, state);
        },
        todayBuilder: (context, day, focusedDay) {
          return _buildDayCell(day, state);
        },
        selectedBuilder: (context, day, focusedDay) {
          return _buildDayCell(day, state, isSelected: true);
        },
      ),
      onDaySelected: (selectedDay, focusedDay) async {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });

        final userId =
            await SecurityManager.readSecurely(AppConstants.userIdKey) ?? '';
        if (!mounted) return;

        final scheduleBloc = context.read<ScheduleBloc>();

        // Use new API to load schedule detail
        scheduleBloc.add(LoadScheduleDetail(
          userId: userId,
          date: selectedDay,
        ));

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BlocProvider.value(
              value: scheduleBloc,
              child: ShiftDetailPage(
                userId: userId,
                date: selectedDay,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDayCell(
    DateTime day,
    ScheduleState state, {
    bool isSelected = false,
  }) {
    final agenda = state.dailyAgendas.firstWhere(
      (a) =>
          a.date.day == day.day &&
          a.date.month == day.month &&
          a.date.year == day.year,
      orElse: () => DailyAgenda(
        date: DateTime(2000, 1, 1),
        shiftType: '',
        position: '',
      ),
    );

    final hasShift = agenda.shiftType.isNotEmpty;
    final today = DateTime.now();
    final isActuallyToday = day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;

    return Container(
      margin: EdgeInsets.all(1.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Angka tanggal dengan background
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: isActuallyToday
                  ? primaryColor // Primary untuk hari ini
                  : isSelected
                      ? primaryColor.withOpacity(0.7)
                      : hasShift
                          ? primaryColor.withOpacity(0.1) // Primary tipis untuk tanggal yang ada shift
                          : Colors.transparent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color:
                    isActuallyToday || isSelected ? Colors.white : Colors.black,
              ),
            ),
          ),
          if (hasShift) ...[
            SizedBox(height: 4.h),
            Text(
              agenda.shiftType,
              style: TextStyle(
                fontSize: 8.sp,
                fontWeight: FontWeight.w400,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2.h),
            Text(
              agenda.position,
              style: TextStyle(
                fontSize: 7.sp,
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
