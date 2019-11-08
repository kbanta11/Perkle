import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'PageComponents.dart';
import 'ProfilePage.dart';
import 'ListPage.dart';

import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<FirebaseUser> currentUser = FirebaseAuth.instance.currentUser();
  DocumentReference userDoc;
  int _selectedIndex = 0;

  void _onItemTapped(int index) async {
    String uid = await _getUID();
    if(index == 3) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ProfilePage(userId: uid),
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

  Future<String> _getUID() async {
    return await currentUser.then((user) async {
      return user.uid.toString();
    });
  }

  _HomePageState () {
    UserManagement().getUserData().then((DocumentReference doc) => setState(() {
      userDoc = doc;
    }));
  }

  @override
  void initState() {

    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _showUsernameDialog(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      Navigator.of(context).pushReplacementNamed('/landingpage');
    }

    return new Scaffold(
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
              child: Center(child: new Text('Perkle')),
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
          child: new Padding(
            padding: EdgeInsets.only(top: 10.0, right: 5.0, left: 5.0, bottom: 5.0),
            child: new Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                /*
                FutureBuilder(
                    future: _getUID(),
                    builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                      print('UID in Future Builder: ${snapshot.data}');
                      return UserInfoSection(userId: snapshot.data);
                  }
                ),
                Divider(
                  height: 10.0
                ),
                */
                Expanded(
                  child:  Container(
                    child: FutureBuilder(
                      future: UserManagement().getUserData().then((document) {
                        return document.get().then((snapshot) {
                          return snapshot.data['mainFeedTimelineId'].toString();
                        });
                      }),
                      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                        if(snapshot == null || snapshot.data == 'null')
                          return Text('Your feed is empty! Start following users to fill your feed.');
                        print('Setting timeline id: ${snapshot.data}');
                        return  TimelineSection(idMap: {'timelineId': snapshot.data});
                      }
                    ),
                  )
                ),
              ],
            ),
          ),
        ),

      bottomNavigationBar: bottomNavBar(_onItemTapped, _selectedIndex),
    );
  }
}


// Show Username dialog
Future<void> _showUsernameDialog(BuildContext context) async {
  String username = await UserManagement().getUserData().then((DocumentReference doc) {
    return doc.get().then((DocumentSnapshot snapshot) {
      return snapshot.data['username'].toString();
    });
  });
  print('username (in dialog): $username-------------');
  if (username == null || username == '' || username == 'null'){
    print('showing username dialog-----------');
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return new WillPopScope(
            onWillPop: () async => false,
            child: UsernameDialog(),
          );
        }
    );
  } else {
    print('show dialog if evaluating false');
  }
  print('show dialog if state skipped?');
  return null;
}





