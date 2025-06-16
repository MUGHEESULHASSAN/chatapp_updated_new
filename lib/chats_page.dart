import 'dart:async';
import 'package:chat_application/chat_bot_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'chat_page.dart';
import 'login_page.dart'; // Make sure to import your LoginPage

// ChatsPage: displays either a list of user search results or the user's existing chats.
class ChatsPage extends StatefulWidget {
  const ChatsPage({Key? key}) : super(key: key);

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  String searchQuery = "";
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        searchQuery = value.trim();
      });
    });
  }

  // Logout functionality
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      return Scaffold(
        body: const Center(
          child: Text("User not logged in", style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final usersRef = FirebaseFirestore.instance.collection('users');
    final chatsRef = FirebaseFirestore.instance.collection('chats');

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
      
        title: const Text(
          'Chats',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.orange),
            tooltip: 'Logout',
          ),
        ],
      ),
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
            // Search field with debounce
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Search by name or email',
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.search, color: Colors.orange),
                  filled: true,
                  fillColor: Colors.grey[800],
                ),
              ),
            ),
            Expanded(
              child: searchQuery.isNotEmpty
              // Show search results based on users collection
                  ? StreamBuilder<QuerySnapshot>(
                stream: usersRef
                    .where('name', isGreaterThanOrEqualTo: searchQuery)
                    .where('name', isLessThanOrEqualTo: searchQuery + '\uf8ff')
                    .snapshots(),
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
                      child: Text("No users found", style: TextStyle(color: Colors.white70)),
                    );
                  }
                  final users = snapshot.data!.docs;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index].data() as Map<String, dynamic>;
                      final userName = user['name'] ?? 'Unknown User';
                      final userEmail = user['email'] ?? 'No Email';
                      final otherUserId = users[index].id;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        color: Colors.grey[900],
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange,
                            child: Text(
                              userName.substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(userName,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          subtitle: Text(userEmail, style: const TextStyle(color: Colors.white70)),
                          onTap: () async {
                            // Check if a chat exists between current user and selected user.
                            final existingChatQuery = await chatsRef
                                .where('users', arrayContains: currentUserId)
                                .get();

                            String? chatId;
                            for (var chat in existingChatQuery.docs) {
                              final chatUsers = List<String>.from(chat['users']);
                              if (chatUsers.contains(otherUserId)) {
                                chatId = chat.id;
                                break;
                              }
                            }
                            if (chatId == null) {
                              // Create new chat if none exists.
                              final newChatDoc = await chatsRef.add({
                                'users': [currentUserId, otherUserId],
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                              chatId = newChatDoc.id;
                            }
                            if (chatId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(chatId: chatId!),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              )
              // Show the user's existing chats.
                  : StreamBuilder<QuerySnapshot>(
                stream: chatsRef.where('users', arrayContains: currentUserId).snapshots(),
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
                      child: Text("No chats found", style: TextStyle(color: Colors.white70)),
                    );
                  }
                  final chats = snapshot.data!.docs;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: chats.length,
                    itemBuilder: (context, index) {
                      final chat = chats[index].data() as Map<String, dynamic>;
                      final users = List<String>.from(chat['users']);
                      final otherUserId = users.firstWhere((id) => id != currentUserId);
                      final chatId = chats[index].id;
                      return FutureBuilder<DocumentSnapshot>(
                        future: usersRef.doc(otherUserId).get(),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.connectionState == ConnectionState.waiting) {
                            return const ListTile(
                              title: Text('Loading...', style: TextStyle(color: Colors.white)),
                            );
                          }
                          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                            return const ListTile(
                              title: Text('User not found', style: TextStyle(color: Colors.white)),
                            );
                          }
                          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                          final userName = userData['name'] ?? 'Unknown User';
                          final userEmail = userData['email'] ?? 'No Email';
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            color: Colors.grey[900],
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              leading: CircleAvatar(
                                backgroundColor: Colors.orange,
                                child: Text(
                                  userName.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(userName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              subtitle: Text(userEmail, style: const TextStyle(color: Colors.white70)),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(chatId: chatId),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatbotScreen()
            ),
          );
        },
        backgroundColor: Colors.orange,
        child: const Icon(Icons.smart_toy, color: Colors.white),
      ),
    );
  }
}