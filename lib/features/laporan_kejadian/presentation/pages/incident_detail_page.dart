import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import '../../../../core/utils/image_compress_util.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../core/utils/user_role_helper.dart';
import '../../../../core/constants/enums.dart';
import '../../../../shared/widgets/Buttons/ui_button.dart';
import '../../../../shared/widgets/custom_dropdown.dart';
import '../../../../shared/widgets/searchable_dropdown.dart';
import '../../../../shared/widgets/TextInput/input_primary.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/security/security_manager.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/incident_entity.dart';
import '../../data/datasources/incident_remote_datasource.dart';
import '../bloc/incident_bloc.dart';
import '../bloc/incident_event.dart';
import '../bloc/incident_state.dart';
import '../utils/incident_permission_helper.dart';
import '../../../chat/presentation/bloc/chat_bloc.dart';
import '../../../chat/presentation/bloc/chat_event.dart';
import '../../../chat/presentation/pages/chat_conversation_page.dart';
import '../../../chat/domain/entities/chat.dart';

class IncidentDetailPage extends StatefulWidget {
  final IncidentEntity incident;
  final bool isFromMyTasks; // true jika dari tab "Tugas Saya", false jika dari "Daftar Insiden"

  const IncidentDetailPage({
    super.key,
    required this.incident,
    required this.isFromMyTasks,
  });

  @override
  State<IncidentDetailPage> createState() => _IncidentDetailPageState();
}

