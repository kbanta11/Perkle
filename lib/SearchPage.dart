import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'ProfilePage.dart';

import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';


class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  DocumentReference userDoc;

  @override
  void initState() {
    userDoc = await UserManagement().getUserData();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: new AppBar(
        title: Text('Search Users'),
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
        child: StreamBuilder<QuerySnapshot>(
          stream: Firestore.instance.collection('users').snapshots(),
          builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if(snapshot.hasError){
              return Text('Error: ${snapshot.error}');
            }
            switch (snapshot.connectionState) {
              case ConnectionState.waiting:
                return Text('Loading Users...');
              default:
                return ListView(
                  children: snapshot.data.documents.map((document) {
                    return Column(
                      children: <Widget>[
                        ListTile(
                          leading: CircleAvatar(),
                          title: Text(document['username']),
                          trailing: IconButton(
                            icon: Icon(Icons.person_add),
                            color: Colors.deepPurple,
                            onPressed: () {
                              print('now following ${document['username']}');
                            }
                          ),
                          onTap: () {
                            print('go to user profile: ${document['uid']}');
                            Navigator.push(context, MaterialPageRoute(
                              builder: (context) => ProfilePage(userId: document['uid']),
                            ));
                          }
                        ),
                        Divider(height: 5.0),
                      ]
                    );
                  }).toList(),
                );
            }
          }
        ),
      ),
    );
  }
}