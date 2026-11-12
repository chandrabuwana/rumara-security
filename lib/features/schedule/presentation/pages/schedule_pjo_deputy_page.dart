import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/security/security_manager.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/design/colors.dart';
import '../bloc/schedule_bloc.dart';
import 'shift_detail_pjo_deputy_page.dart';
import '../../../../shared/widgets/rumara_app_bar.dart';

/// Schedule Page for PJO & Deputy
/// 
/// Versi halaman jadwal khusus untuk role PJO dan Deputy
/// dengan tampilan calendar langsung tanpa tab
/// 
/// **Accessible by roles:**
/// - PJO (Petugas Jaga): Lihat jadwal operasional
/// - Deputy (DPT): Lihat jadwal tim
class SchedulePJODeputyPage extends StatefulWidget {
  const SchedulePJODeputyPage({super.key});

  @override
  State<SchedulePJODeputyPage> createState() => _SchedulePJODeputyPageState();
}

class _SchedulePJODeputyPageState extends State<SchedulePJODeputyPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _hasLoadedInitialData = false;

  void _loadSchedule(BuildContext context) async {
    final userId = await SecurityManager.readSecurely(AppConstants.userIdKey) ?? '';
    
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
                    SizedBox(height: 16.h),

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
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) {
        return isSameDay(_selectedDay, day);
      },
      availableGestures: AvailableGestures.none,
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
        });
        _loadSchedule(context);
      },
      onDaySelected: (selectedDay, focusedDay) async {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
        
        final userId = await SecurityManager.readSecurely(AppConstants.userIdKey) ?? '';
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
              child: ShiftDetailPJODeputyPage(
                userId: userId,
                date: selectedDay,
              ),
            ),
          ),
        );
      },
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.monday,
      headerVisible: false,
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        weekendTextStyle: TextStyle(color: Colors.black87, fontSize: 14.sp),
        defaultTextStyle: TextStyle(color: Colors.black87, fontSize: 14.sp),
        selectedDecoration: BoxDecoration(
          color: primaryColor,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: primaryColor,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: const TextStyle(color: Colors.white),
        todayTextStyle: const TextStyle(color: Colors.white),
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
        selectedBuilder: (context, day, focusedDay) {
          return _buildDayCell(day, state, isSelected: true);
        },
        todayBuilder: (context, day, focusedDay) {
          return _buildDayCell(day, state, isToday: true);
        },
      ),
    );
  }

  Widget _buildDayCell(DateTime day, ScheduleState state, {
    bool isToday = false,
    bool isSelected = false,
  }) {
    // Cek apakah hari ini ada agenda (tidak kosong)
    final hasAgenda = state.dailyAgendas.any((agenda) =>
      agenda.date.day == day.day &&
      agenda.date.month == day.month &&
      agenda.date.year == day.year &&
      agenda.shiftType.isNotEmpty
    );

    return Container(
      margin: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: isToday || isSelected
            ? primaryColor
            : hasAgenda
                ? Colors.grey.shade100
                : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: isToday || isSelected
                ? Colors.white
                : hasAgenda
                    ? Colors.black87
                    : Colors.grey.shade400,
            fontSize: 14.sp,
            fontWeight: hasAgenda ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
