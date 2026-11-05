import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/security/security_manager.dart';
import '../../domain/entities/message.dart';

/// Service untuk mengelola SignalR connection untuk realtime chat
/// Menggunakan WebSockets transport dengan HubConnectionBuilder
@lazySingleton  
class SignalRChatService {
  HubConnection? _hubConnection;
  String? _token;
  Timer? _reconnectTimer;
  final _messageController = StreamController<Message>.broadcast();
  final _connectionStateController = StreamController<ConnectionState>.broadcast();
  
  bool _isConnected = false;
  String? _currentConversationId;
  String? _currentUserId;
  int _reconnectAttempt = 0;
  final List<Duration> _reconnectDelays = [
    const Duration(seconds: 0),
    const Duration(seconds: 2),
    const Duration(seconds: 10),
    const Duration(seconds: 30),
  ];

  /// Stream untuk menerima messages realtime
  Stream<Message> get messageStream => _messageController.stream;

  /// Stream untuk connection state changes
  Stream<ConnectionState> get connectionStateStream => _connectionStateController.stream;

  /// Status koneksi
  bool get isConnected => _isConnected;

  /// Initialize SignalR connection
  /// Menggunakan JWT token dari login yang disimpan di secure storage
  /// Menggunakan HubConnectionBuilder dengan WebSockets transport
  Future<void> initialize() async {
    try {
      // Ambil JWT token dari login (fresh dari secure storage)
      _token = await SecurityManager.readSecurely(AppConstants.tokenKey);
      if (_token == null || _token!.isEmpty) {
        throw Exception('JWT token not found. Please login first.');
      }

      print('🔐 Using JWT token from login for SignalR connection');
      print('🔐 Token length: ${_token!.length}');

      // Build HubConnection dengan WebSockets transport
      _hubConnection = HubConnectionBuilder()
          .withUrl(
            AppConstants.signalRHubUrl,
            options: HttpConnectionOptions(
              accessTokenFactory: () async {
                // Ambil JWT token fresh dari secure storage
                final token = await SecurityManager.readSecurely(AppConstants.tokenKey);
                if (token == null || token.isEmpty) {
                  throw Exception('JWT token not found');
                }
                return token;
              },
              transport: HttpTransportType.WebSockets, // Paksa WebSockets
            ),
          )
          .withAutomaticReconnect()
          .build();

      // Setup event handlers
      _setupHubConnectionHandlers();

      // Start connection
      print('🔄 Starting HubConnection...');
      await _hubConnection!.start();
      
      // Wait a bit to ensure connection is fully established
      // Increase delay to ensure connection is truly ready
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Double check connection is still active after delay
      if (_hubConnection != null) {
        _isConnected = true;
        _reconnectAttempt = 0;
        _connectionStateController.add(ConnectionState.connected);
        print('✅ SignalR service initialized and connected (WebSockets)');
      } else {
        throw Exception('HubConnection became null after start');
      }
    } catch (e) {
      print('❌ Error initializing SignalR: $e');
      _isConnected = false;
      _connectionStateController.add(ConnectionState.disconnected);
      rethrow;
    }
  }

