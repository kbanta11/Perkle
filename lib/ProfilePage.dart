import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';

import 'PageComponents.dart';
import 'HomePage.dart';
import 'ListPage.dart';

class ProfilePage extends StatefulWidget {
  final String userId;

  ProfilePage({Key key, @required this.userId}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String userId;
  int _selectedIndex = 3;

  void _onItemTapped(int index) async {
    if(index == 0) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => HomePage(),
      ));
    }
    if(index == 2) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ListPage(type: 'conversation'),
      ));
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<String> _getUsername(String uid) async {
    return await Firestore.instance.collection('/users').document(uid).get().then((snapshot) async {
      return snapshot.data['username'].toString();
    });
  }

  @override
  void initState() {
    userId = widget.userId;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
      return Scaffold(

        body: Container(
          child: Column(
            children: <Widget>[
              topPanel(context),
              SizedBox(height: 5.0),
              UserInfoSection(userId: userId),
              Divider(height: 1.0),
              Expanded(
                child: TimelineSection(idMap: {'userId': userId}),
              ),
            ]
          ),
        ),

        bottomNavigationBar: bottomNavBar(_onItemTapped, _selectedIndex),
      );
  }
}