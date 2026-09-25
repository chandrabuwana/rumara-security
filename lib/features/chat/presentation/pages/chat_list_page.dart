import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/chat_event.dart';
import '../bloc/chat_state.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/contact.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/security/security_manager.dart';
import '../../../../core/constants/app_constants.dart';
import 'chat_conversation_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchingUsers = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<ChatBloc>().add(const ChatLoadChats());
    // Start periodic refresh every 15 seconds to pick up new messages
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && !_isSearchingUsers) {
        context.read<ChatBloc>().add(const ChatLoadChats());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reload chat list when app comes back to foreground
    if (state == AppLifecycleState.resumed && mounted && !_isSearchingUsers) {
      context.read<ChatBloc>().add(const ChatLoadChats());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Pesan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: BlocConsumer<ChatBloc, ChatState>(
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
        },
        builder: (context, state) {
          return Column(
            children: [
              // Search Bar
              Container(
                padding: EdgeInsets.all(16.w),
                color: Colors.white,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Q Cari',
                    hintStyle: TextStyle(
                      color: neutral50,
                      fontSize: 14.sp,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: neutral50,
                      size: 20.sp,
                    ),
                    filled: true,
                    fillColor: neutral10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                  ),
                  onChanged: (value) {
                    if (value.isEmpty) {
                      setState(() {
                        _isSearchingUsers = false;
                      });
                      // Reload conversations when search is cleared
                      context.read<ChatBloc>().add(const ChatLoadChats());
                    } else {
                      setState(() {
                        _isSearchingUsers = true;
                      });
                      // Search users from API
                      context.read<ChatBloc>().add(ChatLoadUsers(searchQuery: value));
                    }
                  },
                ),
              ),

              // Chat List or User List
              Expanded(
                child: _isSearchingUsers
                    ? _buildUserList(state)
                    : (state.isLoading && state.chats.isEmpty
                        ? Center(
                            child: CircularProgressIndicator(color: primaryColor),
                          )
                        : (state.errorMessage != null && state.chats.isEmpty
                            ? _buildErrorState(state.errorMessage!)
                            : (state.filteredChats.isEmpty
                                ? _buildEmptyState()
                                : ListView.builder(
                                    itemCount: state.filteredChats.length,
                                    itemBuilder: (context, index) {
                                      final chat = state.filteredChats[index];
                                      return _buildChatItem(chat);
                                    },
                                  )))),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Empty state illustration
          Container(
            width: 120.w,
            height: 120.h,
            decoration: BoxDecoration(
              color: neutral30,
              borderRadius: BorderRadius.circular(60.r),
            ),
            child: Icon(
              Icons.mail_outline,
              size: 60.sp,
              color: neutral50,
            ),
          ),
          24.verticalSpace,
          Text(
            'Belum ada pesan',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: neutral70,
            ),
          ),
          8.verticalSpace,
          Text(
            'Mulai percakapan dengan rekan kerja Anda',
            style: TextStyle(
              fontSize: 14.sp,
              color: neutral50,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String errorMessage) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error illustration
            Container(
              width: 120.w,
              height: 120.h,
              decoration: BoxDecoration(
                color: errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(60.r),
              ),
              child: Icon(
                Icons.error_outline,
                size: 60.sp,
                color: errorColor,
              ),
            ),
            24.verticalSpace,
            Text(
              'Gagal memuat pesan',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: neutral70,
              ),
            ),
            8.verticalSpace,
            Text(
              errorMessage,
              style: TextStyle(
                fontSize: 14.sp,
                color: neutral50,
              ),
              textAlign: TextAlign.center,
            ),
            24.verticalSpace,
            ElevatedButton.icon(
              onPressed: () {
                context.read<ChatBloc>().add(const ChatLoadChats());
              },
              icon: Icon(Icons.refresh, size: 20.sp),
              label: Text(
                'Coba Lagi',
                style: TextStyle(fontSize: 14.sp),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: 24.w,
                  vertical: 12.h,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatItem(Chat chat) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade300,
            width: 0.5,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Get ChatBloc before creating new route context
            final chatBloc = context.read<ChatBloc>();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BlocProvider.value(
                  value: chatBloc,
                  child: ChatConversationPage(chat: chat),
                ),
              ),
            ).then((_) {
              // Reload chat list when returning from conversation
              if (mounted) {
                context.read<ChatBloc>().add(const ChatLoadChats());
              }
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: [
                // Profile Picture with Online Indicator
                Stack(
                  children: [
                    _buildProfileAvatar(chat),
                    // Online indicator for direct chat
                    if (chat.type == ChatType.direct && chat.isOnline == true)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14.w,
                          height: 14.h,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                12.horizontalSpace,

                // Chat Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and Time
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              chat.name,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: neutral90,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (chat.lastMessageTimestamp != null)
                            Text(
                              _formatTime(chat.lastMessageTimestamp!),
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: neutral50,
                              ),
                            ),
                        ],
                      ),
                      4.verticalSpace,

                      // Last Message
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.lastMessageContent ?? 'Tidak ada pesan',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: neutral70,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (chat.unreadCount > 0) ...[
                            8.horizontalSpace,
                            Container(
                              constraints: BoxConstraints(
                                minWidth: 20.w,
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: chat.unreadCount > 99 ? 6.w : 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Center(
                              child: Text(
                                  chat.unreadCount > 99 ? '99+' : chat.unreadCount.toString(),
                                style: TextStyle(
                                    fontSize: 11.sp,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ],
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

  /// Build profile avatar with image or fallback icon
  Widget _buildProfileAvatar(Chat chat) {
    final imageUrl = _getProfileImageUrl(chat);
    
    if (imageUrl != null && imageUrl.isNotEmpty) {
      // Check if it's an S3 URL (public, no auth needed)
      final isS3Url = imageUrl.contains('s3.ap-southeast-1.amazonaws.com') ||
                      imageUrl.contains('s3.amazonaws.com') ||
                      imageUrl.contains('amazonaws.com');
      
      if (isS3Url) {
        // S3 URL is public, use NetworkImage directly
        return CircleAvatar(
          radius: 24.r,
          backgroundColor: primary10,
          backgroundImage: NetworkImage(imageUrl),
          onBackgroundImageError: (exception, stackTrace) {
            // If image fails to load, show icon instead
            debugPrint('⚠️ Failed to load S3 profile image: $imageUrl');
          },
          child: null,
        );
      } else {
        // Non-S3 URL, might need auth header
        return FutureBuilder<Uint8List?>(
          future: _loadImageWithAuth(imageUrl),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return CircleAvatar(
                radius: 24.r,
                backgroundColor: primary10,
                child: SizedBox(
                  width: 16.w,
                  height: 16.h,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primaryColor,
                  ),
                ),
              );
            }

            if (snapshot.hasError || snapshot.data == null) {
              // If image fails to load, show icon instead
              return CircleAvatar(
                radius: 24.r,
                backgroundColor: primary10,
                child: Icon(
                  chat.type == ChatType.group
                      ? Icons.group
                      : Icons.person,
                  color: primaryColor,
                  size: 24.sp,
                ),
              );
            }

            return CircleAvatar(
              radius: 24.r,
              backgroundColor: primary10,
              backgroundImage: MemoryImage(snapshot.data!),
              child: null,
            );
          },
        );
      }
    }
    
    return CircleAvatar(
      radius: 24.r,
      backgroundColor: primary10,
      child: Icon(
        chat.type == ChatType.group
            ? Icons.group
            : Icons.person,
        color: primaryColor,
        size: 24.sp,
      ),
    );
  }

  /// Load image with authorization header using Dio (for non-S3 URLs)
  Future<Uint8List?> _loadImageWithAuth(String imageUrl) async {
    try {
      // Validate URL before attempting to load
      if (imageUrl.isEmpty || !imageUrl.startsWith('http')) {
        debugPrint('⚠️ Invalid image URL for auth load: $imageUrl');
        return null;
      }

      final token = await SecurityManager.readSecurely(AppConstants.tokenKey);
      
      final dio = Dio();
      final response = await dio.get<Uint8List>(
        imageUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
          validateStatus: (status) {
            // Don't throw exception for 404/403, return null instead
            return status != null && status < 500;
          },
        ),
      );

      // Check if response is successful
      if (response.statusCode == 200 && response.data != null) {
        return response.data;
      } else {
        debugPrint('⚠️ Profile image load failed with status ${response.statusCode}: $imageUrl');
        return null;
      }
    } on DioException catch (e) {
      debugPrint('❌ Error loading profile image: $e');
      return null;
    } catch (e) {
      debugPrint('❌ Unexpected error loading profile image: $e');
      return null;
    }
  }

  /// Get profile image URL from chat (use OpponentFoto from response)
  String? _getProfileImageUrl(Chat chat) {
    // Use OpponentFoto directly from conversation list response
    // This is the photo of the opponent in the conversation
    return chat.opponentFoto;
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return DateFormat('dd/MM/yyyy').format(timestamp);
    } else if (difference.inHours > 0) {
      return DateFormat('HH:mm').format(timestamp);
    } else {
      return DateFormat('HH:mm').format(timestamp);
    }
  }

  Widget _buildUserList(ChatState state) {
    if (state.isLoadingUsers) {
      return Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    if (state.users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 60.sp,
              color: neutral50,
            ),
            16.verticalSpace,
            Text(
              'Tidak ada user ditemukan',
              style: TextStyle(
                fontSize: 16.sp,
                color: neutral70,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: state.users.length,
      itemBuilder: (context, index) {
        final user = state.users[index];
        return _buildUserItem(user);
      },
    );
  }

  Widget _buildUserItem(Contact user) {
    return Container(
      color: Colors.white,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            // Create conversation when user is clicked
            final chatBloc = context.read<ChatBloc>();
            chatBloc.add(ChatCreateConversation(memberUserIds: [user.id]));
            
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
                    name: user.name,
                    type: ChatType.direct,
                    participantIds: [user.id],
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
                      value: chatBloc,
                      child: ChatConversationPage(chat: newChat),
                    ),
                  ),
                ).then((_) {
                  // Reload chat list when returning from conversation
                  if (mounted) {
                    context.read<ChatBloc>().add(const ChatLoadChats());
                  }
                });
                
                // Clear search
                _searchController.clear();
                setState(() {
                  _isSearchingUsers = false;
                });
              }
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: [
                // Profile Picture
                CircleAvatar(
                  radius: 24.r,
                  backgroundColor: primary10,
                  backgroundImage: user.profileImageUrl != null
                      ? NetworkImage(user.profileImageUrl!)
                      : null,
                  child: user.profileImageUrl == null
                      ? Icon(
                          Icons.person,
                          color: primaryColor,
                          size: 24.sp,
                        )
                      : null,
                ),
                12.horizontalSpace,

                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: neutral90,
                        ),
                      ),
                      if (user.position != null) ...[
                        4.verticalSpace,
                        Text(
                          user.position!,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: neutral70,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Arrow icon
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16.sp,
                  color: neutral50,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
