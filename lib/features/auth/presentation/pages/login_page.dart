import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/utils/screen_utils.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/TextInput/input_primary.dart';
import '../../../../shared/widgets/Buttons/ui_button.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../core/design/branding_config.dart';
import '../../../../core/design/brand_logo.dart';
import '../bloc/auth_bloc.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nrpController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _rememberMe = false;

  @override
  void dispose() {
    _nrpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            AuthLoginRequested(
              email: _nrpController.text, // Using NRP as identifier
              password: _passwordController.text,
            ),
          );
    }
  }

  void _onForgotPasswordPressed() {
    Navigator.pushNamed(context, '/reset-password');
  }

  void _onRegisterPressed() {
    Navigator.pushNamed(context, '/register');
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.authenticated) {
            print('');
            print('🚀 ========================================');
            print('🚀 AUTH SUCCESS - NAVIGATING TO HOME');
            print('🚀 ========================================');
            Navigator.pushReplacementNamed(context, '/home');
            print('🚀 Navigation to /home completed');
            print('🚀 ========================================');
            print('');
          } else if (state.status == AuthStatus.error) {
            // Tampilkan popup dialog untuk error
            _showErrorDialog(
              'Login Gagal',
              state.errorMessage ??
                  'Terjadi kesalahan saat login. Silakan coba lagi.',
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
              stops: [0.4, 0.4],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: SizedBox(
                  child: Stack(
                children: [
                  Container(
                    height: ScreenUtils.halfHeight,
                    color: primaryColor,
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Column(
                      children: [
                        // Top section with logo and title
                        30.verticalSpace,

                        // Shield logo
                        Container(
                          width: 80.w,
                          height: 80.h,
                          padding: EdgeInsets.all(16.r),
                          decoration: const BoxDecoration(
                            // color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: BrandLogo(
                            BrandingController.instance.logo,
                          ),
                        ),

                        // SizedBox(height: 40.h),

                        // Title
                        Text(
                          'Masuk Ke Akun\nAnda',
                          textAlign: TextAlign.center,
                          style: TS.headlineLarge.copyWith(
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),

                        16.verticalSpace,

                        // Subtitle
                        Text(
                          'Masukkan NRP dan password untuk masuk ke aplikasi',
                          textAlign: TextAlign.center,
                          style: TS.bodyLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),

                        30.verticalSpace,

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
                                  hint: '',
                                  controller: _nrpController,
                                  isRequired: true,
                                  validation: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'NRP tidak boleh kosong';
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

                                24.verticalSpace,

                                // Password Field using InputPrimary
                                InputPrimary(
                                  label: 'Password',
                                  hint: '',
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

                                // Remember me and Forgot password row
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: _rememberMe,
                                          onChanged: (value) {
                                            setState(() {
                                              _rememberMe = value ?? false;
                                            });
                                          },
                                          activeColor: primaryColor,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        Text(
                                          'Remember me',
                                          style: TS.bodyMedium.copyWith(
                                            color: neutral70,
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: _onForgotPasswordPressed,
                                      child: Text(
                                        'Lupa Password ?',
                                        style: TS.bodyMedium.copyWith(
                                          color: const Color(0xFF4A90E2),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                30.verticalSpace,

                                // Login Button using UIButton
                                BlocBuilder<AuthBloc, AuthState>(
                                  builder: (context, state) {
                                    return UIButton(
                                      text: 'Masuk',
                                      fullWidth: true,
                                      size: UIButtonSize.medium,
                                      variant: UIButtonVariant.primary,
                                      isLoading: state.isLoading,
                                      onPressed: state.isLoading
                                          ? null
                                          : _onLoginPressed,
                                      borderRadius: 12,
                                    );
                                  },
                                ),

                                20.verticalSpace,

                                // Register Link
                                Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Don\'t have an account? ',
                                        style: TS.bodyMedium.copyWith(
                                          color: neutral70,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _onRegisterPressed,
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          'Register',
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
                  )
                ],
              )),
            ),
          ),
        ),
      ),
    );
  }
}
