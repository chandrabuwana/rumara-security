import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/di/injection.dart';
import '../../../visitor_gate/presentation/widgets/gate_widgets.dart';
import '../../data/info_create_repository.dart';
import '../cubit/info_create_cubit.dart';

class InfoCreatePage extends StatelessWidget {
  const InfoCreatePage({super.key, required this.repository});

  final InfoCreateRepository repository;

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            InfoCreatePage(repository: InfoCreateRepository(getIt<Dio>())),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InfoCreateCubit(repository)..loadCategories(),
      child: const _InfoCreateView(),
    );
  }
}

class _InfoCreateView extends StatefulWidget {
  const _InfoCreateView();

  @override
  State<_InfoCreateView> createState() => _InfoCreateViewState();
}

class _InfoCreateViewState extends State<_InfoCreateView> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  int? _categoryId;
  DateTime? _endDate;
  Uint8List? _photo;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => _photo = bytes);
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil foto'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickPhoto(source);
  }

  Future<void> _pickEndDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? today.add(const Duration(days: 7)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _endDate = picked);
  }

  void _submit() {
    final valid = _formKey.currentState?.validate() ?? false;
    final categoryId = _categoryId;
    if (!valid || categoryId == null) return;
    final photo = _photo;
    context.read<InfoCreateCubit>().submit(
          InfoDraft(
            categoryId: categoryId,
            title: _title.text.trim(),
            content: _content.text.trim(),
            photoBase64: photo == null ? null : base64Encode(photo),
            startDate: DateTime.now(),
            endDate: _endDate,
          ),
        );
  }

  InputDecoration _decoration(String label, {String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InfoCreateCubit, InfoCreateState>(
      listenWhen: (previous, current) =>
          previous.done != current.done || previous.error != current.error,
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        if (state.done) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Informasi berhasil diterbitkan.')),
          );
          Navigator.of(context).pop();
        } else if (state.error != null) {
          messenger.showSnackBar(SnackBar(content: Text(state.error!)));
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: bgColor,
          body: Column(
            children: [
              const GateHeader(
                title: 'Buat Informasi',
                subtitle: 'Langsung tampil di aplikasi penghuni',
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: _categoryId,
                        isExpanded: true,
                        decoration: _decoration(
                          'Kategori *',
                          icon: Icons.category_outlined,
                          hint: state.loadingCategories
                              ? 'Memuat kategori...'
                              : null,
                        ),
                        items: state.categories
                            .map(
                              (item) => DropdownMenuItem<int>(
                                value: item.id,
                                child: Text(item.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _categoryId = value),
                        validator: (value) =>
                            value == null ? 'Pilih kategori' : null,
                      ),
                      if (!state.loadingCategories && state.categories.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Kategori belum tersedia.',
                                  style: TextStyle(
                                      fontSize: 12, color: errorColor),
                                ),
                              ),
                              TextButton(
                                onPressed: () => context
                                    .read<InfoCreateCubit>()
                                    .loadCategories(),
                                child: const Text('Muat ulang'),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _title,
                        maxLength: 150,
                        textCapitalization: TextCapitalization.sentences,
                        decoration:
                            _decoration('Judul *', icon: Icons.title_outlined),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Judul wajib diisi'
                                : null,
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _content,
                        minLines: 5,
                        maxLines: 10,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _decoration(
                          'Isi informasi *',
                          hint: 'Tulis informasi untuk penghuni',
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Isi informasi wajib diisi'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      GateCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: Row(
                          children: [
                            Icon(Icons.event_outlined, color: primaryColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tayang sampai',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: neutral90),
                                  ),
                                  Text(
                                    _endDate == null
                                        ? 'Tanpa batas waktu'
                                        : DateFormat('dd MMM yyyy', 'id_ID')
                                            .format(_endDate!),
                                    style: TextStyle(
                                        fontSize: 12, color: neutral50),
                                  ),
                                ],
                              ),
                            ),
                            if (_endDate != null)
                              IconButton(
                                onPressed: () =>
                                    setState(() => _endDate = null),
                                icon: const Icon(Icons.close),
                              ),
                            TextButton(
                              onPressed: _pickEndDate,
                              child: const Text('Pilih'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _photoField(),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: GateButton(
                    label: 'Terbitkan',
                    icon: Icons.send_outlined,
                    loading: state.submitting,
                    onPressed: state.loadingCategories ? null : _submit,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _photoField() {
    final photo = _photo;
    return GateCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 72,
              height: 72,
              color: neutral10,
              child: photo == null
                  ? Icon(Icons.image_outlined, color: neutral50)
                  : Image.memory(photo, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Foto',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, color: neutral90),
                ),
                Text(
                  'Opsional',
                  style: TextStyle(fontSize: 12, color: neutral50),
                ),
              ],
            ),
          ),
          if (photo != null)
            IconButton(
              onPressed: () => setState(() => _photo = null),
              icon: const Icon(Icons.delete_outline),
            ),
          TextButton(
            onPressed: _choosePhoto,
            child: Text(photo == null ? 'Tambah' : 'Ganti'),
          ),
        ],
      ),
    );
  }
}
