import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';

import 'PageComponents.dart';

class ProfilePage extends StatelessWidget {
  final String userId;

  ProfilePage({Key key, @required this.userId}) : super(key: key);

  Future<String> _getUsername(String uid) async {
    return await Firestore.instance.collection('/users').document(uid).get().then((snapshot) async {
      return snapshot.data['username'].toString();
    });
  }

  @override
  Widget build(BuildContext context) {
      return Scaffold(
        appBar: new AppBar(
            title: FutureBuilder(
              future: _getUsername(userId),
              builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.done:
                    if(snapshot.hasError)
                      return null;
                    return Text(snapshot.data);
                  default:
                    return Text('Loading...');
                }
              }),
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              color: Colors.white,
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            actions: <Widget>[
              FlatButton(
                  child: Text('Logout'),
                  textColor: Colors.white,
                  onPressed: () {
                    FirebaseAuth.instance.signOut().then((value) {
                      Navigator.of(context).pushReplacementNamed('/landingpage');
                    })
                        .catchError((e) {
                      print(e);
                    });
                  }
              ),
            ]
        ), //AppBar
        body: Container(
          child: Column(
            children: <Widget>[
              UserInfoSection(userId: userId),
              Divider(height: 5.0),
              Expanded(
                child: TimelineSection(idMap: {'userId': userId}),
              ),
            ]
          ),
        ),
      );
  }
}