import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:guardify_app/core/design/colors.dart';
import 'package:guardify_app/core/constants/enums.dart';
import 'package:guardify_app/features/home/presentation/bloc/home_state.dart';

class ShiftCard extends StatelessWidget {
  final AttendanceInfo attendanceInfo;
  final List<String> teamMembersImages;
  final VoidCallback onWorkButtonPressed;
  final UserRole? userRole; // Optional parameter for role-based UI
  final VoidCallback? onTrackLocationPressed; // Optional callback for Lacak Lokasi button
  final int? totalPersonil; // Total jumlah personil (untuk pengawas)
  final int? hadirCount; // Jumlah personil yang hadir (untuk pengawas)
  final VoidCallback? onCardTap; // Callback untuk klik card (untuk pengawas)
  final String? location; // Location from current shift

  const ShiftCard({
    super.key,
    required this.attendanceInfo,
    required this.teamMembersImages,
    required this.onWorkButtonPressed,
    this.userRole,
    this.onTrackLocationPressed,
    this.totalPersonil,
    this.hadirCount,
    this.onCardTap,
    this.location,
  });

  @override
  Widget build(BuildContext context) {
    final isCheckedIn = attendanceInfo.isCheckedIn;
    final isCheckedOut = attendanceInfo.isCheckedOut;
    final hasShift = attendanceInfo.hasShift;
    final isOnLeave = attendanceInfo.isOnLeave;
    
    // Untuk pengawas, tidak perlu validasi shift (selalu tampilkan tombol kecuali sudah checkout)
    // Untuk role lain:
    // - Jika sudah checkin, WAJIB tampilkan tombol checkout (untuk handle kasus hari berganti)
    // - Jika belum checkin, perlu validasi shift dan tidak sedang cuti
    // Juga disable tombol jika user sedang cuti (kecuali jika sudah checkin)
    final shouldShowButton = userRole == UserRole.pengawas
        ? !isCheckedOut
        : (isCheckedIn ? !isCheckedOut : (!isCheckedOut && hasShift && !isOnLeave));

    Widget cardContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date and Shift Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(attendanceInfo.date),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: neutral90,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Untuk pengawas, tampilkan "Shift Pagi - 28 Personil"
                    // Untuk role lain, tampilkan shift dengan location jika ada
                    Text(
                      userRole == UserRole.pengawas && totalPersonil != null
                          ? '${attendanceInfo.shift} - $totalPersonil Personil'
                          : (location != null && location!.isNotEmpty
                              ? '${attendanceInfo.shift} - $location'
                              : attendanceInfo.shift),
                      style: TextStyle(
                        fontSize: 14,
                        color: neutral70,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge atau Hadir Count (untuk pengawas) - pill-shaped light blue
              userRole == UserRole.pengawas && hadirCount != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: babyBlueColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$hadirCount Hadir',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: neutral90,
                        ),
                      ),
                    )
                  : Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCheckedOut 
                            ? Colors.grey 
                            : (isCheckedIn ? successColor : primaryColor),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isCheckedOut 
                            ? 'Selesai' 
                            : (isCheckedIn ? 'Masuk' : 'Menunggu'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
            ],
          ),

          const SizedBox(height: 16),

          // Untuk pengawas: Tim Jaga di sebelah kanan (label di atas, avatars di bawah)
          if (userRole == UserRole.pengawas)
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                Text(
                  'Tim Jaga',
                  style: TextStyle(
                    fontSize: 14,
                    color: neutral70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _buildTeamAvatars(),
              ],
              ),
            )
          else
            // Attendance Time Row untuk role lain
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jam Absen',
                      style: TextStyle(
                        fontSize: 14,
                        color: neutral70,
                      ),
                    ),
                    Text(
                      attendanceInfo.currentTime,
                      style: TextStyle(
                        fontSize: 14,
                        color: neutral70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                6.horizontalSpace,
                // Team Members Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tim Jaga',
                          style: TextStyle(
                            fontSize: 14,
                            color: neutral70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildTeamAvatars(),
                      ],
                    ),
                  ],
                ),
              ],
            ),

          const SizedBox(height: 20),

          // Buttons - Only show if not checked out
          if (shouldShowButton)
            // Show "Lacak Lokasi" button for Pengawas role
            if (userRole == UserRole.pengawas)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onTrackLocationPressed ?? () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Lacak Lokasi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              // Work Button for other roles
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onWorkButtonPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isCheckedIn ? 'Akhiri Bekerja' : 'Mulai Bekerja',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );

    // Wrap dengan Container untuk margin
    final cardWithMargin = Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: cardContent,
    );

    // Untuk pengawas, wrap dengan GestureDetector agar card bisa diklik
    // Tombol "Lacak Lokasi" akan menangkap tap terlebih dahulu, tap di area lain akan trigger onCardTap
    if (userRole == UserRole.pengawas && onCardTap != null) {
      return GestureDetector(
        onTap: onCardTap,
        behavior: HitTestBehavior.opaque,
        child: cardWithMargin,
      );
    }

    return cardWithMargin;
  }

  Widget _buildTeamAvatars() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Show up to 3 avatars (overlapping via Transform.translate)
        ...List.generate(
          teamMembersImages.length > 3 ? 3 : teamMembersImages.length,
          (index) => Transform.translate(
            offset: Offset(-8.0 * index, 0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: primary30,
                backgroundImage: teamMembersImages[index].isNotEmpty
                    ? NetworkImage(teamMembersImages[index])
                    : null,
                child: teamMembersImages[index].isEmpty
                    ? const Icon(
                        Icons.person,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
          ),
        ),
        // Show +X if more than 3 members
        if (teamMembersImages.length > 3)
          Container(
            margin: const EdgeInsets.only(left: 4),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: primaryColor,
              child: Text(
                '+${teamMembersImages.length - 3}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final days = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu'
    ];
    final months = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];

    // DateTime.weekday returns 1-7 (Monday=1, Sunday=7)
    // Array days: [0]=Minggu, [1]=Senin, [2]=Selasa, [3]=Rabu, [4]=Kamis, [5]=Jumat, [6]=Sabtu
    // Mapping: weekday 1->1, 2->2, 3->3, 4->4, 5->5, 6->6, 7->0
    final dayIndex = date.weekday == 7 ? 0 : date.weekday;

    return '${days[dayIndex]}, ${date.day} ${months[date.month]} ${date.year}';
  }
}
