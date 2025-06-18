import 'dart:io';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mime/mime.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:chat_application/location_picker_screen.dart';

class Contact {
  final String id;
  final String name;
  final String email;
  final String? profileImage;

  Contact({
    required this.id,
    required this.name,
    required this.email,
    this.profileImage,
  });

  factory Contact.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Contact(
      id: doc.id,
      name: data['name'] ?? 'No Name',
      email: data['email'] ?? '',
      profileImage: data['profileImage'],
    );
  }
}

class ContactsService {
  Future<List<Contact>> getContacts(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('contacts')
          .get();

      if (snapshot.docs.isEmpty) return [];

      return snapshot.docs.map((doc) => Contact.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error fetching contacts: $e');
      return [];
    }
  }
}

class CloudinaryConfig {
  static const String cloudName = 'dufgzsmfq';
  static const String uploadPreset = 'chatapp';
  static const String apiUrl =
      'https://api.cloudinary.com/v1_1/$cloudName/upload';
}

class CloudinaryService {
  static Future<String?> uploadFile(File file) async {
    try {
      final request =
          http.MultipartRequest('POST', Uri.parse(CloudinaryConfig.apiUrl));
      request.fields['upload_preset'] = CloudinaryConfig.uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData =
            await response.stream.transform(utf8.decoder).join();
        final data = json.decode(responseData);
        return data['secure_url'];
      }
    } catch (e) {
      print('Error uploading file: $e');
    }
    return null;
  }
}

class MessageBubble extends StatelessWidget {
  final String messageText;
  final String formattedTime;
  final bool isCurrentUser;
  final bool isDelivered;
  final bool isRead;
  final String? fileUrl;
  final String? fileName;
  final String? fileType;
  final String messageId;
  final String chatId;
  final Map<String, dynamic>? repliedMessage;
  final bool isForwarded;
  final String? otherUserName;
  final String? otherUserId;
  final bool isEdited;
  final bool isPinned;
  final Function()? onPinPressed;

  const MessageBubble({
    Key? key,
    required this.messageText,
    required this.formattedTime,
    required this.isCurrentUser,
    required this.isDelivered,
    required this.isRead,
    this.isEdited = false,
    this.isPinned = false,
    this.fileUrl,
    this.fileName,
    this.fileType,
    required this.messageId,
    required this.chatId,
    this.repliedMessage,
    this.isForwarded = false,
    required this.otherUserName,
    this.otherUserId,
    this.onPinPressed,
  }) : super(key: key);

  bool get isImage => fileType?.startsWith('image/') == true;
  bool get isVideo => fileType?.startsWith('video/') == true;
  bool get isAudio => fileType?.startsWith('audio/') == true;
  bool get isPdf => fileType?.contains('pdf') == true;
  bool get isLocation => fileType == 'location';
  bool get isDocument =>
      fileType?.contains('document') == true ||
      fileType?.contains('word') == true ||
      fileType?.contains('text') == true;

