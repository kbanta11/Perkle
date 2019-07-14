import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';

import 'PageComponents.dart';
import 'HomePage.dart';

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

        bottomNavigationBar: BottomNavigationBar(
          items: <BottomNavigationBarItem> [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              title: Text('Home'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.playlist_play),
              title: Text('Playlists'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.group),
              title: Text('Groups'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle),
              title: Text('Profile'),
            ),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          fixedColor: Colors.deepPurple,
          type: BottomNavigationBarType.fixed,
        ),
      );
  }
}