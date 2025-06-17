import 'package:chat_application/models/contact.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class ContactsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Contact>> getContacts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('contacts')
          .get();
      
      return snapshot.docs.map((doc) => Contact.fromMap(doc.data())).toList();
    } catch (e) {
      print('Error fetching contacts: $e');
      return [];
    }
  }
}