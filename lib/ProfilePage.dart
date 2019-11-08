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
        appBar: new AppBar(
          title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                FutureBuilder(
                  future: FirebaseAuth.instance.currentUser(),
                  builder: (context, snapshot) {
                    if(snapshot.hasData){
                      String _userId = snapshot.data.uid;
                      return StreamBuilder(
                          stream: Firestore.instance.collection('users').document(_userId).snapshots(),
                          builder: (context, snapshot) {
                            if(snapshot.hasData) {
                              String profilePicUrl = snapshot.data['profilePicUrl'];
                            if(profilePicUrl != null)
                              return Container(
                                height: 40.0,
                                width: 40.0,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  image: DecorationImage(
                                    fit: BoxFit.cover,
                                    image: NetworkImage(profilePicUrl.toString()),
                                  )
                                ),
                              );
                            }
                            return Container(
                            height: 40.0,
                            width: 40.0,
                            decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            // image: DecorationImage()
                            ),
                            );
                          }
                      );
                    }
                    return Container(
                      height: 40.0,
                      width: 40.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        // image: DecorationImage()
                      ),
                    );
                  }
                ),
                IconButton(
                  icon: Icon(Icons.search),
                  iconSize: 40.0,
                  onPressed: () {
                    Navigator.of(context).pushNamed('/searchpage');
                  },
                ),
                Expanded(
                  child: Center(
                      child: FutureBuilder(
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
                  ),
                ),
              ]
          ),
          centerTitle: true,
          automaticallyImplyLeading: false,
          titleSpacing: 5.0,
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: Colors.white),
              iconSize: 40.0,
            ),
            RecordButton(),
            /*new FlatButton(
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
          ),*/
          ],
        ),
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

        bottomNavigationBar: bottomNavBar(_onItemTapped, _selectedIndex),
      );
  }
}