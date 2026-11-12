import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/design/styles.dart';
import '../../../../shared/widgets/Buttons/ui_button.dart';
import '../../../../shared/widgets/custom_dropdown.dart';
import '../../../../shared/widgets/TextInput/input_primary.dart';
import '../../../../shared/widgets/photo_picker_field.dart';
import '../../../../core/security/security_manager.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../bloc/incident_bloc.dart';
import '../bloc/incident_event.dart';
import '../bloc/incident_state.dart';
import '../../domain/entities/incident_location_entity.dart';
import '../../domain/entities/incident_type_entity.dart';
import '../../../../shared/widgets/rumara_app_bar.dart';

class IncidentReportFormPage extends StatefulWidget {
  const IncidentReportFormPage({super.key});

  @override
  State<IncidentReportFormPage> createState() => _IncidentReportFormPageState();

  /// Wrapper widget yang memastikan IncidentBloc selalu tersedia
  static Widget wrapped(BuildContext? parentContext) {
    // Coba ambil dari parent context jika ada
    IncidentBloc? existingBloc;
    if (parentContext != null) {
      try {
        existingBloc = parentContext.read<IncidentBloc>();
      } catch (e) {
        // Bloc tidak ada di context, akan dibuat baru
      }
    }

    if (existingBloc != null) {
      // Gunakan bloc yang sudah ada
      return BlocProvider.value(
        value: existingBloc,
        child: const IncidentReportFormPage(),
      );
    } else {
      // Buat bloc baru
      return BlocProvider(
        create: (context) => getIt<IncidentBloc>(),
        child: const IncidentReportFormPage(),
      );
    }
  }
}