  /// Setup HubConnection event handlers
  /// Note: OnConnectedAsync() is a server-side method, called automatically when client connects
  void _setupHubConnectionHandlers() {
    if (_hubConnection == null) return;

    // Handle connection state changes
    _hubConnection!.onclose(({Exception? error}) {
      print('🔴 SignalR connection closed: $error');
      _isConnected = false;
      _currentConversationId = null;
      _currentUserId = null;
      _connectionStateController.add(ConnectionState.disconnected);
      if (error != null) {
        _scheduleReconnect();
      }
    });

    // Handle ReceiveMessage from server
    _hubConnection!.on('ReceiveMessage', (arguments) {
      try {
        print('📨 Received message via SignalR: $arguments');
        
        // Handle different argument formats
        // Arguments can be: List<dynamic> or direct Map
        dynamic messageData;
        if (arguments is List && arguments.isNotEmpty) {
          messageData = arguments[0];
        } else {
          messageData = arguments;
        }
        
        // Convert to Map if needed
        Map<String, dynamic>? dataMap;
        if (messageData is Map<String, dynamic>) {
          dataMap = messageData;
        } else if (messageData is Map) {
          dataMap = Map<String, dynamic>.from(messageData);
        }
        
        if (dataMap != null) {
          print('📨 [SignalR] Parsing message data: $dataMap');
          print('📨 [SignalR] Message chatId: ${dataMap['conversationId'] ?? dataMap['ConversationId'] ?? 'N/A'}');
          final parsedMessage = _parseMessageFromSignalR(dataMap);
          if (parsedMessage != null) {
            print('✅ [SignalR] Message parsed successfully:');
            print('   ID: ${parsedMessage.id}');
            print('   ChatId: ${parsedMessage.chatId}');
            print('   Content: ${parsedMessage.content}');
            print('   SenderId: ${parsedMessage.senderId}');
            _messageController.add(parsedMessage);
            print('✅ [SignalR] Message added to stream: ${parsedMessage.id}');
          } else {
            print('⚠️ [SignalR] Failed to parse message from data: $dataMap');
          }
        } else {
          print('⚠️ [SignalR] Message data is not a Map: ${messageData?.runtimeType}');
        }
      } catch (e, stackTrace) {
        print('❌ Error handling ReceiveMessage: $e');
        print('❌ Stack trace: $stackTrace');
      }
    });

    // Handle other events
    _hubConnection!.on('MessageSent', (arguments) {
      print('✅ Message sent confirmation received');
    });

    _hubConnection!.on('UserJoined', (arguments) {
      print('👤 User joined conversation');
    });

    _hubConnection!.on('UserLeft', (arguments) {
      print('👋 User left conversation');
    });
  }



  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    if (_reconnectAttempt >= _reconnectDelays.length) {
      print('❌ Max reconnection attempts reached');
      return;
    }

    final delay = _reconnectDelays[_reconnectAttempt];
    _reconnectAttempt++;
    
