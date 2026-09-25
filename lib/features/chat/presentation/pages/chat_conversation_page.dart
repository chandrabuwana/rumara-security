import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:photo_view/photo_view.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:gal/gal.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/chat_event.dart';
import '../bloc/chat_state.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/message.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/security/security_manager.dart';

class ChatConversationPage extends StatefulWidget {
  final Chat chat;

  const ChatConversationPage({
    super.key,
    required this.chat,
  });

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  String? _currentUserId;
  late final Future<void> _loadCurrentUserIdFuture;
  final Map<String, Uint8List?> _imageCache = {}; // Cache untuk image bytes
  ChatBloc? _chatBloc; // Store ChatBloc reference to use in dispose
  final Map<String, File> _pendingLocalFiles = {}; // Map untuk menyimpan local file yang baru dikirim (key: timestamp_content)
  String? _lastShownErrorMessage; // Track last shown error to prevent duplicates

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save ChatBloc reference when dependencies are available
    _chatBloc ??= context.read<ChatBloc>();
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentUserIdFuture = _loadCurrentUserId();
    
    // Use WidgetsBinding to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _chatBloc ??= context.read<ChatBloc>();
        _chatBloc?.add(ChatLoadMessages(widget.chat.id));
        _chatBloc?.add(ChatMarkAsRead(widget.chat.id));
        
