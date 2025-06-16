import 'dart:io';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Cloudinary configuration
class CloudinaryConfig {
  static const String cloudName = 'dufgzsmfq'; // Replace with your cloud name
  static const String uploadPreset = 'chatapp'; // Replace with your upload preset
  static const String apiUrl = 'https://api.cloudinary.com/v1_1/$cloudName/upload';
}

/// Service class for handling Cloudinary uploads
class CloudinaryService {
  static Future<String?> uploadFile(File file) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(CloudinaryConfig.apiUrl));
      request.fields['upload_preset'] = CloudinaryConfig.uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.transform(utf8.decoder).join();
        final data = json.decode(responseData);
        return data['secure_url'];
      }
    } catch (e) {
      print('Error uploading file: $e');
    }
    return null;
  }
}

/// Enhanced MessageBubble with file support
class MessageBubble extends StatelessWidget {
  final String messageText;
  final String formattedTime;
  final bool isCurrentUser;
  final bool isDelivered;
  final bool isRead;
  final String? fileUrl;
  final String? fileName;
  final String? fileType;

  const MessageBubble({
    Key? key,
    required this.messageText,
    required this.formattedTime,
    required this.isCurrentUser,
    required this.isDelivered,
    required this.isRead,
    this.fileUrl,
    this.fileName,
    this.fileType,
  }) : super(key: key);

  bool get isImage => fileType?.startsWith('image/') == true;
  bool get isVideo => fileType?.startsWith('video/') == true;
  bool get isAudio => fileType?.startsWith('audio/') == true;
  bool get isPdf => fileType?.contains('pdf') == true;
  bool get isDocument => fileType?.contains('document') == true || 
                        fileType?.contains('word') == true ||
                        fileType?.contains('text') == true;

