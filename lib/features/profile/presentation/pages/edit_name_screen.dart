import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/TextInput/input_primary.dart';
import '../../../../shared/widgets/Buttons/ui_button.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';

/// Layar untuk edit nama user
class EditNameScreen extends StatefulWidget {
  final String userId;
  final String currentName;

  const EditNameScreen({
    super.key,
    required this.userId,
    required this.currentName,
  });

  @override
  State<EditNameScreen> createState() => _EditNameScreenState();
}

class _EditNameScreenState extends State<EditNameScreen> {
  late TextEditingController _nameController;
  late ProfileBloc _profileBloc;
  bool _isDataChanged = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _profileBloc = getIt<ProfileBloc>();

    // Listen untuk perubahan text
    _nameController.addListener(() {
      setState(() {
        _isDataChanged = _nameController.text.trim() != widget.currentName;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _profileBloc,
      child: AppScaffold(
        backgroundColor: Colors.grey.shade50,
        enableScrolling:
            false, // Disable scrolling since we're using Spacer in Column
        appBar: AppBar(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _onBackPressed(),
          ),
          title: Text(
            'Ubah Nama',
            style: TS.titleLarge.copyWith(color: Colors.white),
          ),
          centerTitle: true,
        ),
        child: BlocConsumer<ProfileBloc, ProfileState>(
          listener: (context, state) {
            // Handle update success
            if (state is ProfileUpdateSuccess) {
              _showSuccessDialog();
            }

            // Handle update failure
            if (state is ProfileUpdateFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          builder: (context, state) {
            final isLoading = state is ProfileUpdateInProgress;

            return Stack(
              children: [
                Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pastikan data Anda telah sesuai',
                        style: TS.bodyLarge.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),

                      SizedBox(height: 24.h),

                      // Input nama
                      Text(
                        'Nama',
                        style: TS.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),

                      SizedBox(height: 8.h),

                      InputPrimary(
                        controller: _nameController,
                        hint: 'Masukkan nama lengkap',
                        validation: _validateName,
                        enable: !isLoading,
                        maxLength: 50,
                      ),

                      const Spacer(),

                      // Button simpan
                      SizedBox(
                        width: double.infinity,
                        child: UIButton(
                          text: 'Simpan',
                          onPressed: _isDataChanged && !isLoading
                              ? _onSavePressed
                              : null,
                          isLoading: isLoading,
                        ),
                      ),
                    ],
                  ),
                ),

                // Loading overlay
                if (isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: primaryColor,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Validasi nama
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nama tidak boleh kosong';
    }

    if (value.trim().length < 2) {
      return 'Nama minimal 2 karakter';
    }

    if (value.trim().length > 50) {
      return 'Nama maksimal 50 karakter';
    }

    return null;
  }

  /// Handle back button pressed
  void _onBackPressed() {
    if (_isDataChanged) {
      _showUnsavedChangesDialog();
    } else {
      Navigator.of(context).pop();
    }
  }

  /// Handle save button pressed
  void _onSavePressed() {
    final newName = _nameController.text.trim();

    // Validasi
    final validation = _validateName(newName);
    if (validation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validation),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Update nama
    _profileBloc.add(UpdateNameEvent(
      userId: widget.userId,
      newName: newName,
    ));
  }

  /// Show dialog perubahan belum disimpan
  void _showUnsavedChangesDialog() {
    showDialog(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Perubahan data nama tidak dapat dilakukan.',
        message:
            'Silakan hubungi admin apabila terdapat kesalahan pada informasi Anda.',
        confirmText: 'Simpan',
        cancelText: 'Batal',
        icon: Icons.warning,
        iconColor: Colors.orange,
        isDestructive: false,
        onConfirm: () {
          Navigator.of(context).pop();
          _onSavePressed();
        },
        onCancel: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  /// Show success dialog
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConfirmDialog(
        title: 'Berhasil Menyimpan Perubahan',
        message: 'Data nama Anda telah berhasil diperbarui.',
        confirmText: 'OK',
        cancelText: '',
        icon: Icons.check_circle,
        iconColor: Colors.green,
        onConfirm: () {
          Navigator.of(context).pop(); // Close dialog
          Navigator.of(context).pop(); // Back to profile details
        },
      ),
    );
  }
}
