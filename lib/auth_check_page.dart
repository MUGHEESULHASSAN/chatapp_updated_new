import 'package:chat_application/chats_page.dart';
import 'package:chat_application/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';


class AuthCheckPage extends StatelessWidget{
  const AuthCheckPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              print(snapshot);
              //logged in
              if (snapshot.hasData){
                return ChatsPage();
              }
              else {
                return LoginPage();
              }
            }
        )
    );
  }
}