class _IncidentReportFormPageState extends State<IncidentReportFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _detailLokasiController = TextEditingController();
  final _deskripsiController = TextEditingController();

  DateTime? _tanggalInsiden;
  TimeOfDay? _jamInsiden;
  IncidentLocationEntity? _selectedLocation;
  IncidentTypeEntity? _selectedType;
  List<String> _fotoPaths = [];
  bool _hasSubmitted = false; // Flag untuk memastikan form hanya ditutup setelah submit berhasil

  @override
  void initState() {
    super.initState();
    // Load locations and types
    // Use BlocProvider.of with listen: false to avoid ProviderNotFoundException
    final bloc = BlocProvider.of<IncidentBloc>(context, listen: false);
    bloc.add(const LoadIncidentLocationsEvent());
    bloc.add(const LoadIncidentTypesEvent());
  }

  @override
  void dispose() {
    _detailLokasiController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _tanggalInsiden ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _tanggalInsiden = date;
      });
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _jamInsiden ?? TimeOfDay.now(),
    );
    if (time != null) {
      setState(() {
        _jamInsiden = time;
      });
    }
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_tanggalInsiden == null || _jamInsiden == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mohon lengkapi tanggal dan jam insiden'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mohon pilih lokasi insiden'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mohon pilih tipe insiden'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Combine date and time
    final dateTime = DateTime(
      _tanggalInsiden!.year,
      _tanggalInsiden!.month,
      _tanggalInsiden!.day,
      _jamInsiden!.hour,
      _jamInsiden!.minute,
    );

    // Get current user ID
    final userId = await SecurityManager.readSecurely(AppConstants.userIdKey) ?? '';

    // Set flag bahwa form sudah di-submit
    setState(() {
      _hasSubmitted = true;
    });

    BlocProvider.of<IncidentBloc>(context, listen: false).add(
          CreateIncidentReportEvent(
            reporterId: userId,
            tanggalInsiden: _tanggalInsiden!,
            jamInsiden: dateTime,
            lokasiInsidenId: _selectedLocation!.id,
            lokasiInsidenName: _selectedLocation!.name,
            detailLokasiInsiden: _detailLokasiController.text.trim(),
            tipeInsidenId: _selectedType!.id,
            deskripsiInsiden: _deskripsiController.text.trim(),
            fotoInsiden: _fotoPaths.isNotEmpty ? _fotoPaths.first : null,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<IncidentBloc, IncidentState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        }
        // Hanya tutup form jika sudah submit dan create berhasil
        // Ini mencegah form ditutup saat baru dibuka karena incidentDetail sudah ada dari operasi sebelumnya
        if (_hasSubmitted && state.incidentDetail != null && !state.isLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Laporan insiden berhasil dibuat'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: const RumaraAppBar(title: 'Lapor Insiden Kejadian'),
        body: BlocBuilder<IncidentBloc, IncidentState>(
          builder: (context, state) {
            return SingleChildScrollView(
              padding: REdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Center(
                      child: Text(
                        'Insiden Kejadian',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    24.verticalSpace,

                    // Status (read-only)
                    _buildReadOnlyField(
                      label: 'Status',
                      value: 'Menunggu',
                    ),
                    20.verticalSpace,

                    // Tanggal Insiden
                    _buildDateField(
                      label: 'Tanggal Insiden',
                      selectedDate: _tanggalInsiden,
                      onTap: _selectDate,
                    ),
                    20.verticalSpace,

                    // Jam Insiden
                    _buildTimeField(
                      label: 'Jam Insiden',
                      selectedTime: _jamInsiden,
                      onTap: _selectTime,
                    ),
                    20.verticalSpace,

                    // Lokasi Insiden
                    BlocBuilder<IncidentBloc, IncidentState>(
                      builder: (context, state) {
                        final locations = state.locations;
                        if (locations.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final dropdownItems = locations
                            .map((location) => DropdownItem<IncidentLocationEntity>(
                                  value: location,
                                  text: location.name,
                                ))
                            .toList();

                        return CustomDropdown<IncidentLocationEntity>(
                          label: 'Lokasi Insiden',
                          hint: 'Pilih lokasi',
                          value: _selectedLocation,
                          items: dropdownItems,
                          isRequired: true,
                          onChanged: (value) {
                            setState(() {
                              _selectedLocation = value;
                            });
                          },
                        );
                      },
                    ),
                    20.verticalSpace,

                    // Detail Lokasi Insiden
                    InputPrimary(
                      label: 'Detail Lokasi Insiden',
                      controller: _detailLokasiController,
                      hint: 'Masukkan detail lokasi',
                      isRequired: true,
                      maxLines: 10, // Increased to allow more text to be visible
                      minLines: 3, // Minimum 3 lines to show more text
                      maxLength: 500,
                      validation: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Detail lokasi harus diisi';
                        }
                        return null;
                      },
                    ),
                    20.verticalSpace,

                    // Tipe Insiden
                    BlocBuilder<IncidentBloc, IncidentState>(
                      builder: (context, state) {
                        final types = state.types;
                        if (types.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final dropdownItems = types
                            .map((type) => DropdownItem<IncidentTypeEntity>(
                                  value: type,
                                  text: type.name,
                                ))
                            .toList();

                        return CustomDropdown<IncidentTypeEntity>(
                          label: 'Tipe Insiden',
                          hint: 'Pilih tipe insiden',
                          value: _selectedType,
                          items: dropdownItems,
                          isRequired: true,
                          onChanged: (value) {
                            setState(() {
                              _selectedType = value;
                            });
                          },
                        );
                      },
                    ),
                    20.verticalSpace,

                    // Deskripsi Insiden
                    InputPrimary(
                      label: 'Deskripsi Insiden',
                      controller: _deskripsiController,
                      hint: 'Masukkan deskripsi insiden',
                      isRequired: true,
                      maxLines: 15, // Increased to allow more text to be visible
                      minLines: 5, // Minimum 5 lines to show more text
                      maxLength: 1000,
                      validation: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Deskripsi insiden harus diisi';
                        }
                        return null;
                      },
                    ),
                    20.verticalSpace,

                    // Foto Insiden
                    _buildPhotoField(),
                    32.verticalSpace,

                    // Submit Button
                    BlocBuilder<IncidentBloc, IncidentState>(
                      builder: (context, state) {
                        return UIButton(
                          text: 'Laporkan',
                          fullWidth: true,
                          size: UIButtonSize.large,
                          isLoading: state.isLoading,
                          onPressed: state.isLoading ? null : _submitForm,
                        );
                      },
                    ),
                    16.verticalSpace,
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TS.labelLarge,
        ),
        8.verticalSpace,
        Container(
          width: double.infinity,
          padding: REdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10.r),
            color: Colors.grey.shade100,
          ),
          child: Text(
            value,
            style: TS.bodyLarge.copyWith(
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? selectedDate,
    required VoidCallback onTap,
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
            Text(
              '*',
              style: TS.bodyLarge.copyWith(color: Colors.red),
            ),
          ],
        ),
        8.verticalSpace,
        InkWell(
          onTap: onTap,
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
                        : 'dd/mm/yyyy',
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

  Widget _buildTimeField({
    required String label,
    required TimeOfDay? selectedTime,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TS.labelLarge,
            ),
            Text(
              '*',
              style: TS.bodyLarge.copyWith(color: Colors.red),
            ),
          ],
        ),
        8.verticalSpace,
        InkWell(
          onTap: onTap,
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
                    selectedTime != null
                        ? '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}'
                        : 'HH:mm',
                    style: TS.bodyLarge.copyWith(
                      color: selectedTime != null
                          ? Colors.black87
                          : Colors.grey.shade500,
                    ),
                  ),
                ),
                Icon(
                  Icons.access_time,
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

  Widget _buildPhotoField() {
    return PhotoPickerField(
      label: 'Foto Insiden',
      photos: _fotoPaths,
      onPhotosChanged: (photos) {
        setState(() {
          _fotoPaths = photos;
        });
      },
      multiple: false,
      maxPhotos: 1,
    );
  }
}