    _connectionStateController.add(ConnectionState.reconnecting);
    print('🟡 Scheduling reconnect in ${delay.inSeconds} seconds (attempt $_reconnectAttempt)');
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!_isConnected) {
        connect();
      }
    });
  }

  /// Parse message dari SignalR response
  /// Handle both lowercase (from server) and uppercase (legacy) formats
  Message? _parseMessageFromSignalR(Map<String, dynamic> data) {
    try {
      print('🔍 Parsing message with keys: ${data.keys.toList()}');
      
      // Handle both lowercase (server format) and uppercase (legacy) field names
      final id = data['id'] ?? data['Id'] ?? '';
      final conversationId = data['conversationId'] ?? data['ConversationId'] ?? '';
      final senderId = data['senderId'] ?? data['SenderId'] ?? '';
      final text = data['text'] ?? data['Text'] ?? '';
      final sentAt = data['sentAt'] ?? data['SentAt'];
      final senderName = data['senderName'] ?? data['SenderName'] ?? 'User';
      final senderProfileImageUrl = data['senderProfileImageUrl'] ?? data['SenderProfileImageUrl'];
      
      print('📝 Parsed fields:');
      print('   id: $id');
      print('   conversationId: $conversationId');
      print('   senderId: $senderId');
      print('   text: $text');
      print('   sentAt: $sentAt');
      
      if (id.isEmpty) {
        print('⚠️ Warning: Message ID is empty!');
      }
      
      // IMPORTANT: Always parse attachments first to get S3Url
      // Do NOT use any attachmentUrl from message level - it might be API URL
      // Check for attachments - support MessageAttachmentResponse format
      // MessageAttachmentResponse: Id (Guid), FileName (string), FileType (string?), FileSize (long?), S3Url (string)
      String? attachmentUrl;
      String? attachmentType;
      final attachments = data['attachments'] ?? data['Attachments'] ?? data['attachment'];
      
      print('📎 Checking attachments: $attachments');
      print('📎 Attachments type: ${attachments?.runtimeType}');
      print('📎 Is List: ${attachments is List}');
      print('📎 Is not null: ${attachments != null}');
      if (attachments != null && attachments is List) {
        print('📎 Attachments length: ${attachments.length}');
      }
      
      if (attachments != null && attachments is List && attachments.isNotEmpty) {
        final attachment = attachments[0] as Map<String, dynamic>?;
        if (attachment != null) {
          print('📎 Parsing attachment: ${attachment.keys.toList()}');
          print('📎 Full attachment data: $attachment');
          
          // PRIORITY 1: Use S3Url from MessageAttachmentResponse (ALWAYS prefer S3Url)
          // Check all possible field names for S3Url (case-insensitive search)
          dynamic s3Url;
          for (final key in attachment.keys) {
            final lowerKey = key.toString().toLowerCase();
            if (lowerKey == 's3url' || lowerKey == 's3_url' || lowerKey == 'url') {
              final value = attachment[key];
              if (value != null && value.toString().trim().isNotEmpty) {
                // Check if value contains S3 indicator
                final valueStr = value.toString().trim();
                if (valueStr.contains('amazonaws.com') || 
                    valueStr.contains('s3.') || 
                    valueStr.contains('s3-ap-southeast-1') ||
                    valueStr.startsWith('http') ||
                    valueStr.startsWith('bnp-s3')) {
                  s3Url = value;
                  print('📎 Found S3Url in field "$key": $s3Url');
                  break;
                }
              }
            }
          }
          
          // Also check standard field names
          if (s3Url == null) {
            s3Url = attachment['s3Url'] ?? 
                    attachment['S3Url'] ?? 
                    attachment['s3url'] ?? 
                    attachment['S3URL'] ??
                    attachment['url'] ??
                    attachment['Url'] ??
                    attachment['URL'];
          }
          
          if (s3Url != null && s3Url.toString().trim().isNotEmpty) {
            String urlString = s3Url.toString().trim();
            print('📎 Found S3Url candidate: $urlString');
            
            // Check if it's already a valid S3 URL
            final isS3Url = urlString.contains('amazonaws.com') || 
                           urlString.contains('s3.') ||
                           urlString.contains('s3-ap-southeast-1');
            
            // Ensure URL has protocol (http/https)
            if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
              if (isS3Url) {
                urlString = 'https://$urlString';
                print('📎 Added https:// protocol: $urlString');
              } else {
                print('⚠️ URL missing protocol and not S3, skipping: $urlString');
                urlString = '';
              }
            }
            
            // Use the URL if it's valid (S3 URL or full HTTP URL)
            // Be more lenient - accept any URL that starts with http
            if (urlString.isNotEmpty) {
              if (isS3Url || urlString.startsWith('http')) {
                attachmentUrl = urlString;
                print('✅ Using S3Url: $attachmentUrl');
              } else {
                // Even if not clearly S3, if it's a valid-looking URL, use it
                attachmentUrl = urlString;
                print('✅ Using URL (may not be S3): $attachmentUrl');
              }
            } else {
              print('⚠️ S3Url is empty after processing, will try other sources');
            }
          } else {
            print('⚠️ No S3Url found in attachment');
          }
          
          // PRIORITY 2: Fallback to FileName ONLY if S3Url is not available
          // But check if fileName contains S3 URL first
          if (attachmentUrl == null || attachmentUrl.isEmpty) {
            final fileName = attachment['fileName'] ?? attachment['FileName'] ?? attachment['filename'];
            if (fileName != null && fileName.toString().isNotEmpty) {
              final fileNameStr = fileName.toString();
              
              // Check if fileName is actually an S3 URL
              if (fileNameStr.contains('amazonaws.com') || fileNameStr.contains('s3.')) {
                String urlString = fileNameStr.trim();
                if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
                  urlString = 'https://$urlString';
                }
                attachmentUrl = urlString;
                print('✅ Using S3Url from fileName field: $attachmentUrl');
              } else {
                // Use API URL as fallback, even for scaled_ files
                // The API might have the file, or we can try to construct S3 URL from fileName
                // First, try to construct S3 URL pattern from fileName if it looks like a GUID
                if (fileNameStr.startsWith('scaled_')) {
                  // Extract the GUID part (after scaled_)
                  final guidPart = fileNameStr.replaceFirst('scaled_', '').split('.').first;
                  // Try to construct S3 URL pattern: bnp-s3-abb.s3.ap-southeast-1.amazonaws.com/Abb/{guid}.jpg
                  if (guidPart.length > 20) { // Likely a GUID
                    final extension = fileNameStr.split('.').last;
                    final possibleS3Url = 'https://bnp-s3-abb.s3.ap-southeast-1.amazonaws.com/Abb/$guidPart.$extension';
                    attachmentUrl = possibleS3Url;
                    print('✅ Constructed S3Url from scaled_ fileName: $attachmentUrl');
                  } else {
                    // Fallback to API URL
                    final baseUrl = AppConstants.baseUrl;
                    final encodedFileName = Uri.encodeComponent(fileNameStr);
                    attachmentUrl = '$baseUrl/file/$encodedFileName';
                    print('⚠️ Using API URL fallback for scaled_ file: $attachmentUrl');
                  }
                } else {
                  // Use API URL for non-scaled files
                  final baseUrl = AppConstants.baseUrl;
                  final encodedFileName = Uri.encodeComponent(fileNameStr);
                  attachmentUrl = '$baseUrl/file/$encodedFileName';
                  print('⚠️ Using FileName fallback (API URL): $attachmentUrl');
                }
              }
            }
          }
          
          // Final validation and logging
          if (attachmentUrl == null || attachmentUrl.isEmpty) {
            print('❌ ERROR: attachmentUrl is null or empty after parsing!');
            print('❌ Attachment keys: ${attachment.keys.toList()}');
            print('❌ Full attachment: $attachment');
            // Try one more time - check if there's any URL-like field
            for (final key in attachment.keys) {
              final value = attachment[key];
              if (value != null) {
                final valueStr = value.toString();
                if (valueStr.contains('http') || valueStr.contains('amazonaws') || valueStr.contains('s3')) {
                  print('⚠️ Found potential URL in field "$key": $valueStr');
                  attachmentUrl = valueStr;
                  if (!attachmentUrl.startsWith('http')) {
                    attachmentUrl = 'https://$attachmentUrl';
                  }
                  print('✅ Using URL from field "$key": $attachmentUrl');
                  break;
                }
              }
            }
          }
          
          if (attachmentUrl != null && 
              attachmentUrl.contains('api-devguardify.abb-apps.com') && 
              !attachmentUrl.contains('amazonaws.com')) {
            print('⚠️ WARNING: Using API URL instead of S3Url. This may cause 404 errors.');
            print('⚠️ Attachment data available: ${attachment.keys.toList()}');
          }
          
          // Get FileType from MessageAttachmentResponse
          attachmentType = (attachment['fileType'] ?? attachment['FileType'] ?? attachment['filetype'] ?? attachment['mimeType'] ?? attachment['MimeType'])?.toString();
          if (attachmentType != null) {
            print('📎 FileType: $attachmentType');
          }
          
          // Log other fields for debugging
          final attachmentId = attachment['id'] ?? attachment['Id'];
          final fileSize = attachment['fileSize'] ?? attachment['FileSize'];
          if (attachmentId != null) {
            print('📎 Attachment Id: $attachmentId');
          }
          if (fileSize != null) {
            print('📎 FileSize: $fileSize');
          }
        }
      }

      // Determine message type
      // If there's an attachmentUrl, it's definitely not a text-only message
      MessageType messageType = MessageType.text;
      if (attachmentUrl != null && attachmentUrl.isNotEmpty) {
        // If we have attachmentUrl, determine type from attachmentType or URL extension
        if (attachmentType != null) {
          final fileType = attachmentType.toLowerCase();
          if (fileType.contains('image')) {
            messageType = MessageType.image;
          } else if (fileType.contains('video')) {
            messageType = MessageType.file;
          } else {
            messageType = MessageType.file;
          }
        } else {
          // Try to determine from URL extension
          final urlLower = attachmentUrl.toLowerCase();
          if (urlLower.contains('.jpg') || 
              urlLower.contains('.jpeg') || 
              urlLower.contains('.png') || 
              urlLower.contains('.gif') || 
              urlLower.contains('.webp')) {
            messageType = MessageType.image;
            print('📎 Determined message type as image from URL extension');
          } else {
            messageType = MessageType.file;
            print('📎 Determined message type as file from URL extension');
          }
        }
      } else if (attachmentType != null) {
        // Fallback: use attachmentType even if no URL
        final fileType = attachmentType.toLowerCase();
        if (fileType.contains('image')) {
          messageType = MessageType.image;
        } else if (fileType.contains('video')) {
          messageType = MessageType.file;
        } else {
          messageType = MessageType.file;
        }
      }
      
      print('📎 Final message type: $messageType, attachmentUrl: $attachmentUrl');

      final sentAtDateTime = _parseDateTime(sentAt);
      print('🕐 Parsed sentAt: $sentAt -> $sentAtDateTime (local: ${DateTime.now()})');
      
      final parsedMessage = Message(
        id: id.toString(),
        chatId: conversationId.toString(),
        senderId: senderId.toString(),
        senderName: senderName.toString(),
        senderProfileImageUrl: senderProfileImageUrl?.toString(),
        content: text.toString(),
        type: messageType,
        timestamp: sentAtDateTime, // Use server timestamp
        status: MessageStatus.delivered,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
        // Set sentAt to indicate message was sent successfully
        sentAt: sentAtDateTime,
      );
      
      print('✅ Successfully parsed message: ${parsedMessage.id}, timestamp: ${parsedMessage.timestamp}');
      return parsedMessage;
    } catch (e, stackTrace) {
      print('❌ Error parsing message: $e');
      print('❌ Stack trace: $stackTrace');
      print('❌ Data: $data');
      return null;
    }
  }

  /// Parse DateTime from string
  /// Handles UTC and local timezone correctly
  DateTime _parseDateTime(dynamic dateTime) {
    if (dateTime == null) return DateTime.now();
    if (dateTime is DateTime) return dateTime;
    if (dateTime is String) {
      try {
        // Parse the string - DateTime.parse handles ISO 8601 format
        final parsed = DateTime.parse(dateTime);
        
        // DateTime.parse automatically handles timezone:
        // - If string ends with 'Z', it's UTC
        // - If string has timezone offset (+/-HH:MM), it uses that
        // - If no timezone info, it's treated as local time
        
        // For server timestamps without timezone, assume they're UTC
        // Check if the string has timezone info
        final hasTimezone = dateTime.contains('Z') || 
                           dateTime.contains('+') || 
                           (dateTime.contains('-') && dateTime.indexOf('-') > 10); // Timezone offset, not date separator
        
        if (!hasTimezone) {
          // No timezone info - assume it's UTC from server and convert to local
          // DateTime.parse without timezone treats it as local, so we need to parse as UTC first
          try {
            // Try parsing as UTC by appending 'Z'
            final utcString = dateTime.endsWith('Z') ? dateTime : '${dateTime}Z';
            final utcParsed = DateTime.parse(utcString);
            return utcParsed.toLocal();
          } catch (e) {
            // If that fails, use the parsed value as-is (already local)
            return parsed;
          }
        }
        
        // Already has timezone info, DateTime.parse handles it correctly
        // Convert to local time if it's UTC
        if (parsed.isUtc) {
          return parsed.toLocal();
        }
        
        return parsed;
      } catch (e) {
        print('⚠️ Error parsing DateTime: $dateTime, error: $e');
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  /// Connect to SignalR hub
  Future<void> connect() async {
    if (_isConnected) {
      print('✅ Already connected to SignalR');
      return;
    }

    try {
      await initialize();
    } catch (e) {
      print('❌ Error connecting to SignalR: $e');
      rethrow;
    }
  }

  /// Disconnect from SignalR hub
  Future<void> disconnect() async {
    try {
      if (_hubConnection != null) {
        await _hubConnection!.stop();
      }
      _isConnected = false;
      _reconnectTimer?.cancel();
      _currentConversationId = null;
      _currentUserId = null;
      _connectionStateController.add(ConnectionState.disconnected);
      print('🔴 SignalR disconnected');
    } catch (e) {
      print('❌ Error disconnecting from SignalR: $e');
    }
  }

  /// Join a conversation
  /// Server signature: JoinConversation(Guid conversationId, Guid userId)
  Future<void> joinConversation(String conversationId, String userId) async {
    print('🔵 Attempting to join conversation: $conversationId, userId: $userId');
    
    // Ensure connection is established
    if (_hubConnection == null) {
      print('⚠️ HubConnection is null, initializing...');
      await connect();
    }
    
    // Wait for connection to be fully established
    if (!isConnected) {
      print('⚠️ SignalR not connected, connecting first...');
      await connect();
    }
    
    // Wait until connection is truly connected (with timeout and retry)
    int retryCount = 0;
    const maxRetries = 15; // Increase retries for more reliability
    while ((!_isConnected || _hubConnection == null) && retryCount < maxRetries) {
      print('⏳ Waiting for connection to be ready... (attempt ${retryCount + 1}/$maxRetries)');
      await Future.delayed(const Duration(milliseconds: 300));
      retryCount++;
      
      // If still not connected after several attempts, try reconnecting
      if (retryCount == 5 && !_isConnected) {
        print('🔄 Reconnecting SignalR...');
        try {
          await connect();
        } catch (e) {
          print('⚠️ Reconnection attempt failed: $e');
        }
      }
    }
    
    if (_hubConnection == null) {
      throw Exception('SignalR HubConnection is null. Cannot join conversation.');
    }
    
    if (!_isConnected) {
      throw Exception('SignalR connection is not established. Cannot join conversation.');
    }

    try {
      print('📤 Invoking JoinConversation with args: [$conversationId, $userId]');
      print('📤 Is connected: $_isConnected');
      
      // Pastikan args adalah string, bukan object
      final result = await _hubConnection!.invoke(
        'JoinConversation', 
        args: <Object>[conversationId, userId],
      );
      
      print('✅ JoinConversation result: $result');
      _currentConversationId = conversationId;
      _currentUserId = userId;
      print('✅ Successfully joined conversation: $conversationId');
    } catch (e, stackTrace) {
      print('❌ Error joining conversation: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: $stackTrace');
      
      // If error is about connection state, try reconnecting first
      if (e.toString().contains('Connected') || e.toString().contains('connection')) {
        print('🔄 Connection state error detected, attempting to reconnect...');
        try {
          await disconnect();
          await Future.delayed(const Duration(milliseconds: 500));
          await connect();
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Retry join after reconnection
          if (_isConnected && _hubConnection != null) {
            print('🔄 Retrying JoinConversation after reconnect...');
            final result = await _hubConnection!.invoke(
              'JoinConversation', 
              args: <Object>[conversationId, userId],
            );
            _currentConversationId = conversationId;
            _currentUserId = userId;
            print('✅ Successfully joined conversation after reconnect: $conversationId');
            return;
          }
        } catch (reconnectError) {
          print('❌ Reconnection failed: $reconnectError');
        }
      }
      
      // Coba dengan method name yang berbeda (case sensitivity)
      try {
        print('🔄 Retrying with lowercase method name: joinConversation');
        await _hubConnection!.invoke(
          'joinConversation', 
          args: <Object>[conversationId, userId],
        );
        _currentConversationId = conversationId;
        _currentUserId = userId;
        print('✅ Successfully joined conversation (retry): $conversationId');
      } catch (e2) {
        print('❌ Retry also failed: $e2');
        print('❌ This might be a server-side error. Check server logs.');
        rethrow;
      }
    }
  }

  /// Leave a conversation
  /// Server signature: LeaveConversation(Guid conversationId)
  Future<void> leaveConversation(String conversationId, String userId) async {
    print('🔴 Attempting to leave conversation: $conversationId');
    
    if (!isConnected || _hubConnection == null) {
      print('⚠️ SignalR not connected, skipping leave');
      return;
    }

    try {
      // Server hanya butuh conversationId, tidak butuh userId
      await _hubConnection!.invoke(
        'LeaveConversation', 
        args: <Object>[conversationId],
      );
      if (_currentConversationId == conversationId) {
        _currentConversationId = null;
        _currentUserId = null;
      }
      print('✅ Successfully left conversation: $conversationId');
    } catch (e) {
      print('❌ Error leaving conversation: $e');
    }
  }

  /// Mark messages as read via SignalR
  /// Server signature: ReadMessage(Guid conversationId, Guid userId)
  Future<void> readMessage(String conversationId, String userId) async {
    print('📖 Attempting to mark messages as read: $conversationId');
    
    if (!isConnected || _hubConnection == null) {
      print('⚠️ SignalR not connected, skipping read message');
      return;
    }

    try {
      await _hubConnection!.invoke(
        'ReadMessage',
        args: <Object>[
          conversationId,
          userId,
        ],
      );
      print('✅ Successfully marked messages as read: $conversationId');
    } catch (e) {
      print('❌ Error marking messages as read: $e');
      rethrow;
    }
  }

  /// Send message via SignalR
  /// Server signature: SendMessage(Guid conversationId, Guid senderId, string text, string username, List<MessageAttachmentResponse> attachment)
  /// MessageAttachmentResponse: Id (Guid), FileName (string), FileType (string?), FileSize (long?), S3Url (string)
  /// Note: For sending, server may still accept FileObject format (Filename, MimeType, Base64, FileSize)
  Future<void> sendMessageRealtime({
    required String conversationId,
    required String senderId,
    required String text,
    required String username,
    List<Map<String, dynamic>>? attachments,
  }) async {
    if (!isConnected || _hubConnection == null) {
      throw Exception('Not connected to SignalR');
    }

    try {
      // Format attachments sesuai FileObject
      // FileObject: Filename, MimeType, Base64, FileSize
      List<Map<String, dynamic>>? formattedAttachments;
      if (attachments != null && attachments.isNotEmpty) {
        formattedAttachments = attachments.map((att) {
          return {
            'Filename': att['Filename'] ?? att['FileName'] ?? '',
            'MimeType': att['MimeType'] ?? att['FileType'] ?? 'image/jpeg',
            'Base64': att['Base64'] ?? '',
            'FileSize': att['FileSize'],
          };
        }).toList();
      }

      print('📤 Sending message via SignalR:');
      print('   ConversationId: $conversationId');
      print('   SenderId: $senderId');
      print('   Text: $text');
      print('   Username: $username');
      print('   Attachments: ${formattedAttachments?.length ?? 0}');

      // Server signature: SendMessage(conversationId, senderId, text, username, attachments)
      await _hubConnection!.invoke(
        'SendMessage',
        args: <Object>[
          conversationId,
          senderId,
          text,
          username,
          formattedAttachments ?? <Map<String, dynamic>>[],
        ],
      );
      print('✅ Message sent via SignalR');
    } catch (e) {
      print('❌ Error sending message via SignalR: $e');
      rethrow;
    }
  }

  /// Dispose resources
  void dispose() {
    _reconnectTimer?.cancel();
    _messageController.close();
    _connectionStateController.close();
    disconnect();
    _hubConnection = null;
  }
}

/// Connection state enum
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}
