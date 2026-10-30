import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/design/colors.dart';
import '../../data/visitor_gate_models.dart';
import '../../data/visitor_gate_repository.dart';
import '../cubit/walk_in_form_cubit.dart';
import '../widgets/gate_widgets.dart';
import 'walk_in_wait_page.dart';

class WalkInFormPage extends StatelessWidget {
  const WalkInFormPage({super.key, required this.repository});

  final VisitorGateRepository repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => WalkInFormCubit(repository)..loadOptions(),
      child: _WalkInFormView(repository: repository),
    );
  }
}

class _WalkInFormView extends StatefulWidget {
  const _WalkInFormView({required this.repository});

  final VisitorGateRepository repository;

  @override
  State<_WalkInFormView> createState() => _WalkInFormViewState();
}

class _WalkInFormViewState extends State<_WalkInFormView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _unitSearch = TextEditingController();
  final _plate = TextEditingController();
  final _purpose = TextEditingController();
  String? _type;
  int _guests = 1;
  Uint8List? _photo;
  bool _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _unitSearch.dispose();
    _plate.dispose();
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => _photo = bytes);
  }

  void _submit(WalkInFormState state) {
    setState(() => _submitted = true);
    final valid = _formKey.currentState?.validate() ?? false;
    final unit = state.unit;
    final photoMissing = state.options.photoRequired && _photo == null;
    if (!valid || unit == null || photoMissing) return;
    final photo = _photo;
    context.read<WalkInFormCubit>().submit(
          WalkInDraft(
            unitId: unit.unitId,
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            guestCount: _guests,
            visitorType: _type,
            plateNumber: _plate.text.trim().isEmpty ? null : _plate.text.trim(),
            purpose: _purpose.text.trim().isEmpty ? null : _purpose.text.trim(),
            photoBase64: photo == null ? '' : base64Encode(photo),
            photoMimeType: 'image/jpeg',
          ),
        );
  }

  Future<void> _openWaiting(WalkInTicket ticket) async {
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            WalkInWaitPage(repository: widget.repository, ticket: ticket),
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
    return BlocConsumer<WalkInFormCubit, WalkInFormState>(
      listenWhen: (previous, current) =>
          previous.ticket != current.ticket || previous.error != current.error,
      listener: (context, state) {
        final ticket = state.ticket;
        if (ticket != null && ticket.requestId.isNotEmpty) {
          _openWaiting(ticket);
        } else if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!)),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<WalkInFormCubit>();
        return Scaffold(
          backgroundColor: bgColor,
          body: Column(
            children: [
              const GateHeader(
                title: 'Walk-In Visitor',
                subtitle: 'Tamu tanpa undangan, perlu persetujuan penghuni',
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: _decoration('Nama tamu *',
                            icon: Icons.person_outline),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Nama wajib diisi'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration:
                            _decoration('No. HP *', icon: Icons.phone_outlined),
                        validator: (value) =>
                            (value == null || value.trim().length < 8)
                                ? 'No. HP wajib diisi'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      _unitField(state, cubit),
                      const SizedBox(height: 16),
                      if (state.options.visitorTypes.isNotEmpty) ...[
                        Text(
                          'Jenis kunjungan',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: neutral90),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: state.options.visitorTypes
                              .map(
                                (option) => ChoiceChip(
                                  label: Text(option.label),
                                  selected: _type == option.code,
                                  onSelected: (selected) => setState(() =>
                                      _type = selected ? option.code : null),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      GateCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Jumlah orang',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: neutral90),
                              ),
                            ),
                            IconButton(
                              onPressed: _guests > 1
                                  ? () => setState(() => _guests--)
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text(
                              '$_guests',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: neutral90,
                              ),
                            ),
                            IconButton(
                              onPressed: _guests < 20
                                  ? () => setState(() => _guests++)
                                  : null,
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _plate,
                        textCapitalization: TextCapitalization.characters,
                        decoration: _decoration(
                          'Plat kendaraan',
                          hint: 'Opsional',
                          icon: Icons.directions_car_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _purpose,
                        maxLines: 2,
                        decoration: _decoration(
                          'Keperluan',
                          hint: 'Opsional',
                          icon: Icons.notes_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _photoField(state),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: GateButton(
                    label: 'Kirim ke penghuni',
                    icon: Icons.send_outlined,
                    loading: state.submitting,
                    onPressed:
                        state.loadingOptions ? null : () => _submit(state),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _unitField(WalkInFormState state, WalkInFormCubit cubit) {
    final unit = state.unit;
    if (unit != null) {
      return GateCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.home_outlined, color: primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unit.label,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: neutral90),
                  ),
                  Text(
                    unit.accountCount > 0
                        ? '${unit.residentName ?? 'Penghuni'} · ${unit.accountCount} akun akan menerima notifikasi'
                        : 'Unit belum memiliki akun penghuni',
                    style: TextStyle(
                      fontSize: 12,
                      color: unit.accountCount > 0 ? neutral50 : errorColor,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => cubit.selectUnit(null),
              child: const Text('Ganti'),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _unitSearch,
          onChanged: cubit.searchUnits,
          decoration: _decoration(
            'Tujuan unit *',
            hint: 'Cari blok atau nomor unit',
            icon: Icons.search,
          ).copyWith(
            errorText: _submitted ? 'Pilih unit tujuan' : null,
            suffixIcon: state.searching
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
        if (state.units.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: neutral20),
            ),
            child: Column(
              children: state.units
                  .map(
                    (item) => ListTile(
                      dense: true,
                      leading: Icon(Icons.home_outlined, color: primaryColor),
                      title: Text(item.label),
                      subtitle: Text(
                        '${item.residentName ?? 'Belum ada penghuni'} · ${item.accountCount} akun',
                      ),
                      onTap: () {
                        _unitSearch.clear();
                        FocusScope.of(context).unfocus();
                        cubit.selectUnit(item);
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _photoField(WalkInFormState state) {
    final required = state.options.photoRequired;
    final missing = _submitted && required && _photo == null;
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
                  ? Icon(Icons.photo_camera_outlined, color: neutral50)
                  : Image.memory(photo, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  required ? 'Foto tamu *' : 'Foto tamu',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, color: neutral90),
                ),
                Text(
                  missing
                      ? 'Foto wajib diambil'
                      : 'Dikirim ke penghuni untuk verifikasi',
                  style: TextStyle(
                      fontSize: 12, color: missing ? errorColor : neutral50),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _takePhoto,
            child: Text(photo == null ? 'Ambil' : 'Ulangi'),
          ),
        ],
      ),
    );
  }
}
