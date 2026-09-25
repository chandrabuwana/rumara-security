import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/utils/user_role_helper.dart';
import '../bloc/news_bloc.dart';
import '../bloc/news_event.dart';
import '../bloc/news_state.dart';
import '../../domain/entities/news.dart';
import '../../../../core/design/colors.dart';

class AddNewsPage extends StatefulWidget {
  const AddNewsPage({super.key});

  @override
  State<AddNewsPage> createState() => _AddNewsPageState();
}

class _AddNewsPageState extends State<AddNewsPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _sourceController = TextEditingController();
  final _photoController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  NewsCategory _selectedCategory = NewsCategory.cuaca;
  UserRole? _userRole;
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await UserRoleHelper.getUserRole();
    if (!mounted) return;
    setState(() {
      _userRole = role;
      _isLoadingRole = false;
    });
  }

  bool get _canCreateNews => _userRole == UserRole.pengawas;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _sourceController.dispose();
    _photoController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (!_canCreateNews) return;
    try {
      final XFile? xFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (xFile == null) return;

      final file = File(xFile.path);
      setState(() {
        _photoController.text = file.path;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memilih foto'),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showPickPhotoSheet() async {
    if (!_canCreateNews) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hanya role Pengawas yang dapat menambahkan berita'),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    HardwareKeyboard.instance.clearState();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Kamera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeri'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null || !mounted) return;
    await _pickPhoto(source);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Tambah Berita',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocConsumer<NewsBloc, NewsState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: errorColor,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }

          if (state.createSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Berita berhasil ditambahkan'),
                backgroundColor: successColor,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.pop(context);
          }
        },
        builder: (context, state) {
          if (_isLoadingRole) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!_canCreateNews) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Text(
                  'Hanya role Pengawas yang dapat menambahkan berita',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: neutral90,
                  ),
                ),
              ),
            );
          }

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Heading
                  Text(
                    'Buat Berita',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: neutral90,
                    ),
                  ),

                  24.verticalSpace,

                  // Category Dropdown
                  Text(
                    'Kategori',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: neutral90,
                    ),
                  ),
                  8.verticalSpace,
                  Container(
                    width: double.infinity,
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      border: Border.all(color: neutral30),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<NewsCategory>(
                        value: _selectedCategory,
                        isExpanded: true,
                        items: NewsCategory.values.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(
                              category.displayName,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: neutral90,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (NewsCategory? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedCategory = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ),

                  16.verticalSpace,

                  // Title Field
                  Text(
                    'Judul',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: neutral90,
                    ),
                  ),
                  8.verticalSpace,
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'XXX',
                      hintStyle: TextStyle(
                        color: neutral50,
                        fontSize: 14.sp,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: neutral30),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: neutral30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Judul tidak boleh kosong';
                      }
                      return null;
                    },
                  ),

                  16.verticalSpace,

                  // Content Field
                  Text(
                    'Isi Berita',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: neutral90,
                    ),
                  ),
                  8.verticalSpace,
                  TextFormField(
                    controller: _contentController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'XXX',
                      hintStyle: TextStyle(
                        color: neutral50,
                        fontSize: 14.sp,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: neutral30),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: neutral30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      contentPadding: EdgeInsets.all(16.w),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Isi berita tidak boleh kosong';
                      }
                      return null;
                    },
                  ),

                  16.verticalSpace,

                  // Source Field
                  Text(
                    'Sumber',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: neutral90,
                    ),
                  ),
                  8.verticalSpace,
                  TextFormField(
                    controller: _sourceController,
                    decoration: InputDecoration(
                      hintText: 'XXX',
                      hintStyle: TextStyle(
                        color: neutral50,
                        fontSize: 14.sp,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: neutral30),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: neutral30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Sumber tidak boleh kosong';
                      }
                      return null;
                    },
                  ),

                  16.verticalSpace,

                  // Photo Field
                  Text(
                    'Foto',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: neutral90,
                    ),
                  ),
                  8.verticalSpace,
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _photoController,
                          decoration: InputDecoration(
                            hintText: 'XXX',
                            hintStyle: TextStyle(
                              color: neutral50,
                              fontSize: 14.sp,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              borderSide: BorderSide(color: neutral30),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              borderSide: BorderSide(color: neutral30),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              borderSide: BorderSide(color: primaryColor),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 12.h,
                            ),
                          ),
                        ),
                      ),
                      8.horizontalSpace,
                      Container(
                        width: 48.w,
                        height: 48.h,
                        decoration: BoxDecoration(
                          color: neutral10,
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: neutral30),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.camera_alt,
                            color: neutral70,
                            size: 20.sp,
                          ),
                          onPressed: () {
                            _showPickPhotoSheet();
                          },
                        ),
                      ),
                      8.horizontalSpace,
                      Container(
                        width: 48.w,
                        height: 48.h,
                        decoration: BoxDecoration(
                          color: neutral10,
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: neutral30),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.keyboard_arrow_down,
                            color: neutral70,
                            size: 20.sp,
                          ),
                          onPressed: () {
                            _showPickPhotoSheet();
                          },
                        ),
                      ),
                    ],
                  ),

                  if (_photoController.text.trim().isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 8.h),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 10.h,
                        ),
                        decoration: BoxDecoration(
                          color: neutral10,
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: neutral30),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _photoController.text.trim(),
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: neutral90,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                size: 18.sp,
                                color: neutral70,
                              ),
                              onPressed: () {
                                setState(() {
                                  _photoController.clear();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                  32.verticalSpace,

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: (state.isLoading || !_canCreateNews)
                          ? null
                          : _saveNews,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: state.isLoading
                          ? SizedBox(
                              width: 20.w,
                              height: 20.h,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Simpan',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  32.verticalSpace,
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _saveNews() {
    if (_formKey.currentState!.validate()) {
      final news = News(
        id: '', // Will be generated by repository
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        category: _selectedCategory.displayName,
        source: _sourceController.text.trim(),
        imageUrl: _photoController.text.trim().isNotEmpty
            ? _photoController.text.trim()
            : null,
        publishedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      context.read<NewsBloc>().add(NewsCreateNews(news));
    }
  }
}
