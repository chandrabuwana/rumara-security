import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/design/colors.dart';
import '../bloc/personnel_bloc.dart';
import '../bloc/personnel_event.dart';
import '../bloc/personnel_state.dart';
import '../../domain/entities/personnel.dart';
import 'personnel_document_page.dart';

class PersonnelDetailPage extends StatefulWidget {
  final String personnelId;

  const PersonnelDetailPage({super.key, required this.personnelId});

  @override
  State<PersonnelDetailPage> createState() => _PersonnelDetailPageState();
}

class _PersonnelDetailPageState extends State<PersonnelDetailPage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: neutral10,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: neutral90),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profil Detail',
          style: TextStyle(
            color: neutral90,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: BlocConsumer<PersonnelBloc, PersonnelState>(
        listener: (context, state) {
          if (state is PersonnelError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }

          // Listen for action success
          if (state is PersonnelActionSuccess) {
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );

            // Navigate back and refresh list
            Navigator.pop(context, true);
          }
        },
        builder: (context, state) {
          if (state is PersonnelLoading) {
            return Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          if (state is PersonnelDetailLoaded) {
            return _buildDetailContent(context, state.personnel);
          }

          if (state is PersonnelError) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64.sp,
                      color: neutral50,
                    ),
                    16.verticalSpace,
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: neutral70,
                      ),
                    ),
                    24.verticalSpace,
                    ElevatedButton(
                      onPressed: () {
                        context.read<PersonnelBloc>().add(
                              LoadPersonnelDetailEvent(widget.personnelId),
                            );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildDetailContent(BuildContext context, Personnel personnel) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Status Badge
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status :',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: neutral70,
                  ),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: _getStatusColor(personnel.status),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Text(
                    personnel.status,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          16.verticalSpace,

          // Personal Information
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: EdgeInsets.all(24.w),
            child: Column(
              children: [
                _buildInfoRow('Nama', personnel.name),
                _buildInfoRow('NRP', personnel.nrp),
                if (personnel.noKtp != null)
                  _buildInfoRow('No KTP', personnel.noKtp!),
                if (personnel.tempatLahir != null)
                  _buildInfoRow('Tempat Lahir', personnel.tempatLahir!),
                if (personnel.tanggalLahir != null)
                  _buildInfoRow(
                    'Tanggal Lahir',
                    DateFormat('dd MMMM yyyy', 'id_ID')
                        .format(personnel.tanggalLahir!),
                  ),
                if (personnel.jenisKelamin != null)
                  _buildInfoRow('Jenis Kelamin', personnel.jenisKelamin!),
                if (personnel.pendidikan != null)
                  _buildInfoRow('Pendidikan', personnel.pendidikan!),
                if (personnel.teleponPribadi != null)
                  _buildInfoRow('Telepon Pribadi', personnel.teleponPribadi!),
                if (personnel.teleponDarurat != null)
                  _buildInfoRow('Telepon Darurat', personnel.teleponDarurat!),
                if (personnel.site != null)
                  _buildInfoRow('Site', personnel.site!),
                if (personnel.jabatan != null)
                  _buildInfoRow('Jabatan', personnel.jabatan!),
                _buildInfoRow('Atasan', personnel.namaAtasan ?? '-'),
                if (personnel.tanggalPenerimaanKaryawan != null)
                  _buildInfoRow(
                    'Tgl Penerimaan Karyawan',
                    DateFormat('dd MMMM yyyy', 'id_ID')
                        .format(personnel.tanggalPenerimaanKaryawan!),
                  ),
                if (personnel.masaBerlakuPermit != null)
                  _buildInfoRow(
                    'Masa Berlaku Permit',
                    DateFormat('dd MMMM yyyy', 'id_ID')
                        .format(personnel.masaBerlakuPermit!),
                  ),
                if (personnel.kompetensiPekerjaan != null)
                  _buildInfoRow(
                      'Kompetensi Pekerjaan', personnel.kompetensiPekerjaan!),
                if (personnel.wargaNegara != null)
                  _buildInfoRow('Warga Negara', personnel.wargaNegara!),
                if (personnel.provinsi != null)
                  _buildInfoRow('Provinsi', personnel.provinsi!),
                if (personnel.kotaKabupaten != null)
                  _buildInfoRow('Kota / Kabupaten', personnel.kotaKabupaten!),
                if (personnel.kecamatan != null)
                  _buildInfoRow('Kecamatan', personnel.kecamatan!),
                if (personnel.kelurahan != null)
                  _buildInfoRow('Kelurahan', personnel.kelurahan!),
                if (personnel.alamatDomisili != null)
                  _buildInfoRow('Alamat Domisili', personnel.alamatDomisili!),
                if (personnel.status == 'Pending') ...[
                  _buildInfoRow('Diverifikasi Oleh', '-'),
                  _buildInfoRow('Tanggal Verifikasi', '-'),
                ] else ...[
                  if (personnel.updateBy != null)
                    _buildInfoRow('Diverifikasi Oleh', personnel.updateBy!),
                  if (personnel.updateDate != null)
                    _buildInfoRow(
                      'Tanggal Verifikasi',
                      DateFormat('dd MMMM yyyy - HH.mm', 'id_ID')
                          .format(personnel.updateDate!),
                    ),
                ],
              ],
            ),
          ),

          16.verticalSpace,

          // Button to navigate to document page
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                onPressed: () {
                  final personnelBloc = context.read<PersonnelBloc>();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: personnelBloc,
                        child: PersonnelDocumentPage(
                          personnel: personnel,
                        ),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon(Icons.folder_open, size: 20.w),
                    // SizedBox(width: 8.w),
                    Text(
                      'Selanjutnya',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          24.verticalSpace,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140.w,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: neutral70,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: neutral90,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Aktif':
        return Colors.green;
      case 'Pending':
        return neutral50;
      case 'Non Aktif':
        return Colors.red;
      default:
        return neutral50;
    }
  }
}
//3desember 