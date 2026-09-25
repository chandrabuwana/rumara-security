import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/di/injection.dart';
import '../../domain/entities/notification_item.dart';

class NotificationListPage extends StatefulWidget {
  const NotificationListPage({super.key});

  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  int _pageSize = 10;
  int _totalCount = 0;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadNotifications(isRefresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      // User scrolled to bottom
      if (!_isLoadingMore && _notifications.length < _totalCount) {
        _loadNotifications(isRefresh: false);
      }
    }
  }

  Future<void> _loadNotifications({required bool isRefresh}) async {
    if (!mounted) return;

    if (isRefresh) {
      _currentPage = 1;
      setState(() => _isLoading = true);
    } else {
      if (_isLoadingMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final dio = getIt<Dio>();
      final response = await dio.post(
        '/Notification/list',
        data: {
          'Filter': [
            {
              'Field': '',
              'Search': '',
            }
          ],
          'Sort': {
            'Field': 'CreateDate',
            'Type': 1, // Descending order
          },
          'Start': _currentPage,
          'Length': _pageSize,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final list = data['List'] as List<dynamic>? ?? [];
        _totalCount = data['Count'] as int? ?? 0;

        final newNotifications = list.map((item) {
          final notification = item as Map<String, dynamic>;
          
          return NotificationItem(
            id: notification['Id'] ?? '',
            title: notification['Subject'] ?? 'Notifikasi',
            description: notification['Description'] ?? '',
            time: notification['CreateDate'] != null
                ? DateTime.parse(notification['CreateDate'] as String)
                : DateTime.now(),
            isRead: notification['IsOpen'] == true,
          );
        }).toList();

        if (mounted) {
          setState(() {
            if (isRefresh) {
              _notifications = newNotifications;
              _isLoading = false;
            } else {
              _notifications.addAll(newNotifications);
              _isLoadingMore = false;
              _currentPage++;
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isLoadingMore = false;
          });
          _showError('Gagal memuat notifikasi');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
        _showError('Gagal memuat notifikasi: ${e.toString()}');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: neutral10,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: primaryColor,
                    onPressed: () => Navigator.pop(context),
                  ),
                  4.horizontalSpace,
                  Text(
                    'Notifikasi',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    )
                  : _notifications.isEmpty
                      ? _buildEmptyState()
                      : _buildNotificationList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64.sp,
            color: neutral50,
          ),
          16.verticalSpace,
          Text(
            'Belum Ada Notifikasi',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: neutral20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList() {
    return RefreshIndicator(
      color: primaryColor,
      onRefresh: () => _loadNotifications(isRefresh: true),
      child: ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
        itemCount: _notifications.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => 8.verticalSpace,
        itemBuilder: (context, index) {
          // Show loading indicator at the bottom
          if (index == _notifications.length) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Center(
                child: CircularProgressIndicator(color: primaryColor),
              ),
            );
          }
          return _buildNotificationCard(_notifications[index]);
        },
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    final timeFormat = DateFormat('HH.mm');
    final timeString = timeFormat.format(notification.time);

    return GestureDetector(
      onTap: () {
        // Mark as read and navigate to detail
        setState(() {
          final index = _notifications.indexWhere((n) => n.id == notification.id);
          if (index != -1) {
            _notifications[index] = _notifications[index].copyWith(isRead: true);
          }
        });
        _showNotificationDetail(notification);
      },
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: neutral30.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Bell icon
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: primary10,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_active,
                color: primaryColor,
                size: 22.sp,
              ),
            ),
            12.horizontalSpace,

            // Title & description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: neutral90,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  2.verticalSpace,
                  Text(
                    notification.description,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: neutral20,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            8.horizontalSpace,

            // Time & unread dot
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeString,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: neutral20,
                  ),
                ),
                if (!notification.isRead) ...[
                  6.verticalSpace,
                  Container(
                    width: 8.w,
                    height: 8.w,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationDetail(NotificationItem notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.description),
            8.verticalSpace,
            Text(
              DateFormat('dd MMMM yyyy HH:mm', 'id').format(notification.time),
              style: TextStyle(
                fontSize: 12.sp,
                color: neutral20,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}