        // Join conversation via SignalR after loading user ID
        _loadCurrentUserIdFuture.then((_) {
          if (_currentUserId != null && _chatBloc != null && mounted) {
            _chatBloc!.add(
                  ChatJoinConversation(
                    conversationId: widget.chat.id,
                    userId: _currentUserId!,
                  ),
                );
          }
        });
      }
    });
  }

  Future<void> _loadCurrentUserId() async {
    final userId = await SecurityManager.readSecurely(AppConstants.userIdKey);
    setState(() {
      _currentUserId = userId;
    });
  }

  @override
  void dispose() {
    // Leave conversation via SignalR before disposing
    // Use stored ChatBloc reference instead of context.read to avoid deactivated widget error
    if (_currentUserId != null && _chatBloc != null && mounted) {
      _chatBloc!.add(
            ChatLeaveConversation(
              conversationId: widget.chat.id,
              userId: _currentUserId!,
            ),
          );
    }
    
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: neutral10,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBarWidget(),
      body: BlocConsumer<ChatBloc, ChatState>(
        listener: (context, state) {
          // Handle error message - show snackbar and clear error
          // Only show if error message is different from last shown error
          if (state.errorMessage != null && 
              state.errorMessage!.isNotEmpty &&
              state.errorMessage != _lastShownErrorMessage) {
            _lastShownErrorMessage = state.errorMessage;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
            // Clear error message after showing
            _chatBloc?.add(ChatClearError());
          }
          
          // Reset last shown error if error is cleared
          if (state.errorMessage == null || state.errorMessage!.isEmpty) {
            _lastShownErrorMessage = null;
          }
          
          // Auto scroll to bottom when messages are loaded or new message is added
          if (state.messages.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              } else {
                // If scroll controller doesn't have clients yet, try again after a short delay
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (_scrollController.hasClients && mounted) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });
              }
            });
          }
          
          // Scroll to bottom when messages finish loading (first time load)
          if (!state.isLoadingMessages && state.messages.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Future.delayed(const Duration(milliseconds: 200), () {
                if (_scrollController.hasClients && mounted) {
                  _scrollController.jumpTo(
                    _scrollController.position.maxScrollExtent,
                  );
                }
              });
            });
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              // Messages List
              Expanded(
                child: state.isLoadingMessages
                    ? Center(
                        child: CircularProgressIndicator(color: primaryColor),
                      )
                    : state.messages.isEmpty
                        ? _buildEmptyMessages()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.all(16.w),
                            itemCount: state.messages.length,
                            reverse: false, // Keep normal order (oldest at top, newest at bottom)
                            itemBuilder: (context, index) {
                              final message = state.messages[index];
                              final isLastMessage =
                                  index == state.messages.length - 1;
                              final showDateSeparator = index == 0 ||
                                  !_isSameDay(
                                    state.messages[index - 1].timestamp,
                                    message.timestamp,
                                  );

                              return Column(
                                children: [
                                  if (showDateSeparator)
                                    _buildDateSeparator(message.timestamp),
                                  _buildMessageBubble(message, isLastMessage),
                                ],
                              );
                            },
                          ),
              ),

              // Message Input
              _buildMessageInput(),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBarWidget() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: BlocBuilder<ChatBloc, ChatState>(
        builder: (context, state) {
          // Get Header information from the most recent message
          Message? lastMessage;
          if (state.messages.isNotEmpty) {
            // Find the most recent message (messages are sorted by timestamp)
            lastMessage = state.messages.last;
          }
          
          // Get opponent info from Header (for direct chat) or from Chat entity
          final opponentFoto = lastMessage?.opponentFoto ??
                              widget.chat.opponentFoto ??
                              widget.chat.profileImageUrl;
          final isOnline = lastMessage?.isOnline ?? widget.chat.isOnline ?? false;
          final lastSeen = lastMessage?.lastSeen;
          final opponentName = lastMessage?.fullname ?? widget.chat.name;

          // Debug logging to track name fallback
          print('🔍 Chat Header Debug:');
          print('  - widget.chat.name: "${widget.chat.name}"');
          print('  - lastMessage: ${lastMessage != null ? "exists" : "null"}');
          print('  - lastMessage?.fullname: ${lastMessage?.fullname ?? "null"}');
          print('  - opponentName (final): "$opponentName"');
          
          // Format last seen text
          String statusText = widget.chat.type == ChatType.group
              ? 'Grup'
              : _getLastSeenText(isOnline, lastSeen);
          
          return AppBar(
            backgroundColor: primaryColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 18.r,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      backgroundImage: opponentFoto != null
                          ? NetworkImage(opponentFoto)
                          : null,
                      child: opponentFoto == null
                          ? Icon(
                              widget.chat.type == ChatType.group
                                  ? Icons.group
                                  : Icons.person,
                              color: Colors.white,
                              size: 20.sp,
                            )
                          : null,
                    ),
                    // Online indicator for direct chat
                    if (widget.chat.type == ChatType.direct && isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12.w,
                          height: 12.h,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                12.horizontalSpace,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opponentName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  String _getLastSeenText(bool isOnline, DateTime? lastSeen) {
    if (isOnline) {
      return 'Online';
    }
    
    if (lastSeen == null) {
      return 'Tidak aktif';
    }
    
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    
    if (difference.inMinutes < 1) {
      return 'Baru saja aktif';
    } else if (difference.inMinutes < 60) {
      return 'Aktif ${difference.inMinutes} menit yang lalu';
    } else if (difference.inHours < 24) {
      return 'Aktif ${difference.inHours} jam yang lalu';
    } else if (difference.inDays < 7) {
      return 'Aktif ${difference.inDays} hari yang lalu';
    } else {
      return DateFormat('dd/MM/yyyy').format(lastSeen);
    }
  }

  Widget _buildEmptyMessages() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64.sp,
            color: neutral50,
          ),
          16.verticalSpace,
          Text(
            'Belum ada pesan',
            style: TextStyle(
              fontSize: 16.sp,
              color: neutral70,
            ),
          ),
          8.verticalSpace,
          Text(
            'Mulai percakapan dengan mengirim pesan',
            style: TextStyle(
              fontSize: 14.sp,
              color: neutral50,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime timestamp) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16.h),
      child: Text(
        DateFormat('dd/MM/yyyy').format(timestamp),
        style: TextStyle(
          fontSize: 12.sp,
          color: neutral50,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isLastMessage) {
    final isMe = _currentUserId != null && message.senderId == _currentUserId;
    
    // Use Header information for avatar
    // For current user: use SelfFoto, for opponent: use OpponentFoto
    final avatarUrl = isMe 
        ? (message.selfFoto ?? message.senderProfileImageUrl)
        : (message.opponentFoto ?? message.senderProfileImageUrl);

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16.r,
              backgroundColor: primary10,
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Icon(
                      Icons.person,
                      color: primaryColor,
                      size: 16.sp,
                    )
                  : null,
            ),
            8.horizontalSpace,
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 8.h,
              ),
              decoration: BoxDecoration(
                color: isMe ? primaryColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  topRight: Radius.circular(16.r),
                  bottomLeft: Radius.circular(isMe ? 16.r : 4.r),
                  bottomRight: Radius.circular(isMe ? 4.r : 16.r),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  if (!isMe) 4.verticalSpace,
                  
                  // Show attachment image if available
                  // Check if message has image (either from URL or local file)
                  if (((message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty) || _hasLocalFile(message)) && 
                      (message.type == MessageType.image || _hasLocalFile(message)))
                    GestureDetector(
                      onTap: () => _showImagePreview(message),
                      child: Container(
                        margin: EdgeInsets.only(bottom: 8.h),
                        constraints: BoxConstraints(
                          maxWidth: 200.w,
                          maxHeight: 200.h,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: isMe 
                                ? Colors.white.withValues(alpha: 0.3)
                                : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.r),
                          child: _buildImageWidgetForMessage(message),
                        ),
                      ),
                    ),
                  
                  // Show text content if available (with clickable links)
                  if (message.content.isNotEmpty)
                    _buildLinkifiedText(
                      message.content,
                      isMe: isMe,
                    ),
                  
                  // Show file attachment info if not image
                  if (message.attachmentUrl != null && 
                      message.type != MessageType.image)
                    Container(
                      padding: EdgeInsets.all(8.w),
                      margin: EdgeInsets.only(bottom: 4.h),
                      decoration: BoxDecoration(
                        color: isMe 
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.attach_file,
                            size: 16.sp,
                            color: isMe ? Colors.white : neutral70,
                          ),
                          8.horizontalSpace,
                          Expanded(
                            child: Text(
                              message.attachmentUrl!.split('/').last,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: isMe ? Colors.white : neutral70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  4.verticalSpace,
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(message.timestamp),
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.7)
                              : neutral50,
                        ),
                      ),
                      // Show double check mark if sentAt is not null (message was sent)
                      if (isMe && message.sentAt != null) ...[
                        4.horizontalSpace,
                        Icon(
                          Icons.done_all,
                          size: 14.sp,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            8.horizontalSpace,
            CircleAvatar(
              radius: 16.r,
              backgroundColor: primary10,
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Icon(
                      Icons.person,
                      color: primaryColor,
                      size: 16.sp,
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    // Use SafeArea bottom padding for devices with bottom notch/bar
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Container(
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: 8.h,
        bottom: bottomPadding > 0 ? bottomPadding : 8.h,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selected Image Preview
          if (_selectedImage != null)
            Container(
              margin: EdgeInsets.only(bottom: 8.h),
              height: 100.h,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: Image.file(
                      _selectedImage!,
                      width: 100.w,
                      height: 100.h,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedImage = null;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(4.w),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16.sp,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Input Row
          Row(
            children: [
              // Attachment Button (Gallery)
              IconButton(
                icon: Icon(
                  Icons.attach_file,
                  color: neutral50,
                  size: 24.sp,
                ),
                onPressed: _pickImageFromGallery,
              ),

              // Camera Button
              IconButton(
                icon: Icon(
                  Icons.camera_alt,
                  color: neutral50,
                  size: 24.sp,
                ),
                onPressed: _pickImageFromCamera,
              ),

              // Message Input Field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: neutral10,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ketik pesan disini',
                      hintStyle: TextStyle(
                        color: neutral50,
                        fontSize: 14.sp,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                    ),
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                  ),
                ),
              ),

              // Send Button
              IconButton(
                icon: Icon(
                  Icons.send,
                  color: primaryColor,
                  size: 24.sp,
                ),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih gambar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final cameraPermission = await Permission.camera.request();
      if (cameraPermission != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Akses kamera ditolak'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isNotEmpty || _selectedImage != null) {
      // Generate temporary key untuk mapping local file dengan message
      // Gunakan timestamp + content sebagai key untuk matching yang lebih akurat
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempKey = '${timestamp}_${content.isEmpty ? "image" : content.substring(0, content.length > 20 ? 20 : content.length)}';
      
      // Simpan local file jika ada attachment
      File? imageFileToKeep;
      if (_selectedImage != null) {
        imageFileToKeep = _selectedImage;
        _pendingLocalFiles[tempKey] = _selectedImage!;
        debugPrint('💾 Saved local file for pending message: $tempKey');
      }
      
      // Determine message type
      final messageType = _selectedImage != null ? MessageType.image : MessageType.text;
      
      _chatBloc?.add(
            ChatSendMessage(
              chatId: widget.chat.id,
              content: content,
              type: messageType,
              attachmentFile: _selectedImage,
            ),
          );
      
      // Add temporary message to show immediately with local file
      if (imageFileToKeep != null && _currentUserId != null) {
        final tempMessage = Message(
          id: 'temp_$timestamp',
          chatId: widget.chat.id,
          senderId: _currentUserId!,
          senderName: 'Saya',
          content: content,
          type: MessageType.image,
          timestamp: DateTime.now(),
          status: MessageStatus.sending,
          attachmentUrl: null, // No URL yet, will use local file
          attachmentType: 'image/jpeg',
        );
        
        // Add to bloc state immediately (optimistic update)
        // Note: This might need to be handled in bloc, but for now we'll rely on local file display
        debugPrint('📝 Created temp message with local file: ${tempMessage.id}');
      }
      
      _messageController.clear();
      setState(() {
        _selectedImage = null;
      });
    }
  }

  /// Build text widget with clickable links
  Widget _buildLinkifiedText(String text, {required bool isMe}) {
    // Regex to detect URLs (http, https, www)
    final urlRegex = RegExp(
      r'(https?://[^\s]+)|(www\.[^\s]+)',
      caseSensitive: false,
    );

    final matches = urlRegex.allMatches(text).toList();

    // If no links found, return plain text
    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 14.sp,
          color: isMe ? Colors.white : neutral90,
        ),
      );
    }

    // Build rich text with clickable links
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Add plain text before the link
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(
            fontSize: 14.sp,
            color: isMe ? Colors.white : neutral90,
          ),
        ));
      }

      // Add clickable link
      final linkText = match.group(0)!;
      spans.add(TextSpan(
        text: linkText,
        style: TextStyle(
          fontSize: 14.sp,
          color: isMe ? Colors.white : primaryColor,
          decoration: TextDecoration.underline,
          decorationColor: isMe ? Colors.white : primaryColor,
          fontWeight: FontWeight.w500,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            _launchUrl(linkText);
          },
      ));

      lastEnd = match.end;
    }

    // Add remaining plain text after last link
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(
          fontSize: 14.sp,
          color: isMe ? Colors.white : neutral90,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  /// Launch URL in external browser
  Future<void> _launchUrl(String url) async {
    // Add https:// if URL starts with www.
    String finalUrl = url;
    if (url.startsWith('www.')) {
      finalUrl = 'https://$url';
    }

    try {
      final uri = Uri.parse(finalUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('⚠️ Cannot launch URL: $finalUrl');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tidak dapat membuka link: $finalUrl'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error launching URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka link: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Check if message has local file (pending upload)
  bool _hasLocalFile(Message message) {
    // Check if message is from current user
    final isFromMe = _currentUserId != null && message.senderId == _currentUserId;
    if (!isFromMe) return false;
    
    // If message already has attachmentUrl from server, don't use local file
    if (message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty) {
      return false;
    }
    
    // Check if message type is image OR if message is temp message (id starts with 'temp_')
    // Temp messages are optimistic updates that should use local file
    final isImageType = message.type == MessageType.image;
    final isTempMessage = message.id.startsWith('temp_');
    final hasPendingFiles = _pendingLocalFiles.isNotEmpty;
    
    if (!isImageType && !isTempMessage && !hasPendingFiles) return false;
    
    // Find local file by matching timestamp and content
    // Use larger time window for temp messages (60 seconds) vs real messages (30 seconds)
    final messageTime = message.timestamp.millisecondsSinceEpoch;
    final messageContent = message.content.isEmpty ? "image" : message.content.substring(0, message.content.length > 20 ? 20 : message.content.length);
    final timeWindow = isTempMessage ? 60000 : 30000; // 60s for temp, 30s for real
    
    // For temp messages, if we have any pending files, consider it a match
    // (we'll use most recent file in _getLocalFile)
    if (isTempMessage && _pendingLocalFiles.isNotEmpty) {
      debugPrint('✅ Temp message found, will use most recent local file');
      return true;
    }
    
    for (final entry in _pendingLocalFiles.entries) {
      final parts = entry.key.split('_');
      if (parts.length >= 2) {
        final keyTime = int.tryParse(parts[0]) ?? 0;
        final keyContent = parts.sublist(1).join('_');
        
        // Match if timestamp is within window and content matches
        // For temp messages, be more lenient with content matching
        final contentMatches = keyContent == messageContent || 
                              (isTempMessage && (messageContent.isEmpty || messageContent == "image" || keyContent == "image"));
        
        if ((messageTime - keyTime).abs() < timeWindow && contentMatches) {
          debugPrint('✅ Found matching local file for message: ${message.id}, timeDiff=${(messageTime - keyTime).abs()}ms');
          return true;
        }
      } else {
        // Fallback: match by timestamp only (for old format)
        final keyTime = int.tryParse(entry.key) ?? 0;
        if ((messageTime - keyTime).abs() < timeWindow) {
          debugPrint('✅ Found matching local file by timestamp for message: ${message.id}');
          return true;
        }
      }
    }
    
    debugPrint('⚠️ No matching local file for message: ${message.id}, content: ${message.content}, type: ${message.type}, isTemp: $isTempMessage');
    debugPrint('   Message time: $messageTime, Pending files: ${_pendingLocalFiles.keys.toList()}');
    return false;
  }

  /// Get local file for message
  File? _getLocalFile(Message message) {
    if (!_hasLocalFile(message)) return null;
    
    final messageTime = message.timestamp.millisecondsSinceEpoch;
    final messageContent = message.content.isEmpty ? "image" : message.content.substring(0, message.content.length > 20 ? 20 : message.content.length);
    
    // Try to find matching local file by timestamp and content
    // For temp messages (id starts with 'temp_'), match more flexibly
    final isTempMessage = message.id.startsWith('temp_');
    final timeWindow = isTempMessage ? 60000 : 30000; // 60 seconds for temp, 30 for real
    
    // For temp messages or messages with empty content, try to match any recent local file
    // Priority: Use most recent local file for temp messages
    if (isTempMessage || messageContent.isEmpty || messageContent == "image") {
      // Find the most recent local file (highest timestamp that's before or close to message time)
      String? mostRecentKey;
      int mostRecentTime = 0;
      
      for (final entry in _pendingLocalFiles.entries) {
        final parts = entry.key.split('_');
        if (parts.isNotEmpty) {
          final keyTime = int.tryParse(parts[0]) ?? 0;
          final timeDiff = (messageTime - keyTime).abs();
          
          // For temp messages, prefer files that are close in time (within window)
          // and are the most recent (highest timestamp)
          if (timeDiff < timeWindow) {
            // Prefer files that are before message time (sent before message created)
            // or very close to message time
            if (keyTime <= messageTime || timeDiff < 5000) {
              if (keyTime > mostRecentTime) {
                mostRecentTime = keyTime;
                mostRecentKey = entry.key;
              }
            }
          }
        }
      }
      
      if (mostRecentKey != null) {
        debugPrint('✅ Matched most recent local file for temp/empty message: $mostRecentKey');
        debugPrint('   Message time: $messageTime, Key time: $mostRecentTime, Diff: ${(messageTime - mostRecentTime).abs()}ms');
        return _pendingLocalFiles[mostRecentKey];
      } else {
        debugPrint('⚠️ No recent local file found within time window for temp message');
        debugPrint('   Message time: $messageTime, Time window: $timeWindow');
        debugPrint('   Available files: ${_pendingLocalFiles.keys.toList()}');
      }
    }
    
    // Try exact matching by timestamp and content
    for (final entry in _pendingLocalFiles.entries) {
      final parts = entry.key.split('_');
      if (parts.length >= 2) {
        final keyTime = int.tryParse(parts[0]) ?? 0;
        final keyContent = parts.sublist(1).join('_');
        
        // Match if timestamp is within window and content matches
        // For temp messages, be more lenient with content matching
        final contentMatches = keyContent == messageContent || 
                              (isTempMessage && (messageContent.isEmpty || messageContent == "image" || keyContent == "image"));
        
        if ((messageTime - keyTime).abs() < timeWindow && contentMatches) {
          debugPrint('✅ Matched local file: key=$entry.key, messageTime=$messageTime, keyTime=$keyTime, diff=${(messageTime - keyTime).abs()}ms');
          return entry.value;
        }
      } else {
        // Fallback: match by timestamp only (for old format)
        final keyTime = int.tryParse(entry.key) ?? 0;
        if ((messageTime - keyTime).abs() < timeWindow) {
          debugPrint('✅ Matched local file by timestamp only: key=$entry.key');
          return entry.value;
        }
      }
    }
    
    debugPrint('⚠️ No matching local file found for message: id=${message.id}, time=$messageTime, content=$messageContent');
    debugPrint('   Pending files: ${_pendingLocalFiles.keys.toList()}');
    return null;
  }

  /// Build image widget for message - check local file first, then URL
  Widget _buildImageWidgetForMessage(Message message) {
    // Cleanup old pending files (older than 30 seconds)
    _cleanupOldPendingFiles();
    
    debugPrint('🖼️ Building image widget for message: ${message.id}');
    debugPrint('   Type: ${message.type}, hasLocalFile: ${_hasLocalFile(message)}, attachmentUrl: ${message.attachmentUrl}');
    debugPrint('   Pending files count: ${_pendingLocalFiles.length}');
    
    // Check if we have local file for this message
    final localFile = _getLocalFile(message);
    if (localFile != null) {
      debugPrint('📸 Using local file for message: ${message.id}, path: ${localFile.path}');
      return Image.file(
        localFile,
        fit: BoxFit.cover,
        width: 200.w,
        height: 200.h,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ Error loading local file: $error');
          return Container(
            width: 200.w,
            height: 200.h,
            color: Colors.grey.shade200,
            child: Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 48.sp,
            ),
          );
        },
      );
    }
    
    // Use URL from server, but keep local file as fallback if server fails
    if (message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty) {
      debugPrint('🌐 Using server URL for message: ${message.id}, URL: ${message.attachmentUrl}');
      
      // Build widget with server URL, but with fallback to local file if it fails
      return _buildImageWidgetWithLocalFallback(message.attachmentUrl!, message);
    }
    
    // Fallback - show broken image
    debugPrint('⚠️ No local file or URL for message: ${message.id}');
    return Container(
      width: 200.w,
      height: 200.h,
      color: Colors.grey.shade200,
      child: Icon(
        Icons.broken_image,
        color: Colors.grey,
        size: 48.sp,
      ),
    );
  }

  /// Cleanup old pending files (older than 30 seconds)
  void _cleanupOldPendingFiles() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final keysToRemove = <String>[];
    
    for (final entry in _pendingLocalFiles.entries) {
      final parts = entry.key.split('_');
      if (parts.isNotEmpty) {
        final keyTime = int.tryParse(parts[0]) ?? 0;
        // Remove if older than 30 seconds
        if ((now - keyTime) > 30000) {
          keysToRemove.add(entry.key);
        }
      }
    }
    
    for (final key in keysToRemove) {
      _pendingLocalFiles.remove(key);
      debugPrint('🗑️ Cleaned up old pending file: $key');
    }
  }

  /// Remove pending file when server URL is available
  void _removePendingFile(Message message) {
    final messageTime = message.timestamp.millisecondsSinceEpoch;
    final messageContent = message.content.isEmpty ? "image" : message.content.substring(0, message.content.length > 20 ? 20 : message.content.length);
    final keysToRemove = <String>[];
    
    for (final entry in _pendingLocalFiles.entries) {
      final parts = entry.key.split('_');
      if (parts.length >= 2) {
        final keyTime = int.tryParse(parts[0]) ?? 0;
        final keyContent = parts.sublist(1).join('_');
        
        // Match if timestamp is within 10 seconds and content matches
        if ((messageTime - keyTime).abs() < 10000 && keyContent == messageContent) {
          keysToRemove.add(entry.key);
        }
      }
    }
    
    for (final key in keysToRemove) {
      _pendingLocalFiles.remove(key);
      debugPrint('🗑️ Removed pending local file: $key');
    }
  }

  /// Build image widget with local file fallback if server URL fails
  Widget _buildImageWidgetWithLocalFallback(String imageUrl, Message message) {
    // Get local file as fallback (don't check attachmentUrl)
    final localFile = _getLocalFileIgnoringUrl(message);
    
    // Check if it's an S3 URL
    final isS3Url = imageUrl.contains('s3.ap-southeast-1.amazonaws.com') ||
                    imageUrl.contains('s3.amazonaws.com') ||
                    imageUrl.contains('amazonaws.com');
    
    if (isS3Url) {
      // S3 URL - try with fallback
      return _buildS3ImageWithFallback(imageUrl, localFile);
    }
    
    // API URL - use authorization header with fallback
    return _buildNetworkImageWithAuthAndFallback(imageUrl, localFile);
  }

  /// Build network image with auth and local file fallback
  Widget _buildNetworkImageWithAuthAndFallback(String imageUrl, File? localFile) {
    // Check cache first
    if (_imageCache.containsKey(imageUrl) && _imageCache[imageUrl] != null) {
      return Image.memory(
        _imageCache[imageUrl]!,
        fit: BoxFit.cover,
        width: 200.w,
        height: 200.h,
      );
    }

    // Load image with authorization
    return FutureBuilder<Uint8List?>(
      future: _loadImageWithAuth(imageUrl, fallbackToApi: false, isS3Fallback: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // While loading, show local file if available
          if (localFile != null) {
            debugPrint('⏳ Loading API URL, showing local file meanwhile');
            return Image.file(
              localFile,
              fit: BoxFit.cover,
              width: 200.w,
              height: 200.h,
            );
          }
          return Container(
            width: 200.w,
            height: 200.h,
            color: Colors.grey.shade200,
            child: Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          // If API fails, use local file as fallback
          if (localFile != null) {
            debugPrint('⚠️ API URL failed, using local file as fallback');
            return Image.file(
              localFile,
              fit: BoxFit.cover,
              width: 200.w,
              height: 200.h,
            );
          }
          return Container(
            width: 200.w,
            height: 200.h,
            color: Colors.grey.shade200,
            child: Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 48.sp,
            ),
          );
        }

        // Cache the image
        _imageCache[imageUrl] = snapshot.data;

        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          width: 200.w,
          height: 200.h,
        );
      },
    );
  }

  /// Get local file ignoring attachmentUrl (for fallback)
  File? _getLocalFileIgnoringUrl(Message message) {
    final isFromMe = _currentUserId != null && message.senderId == _currentUserId;
    if (!isFromMe) return null;
    
    final isTempMessage = message.id.startsWith('temp_');
    final messageTime = message.timestamp.millisecondsSinceEpoch;
    final messageContent = message.content.isEmpty ? "image" : message.content.substring(0, message.content.length > 20 ? 20 : message.content.length);
    final timeWindow = isTempMessage ? 60000 : 30000;
    
    // For temp messages or empty content, use most recent file
    if (isTempMessage || messageContent.isEmpty || messageContent == "image") {
      String? mostRecentKey;
      int mostRecentTime = 0;
      
      for (final entry in _pendingLocalFiles.entries) {
        final parts = entry.key.split('_');
        if (parts.isNotEmpty) {
          final keyTime = int.tryParse(parts[0]) ?? 0;
          final timeDiff = (messageTime - keyTime).abs();
          
          if (timeDiff < timeWindow) {
            if (keyTime <= messageTime || timeDiff < 5000) {
              if (keyTime > mostRecentTime) {
                mostRecentTime = keyTime;
                mostRecentKey = entry.key;
              }
            }
          }
        }
      }
      
      if (mostRecentKey != null) {
        debugPrint('✅ Found local file for fallback: $mostRecentKey');
        return _pendingLocalFiles[mostRecentKey];
      }
    }
    
    // Try exact matching
    for (final entry in _pendingLocalFiles.entries) {
      final parts = entry.key.split('_');
      if (parts.length >= 2) {
        final keyTime = int.tryParse(parts[0]) ?? 0;
        final keyContent = parts.sublist(1).join('_');
        
        if ((messageTime - keyTime).abs() < timeWindow && keyContent == messageContent) {
          return entry.value;
        }
      }
    }
    
    return null;
  }

  /// Build image widget - use direct Image.network for S3 URLs, auth header for API URLs
  Widget _buildImageWidget(String imageUrl) {
    // Validate URL first
    if (imageUrl.isEmpty || !imageUrl.startsWith('http')) {
      debugPrint('⚠️ Invalid image URL: $imageUrl');
      return Container(
        width: 200.w,
        height: 200.h,
        color: Colors.grey.shade200,
        child: Icon(
          Icons.broken_image,
          color: Colors.grey,
          size: 48.sp,
        ),
      );
    }

    // Check if it's an S3 URL
    final isS3Url = imageUrl.contains('s3.ap-southeast-1.amazonaws.com') ||
                    imageUrl.contains('s3.amazonaws.com') ||
                    imageUrl.contains('amazonaws.com');
    
    if (isS3Url) {
      // S3 URL - try with authorization first, if fails fallback to API URL
      // Since S3 might not be public, we'll use auth-based loading
      debugPrint('🖼️ Loading S3 image with fallback: $imageUrl');
      return _buildS3ImageWithFallback(imageUrl, null);
    }
    
    // API URL - use authorization header
    debugPrint('🖼️ Loading API image with auth: $imageUrl');
    return _buildNetworkImageWithAuth(imageUrl);
  }

  /// Build network image with authorization header
  Widget _buildNetworkImageWithAuth(String imageUrl, {bool fallbackToApi = false, bool isS3Fallback = false}) {
    // Check cache first
    if (_imageCache.containsKey(imageUrl) && _imageCache[imageUrl] != null) {
      return Image.memory(
        _imageCache[imageUrl]!,
        fit: BoxFit.cover,
        width: 200.w,
        height: 200.h,
      );
    }

    // Load image with authorization
    return FutureBuilder<Uint8List?>(
      future: _loadImageWithAuth(imageUrl, fallbackToApi: fallbackToApi, isS3Fallback: isS3Fallback),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 200.w,
            height: 200.h,
            color: Colors.grey.shade200,
            child: Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Container(
            width: 200.w,
            height: 200.h,
            color: Colors.grey.shade200,
            child: Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 48.sp,
            ),
          );
        }

        // Cache the image
        _imageCache[imageUrl] = snapshot.data;

        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          width: 200.w,
          height: 200.h,
        );
      },
    );
  }

  /// Load image with authorization header using Dio
  Future<Uint8List?> _loadImageWithAuth(String imageUrl, {bool fallbackToApi = false, bool isS3Fallback = false}) async {
    try {
      // Validate URL before attempting to load
      if (imageUrl.isEmpty || !imageUrl.startsWith('http')) {
        debugPrint('⚠️ Invalid image URL for auth load: $imageUrl');
        return null;
      }

      // Check if it's an S3 URL (public, no auth needed)
      final isS3Url = imageUrl.contains('s3.ap-southeast-1.amazonaws.com') ||
                      imageUrl.contains('s3.amazonaws.com') ||
                      imageUrl.contains('amazonaws.com');
      
      final dio = Dio();
      final Options options;
      
      if (isS3Url) {
        // S3 URL is public, no auth header needed
        debugPrint('🖼️ Loading S3 URL without auth header: $imageUrl');
        options = Options(
          responseType: ResponseType.bytes,
          validateStatus: (status) {
            // Don't throw exception for 404/403, return null instead
            return status != null && status < 500;
          },
        );
      } else {
        // Non-S3 URL, use auth header
        final token = await SecurityManager.readSecurely(AppConstants.tokenKey);
        options = Options(
          responseType: ResponseType.bytes,
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
          validateStatus: (status) {
            // Don't throw exception for 404/403, return null instead
            return status != null && status < 500;
          },
        );
      }
      
      final response = await dio.get<Uint8List>(
        imageUrl,
        options: options,
      );

      // Check if response is successful
      if (response.statusCode == 200 && response.data != null) {
        return response.data;
      } else if ((response.statusCode == 403 || response.statusCode == 400) && (fallbackToApi || isS3Fallback)) {
        // S3 URL returned 403/400 (Forbidden/Bad Request) - try API URL as fallback
        debugPrint('⚠️ S3 URL returned ${response.statusCode}, trying API URL fallback: $imageUrl');
        return await _loadImageFromApiUrl(imageUrl);
      } else {
        debugPrint('⚠️ Image load failed with status ${response.statusCode}: $imageUrl');
        return null;
      }
    } on DioException catch (e) {
      // Handle DioException specifically
      if ((e.response?.statusCode == 403 || e.response?.statusCode == 400) && (fallbackToApi || isS3Fallback)) {
        // S3 URL returned 403/400 (Forbidden/Bad Request) - try API URL as fallback
        debugPrint('⚠️ S3 URL returned ${e.response?.statusCode}, trying API URL fallback: $imageUrl');
        return await _loadImageFromApiUrl(imageUrl);
      } else if (e.response?.statusCode == 404) {
        debugPrint('⚠️ Image not found (404): $imageUrl');
      } else {
        debugPrint('❌ Error loading image: ${e.message}');
        debugPrint('   URL: $imageUrl');
        debugPrint('   Status: ${e.response?.statusCode}');
        // If it's a 403/400 and we have fallback, try API URL
        if ((e.response?.statusCode == 403 || e.response?.statusCode == 400) && (fallbackToApi || isS3Fallback)) {
          return await _loadImageFromApiUrl(imageUrl);
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Unexpected error loading image: $e');
      debugPrint('   URL: $imageUrl');
      return null;
    }
  }

  /// Build S3 image with fallback to API URL if S3 fails (legacy - use version with localFile parameter)
  Widget _buildS3ImageWithFallback(String s3Url, [File? localFile]) {
    return FutureBuilder<Uint8List?>(
      future: _loadS3ImageWithFallback(s3Url),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // While loading, show local file if available
          if (localFile != null) {
            debugPrint('⏳ Loading S3 URL, showing local file meanwhile');
            return Image.file(
              localFile,
              fit: BoxFit.cover,
              width: 200.w,
              height: 200.h,
            );
          }
          return Container(
            width: 200.w,
            height: 200.h,
            color: Colors.grey.shade200,
            child: Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          // If S3 fails, use local file as fallback
          if (localFile != null) {
            debugPrint('⚠️ S3 URL failed, using local file as fallback');
            return Image.file(
              localFile,
              fit: BoxFit.cover,
              width: 200.w,
              height: 200.h,
            );
          }
          return Container(
            width: 200.w,
            height: 200.h,
            color: Colors.grey.shade200,
            child: Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 48.sp,
            ),
          );
        }

        // Cache the image
        _imageCache[s3Url] = snapshot.data;

        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          width: 200.w,
          height: 200.h,
        );
      },
    );
  }

  /// Load S3 image, fallback to API URL if fails
  Future<Uint8List?> _loadS3ImageWithFallback(String s3Url) async {
    try {
      // First, try loading S3 URL directly (public access)
      debugPrint('🔄 Trying S3 URL directly: $s3Url');
      final dio = Dio();
      final response = await dio.get<Uint8List>(
        s3Url,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (status) {
            return status != null && status < 500;
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        debugPrint('✅ S3 URL loaded successfully');
        return response.data;
      } else {
        debugPrint('⚠️ S3 URL returned ${response.statusCode}, trying API fallback');
        // Fallback to API URL
        return await _loadImageFromApiUrl(s3Url);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 403 || e.response?.statusCode == 400) {
        debugPrint('⚠️ S3 URL returned ${e.response?.statusCode}, trying API fallback');
        // Fallback to API URL
        return await _loadImageFromApiUrl(s3Url);
      } else {
        debugPrint('❌ Error loading S3 image: ${e.message}');
        // Still try API fallback
        return await _loadImageFromApiUrl(s3Url);
      }
    } catch (e) {
      debugPrint('❌ Unexpected error loading S3 image: $e');
      // Still try API fallback
      return await _loadImageFromApiUrl(s3Url);
    }
  }

  /// Show image preview dialog with download and share options
  Future<void> _showImagePreview(Message message) async {
    String? imageUrl;
    File? localFile;
    Uint8List? imageBytes;
    
    // Get image URL or local file
    localFile = _getLocalFile(message);
    if (localFile != null && await localFile.exists()) {
      imageUrl = localFile.path;
    } else if (message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty) {
      imageUrl = message.attachmentUrl;
      // Pre-load image with auth for preview
      try {
        imageBytes = await _loadImageWithAuth(imageUrl!);
      } catch (e) {
        print('⚠️ Failed to pre-load image for preview: $e');
      }
    }
    
    if (imageUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gambar tidak tersedia'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      builder: (dialogBuilderContext) => _ImagePreviewDialog(
        imageUrl: imageUrl!,
        isLocalFile: localFile != null,
        imageBytes: imageBytes,
        message: message,
        dialogContext: dialogBuilderContext,
        onDownload: () async {
          // Use parent context for snackbar (dialog will be closed by button)
          await _downloadImage(message, dialogContext: context);
        },
        onShare: () async {
          // Use parent context for snackbar (dialog will be closed by button)
          await _shareImage(message, localFile, dialogContext: context);
        },
      ),
    );
  }

  /// Download image to device storage
  Future<void> _downloadImage(Message message, {BuildContext? dialogContext}) async {
    try {
      print('📥 Starting image download for message: ${message.id}');
      
      // Request storage permission for Android < 10 only
      // Android 10+ (API 29+) uses scoped storage and doesn't need permission for app-specific directories
      if (Platform.isAndroid) {
        try {
          final deviceInfo = DeviceInfoPlugin();
          final androidInfo = await deviceInfo.androidInfo;
          final sdkInt = androidInfo.version.sdkInt;
          
          print('📥 Android SDK version: $sdkInt');
          
          // Only request permission for Android < 10 (API < 29)
          if (sdkInt < 29) {
            print('📥 Android < 10 detected, requesting storage permission...');
            try {
              final storageStatus = await Permission.storage.status;
              if (storageStatus.isDenied) {
                final result = await Permission.storage.request();
                if (result.isDenied || result.isPermanentlyDenied) {
                  print('⚠️ Storage permission denied');
                  if (mounted) {
                    final snackbarContext = dialogContext ?? context;
                    ScaffoldMessenger.of(snackbarContext).showSnackBar(
                      const SnackBar(
                        content: Text('Izin akses penyimpanan diperlukan untuk download gambar'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                  return;
                }
              }
              print('✅ Storage permission granted');
            } catch (permissionError) {
              print('⚠️ Error requesting storage permission: $permissionError');
              // Continue anyway - might work without permission
            }
          } else if (sdkInt >= 33) {
            // Android 13+ (API 33+) - gal package handles permission internally
            // We don't need to request permission manually, gal will handle it
            print('✅ Android 13+ detected, gal package will handle permission automatically');
          } else {
            print('✅ Android 10-12 detected, using scoped storage (no permission needed)');
          }
        } catch (e) {
          print('⚠️ Error checking Android version: $e');
          // Continue anyway - scoped storage should work for Android 10+
        }
      }
      
      String? imageUrl = message.attachmentUrl;
      File? localFile = _getLocalFile(message);
      
      Uint8List? imageBytes;
      
      // Prefer local file if available
      if (localFile != null && await localFile.exists()) {
        print('📥 Using local file for download: ${localFile.path}');
        imageBytes = await localFile.readAsBytes();
      } else if (imageUrl != null && imageUrl.isNotEmpty) {
        print('📥 Downloading image from URL: $imageUrl');
        
        // Check if it's an S3 URL (public, no auth needed)
        final isS3Url = imageUrl.contains('s3.ap-southeast-1.amazonaws.com') ||
                        imageUrl.contains('s3.amazonaws.com') ||
                        imageUrl.contains('amazonaws.com');
        
        final dio = Dio();
        final Options options;
        
        if (isS3Url) {
          print('📥 S3 URL detected, no auth header needed');
          // S3 URL is public, no auth header needed
          options = Options(
            responseType: ResponseType.bytes,
            validateStatus: (status) {
              return status != null && status < 500;
            },
          );
        } else {
          print('📥 Non-S3 URL, using auth header');
          // Non-S3 URL, might need auth header
          final token = await SecurityManager.readSecurely(AppConstants.tokenKey);
          options = Options(
            responseType: ResponseType.bytes,
            headers: {
              if (token != null && token.isNotEmpty)
                'Authorization': 'Bearer $token',
            },
            validateStatus: (status) {
              return status != null && status < 500;
            },
          );
        }
        
        try {
          final response = await dio.get<Uint8List>(
            imageUrl,
            options: options,
          );

          if (response.statusCode == 200 && response.data != null) {
            imageBytes = response.data;
            print('✅ Image downloaded successfully, size: ${imageBytes?.length ?? 0} bytes');
          } else {
            print('⚠️ Failed to download image: status ${response.statusCode}');
            throw Exception('Failed to download image: HTTP ${response.statusCode}');
          }
        } catch (e) {
          print('❌ Error downloading image from URL: $e');
          rethrow;
        }
      } else {
        print('⚠️ No image URL or local file available');
        throw Exception('No image URL or local file available');
      }

      if (imageBytes == null || imageBytes.isEmpty) {
        print('❌ Image bytes is null or empty');
        if (mounted) {
          final snackbarContext = dialogContext ?? context;
          ScaffoldMessenger.of(snackbarContext).showSnackBar(
            const SnackBar(
              content: Text('Gagal memuat gambar untuk didownload'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Save to gallery using gal package (works for Android 10+ with MediaStore)
      print('📥 Saving image to gallery using gal package...');
      
      // Get file name from URL or generate one
      String fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      if (imageUrl != null && imageUrl.isNotEmpty) {
        final urlFileName = path.basename(imageUrl.split('?').first); // Remove query params
        if (urlFileName.isNotEmpty && urlFileName.contains('.')) {
          fileName = urlFileName;
        } else {
          // Try to get extension from URL
          final uri = Uri.tryParse(imageUrl);
          if (uri != null) {
            final pathSegments = uri.pathSegments;
            if (pathSegments.isNotEmpty) {
              final lastSegment = pathSegments.last;
              if (lastSegment.contains('.')) {
                fileName = lastSegment;
              }
            }
          }
        }
      }
      
      print('📥 File name: $fileName');
      print('📥 Image bytes size: ${imageBytes.length}');
      
      // Save to gallery using gal package
      try {
        // Note: gal package handles permission internally, we don't need to request manually
        // Save temporary file first
        print('📥 Preparing to save temporary file...');
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$fileName');
        
        print('📥 Writing ${imageBytes.length} bytes to temp file: ${tempFile.path}');
        await tempFile.writeAsBytes(imageBytes);
        
        print('✅ Temporary file saved: ${tempFile.path}');
        print('📥 File exists: ${await tempFile.exists()}');
        print('📥 File size: ${await tempFile.length()} bytes');
        
        // Save to gallery using gal
        print('📥 Calling Gal.putImage...');
        try {
          await Gal.putImage(tempFile.path, album: 'Guardify');
          print('✅ Gal.putImage completed successfully');
        } catch (galError) {
          print('❌ Error from Gal.putImage: $galError');
          print('❌ Error type: ${galError.runtimeType}');
          rethrow;
        }
        
        print('✅ Image saved successfully to gallery');
        
        // Clean up temporary file
        try {
          await tempFile.delete();
          print('✅ Temporary file deleted');
        } catch (e) {
          print('⚠️ Error deleting temp file: $e');
        }
        
        if (mounted) {
          final snackbarContext = dialogContext ?? context;
          ScaffoldMessenger.of(snackbarContext).showSnackBar(
            SnackBar(
              content: const Text('Gambar berhasil disimpan ke Gallery'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {
                  // Dismiss snackbar
                },
              ),
            ),
          );
        }
      } catch (saveError, stackTrace) {
        print('❌ Error saving to gallery: $saveError');
        print('❌ Error type: ${saveError.runtimeType}');
        print('❌ Stack trace: $stackTrace');
        if (mounted) {
          final snackbarContext = dialogContext ?? context;
          ScaffoldMessenger.of(snackbarContext).showSnackBar(
            SnackBar(
              content: Text('Gagal menyimpan ke Gallery: ${saveError.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        rethrow;
      }
    } catch (e, stackTrace) {
      print('❌ Error downloading image: $e');
      print('❌ Stack trace: $stackTrace');
      if (mounted) {
        final snackbarContext = dialogContext ?? context;
        ScaffoldMessenger.of(snackbarContext).showSnackBar(
          SnackBar(
            content: Text('Gagal download gambar: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Share image
  Future<void> _shareImage(Message message, File? localFile, {BuildContext? dialogContext}) async {
    try {
      XFile? fileToShare;
      
      // Prefer local file if available
      if (localFile != null && await localFile.exists()) {
        fileToShare = XFile(localFile.path);
      } else if (message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty) {
        // Download image temporarily for sharing
        final imageUrl = message.attachmentUrl!;
        
        // Check if it's an S3 URL (public, no auth needed)
        final isS3Url = imageUrl.contains('s3.ap-southeast-1.amazonaws.com') ||
                        imageUrl.contains('s3.amazonaws.com') ||
                        imageUrl.contains('amazonaws.com');
        
        final dio = Dio();
        final Options options;
        
        if (isS3Url) {
          // S3 URL is public, no auth header needed
          options = Options(
            responseType: ResponseType.bytes,
            validateStatus: (status) {
              return status != null && status < 500;
            },
          );
        } else {
          // Non-S3 URL, might need auth header
          final token = await SecurityManager.readSecurely(AppConstants.tokenKey);
          options = Options(
            responseType: ResponseType.bytes,
            headers: {
              if (token != null && token.isNotEmpty)
                'Authorization': 'Bearer $token',
            },
            validateStatus: (status) {
              return status != null && status < 500;
            },
          );
        }
        
        final response = await dio.get<Uint8List>(
          imageUrl,
          options: options,
        );

        if (response.statusCode == 200 && response.data != null) {
          // Save to temp directory
          final tempDir = await getTemporaryDirectory();
          final fileName = path.basename(imageUrl) != imageUrl && path.basename(imageUrl).isNotEmpty
              ? path.basename(imageUrl)
              : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final tempFile = File('${tempDir.path}/$fileName');
          await tempFile.writeAsBytes(response.data!);
          fileToShare = XFile(tempFile.path);
        } else {
          debugPrint('⚠️ Failed to download image for sharing: status ${response.statusCode}');
        }
      }

      if (fileToShare != null) {
        await Share.shareXFiles(
          [fileToShare],
          text: message.content.isNotEmpty ? message.content : 'Gambar dari chat',
        );
      } else {
        if (mounted) {
          final snackbarContext = dialogContext ?? context;
          ScaffoldMessenger.of(snackbarContext).showSnackBar(
            const SnackBar(
              content: Text('Gagal memuat gambar untuk dibagikan'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error sharing image: $e');
      if (mounted) {
        final snackbarContext = dialogContext ?? context;
        ScaffoldMessenger.of(snackbarContext).showSnackBar(
          SnackBar(
            content: Text('Gagal membagikan gambar: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Load image from API URL as fallback when S3 URL fails
  Future<Uint8List?> _loadImageFromApiUrl(String s3Url) async {
    try {
      // Extract filename from S3 URL
      // Example: https://bnp-s3-abb.s3.ap-southeast-1.amazonaws.com/Abb/3463b0f2-b48b-4fc8-abc2-56f4a855b481.jpg
      // Extract: 3463b0f2-b48b-4fc8-abc2-56f4a855b481.jpg
      final uri = Uri.parse(s3Url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isEmpty) {
        debugPrint('⚠️ Cannot extract filename from S3 URL: $s3Url');
        return null;
      }
      
      // Get the last segment (filename)
      // Handle both cases: with and without "Abb/" prefix
      String fileName = pathSegments.last;
      
      // If path is like ["Abb", "filename.jpg"], we want "filename.jpg"
      // If path is like ["filename.jpg"], we want "filename.jpg"
      if (pathSegments.length > 1 && pathSegments[pathSegments.length - 2] == 'Abb') {
        fileName = pathSegments.last;
      }
      
      debugPrint('📎 Extracted filename from S3 URL: $fileName');
      debugPrint('📎 Full path segments: $pathSegments');
      
      // Build API URL - don't double encode, fileName should already be the correct format
      final baseUrl = AppConstants.baseUrl;
      // Only encode if fileName contains special characters that need encoding
      final encodedFileName = fileName.contains('%') ? fileName : Uri.encodeComponent(fileName);
      final apiUrl = '$baseUrl/file/$encodedFileName';
      debugPrint('📎 Trying API URL: $apiUrl');
      
      // Load from API URL with auth
      final token = await SecurityManager.readSecurely(AppConstants.tokenKey);
      final dio = Dio();
      final response = await dio.get<Uint8List>(
        apiUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
          validateStatus: (status) {
            return status != null && status < 500;
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        debugPrint('✅ Successfully loaded image from API URL');
        return response.data;
      } else {
        debugPrint('⚠️ API URL also failed with status ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error loading image from API URL: $e');
      return null;
    }
  }
}

/// Dialog for image preview with zoom, download, and share
class _ImagePreviewDialog extends StatefulWidget {
  final String imageUrl;
  final bool isLocalFile;
  final Uint8List? imageBytes;
  final Message message;
  final BuildContext dialogContext;
  final Future<void> Function() onDownload;
  final Future<void> Function() onShare;

  const _ImagePreviewDialog({
    required this.imageUrl,
    required this.isLocalFile,
    this.imageBytes,
    required this.message,
    required this.dialogContext,
    required this.onDownload,
    required this.onShare,
  });

  @override
  State<_ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<_ImagePreviewDialog> {
  @override
  Widget build(BuildContext context) {
    ImageProvider imageProvider;
    
    if (widget.isLocalFile) {
      imageProvider = FileImage(File(widget.imageUrl));
    } else if (widget.imageBytes != null) {
      imageProvider = MemoryImage(widget.imageBytes!);
    } else {
      // Fallback to NetworkImage (may need auth)
      imageProvider = NetworkImage(widget.imageUrl);
    }
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Full screen image viewer with zoom
          PhotoView(
            imageProvider: imageProvider,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
            backgroundDecoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, size: 64.sp, color: Colors.white),
                    16.verticalSpace,
                    Text(
                      'Gagal memuat gambar',
                      style: TextStyle(color: Colors.white, fontSize: 16.sp),
                    ),
                  ],
                ),
              );
            },
            loadingBuilder: (context, event) {
              return Center(
                child: CircularProgressIndicator(
                  color: primaryColor,
                  value: event == null
                      ? null
                      : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
                ),
              );
            },
          ),
          
          // Close button
          Positioned(
            top: 40.h,
            right: 16.w,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
              ),
            ),
          ),
          
          // Action buttons (Download & Share)
          Positioned(
            bottom: 40.h,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Download button
                ElevatedButton.icon(
                  onPressed: () async {
                    // Close dialog first
                    Navigator.of(context).pop();
                    
                    // Then start download
                    try {
                      await widget.onDownload();
                    } catch (e) {
                      // Error handling is done in _downloadImage
                      print('Error in download callback: $e');
                    }
                  },
                  icon: const Icon(Icons.download, color: Colors.white),
                  label: const Text(
                    'Download',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                  ),
                ),
                16.horizontalSpace,
                
                // Share button
                ElevatedButton.icon(
                  onPressed: () async {
                    // Close dialog first
                    Navigator.of(context).pop();
                    
                    // Then start share
                    try {
                      await widget.onShare();
                    } catch (e) {
                      // Error handling is done in _shareImage
                      print('Error in share callback: $e');
                    }
                  },
                  icon: const Icon(Icons.share, color: Colors.white),
                  label: const Text(
                    'Share',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
