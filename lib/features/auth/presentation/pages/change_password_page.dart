import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../shared/widgets/Buttons/ui_button.dart';
import '../../../../shared/widgets/TextInput/input_primary.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../bloc/auth_bloc.dart';
import 'change_password_success_page.dart';

class ChangePasswordPage extends StatelessWidget {
  const ChangePasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ChangePasswordView();
  }
}

class _ChangePasswordView extends StatefulWidget {
  const _ChangePasswordView();

  @override
  State<_ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<_ChangePasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: primaryColor,
      ),
    );
  }

  void _onChangePasswordPressed() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    context.read<AuthBloc>().add(
          AuthChangePasswordRequested(
            currentPassword: _currentPasswordController.text,
            newPassword: _newPasswordController.text,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      enableScrolling: false,
      backgroundColor: Colors.white,
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.changePasswordSuccess) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ChangePasswordSuccessPage(),
              ),
            );
          } else if (state.status == AuthStatus.error) {
            _showMessage(state.errorMessage ?? 'Ubah password gagal');
          }
        },
        child: Container(
          height: MediaQuery.of(context).size.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [
                primaryColor,
                Colors.white,
              ],
              stops: [0.35, 0.35],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          'Ubah Password',
                          style: TS.titleLarge.copyWith(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(width: 48.w),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Column(
                        children: [
                          24.verticalSpace,
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 24.w,
                              vertical: 24.h,
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InputPrimary(
                                    label: 'Password Saat Ini',
                                    hint: '',
                                    controller: _currentPasswordController,
                                    isRequired: true,
                                    obscureText: !_showCurrentPassword,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _showCurrentPassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: neutral50,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _showCurrentPassword =
                                              !_showCurrentPassword;
                                        });
                                      },
                                    ),
                                    validation: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Password saat ini tidak boleh kosong';
                                      }
                                      return null;
                                    },
                                    borderRadius: 12,
                                    color: Colors.white,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 15.w,
                                      vertical: 8.h,
                                    ),
                                  ),
                                  20.verticalSpace,
                                  InputPrimary(
                                    label: 'Password Baru',
                                    hint: '',
                                    controller: _newPasswordController,
                                    isRequired: true,
                                    obscureText: !_showNewPassword,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _showNewPassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: neutral50,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _showNewPassword = !_showNewPassword;
                                        });
                                      },
                                    ),
                                    validation: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Password baru tidak boleh kosong';
                                      }
                                      return null;
                                    },
                                    borderRadius: 12,
                                    color: Colors.white,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 15.w,
                                      vertical: 8.h,
                                    ),
                                  ),
                                  20.verticalSpace,
                                  InputPrimary(
                                    label: 'Konfirmasi Password Baru',
                                    hint: '',
                                    controller: _confirmPasswordController,
                                    isRequired: true,
                                    obscureText: !_showConfirmPassword,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _showConfirmPassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: neutral50,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _showConfirmPassword =
                                              !_showConfirmPassword;
                                        });
                                      },
                                    ),
                                    validation: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Konfirmasi password tidak boleh kosong';
                                      }
                                      if (value != _newPasswordController.text) {
                                        return 'Konfirmasi password tidak sama';
                                      }
                                      return null;
                                    },
                                    borderRadius: 12,
                                    color: Colors.white,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 15.w,
                                      vertical: 8.h,
                                    ),
                                  ),
                                  30.verticalSpace,
                                  BlocBuilder<AuthBloc, AuthState>(
                                    builder: (context, state) {
                                      return UIButton(
                                        text: 'Ubah Password',
                                        fullWidth: true,
                                        size: UIButtonSize.medium,
                                        variant: UIButtonVariant.primary,
                                        isLoading: state.isLoading,
                                        onPressed: state.isLoading
                                            ? null
                                            : _onChangePasswordPressed,
                                        borderRadius: 12,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          24.verticalSpace,
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/reset-password');
                            },
                            child: Text(
                              'Lupa Password?',
                              style: TS.bodyMedium.copyWith(
                                color: const Color(0xFF4A90E2),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          16.verticalSpace,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