  Widget _buildReplyPreview(BuildContext context) {
    if (repliedMessage == null) return const SizedBox.shrink();

    final repliedText = repliedMessage!['text'] ?? '';
    final repliedSenderName = repliedMessage!['senderName'] ?? 'Unknown';
    final isCurrentUserReplied = repliedMessage!['isCurrentUser'] ?? false;
    final repliedFileUrl = repliedMessage!['fileUrl'];
    final repliedFileName = repliedMessage!['fileName'];

    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isCurrentUserReplied ? Colors.orange : Colors.grey,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Replying to $repliedSenderName',
            style: TextStyle(
              color: isCurrentUserReplied ? Colors.orange : Colors.grey[400],
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          if (repliedFileUrl != null)
            Text(
              repliedFileName ?? 'Attachment',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          if (repliedText.isNotEmpty)
            Text(
              repliedText,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final textEditingController = TextEditingController(text: messageText);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Message'),
          content: TextField(
            controller: textEditingController,
            decoration: const InputDecoration(
              hintText: 'Edit your message...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (textEditingController.text.trim().isNotEmpty &&
                    textEditingController.text != messageText) {
                  _editMessage(textEditingController.text);
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _editMessage(String newText) {
    FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'text': newText,
      'edited': true,
    });
  }

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
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FullScreenImageViewer(
            imageUrl: fileUrl!,
            fileName: fileName ?? 'Image',
          ),
        ),
      );
    } else {
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

  void _copyToClipboard(BuildContext context) {
    if (messageText.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: messageText));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message copied to clipboard'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _deleteMessage(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Delete Message',
              style: TextStyle(color: Colors.white)),
          content: const Text('Are you sure you want to delete this message?',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatId)
                    .collection('messages')
                    .doc(messageId)
                    .delete();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Message deleted'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _forwardMessage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ForwardMessageScreen(
          messageText: messageText,
          fileUrl: fileUrl,
          fileName: fileName,
          fileType: fileType,
          repliedMessage: repliedMessage,
          isForwarded: true,
        ),
      ),
    );
  }

  void _replyToMessage(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final Map<String, dynamic> replyData = {
      'messageId': messageId,
      'text': messageText,
      'senderId': isCurrentUser ? currentUser.uid : otherUserId,
      'senderName': isCurrentUser ? 'You' : otherUserName ?? 'Unknown',
      'isCurrentUser': isCurrentUser,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'timestamp': DateTime.now().toIso8601String(),
    };

    Navigator.of(context).pop();
    context
        .findAncestorStateOfType<ChatScreenState>()
        ?.setReplyingTo(replyData);
  }

  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCurrentUser) ...[
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.white70),
                  title:
                      const Text('Edit', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDialog(context);
                  },
                ),
                ListTile(
                  leading: Icon(
                    isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    color: Colors.white70,
                  ),
                  title: Text(
                    isPinned ? 'Unpin' : 'Pin',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (onPinPressed != null) onPinPressed!();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title:
                      const Text('Delete', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(context);
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.reply, color: Colors.white70),
                title:
                    const Text('Reply', style: TextStyle(color: Colors.white)),
                onTap: () => _replyToMessage(context),
              ),
              ListTile(
                leading: const Icon(Icons.forward, color: Colors.white70),
                title: const Text('Forward',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _forwardMessage(context);
                },
              ),
              if (messageText.isNotEmpty)
                ListTile(
                  leading:
                      const Icon(Icons.content_copy, color: Colors.white70),
                  title:
                      const Text('Copy', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _copyToClipboard(context);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.white70),
                title:
                    const Text('Cancel', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationPreview(BuildContext context) {
    if (!isLocation || fileUrl == null) return const SizedBox.shrink();

    try {
      final latLng = fileUrl!.split(',');
      final lat = double.parse(latLng[0]);
      final lng = double.parse(latLng[1]);
      final staticMapUrl =
          'https://maps.googleapis.com/maps/api/staticmap?center=$lat,$lng&zoom=15&size=600x300&maptype=roadmap&markers=color:red%7C$lat,$lng&key=AIzaSyAj9n8GkUH-8Qev5B98MpvFtrGJggmTXQU';

      return GestureDetector(
        onTap: () => _openLocationInMaps(lat, lng),
        child: Column(
          children: [
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: staticMapUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.orange,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.error, color: Colors.white70),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              fileName ?? 'Shared Location',
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to open in maps',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return const Text('Invalid location data',
          style: TextStyle(color: Colors.red));
    }
  }

  void _openLocationInMaps(double lat, double lng) async {
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isCurrentUser ? Colors.orange : Colors.grey[850];
    final alignment =
        isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Align(
        alignment: alignment,
        child: GestureDetector(
          onLongPress: () => _showMessageOptions(context),
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
                if (isForwarded)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.forward,
                            size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          'Forwarded',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (repliedMessage != null) ...[
                  _buildReplyPreview(context),
                  const SizedBox(height: 8),
                ],
                if (fileUrl != null && !isLocation) ...[
                  _buildFilePreview(context),
                  if (messageText.isNotEmpty) const SizedBox(height: 8),
                ],
                if (isLocation) ...[
                  _buildLocationPreview(context),
                  if (messageText.isNotEmpty) const SizedBox(height: 8),
                ],
                if (messageText.isNotEmpty)
                  Text(
                    messageText,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                if (isEdited)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'edited',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                if (formattedTime.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formattedTime,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        if (isCurrentUser) ...[
                          if (isRead)
                            const Icon(Icons.done_all,
                                color: Colors.green, size: 16)
                          else if (isDelivered)
                            const Icon(Icons.done,
                                color: Colors.grey, size: 16),
                        ],
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

class ForwardMessageScreen extends StatefulWidget {
  final String messageText;
  final String? fileUrl;
  final String? fileName;
  final String? fileType;
  final Map<String, dynamic>? repliedMessage;
  final bool isForwarded;

  const ForwardMessageScreen({
    Key? key,
    required this.messageText,
    this.fileUrl,
    this.fileName,
    this.fileType,
    this.repliedMessage,
    this.isForwarded = false,
  }) : super(key: key);

  @override
  State<ForwardMessageScreen> createState() => _ForwardMessageScreenState();
}

class _ForwardMessageScreenState extends State<ForwardMessageScreen> {
  final ContactsService _contactsService = ContactsService();
  List<Contact> _contacts = [];
  final Set<String> _selectedContacts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not authenticated')),
          );
        }
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final contacts = await _contactsService.getContacts(currentUser.uid);
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading contacts: $e')),
        );
      }
    }
  }

  void _toggleContactSelection(String contactId) {
    setState(() {
      if (_selectedContacts.contains(contactId)) {
        _selectedContacts.remove(contactId);
      } else {
        _selectedContacts.add(contactId);
      }
    });
  }

  Future<void> _forwardToSelectedContacts() async {
    if (_selectedContacts.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      for (String contactId in _selectedContacts) {
        final chatQuery = await FirebaseFirestore.instance
            .collection('chats')
            .where('users', arrayContains: currentUser.uid)
            .where('users', arrayContains: contactId)
            .limit(1)
            .get();

        String chatId;
        if (chatQuery.docs.isEmpty) {
          final newChatRef =
              await FirebaseFirestore.instance.collection('chats').add({
            'users': [currentUser.uid, contactId],
            'createdAt': FieldValue.serverTimestamp(),
            'lastMessage': widget.messageText.isNotEmpty
                ? widget.messageText
                : (widget.fileName ?? 'Attachment'),
            'lastMessageTime': FieldValue.serverTimestamp(),
          });
          chatId = newChatRef.id;
        } else {
          chatId = chatQuery.docs.first.id;
        }

        final messageData = {
          'text': widget.messageText,
          'senderId': currentUser.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'delivered': false,
          'read': false,
          'isForwarded': true,
        };
        if (widget.fileType == 'location') {
          messageData['fileUrl'] = widget.fileUrl!;
          messageData['fileName'] = widget.fileName ?? 'Location';
          messageData['fileType'] = 'location';
          if (widget.fileUrl != null) {
            messageData['fileUrl'] = widget.fileUrl!;
            messageData['fileName'] = widget.fileName ?? 'File';
            messageData['fileType'] =
                widget.fileType ?? 'application/octet-stream';
          }

          if (widget.repliedMessage != null) {
            messageData['repliedMessage'] = widget.repliedMessage!;
          }

          await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .add(messageData);
        }

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Message forwarded to ${_selectedContacts.length} contacts'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error forwarding message: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forward to'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadContacts,
          ),
          if (_selectedContacts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _forwardToSelectedContacts,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No contacts available'),
                      TextButton(
                        onPressed: _loadContacts,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    return CheckboxListTile(
                      title: Text(contact.name),
                      subtitle: Text(contact.email),
                      value: _selectedContacts.contains(contact.id),
                      onChanged: (_) => _toggleContactSelection(contact.id),
                      secondary: CircleAvatar(
                        backgroundColor: Colors.grey[300],
                        backgroundImage: contact.profileImage != null
                            ? NetworkImage(contact.profileImage!)
                            : null,
                        child: contact.profileImage == null
                            ? Text(contact.name[0])
                            : null,
                      ),
                    );
                  },
                ),
    );
  }
}

class ChatInfoScreen extends StatelessWidget {
  final String chatId;
  final Map<String, dynamic>? chatInfo;

  const ChatInfoScreen({
    Key? key,
    required this.chatId,
    this.chatInfo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Fixed error: Properly cast values from Map
    final isGroup = chatInfo?['isGroup'] as bool? ?? false;
    final users = chatInfo?['users'] as List<dynamic>? ?? [];
    final groupName = chatInfo?['name'] as String? ?? 'Group Chat';
    final groupDescription = chatInfo?['description'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Info'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.orange[100],
                    child:
                        const Icon(Icons.group, size: 50, color: Colors.orange),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isGroup ? groupName : 'User Name',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isGroup && groupDescription.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        groupDescription,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Media, Links, and Docs'),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              children: List.generate(9, (index) {
                return Container(
                  margin: const EdgeInsets.all(2),
                  color: Colors.grey[300],
                  child: const Icon(Icons.image),
                );
              }),
            ),
            const SizedBox(height: 24),
            if (isGroup) ...[
              _buildSectionTitle('Participants (${users.length})'),
              ...List.generate(users.length, (index) {
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(users[index] as String)
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final user =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      return ListTile(
                        leading: const CircleAvatar(),
                        title: Text(user?['name'] as String? ?? 'Unknown'),
                        subtitle: Text(user?['email'] as String? ?? ''),
                      );
                    }
                    return const ListTile(
                      leading: CircleAvatar(),
                      title: Text('Loading...'),
                    );
                  },
                );
              }),
            ],
            const SizedBox(height: 24),
            _buildSectionTitle('Chat Actions'),
            _buildActionTile(
              icon: Icons.notifications,
              title: 'Mute Notifications',
              onTap: () {},
            ),
            _buildActionTile(
              icon: Icons.wallpaper,
              title: 'Change Wallpaper',
              onTap: () {},
            ),
            _buildActionTile(
              icon: Icons.block,
              title: 'Block User',
              onTap: () {},
              color: Colors.red,
            ),
            _buildActionTile(
              icon: Icons.delete,
              title: 'Delete Chat',
              onTap: () {},
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String chatId;

  const ChatScreen({
    Key? key,
    required this.chatId,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final Stream<DocumentSnapshot> _chatDocStream;
  DocumentSnapshot? _chatInfo;
  String? _otherUserName;
  String? _otherUserId;
  bool _isUploading = false;
  Map<String, dynamic>? _replyingTo;
  String? _pinnedMessageId;

  void _scrollToMessage(String messageId) {
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void setReplyingTo(Map<String, dynamic>? message) {
    if (mounted) {
      setState(() {
        _replyingTo = message;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPinnedMessage();
    _chatDocStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .snapshots();
    _fetchChatInfo();
    _fetchOtherUserId();
    _fetchOtherUserName();
  }

  Future<void> _loadPinnedMessage() async {
    final doc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .get();

    if (doc.exists && doc.data()?.containsKey('pinnedMessageId') == true) {
      setState(() {
        _pinnedMessageId = doc['pinnedMessageId'] as String?;
      });
    }
  }

  Future<void> _togglePinMessage(String messageId) async {
    try {
      final chatRef =
          FirebaseFirestore.instance.collection('chats').doc(widget.chatId);

      if (_pinnedMessageId == messageId) {
        await chatRef.update({'pinnedMessageId': FieldValue.delete()});
        setState(() => _pinnedMessageId = null);
      } else {
        await chatRef.update({'pinnedMessageId': messageId});
        setState(() => _pinnedMessageId = messageId);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pin message: $e')),
      );
    }
  }

  Widget _buildPinnedMessageIndicator() {
    if (_pinnedMessageId == null) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(_pinnedMessageId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final message = snapshot.data!.data() as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: Colors.orange, width: 4)),
          ),
          child: ListTile(
            leading: const Icon(Icons.push_pin, color: Colors.orange, size: 20),
            title: Text(
              message['text'] ?? 'Pinned message',
              style: const TextStyle(color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => _togglePinMessage(_pinnedMessageId!),
            ),
            onTap: () => _scrollToMessage(_pinnedMessageId!),
          ),
        );
      },
    );
  }

  Future<void> _fetchChatInfo() async {
    final doc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        _chatInfo = doc;
      });
    }
  }

  Future<void> _fetchOtherUserId() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final chatDoc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .get();

    if (chatDoc.exists && mounted) {
      final users = List<String>.from(chatDoc.data()?['users'] ?? []);
      setState(() {
        _otherUserId = users.firstWhere((id) => id != currentUserId);
      });
    }
  }

  Future<void> _fetchOtherUserName() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final chatDoc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .get();

    if (chatDoc.exists) {
      final users = List<String>.from(chatDoc.data()?['users'] ?? []);
      final otherUserId = users.firstWhere((id) => id != currentUserId);

      final otherUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .get();

      if (otherUserDoc.exists && mounted) {
        setState(() {
          _otherUserName = otherUserDoc.data()?['name'] as String?;
        });
      }
    }
  }

  void _sendMessage(String currentUserId,
      {String? fileUrl, String? fileName, String? fileType}) {
    final messageText = _messageController.text.trim();
    if (messageText.isNotEmpty || fileUrl != null) {
      final messageData = {
        'text': messageText,
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'delivered': false,
        'read': false,
      };

      if (_replyingTo != null) {
        messageData['repliedMessage'] = {
          'messageId': _replyingTo!['messageId'],
          'text': _replyingTo!['text'],
          'senderId': _replyingTo!['senderId'],
          'senderName': _replyingTo!['senderName'],
          'isCurrentUser': _replyingTo!['isCurrentUser'],
          'fileName': _replyingTo!['fileName'],
          'fileUrl': _replyingTo!['fileUrl'],
          'fileType': _replyingTo!['fileType'],
          'timestamp': _replyingTo!['timestamp'],
        };
      }

      if (fileUrl != null) {
        messageData['fileUrl'] = fileUrl;
        messageData['fileName'] = fileName ?? 'File';
        messageData['fileType'] = fileType ?? 'application/octet-stream';
      }

      FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add(messageData)
          .then((_) {
        FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .update({
          'lastMessage':
              messageText.isNotEmpty ? messageText : (fileName ?? 'Attachment'),
          'lastMessageTime': FieldValue.serverTimestamp(),
        });
      });

      _messageController.clear();
      _updateTypingStatus('');
      _scrollToBottom();

      if (mounted) {
        setState(() {
          _replyingTo = null;
        });
      }
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
        String? fileType =
            lookupMimeType(file.path) ?? 'application/octet-stream';

        final fileUrl = await CloudinaryService.uploadFile(file);

        setState(() {
          _isUploading = false;
        });

        if (fileUrl != null) {
          _sendMessage(
            FirebaseAuth.instance.currentUser!.uid,
            fileUrl: fileUrl,
            fileName: fileName,
            fileType: fileType,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting file: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _pickLocation() async {
    final location = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          onLocationSelected: (location, address) {
            Navigator.of(context).pop(location);
            _sendLocation(location, address);
          },
        ),
      ),
    );

    if (location != null) {
      _sendLocation(location, null);
    }
  }

  void _sendLocation(LatLng location, String? address) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final messageData = {
      'text': address ?? 'Location shared',
      'senderId': currentUserId,
      'timestamp': FieldValue.serverTimestamp(),
      'delivered': false,
      'read': false,
      'fileUrl': '${location.latitude},${location.longitude}',
      'fileName': address ?? 'My Location',
      'fileType': 'location',
    };

    FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add(messageData)
        .then((_) {
      FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
        'lastMessage': 'Location shared',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    });
  }

  void _showChatInfo() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatInfoScreen(
          chatId: widget.chatId,
          chatInfo: _chatInfo?.data() as Map<String, dynamic>?,
        ),
      ),
    );
  }

  void _cancelReply() {
    if (mounted) {
      setState(() {
        _replyingTo = null;
      });
    }
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
          child:
              Text("User not logged in", style: TextStyle(color: Colors.white)),
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
                      if (typingUser.isNotEmpty &&
                          typingUser != currentUser.uid) {
                        typingIndicator = "User is typing...";
                      }
                    }
                  }
                  return typingIndicator.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            typingIndicator,
                            style: TextStyle(
                                color: Colors.orange[200], fontSize: 14),
                          ),
                        )
                      : const SizedBox.shrink();
                },
              ),
              _buildPinnedMessageIndicator(),
              if (_replyingTo != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[700]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Replying to ${_replyingTo!['senderName']}',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 14,
                              ),
                            ),
                            if (_replyingTo!['fileUrl'] != null)
                              Text(
                                _replyingTo!['fileName'] ?? 'Attachment',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            if (_replyingTo!['text'] != null &&
                                _replyingTo!['text'].isNotEmpty)
                              Text(
                                _replyingTo!['text'],
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: _cancelReply,
                      ),
                    ],
                  ),
                ),
              if (_isUploading)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.orange),
                      SizedBox(width: 16),
                      Text('Uploading file...',
                          style: TextStyle(color: Colors.white)),
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
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.orange),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text("No messages yet",
                            style:
                                TextStyle(fontSize: 16, color: Colors.white70)),
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
                        final isCurrentUser =
                            message['senderId'] == currentUser.uid;
                        final isPinned = doc.id == _pinnedMessageId;

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
                          isEdited: message['edited'] ?? false,
                          isPinned: isPinned,
                          fileUrl: message['fileUrl'],
                          fileName: message['fileName'],
                          fileType: message['fileType'],
                          messageId: doc.id,
                          chatId: widget.chatId,
                          repliedMessage: message['repliedMessage'],
                          isForwarded: message['isForwarded'] ?? false,
                          otherUserName: _otherUserName,
                          otherUserId: _otherUserId,
                          onPinPressed: () => _togglePinMessage(doc.id),
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  border: const Border(top: BorderSide(color: Colors.grey)),
                  color: Colors.grey[900],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.attach_file, color: Colors.white70),
                      onPressed: _isUploading ? null : _pickAndUploadFile,
                      tooltip: 'Attach file',
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.location_on, color: Colors.white70),
                      onPressed: _isUploading ? null : _pickLocation,
                      tooltip: 'Share location',
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        onChanged: (text) {
                          _updateTypingStatus(
                              text.isNotEmpty ? currentUser.uid : '');
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
