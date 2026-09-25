import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';
import '../widgets/profile_menu_item.dart';
import '../widgets/profile_header.dart';
import 'profile_details_screen.dart';
import 'theme_picker_screen.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/pages/change_password_page.dart';

/// Layar utama profil yang menampilkan informasi singkat dan menu-menu profil
class ProfileScreen extends StatelessWidget {
  final String userId;

  const ProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<ProfileBloc>()..add(LoadProfileEvent(userId)),
      child: ProfileScreenView(userId: userId),
    );
  }
}

class ProfileScreenView extends StatelessWidget {
  final String userId;

  const ProfileScreenView({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: primaryColor,
      enableScrolling: false, // Disable scrolling since we're using Expanded
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Profile',
          style: TS.titleLarge.copyWith(color: Colors.white),
        ),
        centerTitle: true,
      ),
      child: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          // Handle logout success
          if (state is LogoutSuccess) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          }

          // Handle logout failure
          if (state is LogoutFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage),
                backgroundColor: Colors.red,
              ),
            );
          }

          // Handle delete account success
          if (state is DeleteAccountSuccess) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          }

          // Handle delete account failure
          if (state is DeleteAccountFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage),
                backgroundColor: Colors.red,
              ),
            );
          }

          // Handle profile update success
          if (state is ProfileUpdateSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage),
                backgroundColor: Colors.green,
              ),
            );
          }

          // Handle profile update failure
          if (state is ProfileUpdateFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage),
                backgroundColor: Colors.red,
              ),
            );
          }

          // Show logout confirmation dialog
          if (state is ProfileLoaded && state.showLogoutConfirmation) {
            _showLogoutConfirmationDialog(context);
          }

          // Show delete account confirmation dialog
          if (state is ProfileLoaded && state.showDeleteAccountConfirmation) {
            _showDeleteAccountConfirmationDialog(context);
          }
        },
        builder: (context, state) {
          if (state is ProfileLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            );
          }

          if (state is ProfileError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 64.w,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Error: ${state.message}',
                    style: TS.bodyMedium.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: () {
                      context.read<ProfileBloc>().add(LoadProfileEvent(userId));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryColor,
                    ),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          }

          if (state is ProfileLoaded ||
              state is ProfileUpdateInProgress ||
              state is DocumentUploadInProgress) {
            final profile = _getProfileFromState(state);
            final isLoading = state is ProfileUpdateInProgress ||
                state is DocumentUploadInProgress;

            return Stack(
              children: [
                Column(
                  children: [
                    // Header dengan foto profil dan info dasar
                    ProfileHeader(
                      profile: profile,
                      onPhotoTap: () => _navigateToPhotoUpdate(context),
                    ),

                    SizedBox(height: 32.h),

                    // Body dengan menu-menu
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(24.r),
                            topRight: Radius.circular(24.r),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(20.w),
                          child: ListView(
                            children: [
                              SizedBox(height: 20.h),

                              // Menu Profil Saya
                              ProfileMenuItem(
                                icon: Icons.person,
                                title: 'Profil Saya',
                                onTap: () => _navigateToProfileDetails(context),
                              ),

                              SizedBox(height: 16.h),

                              // Menu Tema
                              ProfileMenuItem(
                                icon: Icons.palette,
                                title: 'Tema',
                                onTap: () => _navigateToThemePicker(context),
                              ),

                              SizedBox(height: 16.h),

                              // Menu Bantuan
                              ProfileMenuItem(
                                icon: Icons.help_outline,
                                title: 'Bantuan',
                                onTap: () => _navigateToHelp(context),
                              ),

                              SizedBox(height: 16.h),

                              // Menu Ubah Password
                              ProfileMenuItem(
                                icon: Icons.lock_outline,
                                title: 'Ubah Password',
                                onTap: () => _navigateToChangePassword(context),
                              ),

                              SizedBox(height: 16.h),

                              // Menu Keluar
                              ProfileMenuItem(
                                icon: Icons.logout,
                                title: 'Keluar',
                                titleColor: Colors.red,
                                onTap: () => _showLogoutConfirmation(context),
                              ),

                              SizedBox(height: 16.h),

                              // Menu Hapus Akun
                              ProfileMenuItem(
                                icon: Icons.delete_forever,
                                title: 'Hapus Akun',
                                titleColor: Colors.red[700],
                                onTap: () =>
                                    _showDeleteAccountConfirmation(context),
                              ),

                              SizedBox(height: 20.h),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Loading overlay
                if (isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            );
          }

          return const SizedBox();
        },
      ),
    );
  }

  /// Helper method untuk mendapatkan profile dari berbagai state
  dynamic _getProfileFromState(ProfileState state) {
    if (state is ProfileLoaded) return state.profile;
    if (state is ProfileUpdateInProgress) return state.currentProfile;
    if (state is DocumentUploadInProgress) return state.currentProfile;
    return null;
  }

  /// Navigate ke halaman update foto
  void _navigateToPhotoUpdate(BuildContext context) {
    // TODO: Implement navigation to photo update page
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fitur update foto akan segera tersedia')),
    );
  }

  /// Navigate ke halaman detail profil
  void _navigateToProfileDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProfileDetailsScreen(userId: userId),
      ),
    );
  }

  /// Navigate ke halaman bantuan
  void _navigateToHelp(BuildContext context) {
    // TODO: Implement navigation to help page
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fitur bantuan akan segera tersedia')),
    );
  }

  /// Navigate ke halaman tema (paleta + mode brightness).
  void _navigateToThemePicker(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ThemePickerScreen(),
      ),
    );
  }

  void _navigateToChangePassword(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BlocProvider(
          create: (context) => getIt<AuthBloc>(),
          child: const ChangePasswordPage(),
        ),
      ),
    );
  }

  /// Show logout confirmation
  void _showLogoutConfirmation(BuildContext context) {
    context.read<ProfileBloc>().add(const ShowLogoutConfirmationEvent());
  }

  /// Show logout confirmation dialog
  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ConfirmDialog(
        title: 'Keluar Dari Akun Sekarang?',
        message:
            'Anda akan keluar dari aplikasi dan perlu login kembali untuk mengakses fitur-fitur.',
        confirmText: 'Keluar',
        cancelText: 'Batal',
        icon: Icons.logout,
        iconColor: Colors.red,
        isDestructive: true,
        onConfirm: () {
          Navigator.of(dialogContext).pop();
          context.read<ProfileBloc>().add(const LogoutEvent());
        },
        onCancel: () {
          Navigator.of(dialogContext).pop();
          context.read<ProfileBloc>().add(const HideLogoutConfirmationEvent());
        },
      ),
    );
  }

  /// Show delete account confirmation
  void _showDeleteAccountConfirmation(BuildContext context) {
    context.read<ProfileBloc>().add(const ShowDeleteAccountConfirmationEvent());
  }

  /// Show delete account confirmation dialog
  void _showDeleteAccountConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ConfirmDialog(
        title: 'Hapus Akun Permanen?',
        message:
            'Tindakan ini tidak dapat dibatalkan. Semua data Anda akan dihapus secara permanen dan Anda tidak akan bisa mengakses akun ini lagi.',
        confirmText: 'Hapus Akun',
        cancelText: 'Batal',
        icon: Icons.delete_forever,
        iconColor: Colors.red[700]!,
        isDestructive: true,
        onConfirm: () {
          Navigator.of(dialogContext).pop();
          context.read<ProfileBloc>().add(const DeleteAccountEvent());
        },
        onCancel: () {
          Navigator.of(dialogContext).pop();
          context
              .read<ProfileBloc>()
              .add(const HideDeleteAccountConfirmationEvent());
        },
      ),
    );
  }
}
