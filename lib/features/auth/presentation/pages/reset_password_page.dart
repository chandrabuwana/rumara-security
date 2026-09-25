import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/TextInput/input_primary.dart';
import '../../../../shared/widgets/Buttons/ui_button.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../core/design/branding_config.dart';
import '../bloc/auth_bloc.dart';

class ResetPasswordPage extends StatelessWidget {
  const ResetPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ResetPasswordView();
  }
}

class _ResetPasswordView extends StatefulWidget {
  const _ResetPasswordView();

  @override
  State<_ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<_ResetPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _nipController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _nipController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onSendResetLinkPressed() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            AuthForgotPasswordRequested(
              username: _nipController.text,
              email: _emailController.text,
            ),
          );
    }
  }

  void _onBackToLoginPressed() {
    Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.passwordResetLinkSent) {
            _showMessage('Link reset password telah dikirim ke email Anda');
          } else if (state.status == AuthStatus.error) {
            _showMessage(state.errorMessage ?? 'Reset password gagal');
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
              stops: [0.4, 0.4],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: SizedBox(
                child: Column(
                  children: [
                    Column(
                      children: [
                        // Top section with logo and title
                        // SizedBox(height: 30.h),

                        // Logo with Logoipsum text
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 24.w, vertical: 20.h),
                          color: primaryColor,
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 50.w,
                                    height: 50.h,
                                    padding: EdgeInsets.all(5.r),
                                    decoration: const BoxDecoration(
                                      // color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: SvgPicture.asset(
                                      BrandingController.instance.logo,
                                    ),
                                  ),
                                  Text(
                                    BrandingController.instance.appName,
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),

                              40.verticalSpace,

                              // Title
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Ubah Password',
                                  textAlign: TextAlign.start,
                                  style: TS.headlineLarge.copyWith(
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                              ),

                              16.verticalSpace,

                              // Subtitle
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Masukkan NRP dan Email untuk menerima \ninstruksi perubahan password',
                                  textAlign: TextAlign.start,
                                  style: TS.bodyMedium.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Form Section
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          padding: EdgeInsets.symmetric(
                              horizontal: 24.w, vertical: 32.h),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // NRP Field using InputPrimary
                                InputPrimary(
                                  label: 'NRP',
                                  hint: 'ABB029828',
                                  controller: _nipController,
                                  isRequired: true,
                                  validation: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'NRP tidak boleh kosong';
                                    }
                                    return null;
                                  },
                                  keyboardType: TextInputType.text,
                                  borderRadius: 12,
                                  color: const Color(0xFFF8F9FA),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 15.w,
                                    vertical: 8.h,
                                  ),
                                ),

                                24.verticalSpace,

                                // Email Field using InputPrimary
                                InputPrimary(
                                  label: 'Email',
                                  hint: 'Loisbecket@gmail.com',
                                  controller: _emailController,
                                  isRequired: true,
                                  validation: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Email tidak boleh kosong';
                                    }
                                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                        .hasMatch(value)) {
                                      return 'Format email tidak valid';
                                    }
                                    return null;
                                  },
                                  keyboardType: TextInputType.emailAddress,
                                  borderRadius: 12,
                                  color: const Color(0xFFF8F9FA),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 15.w,
                                    vertical: 8.h,
                                  ),
                                ),

                                30.verticalSpace,

                                // Send Reset Link Button using UIButton
                                BlocBuilder<AuthBloc, AuthState>(
                                  builder: (context, state) {
                                    return UIButton(
                                      text: 'Kirim',
                                      fullWidth: true,
                                      size: UIButtonSize.medium,
                                      variant: UIButtonVariant.primary,
                                      isLoading: state.isLoading,
                                      onPressed: state.isLoading
                                          ? null
                                          : _onSendResetLinkPressed,
                                      borderRadius: 12,
                                    );
                                  },
                                ),

                                30.verticalSpace,
                              ],
                            ),
                          ),
                        ),

                        40.verticalSpace,

                        // Back to Login - moved outside the white container
                        Center(
                          child: GestureDetector(
                            onTap: _onBackToLoginPressed,
                            child: Text(
                              'Kembali Ke Login',
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: const Color(0xFF3498DB),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        40.verticalSpace,
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
