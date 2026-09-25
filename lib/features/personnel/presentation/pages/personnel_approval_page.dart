import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/design/colors.dart';
import '../bloc/personnel_bloc.dart';
import '../bloc/personnel_event.dart';
import '../bloc/personnel_state.dart';
import '../../domain/entities/personnel.dart';

class PersonnelApprovalPage extends StatefulWidget {
  final Personnel personnel;

  const PersonnelApprovalPage({super.key, required this.personnel});

  @override
  State<PersonnelApprovalPage> createState() => _PersonnelApprovalPageState();
}

class _PersonnelApprovalPageState extends State<PersonnelApprovalPage> {
  final TextEditingController _feedbackController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

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
          'Profil Saya',
          style: TextStyle(
            color: neutral90,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: BlocConsumer<PersonnelBloc, PersonnelState>(
        listener: (context, state) {
          if (state is PersonnelActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            // Return true to indicate success
            Navigator.pop(context, true);
          } else if (state is PersonnelError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is PersonnelLoading;

          return Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    // Documents Section
                    Container(
                      width: double.infinity,
                      color: Colors.white,
                      padding: EdgeInsets.all(24.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.personnel.ktpUrl != null)
                            _buildDocumentRow('KTP', widget.personnel.ktpUrl!),
                          if (widget.personnel.ktaUrl != null)
                            _buildDocumentRow('KTA', widget.personnel.ktaUrl!),
                          if (widget.personnel.fotoUrl != null)
                            _buildDocumentRow('Foto', widget.personnel.fotoUrl!),
                          if (widget.personnel.p3tdK3lhUrl != null)
                            _buildDocumentRow(
                              'P3TD K3LH',
                              widget.personnel.p3tdK3lhUrl!,
                            ),
                          if (widget.personnel.p3tdSecurityUrl != null)
                            _buildDocumentRow(
                              'P3TD Security',
                              widget.personnel.p3tdSecurityUrl!,
                            ),
                          if (widget.personnel.pernyataanTidakMerokokUrl != null)
                            _buildDocumentRow(
                              'Pernyataan Tidak Merokok',
                              widget.personnel.pernyataanTidakMerokokUrl!,
                            ),
                        ],
                      ),
                    ),

                    24.verticalSpace,

                    // Feedback Form
                    Container(
                      width: double.infinity,
                      color: Colors.white,
                      padding: EdgeInsets.all(24.w),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Umpan Balik',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: neutral90,
                              ),
                            ),
                            16.verticalSpace,
                            Container(
                              decoration: BoxDecoration(
                                color: neutral10,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(color: neutral30),
                              ),
                              child: TextFormField(
                                controller: _feedbackController,
                                maxLines: 6,
                                enabled: !isLoading,
                                decoration: InputDecoration(
                                  hintText: 'xxx',
                                  hintStyle: TextStyle(
                                    color: neutral50,
                                    fontSize: 14.sp,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(16.w),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Umpan balik tidak boleh kosong';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    24.verticalSpace,

                    // Action Buttons
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Row(
                        children: [
                          // Revisi Button
                          Expanded(
                            child: SizedBox(
                              height: 52.h,
                              child: ElevatedButton(
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        if (_formKey.currentState!.validate()) {
                                          _showConfirmationDialog(
                                            context,
                                            'Revisi',
                                            'Apakah Anda yakin ingin meminta revisi?',
                                            () {
                                              context.read<PersonnelBloc>().add(
                                                    RevisePersonnelEvent(
                                                      widget.personnel.id,
                                                      _feedbackController.text.trim(),
                                                    ),
                                                  );
                                            },
                                          );
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: neutral30,
                                  foregroundColor: neutral90,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                ),
                                child: Text(
                                  'Revisi',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          16.horizontalSpace,
                          // Setujui Button
                          Expanded(
                            child: SizedBox(
                              height: 52.h,
                              child: ElevatedButton(
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        if (_formKey.currentState!.validate()) {
                                          _showConfirmationDialog(
                                            context,
                                            'Setujui',
                                            'Apakah Anda yakin ingin menyetujui personil ini?',
                                            () {
                                              context.read<PersonnelBloc>().add(
                                                    ApprovePersonnelEvent(
                                                      widget.personnel.id,
                                                      _feedbackController.text.trim(),
                                                    ),
                                                  );
                                            },
                                          );
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                ),
                                child: Text(
                                  'Setujui',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    40.verticalSpace,
                  ],
                ),
              ),

              // Loading Overlay
              if (isLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDocumentRow(String label, String documentName) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: neutral70,
            ),
          ),
          SizedBox(height: 4.h),
          // URL - Full width with wrap support
          Tooltip(
            message: documentName,
            child: InkWell(
              onTap: () {
                // TODO: Open/download document
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Membuka dokumen: $documentName'),
                    backgroundColor: primaryColor,
                  ),
                );
              },
              child: Text(
                documentName,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: primaryColor,
                  decoration: TextDecoration.underline,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmationDialog(
    BuildContext context,
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: neutral90,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 14.sp,
            color: neutral70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Batal',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: neutral70,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Ya',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
