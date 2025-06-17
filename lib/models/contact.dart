import 'package:cloud_firestore/cloud_firestore.dart';
// models/contact.dart
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

  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      profileImage: map['profileImage'],
    );
  }
  static Contact fromFirestore(dynamic doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Contact(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      profileImage: data['profileImage'],
    );
  }  
}

// services/contacts_service.dart
