import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../design/colors.dart';
import '../../shared/widgets/Buttons/ui_button.dart';

const _backgroundLocationConsentKey = 'background_location_consent_accepted';

/// Helper untuk mengelola prominent disclosure dan consent background location.
///
/// Google Play memerlukan prominent disclosure yang ditampilkan SEBELUM aplikasi
/// mengakses/minta izin lokasi latar belakang (background location).
/// Disclosure harus:
/// - Dijadikan dialog terpisah (tidak cukup hanya di privacy policy).
/// - Menjelaskan data apa yang dikumpulkan (lokasi di background).
/// - Menjelaskan tujuan penggunaan (pelacakan rute patroli saat bertugas).
/// - Meminta persetujuan eksplisit dari pengguna.
class BackgroundLocationPermissionHelper {
  static Future<bool> hasAcceptedDisclosure() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_backgroundLocationConsentKey) ?? false;
  }

  static Future<void> setAcceptedDisclosure(bool accepted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backgroundLocationConsentKey, accepted);
  }

  /// Menampilkan prominent disclosure untuk background location.
  /// Returns true jika pengguna menyetujui, false jika menolak.
  static Future<bool> showDisclosure(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _BackgroundLocationDisclosureDialog(),
    );
    return result ?? false;
  }

  /// Convenience method untuk menampilkan disclosure menggunakan navigator key.
  /// Berguna untuk menampilkan dialog dari main.dart di mana BuildContext tidak
  /// tersedia secara langsung.
  static Future<bool> showDisclosureWithNavigatorKey(
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    final context = navigatorKey.currentState?.overlay?.context;
    if (context == null) return false;
    return showDisclosure(context);
  }
}

class _BackgroundLocationDisclosureDialog extends StatelessWidget {
  const _BackgroundLocationDisclosureDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      contentPadding: REdgeInsets.all(24),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 0.7.sh),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, color: primaryColor, size: 28.sp),
                  8.horizontalSpace,
                  Expanded(
                    child: Text(
                      'Penggunaan Lokasi Latar Belakang',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              16.verticalSpace,
              Text(
                'Rumara Security mengumpulkan data lokasi perangkat Anda, termasuk saat aplikasi berjalan di latar belakang, untuk keperluan patroli dan pengamanan.',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.black87,
                ),
              ),
              16.verticalSpace,
              _buildBullet(
                'Tujuan penggunaan',
                'Lokasi digunakan untuk melacak rute patroli, memvalidasi kehadiran di titik pengamanan, dan memastikan personil berada di area tugas yang ditentukan.',
              ),
              _buildBullet(
                'Kapan lokasi dikumpulkan',
                'Lokasi dikumpulkan saat Anda sedang bertugas (setelah check-in) dan aplikasi dapat berjalan di latar belakang.',
              ),
              _buildBullet(
                'Bagaimana data digunakan',
                'Data lokasi dikirim ke server perusahaan sesuai jadwal patroli dan hanya digunakan untuk operasional pengamanan.',
              ),
              24.verticalSpace,
              Row(
                children: [
                  Expanded(
                    child: UIButton(
                      text: 'Tolak',
                      buttonType: UIButtonType.outline,
                      variant: UIButtonVariant.neutral,
                      onPressed: () async {
                        await BackgroundLocationPermissionHelper
                            .setAcceptedDisclosure(false);
                        if (context.mounted) {
                          Navigator.of(context).pop(false);
                        }
                      },
                    ),
                  ),
                  12.horizontalSpace,
                  Expanded(
                    child: UIButton(
                      text: 'Izinkan',
                      variant: UIButtonVariant.primary,
                      onPressed: () async {
                        await BackgroundLocationPermissionHelper
                            .setAcceptedDisclosure(true);
                        if (context.mounted) {
                          Navigator.of(context).pop(true);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBullet(String title, String description) {
    return Padding(
      padding: REdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: primaryColor, size: 18.sp),
          8.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                4.verticalSpace,
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13.sp,
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
}
