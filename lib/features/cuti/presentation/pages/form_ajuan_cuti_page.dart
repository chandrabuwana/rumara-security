import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/Buttons/ui_button.dart';
import '../../../../shared/widgets/custom_dropdown.dart';
import '../../../../shared/widgets/TextInput/input_primary.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../bloc/cuti_bloc.dart';
import '../bloc/cuti_event.dart';
import '../bloc/cuti_state.dart';
import '../dialogs/success_dialog.dart';
import '../../domain/entities/cuti_entity.dart';
import '../../domain/entities/leave_request_type_entity.dart';
import '../../../../shared/widgets/rumara_app_bar.dart';

class FormAjuanCutiPage extends StatefulWidget {
  final String userId;
  final String userName;

  const FormAjuanCutiPage({
    Key? key,
    required this.userId,
    required this.userName,
  }) : super(key: key);

  @override
  State<FormAjuanCutiPage> createState() => _FormAjuanCutiPageState();
}

class _FormAjuanCutiPageState extends State<FormAjuanCutiPage> {
  final _formKey = GlobalKey<FormState>();
  final _alasanController = TextEditingController();

  LeaveRequestTypeEntity? _selectedLeaveRequestType;
  DateTime? _tanggalMulai;
  DateTime? _tanggalSelesai;
  int _jumlahHari = 0;
  List<LeaveRequestTypeEntity> _leaveRequestTypes = [];

  @override
  void initState() {
    super.initState();
    // Load leave request types on init
    context.read<CutiBloc>().add(const GetLeaveRequestTypeListEvent());
  }

  @override
  void dispose() {
    _alasanController.dispose();
    super.dispose();
  }

