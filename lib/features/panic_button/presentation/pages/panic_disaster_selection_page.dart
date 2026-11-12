import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../core/di/injection.dart';
import '../../data/models/panic_button_incident_type_model.dart';
import '../../domain/repositories/panic_button_repository.dart';
import '../../../../shared/widgets/rumara_app_bar.dart';

class PanicDisasterSelectionPage extends StatefulWidget {
  const PanicDisasterSelectionPage({super.key});

  @override
  State<PanicDisasterSelectionPage> createState() =>
      _PanicDisasterSelectionPageState();
}

class _PanicDisasterSelectionPageState
    extends State<PanicDisasterSelectionPage> {
  int? selectedIncidentTypeId;
  List<PanicButtonIncidentTypeModel> _incidentTypes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadIncidentTypes();
  }

  Future<void> _loadIncidentTypes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = getIt<PanicButtonRepository>();
      final types = await repository.getIncidentTypes();

      setState(() {
        _isLoading = false;
        _incidentTypes = types;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat jenis keadaan darurat: ${e.toString()}';
        _incidentTypes = [];
      });
    }
  }

  IconData _getIconForType(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('keamanan') || lowerName.contains('kecelakaan')) {
      return Icons.security;
    } else if (lowerName.contains('bencana') || lowerName.contains('alam')) {
      return Icons.nature_outlined;
    } else if (lowerName.contains('kebakaran') || lowerName.contains('fire')) {
      return Icons.local_fire_department;
    } else if (lowerName.contains('medis') || lowerName.contains('kesehatan')) {
      return Icons.medical_services;
    }
    return Icons.warning;
  }

  Color _getColorForType(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('keamanan') || lowerName.contains('kecelakaan')) {
      return const Color(0xFFE5484D);
    } else if (lowerName.contains('bencana') || lowerName.contains('alam')) {
      return const Color(0xFFE67E22);
    } else if (lowerName.contains('kebakaran') || lowerName.contains('fire')) {
      return const Color(0xFFFF5722);
    } else if (lowerName.contains('medis') || lowerName.contains('kesehatan')) {
      return const Color(0xFF2ECC71);
    }
    return const Color(0xFFE5484D);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const RumaraAppBar(title: 'Tombol Darurat'),
      child: Padding(
        padding: REdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jenis keadaan darurat yang sesuai',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            24.verticalSpace,

            // Loading state
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            // Error state
            else if (_errorMessage != null)
              Container(
                padding: REdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Column(
                  children: [
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.red[700],
                      ),
                    ),
                    12.verticalSpace,
                    TextButton(
                      onPressed: _loadIncidentTypes,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              )
            // Empty state
            else if (_incidentTypes.isEmpty)
              Center(
                child: Padding(
                  padding: REdgeInsets.all(32),
                  child: Text(
                    'Tidak ada jenis keadaan darurat yang tersedia',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              )
            // List of incident types
            else
              ..._incidentTypes.map((type) => _buildIncidentTypeOption(type)),

            50.verticalSpace,

            // Continue button
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton(
                onPressed: selectedIncidentTypeId != null && !_isLoading
                    ? () {
                        Navigator.pushNamed(
                          context,
                          '/panic-incident-form',
                          arguments: selectedIncidentTypeId,
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedIncidentTypeId != null && !_isLoading
                      ? const Color(0xFFE5484D)
                      : Colors.grey[300],
                  foregroundColor: selectedIncidentTypeId != null && !_isLoading
                      ? Colors.white
                      : Colors.grey[600],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'AKTIFKAN',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentTypeOption(PanicButtonIncidentTypeModel type) {
    final isSelected = selectedIncidentTypeId == type.id;
    final icon = _getIconForType(type.name);
    final color = _getColorForType(type.name);

    return Container(
      margin: REdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          setState(() {
            selectedIncidentTypeId = type.id;
          });
        },
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: REdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.1)
                : Colors.grey[50],
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Container(
                width: 48.w,
                height: 48.h,
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.grey[400],
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24.r,
                ),
              ),
              16.horizontalSpace,
              Expanded(
                child: Text(
                  type.name,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? color : Colors.black87,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: color,
                  size: 24.r,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