  Widget _buildFilePreview(BuildContext context) {
    if (fileUrl == null) return const SizedBox.shrink();

    if (isImage) {
      return GestureDetector(
        onTap: () => _openFileViewer(context),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: fileUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 100,
                width: 100,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.orange,
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: 100,
                width: 100,
                color: Colors.grey[800],
                child: const Icon(Icons.broken_image, color: Colors.white70),
              ),
            ),
          ),
        ),
      );
    } else {
      return GestureDetector(
        onTap: () => _openFileViewer(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getFileIcon(),
                color: Colors.white70,
                size: 24,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName ?? 'File',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _getFileTypeDescription(),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.open_in_new,
                color: Colors.orange,
                size: 16,
              ),
            ],
          ),
        ),
      );
    }
  }

  String _getFileTypeDescription() {
    if (isVideo) return 'Video';
    if (isAudio) return 'Audio';
    if (isPdf) return 'PDF Document';
    if (isDocument) return 'Document';
    return 'File';
  }

  IconData _getFileIcon() {
    if (isVideo) return Icons.play_circle_outline;
    if (isAudio) return Icons.audiotrack;
    if (isPdf) return Icons.picture_as_pdf;
    if (isDocument) return Icons.description;
    return Icons.insert_drive_file;
  }

  void _openFileViewer(BuildContext context) {
    if (isImage) {
      // Show image in full screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FullScreenImageViewer(
            imageUrl: fileUrl!,
            fileName: fileName ?? 'Image',
          ),
        ),
      );
    } else {
      // Show file options dialog
      _showFileOptionsDialog(context);
    }
  }

  void _showFileOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            fileName ?? 'File',
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            'Choose how to open this ${_getFileTypeDescription().toLowerCase()}:',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openInBrowser();
              },
              child: const Text(
                'Open in Browser',
                style: TextStyle(color: Colors.orange),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _downloadFile(context);
              },
              child: const Text(
                'Download',
                style: TextStyle(color: Colors.orange),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openInBrowser() async {
    if (fileUrl != null) {
      final uri = Uri.parse(fileUrl!);
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        print('Error opening file in browser: $e');
      }
    }
  }

  void _downloadFile(BuildContext context) async {
    if (fileUrl != null) {
      try {
        final uri = Uri.parse(fileUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Opening file for download...'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading file: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isCurrentUser ? Colors.orange : Colors.grey[850];
    final alignment = isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Align(
        alignment: alignment,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(2, 2),
              )
            ],
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment: isCurrentUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (fileUrl != null) ...[
                _buildFilePreview(context),
                if (messageText.isNotEmpty) const SizedBox(height: 8),
              ],
              if (messageText.isNotEmpty)
                Text(
                  messageText,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              if (formattedTime.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formattedTime,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      if (isCurrentUser) ...[
                        if (isRead)
                          const Icon(Icons.done_all, color: Colors.green, size: 16)
                        else if (isDelivered)
                          const Icon(Icons.done, color: Colors.grey, size: 16),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full screen image viewer
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String fileName;

  const FullScreenImageViewer({
    Key? key,
    required this.imageUrl,
    required this.fileName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          fileName,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new, color: Colors.white),
            onPressed: () async {
              final uri = Uri.parse(imageUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          scaleEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            ),
            errorWidget: (context, url, error) => const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.white70, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fetches the other user's name from the chat document and users collection.
Future<String?> _getOtherUserName(String chatId) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return null;
  final currentUserId = currentUser.uid;

  final chatDocSnapshot = await FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .get();
  if (!chatDocSnapshot.exists) return null;

  final data = chatDocSnapshot.data();
  if (data == null || !data.containsKey('users')) return null;

  final List<dynamic> userIds = data['users'];
  String? otherUserId;
  for (var id in userIds) {
    if (id != currentUserId) {
      otherUserId = id;
      break;
    }
  }
  if (otherUserId == null) return null;

  final otherUserDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(otherUserId)
      .get();
  if (!otherUserDoc.exists) return null;
  final otherUserData = otherUserDoc.data();
  if (otherUserData == null) return null;

  return otherUserData['name'] as String?;
}

/// Enhanced ChatScreen with file upload functionality
class ChatScreen extends StatefulWidget {
  final String chatId;

  const ChatScreen({
    Key? key,
    required this.chatId,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final Stream<DocumentSnapshot> _chatDocStream;
  DocumentSnapshot? _chatInfo;
  String? _otherUserName;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _chatDocStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .snapshots();
    _fetchChatInfo();
    _fetchOtherUserName();
  }

  Future<void> _fetchChatInfo() async {
    final doc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .get();
    if (doc.exists) {
      setState(() {
        _chatInfo = doc;
      });
    }
  }

  Future<void> _fetchOtherUserName() async {
    String? name = await _getOtherUserName(widget.chatId);
    if (name != null) {
      setState(() {
        _otherUserName = name;
      });
    }
  }

  void _sendMessage(String currentUserId, {String? fileUrl, String? fileName, String? fileType}) {
    final messageText = _messageController.text.trim();
    if (messageText.isNotEmpty || fileUrl != null) {
      final messageData = {
        'text': messageText,
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'delivered': false,
        'read': false,
      };

      if (fileUrl != null) {
        messageData['fileUrl'] = fileUrl;
        messageData['fileName'] = fileName ?? 'File';
        messageData['fileType'] = fileType ?? 'application/octet-stream';
      }

      FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add(messageData);
      
      _messageController.clear();
      _updateTypingStatus('');
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _updateTypingStatus(String status) {
    FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({'typing': status});
  }

  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _isUploading = true;
        });

        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        
        // Determine file type based on extension
        String fileType = 'application/octet-stream';
        final extension = result.files.single.extension?.toLowerCase();
        
        if (extension != null) {
          switch (extension) {
            case 'jpg':
            case 'jpeg':
            case 'png':
            case 'gif':
            case 'webp':
              fileType = 'image/$extension';
              break;
            case 'mp4':
            case 'avi':
            case 'mkv':
            case 'mov':
              fileType = 'video/$extension';
              break;
            case 'mp3':
            case 'wav':
            case 'aac':
            case 'm4a':
              fileType = 'audio/$extension';
              break;
            case 'pdf':
              fileType = 'application/pdf';
              break;
            case 'doc':
            case 'docx':
              fileType = 'application/msword';
              break;
            case 'txt':
              fileType = 'text/plain';
              break;
            default:
              fileType = 'application/$extension';
          }
        }

        // Show upload progress
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                CircularProgressIndicator(
                  color: Colors.orange,
                  strokeWidth: 2,
                ),
                SizedBox(width: 16),
                Text('Uploading file...'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 30),
          ),
        );

        final fileUrl = await CloudinaryService.uploadFile(file);
        
        setState(() {
          _isUploading = false;
        });

        // Hide the progress snackbar
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (fileUrl != null) {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            _sendMessage(
              currentUser.uid,
              fileUrl: fileUrl,
              fileName: fileName,
              fileType: fileType,
            );
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File uploaded successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload file. Please try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting file: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showChatInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Chat Information',
            style: TextStyle(color: Colors.white)),
        content: _chatInfo != null
            ? Text('Chat details: ${_chatInfo!.data()}',
                style: const TextStyle(color: Colors.white70))
            : const Text('No chat information available.',
                style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  void _markMessageAsDelivered(DocumentSnapshot doc, String currentUserId) {
    final data = doc.data() as Map<String, dynamic>;
    if (data['senderId'] != currentUserId &&
        (data['delivered'] == null || data['delivered'] == false)) {
      FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(doc.reference, {'delivered': true});
      });
    }
  }

  void _markMessageAsRead(DocumentSnapshot doc, String currentUserId) {
    final data = doc.data() as Map<String, dynamic>;
    if (data['senderId'] != currentUserId &&
        (data['read'] == null || data['read'] == false)) {
      FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(doc.reference, {'read': true});
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Chat"),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(
          child: Text("User not logged in", style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final messagesRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: Text(
            _otherUserName ?? "Loading...",
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white),
              onPressed: _showChatInfo,
            ),
          ],
        ),
        backgroundColor: Colors.black,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black87, Colors.black],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: _chatDocStream,
                builder: (context, snapshot) {
                  String typingIndicator = '';
                  if (snapshot.hasData) {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    if (data != null && data['typing'] != null) {
                      final typingUser = data['typing'] as String;
                      if (typingUser.isNotEmpty && typingUser != currentUser.uid) {
                        typingIndicator = "User is typing...";
                      }
                    }
                  }
                  return typingIndicator.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            typingIndicator,
                            style: TextStyle(color: Colors.orange[200], fontSize: 14),
                          ),
                        )
                      : const SizedBox.shrink();
                },
              ),
              if (_isUploading)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.orange),
                      SizedBox(width: 16),
                      Text('Uploading file...', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: messagesRef.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text("No messages yet",
                            style: TextStyle(fontSize: 16, color: Colors.white70)),
                      );
                    }
                    final messages = snapshot.data!.docs;
                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final doc = messages[index];
                        final message = doc.data() as Map<String, dynamic>;
                        final isCurrentUser = message['senderId'] == currentUser.uid;
                        
                        if (!isCurrentUser) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _markMessageAsDelivered(doc, currentUser.uid);
                            _markMessageAsRead(doc, currentUser.uid);
                          });
                        }
                        
                        final timestamp = message['timestamp']?.toDate();
                        final formattedTime = timestamp != null
                            ? DateFormat('h:mm a').format(timestamp)
                            : '';
                            
                        return MessageBubble(
                          messageText: message['text'] ?? '',
                          formattedTime: formattedTime,
                          isCurrentUser: isCurrentUser,
                          isDelivered: message['delivered'] ?? false,
                          isRead: message['read'] ?? false,
                          fileUrl: message['fileUrl'],
                          fileName: message['fileName'],
                          fileType: message['fileType'],
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  border: const Border(top: BorderSide(color: Colors.grey)),
                  color: Colors.grey[900],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file, color: Colors.white70),
                      onPressed: _isUploading ? null : _pickAndUploadFile,
                      tooltip: 'Attach file',
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        onChanged: (text) {
                          _updateTypingStatus(text.isNotEmpty ? currentUser.uid : '');
                        },
                        onSubmitted: (_) => _sendMessage(currentUser.uid),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Type a message...",
                          hintStyle: const TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[800],
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.orange),
                      onPressed: () => _sendMessage(currentUser.uid),
                      tooltip: 'Send message',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}