class _IncidentDetailPageState extends State<IncidentDetailPage> {
  bool _hasLoadedDetail = false;
  bool _statusUpdated = false;
  UserRole? _userRole;
  bool _isPJOOrDeputy = false;
  bool _isDanton = false;
  bool _isPengawas = false;
  bool _isAdmin = false;
  String? _evidenceFromApi; // Store Evidence from API Data level (Bukti Penyelesaian)
  String? _incidentImageFromApi; // Store IncidentImage from API Data level (Foto Insiden)
  bool _wasPreviouslyEscalated = false; // Track if incident was previously escalated
  dynamic _originalIncidentDetail; // Store original IncidentDetail from API for detail data
  dynamic _apiModel; // Store API model untuk akses field Pic (Penanggung Jawab), Pj (Pembuat Keputusan)

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await UserRoleHelper.getUserRole();
    setState(() {
      _userRole = role;
      _isPJOOrDeputy = role == UserRole.pjo || role == UserRole.deputy;
      _isDanton = role == UserRole.danton;
      _isPengawas = role == UserRole.pengawas;
      _isAdmin = role == UserRole.admin;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load detail from API when dependencies are available
    if (!_hasLoadedDetail) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          try {
            // Single API call: GET /Incident/getAll/{id}
            final bloc = context.read<IncidentBloc>();
            final datasource = getIt<IncidentRemoteDataSource>();
            final apiModel = await datasource.getIncidentDetailApiModel(widget.incident.id);
            if (!mounted) return;
            bloc.add(SetIncidentDetailEvent(apiModel.toIncidentModel()));
            String? evidenceValue = apiModel.evidence;
            if (evidenceValue != null) {
              evidenceValue = evidenceValue.trim();
              if (evidenceValue.isEmpty ||
                  evidenceValue == '-' ||
                  evidenceValue.toLowerCase() == 'null') {
                evidenceValue = null;
              }
            }
            setState(() {
              _incidentImageFromApi = apiModel.incidentImage;
              _evidenceFromApi = evidenceValue;
              _originalIncidentDetail = apiModel.incidentDetail;
              _apiModel = apiModel;
            });
            IncidentPermissionHelper.wasPreviouslyEscalated(
              incident: widget.incident,
              apiModel: apiModel,
            ).then((wasEscalated) {
              if (mounted) {
                setState(() => _wasPreviouslyEscalated = wasEscalated);
              }
            });
            _hasLoadedDetail = true;
          } catch (e, stackTrace) {
            debugPrint('❌ Failed to load incident detail: $e');
            debugPrint('❌ Stack trace: $stackTrace');
            if (mounted) {
              context.read<IncidentBloc>().add(const ClearIncidentErrorEvent());
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Gagal memuat detail insiden: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            _hasLoadedDetail = true;
          }
        }
      });
    }
  }

  /// Convert IncidentStatus to API status string
  String _getApiStatus(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.menunggu:
        return 'OPEN';
      case IncidentStatus.revisi:
        return 'REVISED';
      case IncidentStatus.tidakValid:
        return 'INVALID';
      case IncidentStatus.diterima:
        return 'ACKNOWLEDGE';
      case IncidentStatus.eskalasi:
        return 'ESCALATED';
      case IncidentStatus.ditugaskan:
        return 'ASSIGNED';
      case IncidentStatus.proses:
        return 'PROGRESS';
      case IncidentStatus.selesai:
        return 'COMPLETED';
      case IncidentStatus.terverifikasi:
        return 'VERIFIED';
    }
  }

  @override
  Widget build(BuildContext context) {

    return BlocListener<IncidentBloc, IncidentState>(
      listener: (context, state) {
        if (state.errorMessage != null && !_statusUpdated) {
          // Only show error if not in the middle of an update operation
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
        // Only show success message when status is updated (not loading and no error after update)
        if (_statusUpdated && !state.isLoading && state.errorMessage == null) {
          _statusUpdated = false; // Reset flag
          // Use post frame callback to ensure context is still valid
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Check if widget is still mounted before using context
            if (!mounted) return;
            
            try {
              // Check if context is still valid
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Status berhasil diperbarui'),
                    backgroundColor: Colors.green,
                  ),
                );
                // Use Navigator.of(context).pop to ensure proper context
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop(true); // Return true to indicate update
                }
              }
            } catch (e) {
              // Context is no longer valid, ignore
              debugPrint('Error navigating after status update: $e');
            }
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Lapor Insiden Kejadian',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: BlocBuilder<IncidentBloc, IncidentState>(
          builder: (context, state) {
            // Use detail from API if available, otherwise use widget.incident
            final incident = state.incidentDetail ?? widget.incident;
            
            // Show loading indicator when loading detail for the first time
            if (_hasLoadedDetail && state.isLoading && state.incidentDetail == null) {
              return Center(
                child: CircularProgressIndicator(color: primaryColor),
              );
            }

            return SingleChildScrollView(
              padding: REdgeInsets.all(16),
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

                  // Status
                  _buildReadOnlyField(
                    label: 'Status',
                    value: incident.statusDisplayName,
                  ),
                  20.verticalSpace,

                  // ID Insiden
                  _buildReadOnlyField(
                    label: 'ID Insiden',
                    value: incident.formattedId,
                  ),
                  20.verticalSpace,

                  // Pelapor (dengan timestamp CreateDate)
                  _buildReadOnlyField(
                    label: 'Pelapor',
                    value: _getPelaporWithTimestamp(incident),
                  ),
                  20.verticalSpace,

                  // Tanggal Insiden
                  _buildReadOnlyField(
                    label: 'Tanggal Insiden*',
                    value: incident.tanggalInsiden != null
                        ? DateFormat('dd/MM/yyyy', 'id_ID').format(incident.tanggalInsiden!)
                        : '-',
                  ),
                  20.verticalSpace,

                  // Jam Insiden
                  _buildReadOnlyField(
                    label: 'Jam Insiden*',
                    value: incident.jamInsiden != null
                        ? DateFormat('HH:mm', 'id_ID').format(incident.jamInsiden!)
                        : '-',
                  ),
                  20.verticalSpace,

                  // Lokasi Insiden
                  _buildReadOnlyField(
                    label: 'Lokasi Insiden*',
                    value: incident.lokasiInsiden ?? '-',
                  ),
                  20.verticalSpace,

                  // Detail Lokasi Insiden (unlimited lines - bisa panjang)
                  _buildReadOnlyField(
                    label: 'Detail Lokasi Insiden*',
                    value: incident.detailLokasiInsiden ?? '-',
                    maxLines: null,
                  ),
                  20.verticalSpace,

                  // Tipe Insiden
                  _buildReadOnlyField(
                    label: 'Tipe Insiden*',
                    value: incident.tipeInsidenDisplayName,
                  ),
                  20.verticalSpace,

                  // Deskripsi Insiden (unlimited lines - bisa panjang)
                  _buildReadOnlyField(
                    label: 'Deskripsi Insiden*',
                    value: incident.deskripsiInsiden ?? '-',
                    maxLines: null,
                  ),
                  20.verticalSpace,

                  // Foto Insiden (dari IncidentImage di API)
                  if (_incidentImageFromApi != null && _incidentImageFromApi!.isNotEmpty)
                    _buildPhotoField(_incidentImageFromApi!),
                  20.verticalSpace,

                  // Aksi Section
                  _buildAksiSection(incident),
                  20.verticalSpace,

                  // Tim Petugas (horizontal scrollable cards)
                  _buildTeamSection(incident),
                  20.verticalSpace,

                  // Tugas Penanganan (dari NotesAction atau HandlingTask di IncidentDetail) - unlimited lines
                  _buildReadOnlyField(
                    label: 'Tugas Penanganan',
                    value: _getHandlingTask(incident),
                    maxLines: null,
                  ),
                  20.verticalSpace,

                  // Note Penyelesaian (diambil dari ActionTakenNote di IncidentDetail)
                  // ActionTakenNote diisi saat PIC/Anggota menyelesaikan insiden di TUGAS SAYA
                  _buildReadOnlyField(
                    label: 'Note Penyelesaian',
                    value: _getActionTakenNote(incident) ?? '-',
                    maxLines: null,
                  ),
                  20.verticalSpace,

                  // Tanggal Penyelesaian
                  _buildReadOnlyField(
                    label: 'Tanggal Penyelesaian',
                    value: _getCompletionDate(incident),
                  ),
                  20.verticalSpace,

                  // Bukti Penyelesaian
                  _buildEvidenceField(incident),
                  20.verticalSpace,

                  // Diselesaikan Oleh
                  _buildReadOnlyField(
                    label: 'Diselesaikan Oleh',
                    value: _getCompletedBy(incident),
                  ),
                  20.verticalSpace,

                  // Diverifikasi Oleh (VerifiedName - VerifiedDate)
                  _buildReadOnlyField(
                    label: 'Diverifikasi Oleh',
                    value: _getVerifiedBy(incident),
                  ),
                  20.verticalSpace,

                  // Completion Feedback
                  _buildReadOnlyField(
                    label: 'Completion Feedback',
                    value: _getSupervisorFeedback(incident),
                    maxLines: 3,
                  ),
                  20.verticalSpace,
                  32.verticalSpace,

                  // Action Buttons
                  // Untuk PJO/Deputy di tab "Daftar Insiden": Tugaskan, Eskalasi, Verifikasi, Revisi
                  // Untuk danton di tab "Daftar Insiden": Konfirmasi dan Tandai Tidak Valid
                  // Untuk pengawas di tab "Daftar Insiden": Tugaskan, Verifikasi, Revisi
                  // Untuk admin di tab "Daftar Insiden": Verifikasi, Revisi (jika status COMPLETED)
                  // Untuk tab "Tugas Saya" (anggota): Proses dan Tandai Sebagai Selesai
                  if (!widget.isFromMyTasks) 
                    _isPengawas
                      ? _buildPengawasActionButtons(incident)
                      : _isPJOOrDeputy 
                        ? _buildPJOOrDeputyActionButtons(incident)
                        : _isDanton
                          ? _buildDantonActionButtons(incident)
                          : _isAdmin
                            ? _buildAdminActionButtons(incident)
                            : const SizedBox.shrink()
                  else 
                    _buildActionButton(incident),
                  16.verticalSpace,
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Helper methods to extract data from IncidentDetail
  // Use original IncidentDetail from API for detail data (HandlingTask, ActionTakenNote, etc.)
  String? _getFirstIncidentDetailValue(IncidentEntity incident, String key) {
    // Try to get from original IncidentDetail first (for detail data)
    if (_originalIncidentDetail != null) {
      if (_originalIncidentDetail is Map<String, dynamic>) {
        final value = _originalIncidentDetail[key];
        if (value != null && value.toString().isNotEmpty && value.toString() != '-') {
          return value.toString();
        }
      } else if (_originalIncidentDetail is List && (_originalIncidentDetail as List).isNotEmpty) {
        final firstDetail = (_originalIncidentDetail as List).first;
        if (firstDetail is Map<String, dynamic>) {
          final value = firstDetail[key];
          if (value != null && value.toString().isNotEmpty && value.toString() != '-') {
            return value.toString();
          }
        }
      }
    }
    
    // Fallback to incident.incidentDetail if original not available
    if (incident.incidentDetail != null && incident.incidentDetail!.isNotEmpty) {
      final firstDetail = incident.incidentDetail!.first;
      final value = firstDetail[key];
      if (value != null && value.toString().isNotEmpty && value.toString() != '-') {
        return value.toString();
      }
    }
    return null;
  }

  String _getReviewedBy(IncidentEntity incident) {
    // Dikonfirmasi Oleh = ReviewedName - ReviewedDate dari API
    // Sumber: _apiModel (level Data) atau IncidentDetail
    String? reviewerName;
    DateTime? reviewedDate;
    String? reviewedDateStr;
    
    // 1. Dari API model (level Data)
    if (_apiModel != null) {
      reviewerName = _apiModel.reviewedName;
      reviewedDate = _apiModel.reviewedDate;
    }
    
    // 2. Fallback: dari IncidentDetail (ReviewedName, ReviewedDate)
    if ((reviewerName == null || reviewerName.isEmpty) && _originalIncidentDetail != null) {
      if (_originalIncidentDetail is Map<String, dynamic>) {
        reviewerName = _originalIncidentDetail['ReviewedName']?.toString() ?? _originalIncidentDetail['reviewedName']?.toString();
        reviewedDateStr = _originalIncidentDetail['ReviewedDate']?.toString() ?? _originalIncidentDetail['reviewedDate']?.toString();
      } else if (_originalIncidentDetail is List && (_originalIncidentDetail as List).isNotEmpty) {
        final first = (_originalIncidentDetail as List).first;
        if (first is Map<String, dynamic>) {
          reviewerName = first['ReviewedName']?.toString() ?? first['reviewedName']?.toString();
          reviewedDateStr = first['ReviewedDate']?.toString() ?? first['reviewedDate']?.toString();
        }
      }
      if (reviewedDate == null && reviewedDateStr != null && reviewedDateStr.isNotEmpty) {
        reviewedDate = DateTime.tryParse(reviewedDateStr);
      }
    }
    
    // 3. Fallback: dari _getFirstIncidentDetailValue (ReviewedName/ReviewedDate di IncidentDetail)
    if (reviewerName == null || reviewerName.isEmpty) {
      reviewerName = _getFirstIncidentDetailValue(incident, 'ReviewedName') ?? _getFirstIncidentDetailValue(incident, 'reviewedName');
      reviewedDateStr = _getFirstIncidentDetailValue(incident, 'ReviewedDate') ?? _getFirstIncidentDetailValue(incident, 'reviewedDate');
      if (reviewedDate == null && reviewedDateStr != null && reviewedDateStr.isNotEmpty) {
        reviewedDate = DateTime.tryParse(reviewedDateStr);
      }
    }
    
    if (reviewerName == null || reviewerName.isEmpty || reviewerName.trim() == '-' || reviewerName.trim() == '') {
      return '-';
    }
    
    // Format: Nama - Timestamp
    if (reviewedDate != null) {
      try {
        final formattedDate = DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(reviewedDate);
        return '$reviewerName - $formattedDate';
      } catch (e) {
        return reviewerName;
      }
    }
    if (reviewedDateStr != null && reviewedDateStr.isNotEmpty && reviewedDateStr != '-') {
      try {
        final dt = DateTime.tryParse(reviewedDateStr);
        if (dt != null) {
          return '$reviewerName - ${DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(dt)}';
        }
      } catch (_) {}
    }
    
    return reviewerName;
  }

  String? _getActionTakenNote(IncidentEntity incident) {
    return _getFirstIncidentDetailValue(incident, 'ActionTakenNote');
  }

  String _getPelaporWithTimestamp(IncidentEntity incident) {
    // Pelapor = Nama Pelapor - CreateDate (timestamp)
    final pelaporName = incident.pelapor ?? '-';
    
    // Get CreateDate from API model or incident entity
    DateTime? createDate;
    
    // Try to get from stored API model first
    if (_apiModel != null) {
      try {
        createDate = _apiModel.createDate;
      } catch (e) {
        debugPrint('Error accessing createDate from stored API model: $e');
      }
    }
    
    // Fallback to incident.createDate
    if (createDate == null) {
      createDate = incident.createDate;
    }
    
    // Format: Pelapor - CreateDate
    if (pelaporName.isNotEmpty && pelaporName != '-') {
      String formattedDate = '-';
      if (createDate != null) {
        try {
          formattedDate = DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(createDate);
        } catch (e) {
          formattedDate = createDate.toString();
        }
      }
      return '$pelaporName - $formattedDate';
    }
    
    return pelaporName;
  }

  String _getPenanggungJawab(IncidentEntity incident) {
    // Penanggung Jawab = string picName dari response incident/getAll
    if (_apiModel != null) {
      try {
        final picName = _apiModel.picName;
        if (picName != null && picName.isNotEmpty && picName != '-') {
          return picName;
        }
      } catch (e) {
        debugPrint('Error accessing picName from API model: $e');
      }
    }
    return incident.pic ?? '-';
  }

  String _getPembuatKeputusan(IncidentEntity incident) {
    // Pembuat Keputusan = Pj - PjDate dari API model
    String? pjName;
    DateTime? pjDate;
    
    if (_apiModel != null) {
      try {
        final pj = _apiModel.pj;
        pjDate = _apiModel.pjDate;
        
        if (pj != null) {
          if (pj is Map<String, dynamic>) {
            pjName = pj['FullName']?.toString() ?? pj['Fullname']?.toString() ?? pj['fullname']?.toString();
          } else if (pj is String) {
            pjName = pj;
          } else {
            try {
              pjName = pj.fullname?.toString() ?? pj.toString();
            } catch (e) {
              pjName = pj.toString();
            }
          }
        }
      } catch (e) {
        debugPrint('Error accessing Pj from API model: $e');
      }
    }
    
    if (pjName == null || pjName.isEmpty || pjName.trim() == '-' || pjName.trim() == '') {
      return '-';
    }
    
    // Format: Pj - PjDate
    if (pjDate != null) {
      try {
        final formattedDate = DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(pjDate);
        return '$pjName - $formattedDate';
      } catch (e) {
        return pjName;
      }
    }
    
    return pjName;
  }

  String _getHandlingTask(IncidentEntity incident) {
    final handlingTask = _getFirstIncidentDetailValue(incident, 'HandlingTask');
    if (handlingTask != null && handlingTask.isNotEmpty) {
      return handlingTask;
    }
    return incident.notesAction ?? '-';
  }

  String _getCompletionDate(IncidentEntity incident) {
    // Tanggal Penyelesaian = SolvedDate dari API model atau IncidentDetail
    if (_apiModel != null) {
      try {
        final solvedDate = _apiModel.solvedDate;
        if (solvedDate != null) {
          return DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(solvedDate);
        }
      } catch (e) {
        debugPrint('Error accessing solvedDate from API model: $e');
      }
    }
    final solvedDateStr = _getFirstIncidentDetailValue(incident, 'SolvedDate') ??
        _getFirstIncidentDetailValue(incident, 'solvedDate');
    if (solvedDateStr != null && solvedDateStr.isNotEmpty) {
      try {
        final dateTime = DateTime.parse(solvedDateStr);
        return DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(dateTime);
      } catch (e) {
        return solvedDateStr;
      }
    }
    if (incident.solvedDate != null) {
      return DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(incident.solvedDate!);
    }
    return '-';
  }

  String _getCompletedBy(IncidentEntity incident) {
    // Diselesaikan Oleh = CompletedName - IncidentCompletionDate dari IncidentDetail
    // CompletedName dan IncidentCompletionDate diisi saat user klik "Tandai Sebagai Selesai"
    String? completedName;
    String? completionDateStr;
    
    // Try to get from original IncidentDetail first
    if (_originalIncidentDetail != null) {
      if (_originalIncidentDetail is Map<String, dynamic>) {
        final detailMap = _originalIncidentDetail as Map<String, dynamic>;
        completedName = detailMap['CompletedName']?.toString();
        completionDateStr = detailMap['IncidentCompletionDate']?.toString();
      } else if (_originalIncidentDetail is List && (_originalIncidentDetail as List).isNotEmpty) {
        final firstDetail = (_originalIncidentDetail as List).first;
        if (firstDetail is Map<String, dynamic>) {
          completedName = firstDetail['CompletedName']?.toString();
          completionDateStr = firstDetail['IncidentCompletionDate']?.toString();
        }
      }
    }
    
    // Fallback to incident.incidentDetail if original not available
    if ((completedName == null || completedName.isEmpty) && incident.incidentDetail != null && incident.incidentDetail!.isNotEmpty) {
      final firstDetail = incident.incidentDetail!.first;
      completedName = firstDetail['CompletedName']?.toString();
      completionDateStr = firstDetail['IncidentCompletionDate']?.toString();
    }
    
    // Format: CompletedName - IncidentCompletionDate
    if (completedName != null && completedName.isNotEmpty && completedName != '-') {
      String formattedDate = '-';
      if (completionDateStr != null && completionDateStr.isNotEmpty && completionDateStr != '-') {
        try {
          final dateTime = DateTime.parse(completionDateStr);
          formattedDate = DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(dateTime);
        } catch (e) {
          formattedDate = completionDateStr;
        }
      }
      return '$completedName - $formattedDate';
    }
    
    return '-';
  }

  String _getVerifiedBy(IncidentEntity incident) {
    // Diverifikasi Oleh = VerifiedName - VerifiedDate (format sama seperti Diselesaikan Oleh)
    String? verifiedName;
    String? verifiedDateStr;
    if (_originalIncidentDetail != null) {
      if (_originalIncidentDetail is Map<String, dynamic>) {
        final m = _originalIncidentDetail as Map<String, dynamic>;
        verifiedName = m['VerifiedName']?.toString();
        verifiedDateStr = m['VerifiedDate']?.toString();
      } else if (_originalIncidentDetail is List && (_originalIncidentDetail as List).isNotEmpty) {
        final first = (_originalIncidentDetail as List).first;
        if (first is Map<String, dynamic>) {
          verifiedName = first['VerifiedName']?.toString();
          verifiedDateStr = first['VerifiedDate']?.toString();
        }
      }
    }
    if ((verifiedName == null || verifiedName.isEmpty) && incident.incidentDetail != null && incident.incidentDetail!.isNotEmpty) {
      final first = incident.incidentDetail!.first;
      verifiedName = first['VerifiedName']?.toString();
      verifiedDateStr = first['VerifiedDate']?.toString();
    }
    if ((verifiedName == null || verifiedName.isEmpty) && _apiModel != null) {
      verifiedName = _apiModel!.verifiedBy;
      if (_apiModel!.verifiedDate != null) verifiedDateStr = _apiModel!.verifiedDate!.toIso8601String();
    }
    if (verifiedName != null && verifiedName.isNotEmpty && verifiedName != '-') {
      String formattedDate = '-';
      if (verifiedDateStr != null && verifiedDateStr.isNotEmpty && verifiedDateStr != '-') {
        try {
          final dt = DateTime.parse(verifiedDateStr);
          formattedDate = DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(dt);
        } catch (e) {
          formattedDate = verifiedDateStr;
        }
      }
      return '$verifiedName - $formattedDate';
    }
    return '-';
  }

  String _getSupervisorFeedback(IncidentEntity incident) {
    final feedback = _getFirstIncidentDetailValue(incident, 'SupervisorFeedback');
    if (feedback != null && feedback.isNotEmpty && feedback != '-') {
      return feedback;
    }
    return '-';
  }

  Widget _buildEvidenceField(IncidentEntity incident) {
    // Bukti Penyelesaian diambil dari Evidence di Data level API
    // Menggunakan field Evidence dari level Data (bukan dari IncidentDetail)
    String? evidence = _evidenceFromApi;
    
    // Debug: Print current evidence value
    debugPrint('🔍 _buildEvidenceField - _evidenceFromApi: $evidence');
    
    // Clean up evidence value - remove "null" string or empty values
    if (evidence != null) {
      evidence = evidence.trim();
      if (evidence.isEmpty || 
          evidence == '-' || 
          evidence.toLowerCase() == 'null') {
        evidence = null;
      }
    }
    
    // Final check - also check if it's a valid URL
    if (evidence == null || evidence.isEmpty || evidence == '-') {
      debugPrint('⚠️ _buildEvidenceField - No Evidence found from Data level, showing "-"');
      return _buildReadOnlyField(
        label: 'Bukti Penyelesaian',
        value: '-',
      );
    }
    
    // Ensure evidence is a valid URL (starts with http:// or https://)
    final evidenceUrl = evidence;
    if (!evidenceUrl.startsWith('http://') && !evidenceUrl.startsWith('https://')) {
      debugPrint('⚠️ _buildEvidenceField - Evidence is not a valid URL: $evidenceUrl');
      return _buildReadOnlyField(
        label: 'Bukti Penyelesaian',
        value: '-',
      );
    }
    
    debugPrint('✅ _buildEvidenceField - Using Evidence URL from Data level: $evidenceUrl');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bukti Penyelesaian',
          style: TS.labelLarge,
        ),
        8.verticalSpace,
        GestureDetector(
          onTap: () {
            _showImagePreview(evidenceUrl);
          },
          child: Container(
            width: double.infinity,
            height: 200.h,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10.r),
              color: Colors.grey.shade100,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
              child: Image.network(
                evidenceUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: primaryColor,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          size: 48.sp,
                          color: Colors.grey.shade400,
                        ),
                        8.verticalSpace,
                        Text(
                          'Gagal memuat gambar',
                          style: TS.bodySmall.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: REdgeInsets.all(16),
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 64.sp,
                              color: Colors.white,
                            ),
                            16.verticalSpace,
                            Text(
                              'Gagal memuat gambar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _navigateToChat(String userId, String userName) async {
    try {
      // Validate userId
      if (userId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ID pengguna tidak valid'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get or create ChatBloc
      ChatBloc? chatBloc;
      try {
        chatBloc = context.read<ChatBloc>();
      } catch (e) {
        // If ChatBloc is not available in context, create new one
        chatBloc = getIt<ChatBloc>();
      }

      // Get current user ID to verify
      final currentUserId = await SecurityManager.readSecurely(AppConstants.userIdKey);
      if (currentUserId == null || currentUserId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal mendapatkan ID pengguna saat ini'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Don't create conversation if trying to chat with self
      if (userId == currentUserId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak dapat mengirim pesan ke diri sendiri'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Create conversation with the user
      chatBloc.add(ChatCreateConversation(memberUserIds: [userId]));
      
      // Wait for conversation to be created
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Navigate to conversation page
      if (mounted) {
        final currentState = chatBloc.state;
        if (currentState.selectedChatId != null) {
          // Find the chat that was just created
          final newChat = currentState.chats.firstWhere(
            (chat) => chat.id == currentState.selectedChatId,
            orElse: () => Chat(
              id: currentState.selectedChatId!,
              name: userName.isNotEmpty ? userName : 'Anggota Tim',
              type: ChatType.direct,
              participantIds: [userId],
              unreadCount: 0,
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BlocProvider.value(
                value: chatBloc!,
                child: ChatConversationPage(chat: newChat),
              ),
            ),
          );
        } else {
          // If chat creation failed, show error
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gagal membuka chat'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error navigating to chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka chat: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Widget _buildAksiSection(IncidentEntity incident) {
    final reviewedName = _getReviewedBy(incident);
    final pembuatKeputusan = _getPembuatKeputusan(incident);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aksi',
          style: TS.labelLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        8.verticalSpace,
        // Dikonfirmasi Oleh
        _buildReadOnlyField(
          label: 'Dikonfirmasi Oleh',
          value: reviewedName,
        ),
        20.verticalSpace,
        // Pembuat Keputusan (Pj - PjDate dari API)
        _buildReadOnlyField(
          label: 'Pembuat Keputusan',
          value: pembuatKeputusan,
        ),
        20.verticalSpace,
        // Penanggung Jawab (diambil dari field Pic di API)
        _buildReadOnlyField(
          label: 'Penanggung Jawab',
          value: _getPenanggungJawab(incident),
        ),
      ],
    );
  }

  Widget _buildTeamSection(IncidentEntity incident) {
    // Handle IncidentDetail and Teams
    // IncidentDetail contains detailed info (HandlingTask, ActionTakenNote, etc.)
    // Teams contains basic info (UserName, UserPhoto, etc.)
    
    final List<Map<String, dynamic>> teamMembers = [];
    
    if (incident.incidentDetail != null && incident.incidentDetail!.isNotEmpty) {
      for (var detail in incident.incidentDetail!) {
        final detailMap = Map<String, dynamic>.from(detail as Map);
        // Add all team members (from both IncidentDetail and Teams)
        teamMembers.add(detailMap);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tim Petugas',
          style: TS.labelLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        8.verticalSpace,
        // Display team members in horizontal scrollable cards
        if (teamMembers.isNotEmpty)
          SizedBox(
            height: 200.h, // Increased height to prevent overflow
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: teamMembers.length,
              itemBuilder: (context, index) {
                return _buildTeamMemberCardHorizontal(teamMembers[index]);
              },
            ),
          )
        else
          _buildReadOnlyField(
            label: '',
            value: '-',
          ),
      ],
    );
  }

  Widget _buildTeamMemberCardHorizontal(Map<String, dynamic> member) {
    final userName = member['UserName']?.toString() ?? '';
    final userPhoto = member['UserPhoto']?.toString();
    // Try to get userId from multiple possible fields
    final userId = member['UserId']?.toString() ?? 
                   member['userId']?.toString() ?? 
                   member['Id']?.toString() ?? 
                   '';
    
    // Check if userId is valid (not empty and not default UUID)
    final isValidUserId = userId.isNotEmpty && 
                          userId != '00000000-0000-0000-0000-000000000000';
    
    // Role bisa dari status atau field lain, default "Anggota Masuk"
    final role = 'Anggota Masuk';
    
    return Container(
      width: 140.w,
      margin: EdgeInsets.only(right: 12.w),
      padding: REdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Use min to prevent overflow
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Profile Picture
          ClipRRect(
            borderRadius: BorderRadius.circular(40.r),
            child: userPhoto != null && userPhoto.isNotEmpty
                ? Image.network(
                    userPhoto,
                    width: 70.w, // Reduced from 80 to 70
                    height: 70.h, // Reduced from 80 to 70
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 70.w,
                        height: 70.h,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(40.r),
                        ),
                        child: Icon(Icons.person, size: 35.r, color: Colors.grey.shade600),
                      );
                    },
                  )
                : Container(
                    width: 70.w,
                    height: 70.h,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(40.r),
                    ),
                    child: Icon(Icons.person, size: 35.r, color: Colors.grey.shade600),
                  ),
          ),
          6.verticalSpace, // Reduced from 8
          // Name
          Flexible(
            child: Text(
              userName.isNotEmpty ? userName : 'Anggota Tim',
              style: TS.bodySmall.copyWith( // Changed from bodyMedium to bodySmall
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          4.verticalSpace,
          // Role
          Text(
            role,
            style: TS.bodySmall.copyWith(
              color: Colors.red,
              fontSize: 10.sp, // Smaller font
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          6.verticalSpace, // Reduced from 8
          // Kirim Pesan Button
          SizedBox(
            width: double.infinity,
            height: 32.h, // Fixed height
            child: ElevatedButton(
              onPressed: isValidUserId && userName.isNotEmpty ? () async {
                _navigateToChat(userId, userName);
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isValidUserId ? Colors.red : Colors.grey.shade400,
                foregroundColor: Colors.white,
                padding: REdgeInsets.symmetric(vertical: 4), // Reduced padding
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade600,
              ),
              child: Text(
                'Kirim Pesan',
                style: TS.bodySmall.copyWith(
                  color: Colors.white,
                  fontSize: 10.sp, // Smaller font
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    int? maxLines = 1,
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
            maxLines: maxLines,
            overflow: maxLines != null ? TextOverflow.ellipsis : null,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoField(String photoUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Foto Insiden',
          style: TS.labelLarge,
        ),
        8.verticalSpace,
        GestureDetector(
          onTap: () {
            _showImagePreview(photoUrl);
          },
          child: Container(
            width: double.infinity,
            height: 200.h,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10.r),
              color: Colors.grey.shade100,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
              child: Image.network(
                photoUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: primaryColor,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          size: 48.sp,
                          color: Colors.grey.shade400,
                        ),
                        8.verticalSpace,
                        Text(
                          'Gagal memuat gambar',
                          style: TS.bodySmall.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPengawasActionButtons(IncidentEntity incident) {
    // Untuk Pengawas: Tugaskan, Verifikasi, dan Revisi
    if (_userRole == null) {
      return const SizedBox.shrink();
    }
    
    return BlocBuilder<IncidentBloc, IncidentState>(
      builder: (context, state) {
        final buttons = <Widget>[];
        
        // Check permission untuk assign
        final canAssign = IncidentPermissionHelper.canAssignIncident(
          incident: incident,
          currentUserRole: _userRole!,
        );
        
        // Tombol Tugaskan untuk status Diterima atau Escalated
        if (canAssign && 
            (incident.status == IncidentStatus.diterima || 
             incident.status == IncidentStatus.eskalasi)) {
          buttons.add(
            UIButton(
              text: 'Tugaskan',
              fullWidth: true,
              size: UIButtonSize.large,
              isLoading: state.isLoading,
              onPressed: state.isLoading
                  ? null
                  : () {
                      _showAssignDialog(context, incident);
                    },
            ),
          );
        }
        
        // Check permission untuk verify dan revise
        final canVerify = IncidentPermissionHelper.canVerifyIncident(
          incident: incident,
          currentUserRole: _userRole!,
          wasPreviouslyEscalated: _wasPreviouslyEscalated,
        );
        
        final canRevise = IncidentPermissionHelper.canReviseIncident(
          incident: incident,
          currentUserRole: _userRole!,
          wasPreviouslyEscalated: _wasPreviouslyEscalated,
        );
        
        // Tombol Verifikasi dan Revisi untuk status COMPLETED
        if (incident.status == IncidentStatus.selesai) {
          if (canVerify) {
            if (buttons.isNotEmpty) {
              buttons.add(16.verticalSpace);
            }
            buttons.add(
              UIButton(
                text: 'Verifikasi',
                fullWidth: true,
                size: UIButtonSize.large,
                variant: UIButtonVariant.success,
                isLoading: state.isLoading,
                onPressed: state.isLoading
                    ? null
                    : () {
                        _showVerifyDialog(context, incident);
                      },
              ),
            );
            if (canRevise) {
              buttons.add(16.verticalSpace);
            }
          }
          
          if (canRevise) {
            buttons.add(
              UIButton(
                text: 'Revisi',
                fullWidth: true,
                size: UIButtonSize.large,
                buttonType: UIButtonType.outline,
                variant: UIButtonVariant.warning,
                isLoading: state.isLoading,
                onPressed: state.isLoading
                    ? null
                    : () {
                        _showReviseDialog(context, incident);
                      },
              ),
            );
          }
        }
        
        if (buttons.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Column(children: buttons);
      },
    );
  }

  Widget _buildAdminActionButtons(IncidentEntity incident) {
    // Untuk Admin: Verifikasi dan Revisi (hanya untuk status COMPLETED)
    final apiStatus = _getApiStatus(incident.status);
    
    return BlocBuilder<IncidentBloc, IncidentState>(
      builder: (context, state) {
        final buttons = <Widget>[];
        
        // Tombol Verifikasi dan Revisi untuk status COMPLETED
        if (apiStatus == 'COMPLETED') {
          buttons.addAll([
            // Tombol Verifikasi
            UIButton(
              text: 'Verifikasi',
              fullWidth: true,
              size: UIButtonSize.large,
              variant: UIButtonVariant.success,
              isLoading: state.isLoading,
              onPressed: state.isLoading
                  ? null
                  : () {
                      _showVerifyDialog(context, incident);
                    },
            ),
            16.verticalSpace,
            // Tombol Revisi
            UIButton(
              text: 'Revisi',
              fullWidth: true,
              size: UIButtonSize.large,
              buttonType: UIButtonType.outline,
              variant: UIButtonVariant.warning,
              isLoading: state.isLoading,
              onPressed: state.isLoading
                  ? null
                  : () {
                      _showReviseDialog(context, incident);
                    },
            ),
          ]);
        }
        
        if (buttons.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Column(children: buttons);
      },
    );
  }

  Widget _buildPJOOrDeputyActionButtons(IncidentEntity incident) {
    // Untuk PJO/Deputy di tab "Daftar Insiden"
    // Rules:
    // - Jika pelapor adalah Anggota: Hanya Danton yang bisa review, PJO/Deputy TIDAK bisa review
    // - Jika pelapor adalah Danton dan status menunggu: PJO/Deputy dapat review (Diterima/Tidak Valid)
    // - Jika status diterima (setelah danton review): PJO/Deputy dapat Assign PIC dan Tim, serta Eskalasi
    //   * Setelah danton review dan accept, PJO/Deputy akan assign PIC dan tim melalui dialog assign
    if (_userRole == null) {
      return const SizedBox.shrink();
    }
    
    return BlocBuilder<IncidentBloc, IncidentState>(
      builder: (context, state) {
        final buttons = <Widget>[];
        
        // Tombol Review untuk status Menunggu (jika pelapor adalah Danton)
        // Rules: Jika pelapor adalah Anggota, hanya Danton yang bisa review
        //        Jika pelapor adalah Danton, PJO/Deputy bisa review
        //        PJO/Deputy hanya bisa assign setelah danton review (status Diterima)
        if (incident.status == IncidentStatus.menunggu) {
          return FutureBuilder<bool>(
            future: () async {
              // Get current user ID and reporter ID
              final currentUserId = await UserRoleHelper.getUserId();
              final reporterId = incident.pelaporId;
              
              // Get reporter role from incident entity
              // Jika pelapor adalah Anggota, hanya Danton yang bisa review
              // Jika pelapor adalah Danton, PJO/Deputy bisa review
              UserRole? reporterRole;
              if (incident.reporterRole != null && incident.reporterRole!.isNotEmpty) {
                reporterRole = UserRole.fromValue(incident.reporterRole!);
              }
              
              return await IncidentPermissionHelper.canReviewIncident(
                incident: incident,
                currentUserRole: _userRole!,
                reporterRole: reporterRole,
                currentUserId: currentUserId,
                reporterId: reporterId,
              );
            }(),
            builder: (context, reviewSnapshot) {
              if (!reviewSnapshot.hasData || !reviewSnapshot.data!) {
                return const SizedBox.shrink();
              }
              
              return Column(
                children: [
                  // Tombol Diterima (mengubah status ke ACKNOWLEDGE)
                  UIButton(
                    text: 'Diterima',
                    fullWidth: true,
                    size: UIButtonSize.large,
                    variant: UIButtonVariant.success,
                    isLoading: state.isLoading,
                    onPressed: state.isLoading
                        ? null
                        : () async {
                            // Get incident detail untuk mendapatkan semua field yang diperlukan
                            try {
                              final datasource = getIt<IncidentRemoteDataSource>();
                              final apiModel = await datasource.getIncidentDetailApiModel(incident.id);
                              
                              // Get team from existing data
                              List<String> team = [];
                              if (apiModel.teams != null && apiModel.teams!.isNotEmpty) {
                                team = apiModel.teams!
                                    .map((teamMember) {
                                      if (teamMember is Map<String, dynamic>) {
                                        return teamMember['UserId']?.toString() ?? '';
                                      }
                                      return '';
                                    })
                                    .where((id) => id.isNotEmpty)
                                    .toList();
                              }
                              
                              _statusUpdated = true;
                              context.read<IncidentBloc>().add(
                                    UpdateAllIncidentEvent(
                                      incidentId: incident.id,
                                      areasDescription: apiModel.areasDescription ?? '',
                                      areasId: apiModel.areasId ?? '',
                                      idIncidentType: apiModel.idIncidentType ?? 0,
                                      incidentDate: apiModel.incidentDate ?? DateTime.now(),
                                      incidentTime: apiModel.incidentTime ?? '00:00:00',
                                      incidentDescription: apiModel.incidentDescription ?? '',
                                      reportId: apiModel.reportId ?? '',
                                      notesAction: apiModel.notesAction ?? 'Diterima oleh ${_userRole?.displayName ?? 'PJO/Deputy'}',
                                      picId: apiModel.picId,
                                      team: team,
                                      solvedAction: apiModel.solvedAction,
                                      solvedDate: apiModel.solvedDate,
                                      evidence: apiModel.evidence,
                                      status: 'ACKNOWLEDGE',
                                    ),
                                  );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Gagal memuat data: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                  ),
                  16.verticalSpace,
                  // Tombol Tandai Tidak Valid (mengubah status ke INVALID)
                  UIButton(
                    text: 'Tandai Tidak Valid',
                    fullWidth: true,
                    size: UIButtonSize.large,
                    buttonType: UIButtonType.outline,
                    variant: UIButtonVariant.error,
                    isLoading: state.isLoading,
                    onPressed: state.isLoading
                        ? null
                        : () async {
                            // Get incident detail untuk mendapatkan semua field yang diperlukan
                            try {
                              final datasource = getIt<IncidentRemoteDataSource>();
                              final apiModel = await datasource.getIncidentDetailApiModel(incident.id);
                              
                              // Get team from existing data
                              List<String> team = [];
                              if (apiModel.teams != null && apiModel.teams!.isNotEmpty) {
                                team = apiModel.teams!
                                    .map((teamMember) {
                                      if (teamMember is Map<String, dynamic>) {
                                        return teamMember['UserId']?.toString() ?? '';
                                      }
                                      return '';
                                    })
                                    .where((id) => id.isNotEmpty)
                                    .toList();
                              }
                              
                              _statusUpdated = true;
                              context.read<IncidentBloc>().add(
                                    UpdateAllIncidentEvent(
                                      incidentId: incident.id,
                                      areasDescription: apiModel.areasDescription ?? '',
                                      areasId: apiModel.areasId ?? '',
                                      idIncidentType: apiModel.idIncidentType ?? 0,
                                      incidentDate: apiModel.incidentDate ?? DateTime.now(),
                                      incidentTime: apiModel.incidentTime ?? '00:00:00',
                                      incidentDescription: apiModel.incidentDescription ?? '',
                                      reportId: apiModel.reportId ?? '',
                                      notesAction: apiModel.notesAction ?? 'Ditandai tidak valid oleh ${_userRole?.displayName ?? 'PJO/Deputy'}',
                                      picId: apiModel.picId,
                                      team: team,
                                      solvedAction: apiModel.solvedAction,
                                      solvedDate: apiModel.solvedDate,
                                      evidence: apiModel.evidence,
                                      status: 'INVALID',
                                    ),
                                  );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Gagal memuat data: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                  ),
                ],
              );
            },
          );
        }
        
        // Check permission untuk assign
        final canAssign = IncidentPermissionHelper.canAssignIncident(
          incident: incident,
          currentUserRole: _userRole!,
        );
        
        // Check permission untuk escalate
        final canEscalate = IncidentPermissionHelper.canEscalateIncident(
          incident: incident,
          currentUserRole: _userRole!,
        );
        
        // Tombol Tugaskan dan Eskalasi untuk status Diterima
        if (incident.status == IncidentStatus.diterima) {
          if (canAssign) {
            buttons.add(
              UIButton(
                text: 'Tugaskan',
                fullWidth: true,
                size: UIButtonSize.large,
                isLoading: state.isLoading,
                onPressed: state.isLoading
                    ? null
                    : () {
                        _showAssignDialog(context, incident);
                      },
              ),
            );
            if (canEscalate) {
              buttons.add(16.verticalSpace);
            }
          }
          
          if (canEscalate) {
            buttons.add(
              UIButton(
                text: 'Eskalasi',
                fullWidth: true,
                size: UIButtonSize.large,
                buttonType: UIButtonType.outline,
                variant: UIButtonVariant.warning,
                isLoading: state.isLoading,
                onPressed: state.isLoading
                    ? null
                    : () {
                        _statusUpdated = true;
                        _wasPreviouslyEscalated = true; // Track escalation
                        context.read<IncidentBloc>().add(
                              UpdateIncidentStatusEvent(
                                incidentId: incident.id,
                                status: 'ESCALATED',
                                notes: 'Dieskalasi oleh ${_userRole?.displayName ?? 'PJO/Deputy'}',
                              ),
                            );
                      },
              ),
            );
          }
        }
        
        // Tombol Verifikasi dan Revisi untuk status COMPLETED
        if (incident.status == IncidentStatus.selesai) {
          // Check permission untuk verify
          final canVerify = IncidentPermissionHelper.canVerifyIncident(
            incident: incident,
            currentUserRole: _userRole!,
            wasPreviouslyEscalated: _wasPreviouslyEscalated,
          );
          
          // Check permission untuk revise
          final canRevise = IncidentPermissionHelper.canReviseIncident(
            incident: incident,
            currentUserRole: _userRole!,
            wasPreviouslyEscalated: _wasPreviouslyEscalated,
          );
          
          if (canVerify) {
            buttons.add(
              UIButton(
                text: 'Verifikasi',
                fullWidth: true,
                size: UIButtonSize.large,
                variant: UIButtonVariant.success,
                isLoading: state.isLoading,
                onPressed: state.isLoading
                    ? null
                    : () {
                        _showVerifyDialog(context, incident);
                      },
              ),
            );
            if (canRevise) {
              buttons.add(16.verticalSpace);
            }
          }
          
          if (canRevise) {
            buttons.add(
              UIButton(
                text: 'Revisi',
                fullWidth: true,
                size: UIButtonSize.large,
                buttonType: UIButtonType.outline,
                variant: UIButtonVariant.warning,
                isLoading: state.isLoading,
                onPressed: state.isLoading
                    ? null
                    : () {
                        _showReviseDialog(context, incident);
                      },
              ),
            );
          }
        }
        
        if (buttons.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Column(children: buttons);
      },
    );
  }

  Widget _buildDantonActionButtons(IncidentEntity incident) {
    // Untuk danton di tab "Daftar Insiden"
    // Rules: Danton dapat mereview insiden dengan status "menunggu"
    // - Hanya jika pelapor adalah Anggota (bukan Danton)
    // - Danton tidak dapat review laporan sendiri atau laporan dari Danton lain
    // - Tombol "Diterima" -> mengubah status ke ACKNOWLEDGE (Diterima)
    // - Tombol "Tandai Tidak Valid" -> mengubah status ke INVALID (Tidak Valid)
    if (incident.status != IncidentStatus.menunggu || _userRole == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<bool>(
      future: () async {
        // Get current user ID and reporter ID
        final currentUserId = await UserRoleHelper.getUserId();
        final reporterId = incident.pelaporId;
        
        // Get reporter role from incident.reporterRole or API model
        UserRole? reporterRole;
        
        // Try to get from incident.reporterRole first
        if (incident.reporterRole != null && incident.reporterRole!.isNotEmpty) {
          try {
            reporterRole = UserRole.fromValue(incident.reporterRole!);
          } catch (e) {
            // If parsing fails, try to get from API model
            try {
              final datasource = getIt<IncidentRemoteDataSource>();
              final apiModel = await datasource.getIncidentDetailApiModel(incident.id);
              if (apiModel.roles != null && apiModel.roles!.isNotEmpty) {
                // Get first role from roles list (usually there's only one role for reporter)
                final roleName = apiModel.roles!.first.nama;
                reporterRole = UserRole.fromValue(roleName);
              }
            } catch (e) {
              // If API call fails, reporterRole will remain null
            }
          }
        } else {
          // If incident.reporterRole is null, try to get from API model
          try {
            final datasource = getIt<IncidentRemoteDataSource>();
            final apiModel = await datasource.getIncidentDetailApiModel(incident.id);
            if (apiModel.roles != null && apiModel.roles!.isNotEmpty) {
              // Get first role from roles list (usually there's only one role for reporter)
              final roleName = apiModel.roles!.first.nama;
              reporterRole = UserRole.fromValue(roleName);
            }
          } catch (e) {
            // If API call fails, reporterRole will remain null
          }
        }
        
        return await IncidentPermissionHelper.canReviewIncident(
          incident: incident,
          currentUserRole: _userRole!,
          reporterRole: reporterRole, // Now properly extracted from incident or API
          currentUserId: currentUserId,
          reporterId: reporterId,
        );
      }(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!) {
          return const SizedBox.shrink();
        }

        return BlocBuilder<IncidentBloc, IncidentState>(
          builder: (context, state) {
            return Column(
              children: [
                // Tombol Diterima (mengubah status ke ACKNOWLEDGE)
                UIButton(
                  text: 'Diterima',
                  fullWidth: true,
                  size: UIButtonSize.large,
                  variant: UIButtonVariant.success,
                  isLoading: state.isLoading,
                  onPressed: state.isLoading
                      ? null
                      : () async {
                          // Get incident detail untuk mendapatkan semua field yang diperlukan
                          try {
                            final datasource = getIt<IncidentRemoteDataSource>();
                            final apiModel = await datasource.getIncidentDetailApiModel(incident.id);
                            
                            // Get team from existing data
                            List<String> team = [];
                            if (apiModel.teams != null && apiModel.teams!.isNotEmpty) {
                              team = apiModel.teams!
                                  .map((teamMember) {
                                    if (teamMember is Map<String, dynamic>) {
                                      return teamMember['UserId']?.toString() ?? '';
                                    }
                                    return '';
                                  })
                                  .where((id) => id.isNotEmpty)
                                  .toList();
                            }
                            
                            _statusUpdated = true;
                            context.read<IncidentBloc>().add(
                                  UpdateAllIncidentEvent(
                                    incidentId: incident.id,
                                    areasDescription: apiModel.areasDescription ?? '',
                                    areasId: apiModel.areasId ?? '',
                                    idIncidentType: apiModel.idIncidentType ?? 0,
                                    incidentDate: apiModel.incidentDate ?? DateTime.now(),
                                    incidentTime: apiModel.incidentTime ?? '00:00:00',
                                    incidentDescription: apiModel.incidentDescription ?? '',
                                    reportId: apiModel.reportId ?? '',
                                    notesAction: apiModel.notesAction ?? 'Diterima oleh danton',
                                    picId: apiModel.picId,
                                    team: team,
                                    solvedAction: apiModel.solvedAction,
                                    solvedDate: apiModel.solvedDate,
                                    evidence: apiModel.evidence,
                                    status: 'ACKNOWLEDGE',
                                  ),
                                );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Gagal memuat data: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                ),
                16.verticalSpace,
                // Tombol Tandai Tidak Valid (mengubah status ke INVALID)
                UIButton(
                  text: 'Tandai Tidak Valid',
                  fullWidth: true,
                  size: UIButtonSize.large,
                  buttonType: UIButtonType.outline,
                  variant: UIButtonVariant.error,
                  isLoading: state.isLoading,
                  onPressed: state.isLoading
                      ? null
                      : () async {
                          // Get incident detail untuk mendapatkan semua field yang diperlukan
                          try {
                            final datasource = getIt<IncidentRemoteDataSource>();
                            final apiModel = await datasource.getIncidentDetailApiModel(incident.id);
                            
                            // Get team from existing data
                            List<String> team = [];
                            if (apiModel.teams != null && apiModel.teams!.isNotEmpty) {
                              team = apiModel.teams!
                                  .map((teamMember) {
                                    if (teamMember is Map<String, dynamic>) {
                                      return teamMember['UserId']?.toString() ?? '';
                                    }
                                    return '';
                                  })
                                  .where((id) => id.isNotEmpty)
                                  .toList();
                            }
                            
                            _statusUpdated = true;
                            context.read<IncidentBloc>().add(
                                  UpdateAllIncidentEvent(
                                    incidentId: incident.id,
                                    areasDescription: apiModel.areasDescription ?? '',
                                    areasId: apiModel.areasId ?? '',
                                    idIncidentType: apiModel.idIncidentType ?? 0,
                                    incidentDate: apiModel.incidentDate ?? DateTime.now(),
                                    incidentTime: apiModel.incidentTime ?? '00:00:00',
                                    incidentDescription: apiModel.incidentDescription ?? '',
                                    reportId: apiModel.reportId ?? '',
                                    notesAction: apiModel.notesAction ?? 'Ditandai tidak valid oleh danton',
                                    picId: apiModel.picId,
                                    team: team,
                                    solvedAction: apiModel.solvedAction,
                                    solvedDate: apiModel.solvedDate,
                                    evidence: apiModel.evidence,
                                    status: 'INVALID',
                                  ),
                                );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Gagal memuat data: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton(IncidentEntity incident) {
    // Button untuk PIC/Team Member di tab "Tugas Saya"
    // Rules:
    // - PIC maupun Anggota Team dapat memproses (Klik Proses) -> status dari Ditugaskan ke Proses (PROGRESS)
    // - PIC maupun Anggota Team dapat menyelesaikan (Klik Tandai Sebagai Selesai) -> status dari Proses ke Selesai (COMPLETED)
    // - Saat status Revisi: PIC/anggota team mengisi note penyelesaian + bukti, lalu Tandai Sebagai Selesai -> status ke Selesai (COMPLETED)
    
    return FutureBuilder<bool>(
      future: () async {
        // Get current user ID
        final currentUserId = await UserRoleHelper.getUserId();
        if (currentUserId == null || currentUserId.isEmpty) {
          return false;
        }
        
        // Check status
        if (incident.status != IncidentStatus.ditugaskan && 
            incident.status != IncidentStatus.proses &&
            incident.status != IncidentStatus.revisi) {
          return false;
        }
        
        // Check if user is PIC
        if (incident.picId == currentUserId) {
          return true;
        }
        
        // Check if user is in Teams - load from API model to get accurate Teams data
        // This is important because incidentDetail might be empty if Teams is empty
        try {
          final datasource = getIt<IncidentRemoteDataSource>();
          final apiModel = await datasource.getIncidentDetailApiModel(incident.id);
          
          // Check Teams directly from API model
          if (apiModel.teams != null && apiModel.teams!.isNotEmpty) {
            for (var team in apiModel.teams!) {
              if (team is Map<String, dynamic>) {
                final teamUserId = team['UserId']?.toString() ?? '';
                if (teamUserId == currentUserId) {
                  return true;
                }
              }
            }
          }
          
          // Also check from IncidentDetail (for backward compatibility)
          if (apiModel.incidentDetail != null) {
            List<Map<String, dynamic>> incidentDetailList = [];
            if (apiModel.incidentDetail is Map<String, dynamic>) {
              incidentDetailList.add(Map<String, dynamic>.from(apiModel.incidentDetail as Map));
            } else if (apiModel.incidentDetail is List) {
              for (var item in apiModel.incidentDetail as List) {
                if (item is Map) {
                  incidentDetailList.add(Map<String, dynamic>.from(item));
                }
              }
            }
            
            for (var detail in incidentDetailList) {
              final teamUserId = detail['UserId']?.toString() ?? '';
              if (teamUserId == currentUserId) {
                return true;
              }
            }
          }
        } catch (e) {
          // If API call fails, fallback to check from incidentDetail in entity
          if (incident.incidentDetail != null && incident.incidentDetail!.isNotEmpty) {
            for (var detail in incident.incidentDetail!) {
              final teamUserId = detail['UserId']?.toString() ?? '';
              if (teamUserId == currentUserId) {
                return true;
              }
            }
          }
        }
        
        return false;
      }(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!) {
          return const SizedBox.shrink();
        }

        String buttonText;
        String nextStatus;
        bool useUpdateAll = false; // Flag untuk menentukan API yang digunakan
        
        if (incident.status == IncidentStatus.ditugaskan) {
          // Status Ditugaskan -> tombol "Proses" -> update ke PROGRESS (Proses)
          buttonText = 'Proses';
          nextStatus = 'PROGRESS';
          useUpdateAll = false; // Gunakan /Incident/update
        } else if (incident.status == IncidentStatus.proses ||
            incident.status == IncidentStatus.revisi) {
          // Status Proses atau Revisi -> tombol "Tandai Sebagai Selesai" -> update ke COMPLETED
          buttonText = 'Tandai Sebagai Selesai';
          nextStatus = 'COMPLETED';
          useUpdateAll = true; // Gunakan /Incident/updateall
        } else {
          return const SizedBox.shrink();
        }

        return BlocBuilder<IncidentBloc, IncidentState>(
          builder: (context, state) {
            return UIButton(
              text: buttonText,
              fullWidth: true,
              size: UIButtonSize.large,
              isLoading: state.isLoading,
              onPressed: state.isLoading
                  ? null
                  : () {
                      _statusUpdated = true; // Set flag before update
                      
                      if (useUpdateAll) {
                        // Untuk "Tandai Sebagai Selesai", gunakan /Incident/updateall
                        // Status akan diupdate ke COMPLETED (Selesai) di dalam dialog
                        _showCompleteDialog(context, incident);
                      } else {
                        // Untuk "Proses", gunakan /Incident/update
                        // Status akan diupdate ke PROGRESS (Proses)
                        context.read<IncidentBloc>().add(
                              UpdateIncidentStatusEvent(
                                incidentId: incident.id,
                                status: nextStatus, // 'PROGRESS'
                              ),
                            );
                      }
                    },
            );
          },
        );
      },
    );
  }

  Future<void> _showAssignDialog(BuildContext context, IncidentEntity incident) async {
    final datasource = getIt<IncidentRemoteDataSource>();
    String? selectedPjId; // PIC ID (Penanggung Jawab)
    List<String> selectedTeamIds = []; // Team IDs (Anggota - multiple selection)
    final tugasPenangananController = TextEditingController();
    bool isLoading = true;
    bool isSubmitting = false;
    List<Map<String, String>> userList = [];
    Map<String, String>? incidentApiData;

    // Load user list and incident detail
    try {
      final users = await datasource.getUserList();
      final apiModel = await datasource.getIncidentDetailApiModel(incident.id);
      
      // Sort user list by name (alphabetically)
      userList = users;
      userList.sort((a, b) {
        final nameA = (a['name'] ?? '').toLowerCase();
        final nameB = (b['name'] ?? '').toLowerCase();
        return nameA.compareTo(nameB);
      });

      incidentApiData = {
        'areasDescription': apiModel.areasDescription ?? apiModel.areas?.name ?? '',
        'areasId': apiModel.areasId ?? '',
        'idIncidentType': apiModel.idIncidentType?.toString() ?? '0',
        'incidentDate': apiModel.incidentDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'incidentTime': apiModel.incidentTime ?? '00:00:00',
        'incidentDescription': apiModel.incidentDescription ?? '',
        'reportId': apiModel.reportId ?? '',
      };
      
      isLoading = false;
    } catch (e) {
      isLoading = false;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    final apiData = incidentApiData;

    final incidentBloc = context.read<IncidentBloc>();

    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: incidentBloc,
        child: BlocListener<IncidentBloc, IncidentState>(
          listener: (context, state) {
            if (!state.isLoading && isSubmitting) {
              if (state.errorMessage == null) {
                // Success - close dialog
                // Use post frame callback to ensure context is valid
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted && Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                });
                _statusUpdated = true;
              } else {
                // Error - show error and reset submitting
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.errorMessage!),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              }
            }
          },
          child: StatefulBuilder(
          builder: (context, setState) => Dialog(
            backgroundColor: Colors.white,
            insetPadding: REdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: REdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tugaskan Insiden',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black87),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: REdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                      // Penanggung Jawab
                      SearchableDropdown<String?>(
                        label: 'Penanggung Jawab',
                        hint: 'Pilih Penanggung Jawab',
                        value: selectedPjId,
                        items: userList.map((user) => DropdownItem<String?>(
                          value: user['id'],
                          text: user['name'] ?? '',
                        )).toList(),
                        isRequired: true,
                        onChanged: (value) {
                          setState(() {
                            selectedPjId = value;
                          });
                        },
                      ),
                      20.verticalSpace,
                      // Tim (Multiple Selection)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Tim',
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
                            onTap: () => _showTeamSelectionDialog(
                              context,
                              userList,
                              selectedTeamIds,
                              (selectedIds) {
                                setState(() {
                                  selectedTeamIds = selectedIds;
                                });
                              },
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: REdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                                color: inputColor,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      selectedTeamIds.isEmpty
                                          ? 'Pilih Tim'
                                          : selectedTeamIds.length == 1
                                              ? userList
                                                  .firstWhere(
                                                    (u) => u['id'] == selectedTeamIds.first,
                                                    orElse: () => {'name': ''},
                                                  )['name'] ?? 'Pilih Tim'
                                              : '${selectedTeamIds.length} anggota dipilih',
                                      style: TS.bodyLarge.copyWith(
                                        color: selectedTeamIds.isEmpty
                                            ? appHintColor
                                            : Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.grey.shade600,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      20.verticalSpace,
                      // Tugas Penanganan
                      InputPrimary(
                        label: 'Tugas Penanganan',
                        controller: tugasPenangananController,
                        hint: 'Masukkan tugas penanganan',
                        isRequired: true,
                        maxLines: 10, // Allow multiple lines for long text
                        minLines: 3, // Start with 3 lines
                        maxLength: TextField.noMaxLength, // Allow unlimited text length
                        validation: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Tugas penanganan harus diisi';
                          }
                          return null;
                        },
                      ),
                            ],
                          ),
                        ),
                ),
                // Actions
                Container(
                  padding: REdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey, width: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Batal'),
                      ),
                      12.horizontalSpace,
                      ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                      if (selectedPjId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Mohon pilih Penanggung Jawab'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (selectedTeamIds.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Mohon pilih minimal 1 anggota Tim'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (tugasPenangananController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Mohon isi Tugas Penanganan'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setState(() {
                        isSubmitting = true;
                      });
                      
                      // Dispatch event - BlocListener will handle the response
                      // Note: Pembuat Keputusan (UserName - CreateDate) akan otomatis diisi oleh backend
                      // berdasarkan user yang melakukan assign (mengisi PIC, Anggota, klik Tugaskan)
                      context.read<IncidentBloc>().add(
                        UpdateAllIncidentEvent(
                          incidentId: incident.id,
                          areasDescription: apiData['areasDescription']!,
                          areasId: apiData['areasId']!,
                          idIncidentType: int.parse(apiData['idIncidentType']!),
                          incidentDate: DateTime.parse(apiData['incidentDate']!),
                          incidentTime: apiData['incidentTime']!,
                          incidentDescription: apiData['incidentDescription']!,
                          reportId: apiData['reportId']!,
                          notesAction: tugasPenangananController.text.trim(),
                          picId: selectedPjId!,
                          team: selectedTeamIds,
                          handlingTask: tugasPenangananController.text.trim(),
                          // actionTakenNote tidak diisi di sini, karena itu untuk Note Penyelesaian
                          // Pembuat Keputusan (UserName - CreateDate) akan diisi otomatis oleh backend
                          status: 'ASSIGNED',
                        ),
                      );
                    },
                        child: isSubmitting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Tugaskan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: REdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
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

  Future<void> _showReviseDialog(BuildContext context, IncidentEntity incident) async {
    final datasource = getIt<IncidentRemoteDataSource>();
    final supervisorFeedbackController = TextEditingController();
    String? picId;
    List<String> team = [];
    String handlingTask = '';
    Map<String, String>? incidentApiData;

    // Load incident detail untuk mendapatkan data yang sudah ada
    try {
      final apiModel = await datasource.getIncidentDetailApiModel(incident.id);
      
      picId = apiModel.picId;
      // Team diambil dari Teams list, jika kosong ambil dari IncidentDetail
      if (apiModel.teams != null && apiModel.teams!.isNotEmpty) {
        team = apiModel.teams!
            .map((teamMember) {
              if (teamMember is Map<String, dynamic>) {
                return teamMember['UserId']?.toString() ?? '';
              }
              return '';
            })
            .where((id) => id.isNotEmpty)
            .toList();
      } else {
        // Jika Teams kosong, ambil dari IncidentDetail
        if (apiModel.incidentDetail != null) {
          if (apiModel.incidentDetail is Map<String, dynamic>) {
            final detail = apiModel.incidentDetail as Map<String, dynamic>;
            final userId = detail['UserId']?.toString();
            if (userId != null && userId.isNotEmpty) {
              team = [userId];
            }
          } else if (apiModel.incidentDetail is List) {
            final detailList = apiModel.incidentDetail as List;
            team = detailList
                .map((detail) {
                  if (detail is Map<String, dynamic>) {
                    return detail['UserId']?.toString() ?? '';
                  }
                  return '';
                })
                .where((id) => id.isNotEmpty)
                .toList();
          }
        }
      }
      // HandlingTask diambil dari IncidentDetail jika ada, atau dari NotesAction
      handlingTask = '';
      if (apiModel.incidentDetail != null) {
        if (apiModel.incidentDetail is Map<String, dynamic>) {
          final detail = apiModel.incidentDetail as Map<String, dynamic>;
          handlingTask = detail['HandlingTask']?.toString() ?? apiModel.notesAction ?? '';
        } else if (apiModel.incidentDetail is List && (apiModel.incidentDetail as List).isNotEmpty) {
          final detailList = apiModel.incidentDetail as List;
          final firstDetail = detailList.first;
          if (firstDetail is Map<String, dynamic>) {
            handlingTask = firstDetail['HandlingTask']?.toString() ?? apiModel.notesAction ?? '';
          }
        }
      }
      if (handlingTask.isEmpty) {
        handlingTask = apiModel.notesAction ?? '';
      }

      incidentApiData = {
        'areasDescription': apiModel.areasDescription ?? apiModel.areas?.name ?? '',
        'areasId': apiModel.areasId ?? '',
        'idIncidentType': apiModel.idIncidentType?.toString() ?? '0',
        'incidentDate': apiModel.incidentDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'incidentTime': apiModel.incidentTime ?? '00:00:00',
        'incidentDescription': apiModel.incidentDescription ?? '',
        'reportId': apiModel.reportId ?? '',
      };
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // Delay disposal to ensure dialog is fully closed
      Future.delayed(const Duration(milliseconds: 300), () {
        try {
          supervisorFeedbackController.dispose();
        } catch (e) {
          // Controller already disposed, ignore
        }
      });
      return;
    }

    if (!context.mounted) {
      // Delay disposal to ensure dialog is fully closed
      Future.delayed(const Duration(milliseconds: 300), () {
        try {
          supervisorFeedbackController.dispose();
        } catch (e) {
          // Controller already disposed, ignore
        }
      });
      return;
    }
    final apiData = incidentApiData;

    // Tampilkan dialog dengan field SupervisorFeedback
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Revisi Insiden'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Isi feedback supervisor (opsional):'),
                const SizedBox(height: 16),
                TextField(
                  controller: supervisorFeedbackController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Masukkan feedback supervisor...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Revisi'),
            ),
          ],
        ),
      ),
    );

    // Store controller text before potential disposal
    final feedbackText = supervisorFeedbackController.text.trim();

    if (confirmed != true || !context.mounted) {
      // Delay disposal to ensure dialog is fully closed
      Future.delayed(const Duration(milliseconds: 300), () {
        try {
          supervisorFeedbackController.dispose();
        } catch (e) {
          // Controller already disposed, ignore
        }
      });
      return;
    }

    // Revisi menggunakan updateAllIncident - hanya ubah status ke REVISED,
    // semua field payload lain diambil dari detail incident (getAll) di datasource
    try {
      context.read<IncidentBloc>().add(
        UpdateAllIncidentEvent(
          incidentId: incident.id,
          areasDescription: apiData['areasDescription']!,
          areasId: apiData['areasId']!,
          idIncidentType: int.parse(apiData['idIncidentType']!),
          incidentDate: DateTime.parse(apiData['incidentDate']!),
          incidentTime: apiData['incidentTime']!,
          incidentDescription: apiData['incidentDescription']!,
          reportId: apiData['reportId']!,
          notesAction: handlingTask,
          picId: picId,
          team: team,
          handlingTask: handlingTask,
          status: 'REVISED',
          supervisorFeedback: feedbackText.isNotEmpty ? feedbackText : null,
        ),
      );

      if (context.mounted) {
        _statusUpdated = true;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal merevisi: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      // Delay disposal to ensure dialog is fully closed
      Future.delayed(const Duration(milliseconds: 300), () {
        try {
          supervisorFeedbackController.dispose();
        } catch (e) {
          // Controller already disposed, ignore
        }
      });
    }
  }

  Future<void> _showVerifyDialog(BuildContext context, IncidentEntity incident) async {
    final datasource = getIt<IncidentRemoteDataSource>();
    final supervisorFeedbackController = TextEditingController();
    String? picId;
    List<String> team = [];
    String handlingTask = '';
    Map<String, String>? incidentApiData;

    // Load incident detail untuk mendapatkan data yang sudah ada
    try {
      final apiModel = await datasource.getIncidentDetailApiModel(incident.id);
      
      picId = apiModel.picId;
      // Team diambil dari Teams list, jika kosong ambil dari IncidentDetail
      if (apiModel.teams != null && apiModel.teams!.isNotEmpty) {
        team = apiModel.teams!
            .map((teamMember) {
              if (teamMember is Map<String, dynamic>) {
                return teamMember['UserId']?.toString() ?? '';
              }
              return '';
            })
            .where((id) => id.isNotEmpty)
            .toList();
      } else {
        // Jika Teams kosong, ambil dari IncidentDetail
        if (apiModel.incidentDetail != null) {
          if (apiModel.incidentDetail is Map<String, dynamic>) {
            final detail = apiModel.incidentDetail as Map<String, dynamic>;
            final userId = detail['UserId']?.toString();
            if (userId != null && userId.isNotEmpty) {
              team = [userId];
            }
          } else if (apiModel.incidentDetail is List) {
            final detailList = apiModel.incidentDetail as List;
            team = detailList
                .map((detail) {
                  if (detail is Map<String, dynamic>) {
                    return detail['UserId']?.toString() ?? '';
                  }
                  return '';
                })
                .where((id) => id.isNotEmpty)
                .toList();
          }
        }
      }
      // HandlingTask diambil dari IncidentDetail jika ada, atau dari NotesAction
      handlingTask = '';
      if (apiModel.incidentDetail != null) {
        if (apiModel.incidentDetail is Map<String, dynamic>) {
          final detail = apiModel.incidentDetail as Map<String, dynamic>;
          handlingTask = detail['HandlingTask']?.toString() ?? apiModel.notesAction ?? '';
        } else if (apiModel.incidentDetail is List && (apiModel.incidentDetail as List).isNotEmpty) {
          final detailList = apiModel.incidentDetail as List;
          final firstDetail = detailList.first;
          if (firstDetail is Map<String, dynamic>) {
            handlingTask = firstDetail['HandlingTask']?.toString() ?? apiModel.notesAction ?? '';
          }
        }
      }
      if (handlingTask.isEmpty) {
        handlingTask = apiModel.notesAction ?? '';
      }

      incidentApiData = {
        'areasDescription': apiModel.areasDescription ?? apiModel.areas?.name ?? '',
        'areasId': apiModel.areasId ?? '',
        'idIncidentType': apiModel.idIncidentType?.toString() ?? '0',
        'incidentDate': apiModel.incidentDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'incidentTime': apiModel.incidentTime ?? '00:00:00',
        'incidentDescription': apiModel.incidentDescription ?? '',
        'reportId': apiModel.reportId ?? '',
      };
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    final apiData = incidentApiData;

    // Tampilkan dialog dengan field SupervisorFeedback
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Verifikasi Insiden'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Isi feedback supervisor (opsional):'),
                const SizedBox(height: 16),
                TextField(
                  controller: supervisorFeedbackController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Masukkan feedback supervisor...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Verifikasi'),
            ),
          ],
        ),
      ),
    );

    // Store controller text before potential disposal
    final feedbackText = supervisorFeedbackController.text.trim();

    if (confirmed != true || !context.mounted) {
      // Delay disposal to ensure dialog is fully closed
      Future.delayed(const Duration(milliseconds: 300), () {
        try {
          supervisorFeedbackController.dispose();
        } catch (e) {
          // Controller already disposed, ignore
        }
      });
      return;
    }

    // Verifikasi menggunakan updateAllIncident
    // Note dari dialog verifikasi diisi ke SupervisorFeedback (bukan NotesAction)
    try {
      context.read<IncidentBloc>().add(
        UpdateAllIncidentEvent(
          incidentId: incident.id,
          areasDescription: apiData['areasDescription']!,
          areasId: apiData['areasId']!,
          idIncidentType: int.parse(apiData['idIncidentType']!),
          incidentDate: DateTime.parse(apiData['incidentDate']!),
          incidentTime: apiData['incidentTime']!,
          incidentDescription: apiData['incidentDescription']!,
          reportId: apiData['reportId']!,
          notesAction: handlingTask,
          picId: picId,
          team: team,
          handlingTask: handlingTask,
          status: 'VERIFIED',
          supervisorFeedback: feedbackText.isNotEmpty ? feedbackText : null, // Note dari dialog verifikasi diisi ke SupervisorFeedback
        ),
      );

      if (context.mounted) {
        _statusUpdated = true;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memverifikasi: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      // Delay disposal to ensure dialog is fully closed
      Future.delayed(const Duration(milliseconds: 300), () {
        try {
          supervisorFeedbackController.dispose();
        } catch (e) {
          // Controller already disposed, ignore
        }
      });
    }
  }

  Future<void> _showCompleteDialog(BuildContext context, IncidentEntity incident) async {
    final datasource = getIt<IncidentRemoteDataSource>();
    final imagePicker = ImagePicker();
    String? picId;
    List<String> team = [];
    String handlingTask = '';
    Map<String, String>? incidentApiData;
    File? selectedImage;
    final solvedActionController = TextEditingController(); // Controller untuk note penyelesaian

    // Load incident detail untuk mendapatkan data yang sudah ada
    try {
      final apiModel = await datasource.getIncidentDetailApiModel(incident.id);
      
      picId = apiModel.picId;
      // Team diambil dari Teams list, jika kosong ambil dari IncidentDetail
      if (apiModel.teams != null && apiModel.teams!.isNotEmpty) {
        team = apiModel.teams!
            .map((teamMember) {
              if (teamMember is Map<String, dynamic>) {
                return teamMember['UserId']?.toString() ?? '';
              }
              return '';
            })
            .where((id) => id.isNotEmpty)
            .toList();
      } else {
        // Jika Teams kosong, ambil dari IncidentDetail
        if (apiModel.incidentDetail != null) {
          if (apiModel.incidentDetail is Map<String, dynamic>) {
            final detail = apiModel.incidentDetail as Map<String, dynamic>;
            final userId = detail['UserId']?.toString();
            if (userId != null && userId.isNotEmpty) {
              team = [userId];
            }
          } else if (apiModel.incidentDetail is List) {
            final detailList = apiModel.incidentDetail as List;
            team = detailList
                .map((detail) {
                  if (detail is Map<String, dynamic>) {
                    return detail['UserId']?.toString() ?? '';
                  }
                  return '';
                })
                .where((id) => id.isNotEmpty)
                .toList();
          }
        }
      }
      // HandlingTask diambil dari IncidentDetail jika ada, atau dari NotesAction
      handlingTask = '';
      if (apiModel.incidentDetail != null) {
        if (apiModel.incidentDetail is Map<String, dynamic>) {
          final detail = apiModel.incidentDetail as Map<String, dynamic>;
          handlingTask = detail['HandlingTask']?.toString() ?? apiModel.notesAction ?? '';
        } else if (apiModel.incidentDetail is List && (apiModel.incidentDetail as List).isNotEmpty) {
          final detailList = apiModel.incidentDetail as List;
          final firstDetail = detailList.first;
          if (firstDetail is Map<String, dynamic>) {
            handlingTask = firstDetail['HandlingTask']?.toString() ?? apiModel.notesAction ?? '';
          }
        }
      }
      if (handlingTask.isEmpty) {
        handlingTask = apiModel.notesAction ?? '';
      }

      incidentApiData = {
        'areasDescription': apiModel.areasDescription ?? apiModel.areas?.name ?? '',
        'areasId': apiModel.areasId ?? '',
        'idIncidentType': apiModel.idIncidentType?.toString() ?? '0',
        'incidentDate': apiModel.incidentDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'incidentTime': apiModel.incidentTime ?? '00:00:00',
        'incidentDescription': apiModel.incidentDescription ?? '',
        'reportId': apiModel.reportId ?? '',
      };
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // Delay disposal to ensure dialog is fully closed
      Future.delayed(const Duration(milliseconds: 300), () {
        try {
          solvedActionController.dispose();
        } catch (e) {
          // Controller already disposed, ignore
        }
      });
      return;
    }

    if (!context.mounted) {
      // Delay disposal to ensure dialog is fully closed
      Future.delayed(const Duration(milliseconds: 300), () {
        try {
          solvedActionController.dispose();
        } catch (e) {
          // Controller already disposed, ignore
        }
      });
      return;
    }
    final apiData = incidentApiData;

    // Tampilkan dialog dengan form note penyelesaian dan upload image
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Tandai Sebagai Selesai'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Isi informasi penyelesaian insiden:'),
                const SizedBox(height: 16),
                // Field Note Penyelesaian
                const Text(
                  'Note Penyelesaian',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: solvedActionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Masukkan note penyelesaian...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),
                // Field Upload Bukti Foto
                const Text(
                  'Upload Bukti Foto (Opsional)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (selectedImage == null)
                  ElevatedButton.icon(
                    onPressed: () async {
                      final source = await showDialog<ImageSource>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Pilih Sumber Foto'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                                title: const Text('Kamera'),
                                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
                              ),
                              ListTile(
                                leading: const Icon(Icons.photo_library, color: Colors.green),
                                title: const Text('Galeri'),
                                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
                              ),
                            ],
                          ),
                        ),
                      );

                      if (source != null) {
                        try {
                          final XFile? image = await imagePicker.pickImage(
                            source: source,
                            imageQuality: 85,
                          );

                          if (image != null) {
                            setState(() {
                              selectedImage = File(image.path);
                            });
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Gagal mengambil foto: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Pilih Foto'),
                  )
                else
                  Column(
                    children: [
                      Image.file(
                        selectedImage!,
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            selectedImage = null;
                          });
                        },
                        child: const Text('Hapus Foto'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Selesai'),
            ),
          ],
        ),
      ),
    );

    // Store controller text before potential disposal
    final actionTakenNote = solvedActionController.text.trim();

    if (confirmed != true || !context.mounted) {
      // Delay disposal to ensure dialog is fully closed
      Future.delayed(const Duration(milliseconds: 300), () {
        try {
          solvedActionController.dispose();
        } catch (e) {
          // Controller already disposed, ignore
        }
      });
      return;
    }

    // Convert image to base64 if selected
    Map<String, dynamic>? incidentImage;
    if (selectedImage != null) {
      try {
        final bytes = await selectedImage!.readAsBytes();
        final base64Image = base64Encode(bytes);
        final fileName = path.basename(selectedImage!.path);
        final extension = path.extension(fileName).toLowerCase();
        
        String mimeType = 'image/jpeg';
        if (extension == '.png') {
          mimeType = 'image/png';
        } else if (extension == '.jpg' || extension == '.jpeg') {
          mimeType = 'image/jpeg';
        } else if (extension == '.gif') {
          mimeType = 'image/gif';
        }

        incidentImage = {
          'Filename': fileName,
          'MimeType': mimeType,
          'Base64': base64Image,
          'FileSize': bytes.length,
        };
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memproses gambar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        // Delay disposal to ensure dialog is fully closed
        Future.delayed(const Duration(milliseconds: 300), () {
          try {
            solvedActionController.dispose();
          } catch (e) {
            // Controller already disposed, ignore
          }
        });
        return;
      }
    }

    // Update status ke COMPLETED (Selesai) menggunakan updateAllIncident
    // Status akan berubah dari Proses (PROGRESS) ke Selesai (COMPLETED)
    // Include note penyelesaian (solvedAction) dan bukti foto (incidentImage)
    // Note penyelesaian diisi ke SolvedAction di incident/updateAll
    try {
      context.read<IncidentBloc>().add(
        UpdateAllIncidentEvent(
          incidentId: incident.id,
          areasDescription: apiData['areasDescription']!,
          areasId: apiData['areasId']!,
          idIncidentType: int.parse(apiData['idIncidentType']!),
          incidentDate: DateTime.parse(apiData['incidentDate']!),
          incidentTime: apiData['incidentTime']!,
          incidentDescription: apiData['incidentDescription']!,
          reportId: apiData['reportId']!,
          notesAction: handlingTask,
          picId: picId,
          team: team,
          handlingTask: handlingTask,
          actionTakenNote: actionTakenNote.isNotEmpty ? actionTakenNote : null, // Note penyelesaian -> payload ActionTakenNote
          solvedAction: actionTakenNote.isNotEmpty ? actionTakenNote : null,
          solvedDate: DateTime.now(),
          status: 'COMPLETED',
          incidentImage: incidentImage,
        ),
      );

      if (context.mounted) {
        _statusUpdated = true;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menandai sebagai selesai: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      // Delay disposal to ensure dialog is fully closed
      Future.delayed(const Duration(milliseconds: 300), () {
        try {
          solvedActionController.dispose();
        } catch (e) {
          // Controller already disposed, ignore
        }
      });
    }
  }

  void _showTeamSelectionDialog(
    BuildContext context,
    List<Map<String, String>> userList,
    List<String> selectedIds,
    Function(List<String>) onSelected,
  ) {
    List<String> tempSelectedIds = List.from(selectedIds);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.white,
          insetPadding: REdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: REdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pilih Tim',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black87),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: REdgeInsets.all(16),
                    itemCount: userList.length,
                    itemBuilder: (context, index) {
                      final user = userList[index];
                      final userId = user['id'] ?? '';
                      final userName = user['name'] ?? '';
                      final isSelected = tempSelectedIds.contains(userId);

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              if (!tempSelectedIds.contains(userId)) {
                                tempSelectedIds.add(userId);
                              }
                            } else {
                              tempSelectedIds.remove(userId);
                            }
                          });
                        },
                        title: Text(
                          userName,
                          style: TS.bodyLarge,
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  ),
                ),
                // Actions
                Container(
                  padding: REdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey, width: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Batal'),
                      ),
                      12.horizontalSpace,
                      ElevatedButton(
                        onPressed: () {
                          onSelected(tempSelectedIds);
                          Navigator.of(context).pop();
                        },
                        child: const Text('Pilih'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: REdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
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
    );
  }
}
