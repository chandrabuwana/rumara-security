import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../bloc/panic_button_bloc.dart';
import '../bloc/panic_button_state.dart';
import '../../../../shared/widgets/rumara_app_bar.dart';

class PanicSecurityFormPage extends StatelessWidget {
  const PanicSecurityFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PanicSecurityFormView();
  }
}

class _PanicSecurityFormView extends StatefulWidget {
  const _PanicSecurityFormView();

  @override
  State<_PanicSecurityFormView> createState() => _PanicSecurityFormViewState();
}

class _PanicSecurityFormViewState extends State<_PanicSecurityFormView> {
  final TextEditingController _securityController = TextEditingController();
  final TextEditingController _actionController = TextEditingController();
  String? _selectedSeverity;

  @override
  void dispose() {
    _securityController.dispose();
    _actionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const RumaraAppBar(title: 'Tombol Darurat'),
      child: BlocBuilder<PanicButtonBloc, PanicButtonState>(
        builder: (context, state) {
          return Padding(
            padding: REdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress indicator
                Row(
                  children: [
                    _buildProgressDot(true),
                    _buildProgressLine(true),
                    _buildProgressDot(true),
                    _buildProgressLine(true),
                    _buildProgressDot(true),
                    _buildProgressLine(false),
                    _buildProgressDot(false),
                  ],
                ),
                24.verticalSpace,

                Text(
                  'Jenis keadaan darurat yang sesuai',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                16.verticalSpace,

                Text(
                  'Apakah anda yakin ini adalah keadaan darurat yang membutuhkan eskalasi segera?',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
                24.verticalSpace,

                // Security level dropdown
                Text(
                  'Keamanan',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                8.verticalSpace,
                Container(
                  width: double.infinity,
                  padding: REdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSeverity,
                      hint: Text(
                        'Keadaan Darurat',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                      isExpanded: true,
                      items: [
                        'Keamanan dan Kecelakaan Kerja',
                        'Bencana Alam',
                        'Kebakaran',
                        'Keadaan Darurat Medis',
                        'Ancaman Keamanan'
                      ].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: TextStyle(fontSize: 14.sp),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedSeverity = newValue;
                        });
                      },
                    ),
                  ),
                ),
                24.verticalSpace,

                // Action text field
                Text(
                  'Tindakan',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                8.verticalSpace,
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: TextField(
                    controller: _actionController,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: 'Jelaskan tindakan yang perlu diambil...',
                      hintStyle: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[500],
                      ),
                      border: InputBorder.none,
                      contentPadding: REdgeInsets.all(12),
                    ),
                    style: TextStyle(fontSize: 14.sp),
                  ),
                ),

                50.verticalSpace,

                // Bottom button
                SizedBox(
                  width: double.infinity,
                  height: 50.h,
                  child: ElevatedButton(
                    onPressed: (_selectedSeverity != null &&
                            _actionController.text.isNotEmpty)
                        ? () {
                            Navigator.pushNamed(context, '/panic-confirmation');
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE5484D),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'AKTIFKAN',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                20.verticalSpace,
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressDot(bool isActive) {
    return Container(
      width: 12.w,
      height: 12.h,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFE5484D) : Colors.grey[300],
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildProgressLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 2.h,
        color: isActive ? const Color(0xFFE5484D) : Colors.grey[300],
      ),
    );
  }
}