  void _calculateJumlahHari() {
    if (_tanggalMulai != null && _tanggalSelesai != null) {
      final difference = _tanggalSelesai!.difference(_tanggalMulai!).inDays + 1;
      setState(() {
        _jumlahHari = difference > 0 ? difference : 0;
      });
    } else {
      setState(() {
        _jumlahHari = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const RumaraAppBar(title: 'Buat Ajuan Cuti'),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: REdgeInsets.all(16),
            child: BlocListener<CutiBloc, CutiState>(
              listener: (context, state) {
                if (state is LeaveRequestTypeListLoaded) {
                  setState(() {
                    _leaveRequestTypes = state.leaveRequestTypes;
                  });
                } else if (state is AjuanCutiCreated) {
                  // Reload list cuti setelah submit berhasil
                  context.read<CutiBloc>().add(GetDaftarCutiSayaEvent(widget.userId));
                  _showSuccessDialog();
                } else if (state is CutiError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Form Fields
                    BlocBuilder<CutiBloc, CutiState>(
                      builder: (context, state) {
                        if (state is CutiLoading && _leaveRequestTypes.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final dropdownItems = _leaveRequestTypes
                            .map((type) => DropdownItem<LeaveRequestTypeEntity>(
                                  value: type,
                                  text: type.name,
                                ))
                            .toList();

                        return CustomDropdown<LeaveRequestTypeEntity>(
                          label: 'Tipe Cuti',
                          hint: 'Pilih tipe cuti',
                          value: _selectedLeaveRequestType,
                          items: dropdownItems,
                          isRequired: true,
                          onChanged: (value) {
                            setState(() {
                              _selectedLeaveRequestType = value;
                            });
                          },
                        );
                      },
                    ),

                    20.verticalSpace,

                    // Tanggal Mulai
                    _buildDateField(
                      label: 'Tanggal Mulai',
                      hint: 'Pilih tanggal mulai cuti',
                      selectedDate: _tanggalMulai,
                      onDateSelected: (date) {
                        setState(() {
                          _tanggalMulai = date;
                          if (_tanggalSelesai != null &&
                              date != null &&
                              _tanggalSelesai!.isBefore(date)) {
                            _tanggalSelesai = date;
                          }
                          _calculateJumlahHari();
                        });
                      },
                      isRequired: true,
                    ),

                    20.verticalSpace,

                    // Tanggal Selesai
                    _buildDateField(
                      label: 'Tanggal Selesai',
                      hint: 'Pilih tanggal selesai cuti',
                      selectedDate: _tanggalSelesai,
                      onDateSelected: (date) {
                        setState(() {
                          _tanggalSelesai = date;
                          _calculateJumlahHari();
                        });
                      },
                      isRequired: true,
                      firstDate: _tanggalMulai,
                    ),

                    if (_jumlahHari > 0) ...[
                      16.verticalSpace,
                      Container(
                        width: double.infinity,
                        padding: REdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: primaryColor,
                              size: 20.sp,
                            ),
                            12.horizontalSpace,
                            Text(
                              'Total durasi cuti: $_jumlahHari hari',
                              style: TS.bodyMedium.copyWith(
                                color: primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    20.verticalSpace,

                    // Alasan
                    InputPrimary(
                      controller: _alasanController,
                      label: 'Alasan Cuti',
                      hint: 'Jelaskan alasan mengajukan cuti',
                      isRequired: true,
                      maxLines: 4,
                      maxLength: 500,
                      validation: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Alasan cuti harus diisi';
                        }
                        if (value.trim().length < 10) {
                          return 'Alasan cuti minimal 10 karakter';
                        }
                        return null;
                      },
                    ),

                    32.verticalSpace,

                    // Submit Button
                    BlocBuilder<CutiBloc, CutiState>(
                      builder: (context, state) {
                        return UIButton(
                          text: 'Ajukan Cuti',
                          fullWidth: true,
                          size: UIButtonSize.large,
                          isLoading: state is CutiLoading,
                          onPressed: state is CutiLoading ? null : _submitForm,
                        );
                      },
                    ),

                    16.verticalSpace,

                    UIButton(
                      text: 'Batal',
                      fullWidth: true,
                      size: UIButtonSize.large,
                      buttonType: UIButtonType.outline,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Loading Overlay
          BlocBuilder<CutiBloc, CutiState>(
            builder: (context, state) {
              if (state is CutiLoading) {
                return Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: REdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(primaryColor),
                            ),
                            16.verticalSpace,
                            Text(
                              'Mengirim ajuan cuti...',
                              style: TS.titleSmall.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required String hint,
    required DateTime? selectedDate,
    required Function(DateTime?) onDateSelected,
    required bool isRequired,
    DateTime? firstDate,
  }) {
    final formatter = DateFormat('dd/MM/yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TS.labelLarge,
            ),
            if (isRequired)
              Text(
                '*',
                style: TS.bodyLarge.copyWith(color: Colors.red),
              ),
          ],
        ),
        8.verticalSpace,
        InkWell(
          onTap: () => _selectDate(onDateSelected, firstDate),
          borderRadius: BorderRadius.circular(10.r),
          child: Container(
            width: double.infinity,
            padding: REdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10.r),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedDate != null
                        ? formatter.format(selectedDate)
                        : hint,
                    style: TS.bodyLarge.copyWith(
                      color: selectedDate != null
                          ? Colors.black87
                          : Colors.grey.shade500,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  color: Colors.grey.shade600,
                  size: 20.sp,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(
    Function(DateTime?) onDateSelected,
    DateTime? firstDate,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: firstDate ?? DateTime.now(),
      firstDate: firstDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    onDateSelected(date);
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedLeaveRequestType == null) {
      _showErrorSnackBar('Tipe cuti harus dipilih');
      return;
    }

    if (_tanggalMulai == null) {
      _showErrorSnackBar('Tanggal mulai harus dipilih');
      return;
    }

    if (_tanggalSelesai == null) {
      _showErrorSnackBar('Tanggal selesai harus dipilih');
      return;
    }

    if (_jumlahHari <= 0) {
      _showErrorSnackBar('Durasi cuti harus minimal 1 hari');
      return;
    }

    // Show confirmation dialog
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Konfirmasi Ajuan Cuti',
      message: 'Apakah Anda yakin ingin mengajukan cuti ini?\n\n'
          'Tipe: ${_selectedLeaveRequestType!.name}\n'
          'Durasi: $_jumlahHari hari\n'
          'Alasan: ${_alasanController.text.trim()}',
      confirmText: 'Ya, Ajukan',
      cancelText: 'Batal',
      icon: Icons.send,
      iconColor: primaryColor,
    );

    if (confirmed == true && mounted) {
      // Map LeaveRequestType to CutiType for backward compatibility
      // We'll use the ID from API in the datasource
      final cutiType = _mapLeaveRequestTypeToCutiType(_selectedLeaveRequestType!);
      
      context.read<CutiBloc>().add(
            BuatAjuanCutiEvent(
              userId: widget.userId,
              nama: widget.userName,
              tipeCuti: cutiType,
              leaveRequestTypeId: _selectedLeaveRequestType!.id,
              tanggalMulai: _tanggalMulai!,
              tanggalSelesai: _tanggalSelesai!,
              alasan: _alasanController.text.trim(),
              jumlahHari: _jumlahHari,
            ),
          );
    }
  }

  /// Map LeaveRequestType to CutiType for backward compatibility
  /// The actual ID will be used from the selected LeaveRequestType
  CutiType _mapLeaveRequestTypeToCutiType(LeaveRequestTypeEntity type) {
    // Try to match by name
    final name = type.name.toLowerCase();
    if (name.contains('tahunan')) {
      return CutiType.tahunan;
    } else if (name.contains('sakit')) {
      return CutiType.sakit;
    } else if (name.contains('melahirkan')) {
      return CutiType.melahirkan;
    } else if (name.contains('menikah')) {
      return CutiType.menikah;
    } else if (name.contains('meninggal')) {
      return CutiType.keluargaMeninggal;
    } else {
      return CutiType.lainnya;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessDialog() {
    if (!mounted) return;
    
    SuccessDialog.show(
      context: context,
      title: 'Ajuan Berhasil Dikirim',
      message:
          'Ajuan cuti Anda telah berhasil dikirim dan akan segera diproses oleh atasan.',
      buttonText: 'Kembali',
      onPressed: () {
        if (!mounted) return;
        // Close dialog
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        
        // Close form page and return true to indicate success
        Future.microtask(() {
          if (!mounted) return;
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(true);
          }
        });
      },
    );
  }
}
