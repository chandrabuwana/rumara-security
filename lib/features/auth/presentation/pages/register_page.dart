import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/utils/screen_utils.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/TextInput/input_primary.dart';
import '../../../../shared/widgets/Buttons/ui_button.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../core/design/branding_config.dart';
import '../bloc/auth_bloc.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onRegisterPressed() {
    if (_formKey.currentState?.validate() ?? false) {
      // Validasi password dan confirm password match
      if (_passwordController.text != _confirmPasswordController.text) {
        _showErrorDialog(
          'Error',
          'Password dan Ulangi Password tidak sama',
        );
        return;
      }

      // TODO: Implement register API call when available
      // For now, just show a message
      _showSuccessDialog(
        'Registrasi Berhasil',
        'Akun berhasil dibuat. Silakan login dengan kredensial Anda.',
      );

      // Example of how to call the bloc when API is ready:
      // context.read<AuthBloc>().add(
      //   AuthRegisterRequested(
      //     email: _emailController.text,
      //     name: _usernameController.text,
      //     password: _passwordController.text,
      //     phoneNumber: null,
      //   ),
      // );
    }
  }

  void _onBackToLoginPressed() {
    Navigator.pop(context);
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 28.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  title,
                  style: TS.titleLarge.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TS.bodyLarge.copyWith(
              color: neutral70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text(
                'OK',
                style: TS.labelLarge.copyWith(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 28.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  title,
                  style: TS.titleLarge.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TS.bodyLarge.copyWith(
              color: neutral70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.pop(context); // Back to login page
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text(
                'OK',
                style: TS.labelLarge.copyWith(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.authenticated) {
            // Registration successful
            _showSuccessDialog(
              'Registrasi Berhasil',
              'Akun berhasil dibuat. Silakan login dengan kredensial Anda.',
            );
          } else if (state.status == AuthStatus.error) {
            _showErrorDialog(
              'Registrasi Gagal',
              state.errorMessage ??
                  'Terjadi kesalahan saat registrasi. Silakan coba lagi.',
            );
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
            child: SingleChildScrollView(
              child: SizedBox(
                child: Stack(
                  children: [
                    Container(
                      height: ScreenUtils.halfHeight * 0.7,
                      color: primaryColor,
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Column(
                        children: [
                          // Top section with logo and title
                          20.verticalSpace,

                          // Shield logo
                          Container(
                            width: 70.w,
                            height: 70.h,
                            padding: EdgeInsets.all(14.r),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: SvgPicture.asset(
                              BrandingController.instance.logo,
                            ),
                          ),

                          // Title
                          Text(
                            'Create Your\nAccount',
                            textAlign: TextAlign.center,
                            style: TS.headlineLarge.copyWith(
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),

                          12.verticalSpace,

                          // Subtitle
                          Text(
                            'Fill in the details below to register',
                            textAlign: TextAlign.center,
                            style: TS.bodyLarge.copyWith(
                              color: Colors.white,
                            ),
                          ),

                          24.verticalSpace,

                          // Form Section
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 24.w,
                              vertical: 32.h,
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Email Field
                                  InputPrimary(
                                    label: 'Email',
                                    hint: 'example@email.com',
                                    controller: _emailController,
                                    isRequired: true,
                                    validation: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Email tidak boleh kosong';
                                      }
                                      // Basic email validation
                                      final emailRegex = RegExp(
                                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                      );
                                      if (!emailRegex.hasMatch(value)) {
                                        return 'Format email tidak valid';
                                      }
                                      return null;
                                    },
                                    keyboardType: TextInputType.emailAddress,
                                    borderRadius: 12,
                                    color: Colors.white,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 15.w,
                                      vertical: 8.h,
                                    ),
                                  ),

                                  20.verticalSpace,

                                  // Username Field
                                  InputPrimary(
                                    label: 'Username',
                                    hint: 'Enter your username',
                                    controller: _usernameController,
                                    isRequired: true,
                                    validation: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Username tidak boleh kosong';
                                      }
                                      if (value.length < 3) {
                                        return 'Username minimal 3 karakter';
                                      }
                                      return null;
                                    },
                                    keyboardType: TextInputType.text,
                                    borderRadius: 12,
                                    color: Colors.white,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 15.w,
                                      vertical: 8.h,
                                    ),
                                  ),

                                  20.verticalSpace,

                                  // Password Field
                                  InputPrimary(
                                    label: 'Password',
                                    hint: 'Enter your password',
                                    controller: _passwordController,
                                    isRequired: true,
                                    obscureText: !_isPasswordVisible,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isPasswordVisible
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: neutral50,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isPasswordVisible =
                                              !_isPasswordVisible;
                                        });
                                      },
                                    ),
                                    validation: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Password tidak boleh kosong';
                                      }
                                      if (value.length < 6) {
                                        return 'Password minimal 6 karakter';
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

                                  // Confirm Password Field
                                  InputPrimary(
                                    label: 'Ulangi Password',
                                    hint: 'Re-enter your password',
                                    controller: _confirmPasswordController,
                                    isRequired: true,
                                    obscureText: !_isConfirmPasswordVisible,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isConfirmPasswordVisible
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: neutral50,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isConfirmPasswordVisible =
                                              !_isConfirmPasswordVisible;
                                        });
                                      },
                                    ),
                                    validation: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Konfirmasi password tidak boleh kosong';
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

                                  // Register Button
                                  BlocBuilder<AuthBloc, AuthState>(
                                    builder: (context, state) {
                                      return UIButton(
                                        text: 'Register',
                                        fullWidth: true,
                                        size: UIButtonSize.medium,
                                        variant: UIButtonVariant.primary,
                                        isLoading: state.isLoading,
                                        onPressed: state.isLoading
                                            ? null
                                            : _onRegisterPressed,
                                        borderRadius: 12,
                                      );
                                    },
                                  ),

                                  20.verticalSpace,

                                  // Back to Login
                                  Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Already have an account? ',
                                          style: TS.bodyMedium.copyWith(
                                            color: neutral70,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: _onBackToLoginPressed,
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: Text(
                                            'Log In',
                                            style: TS.bodyMedium.copyWith(
                                              color: primaryColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  16.verticalSpace,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
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
