import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'ProfilePage.dart';
import 'PageComponents.dart';
import 'ListPage.dart';
import 'HomePage.dart';

import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';


class SearchPage extends StatefulWidget {
  ActivityManager activityManager;

  SearchPage({Key key, this.activityManager}) : super(key: key);

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  DocumentReference userDoc;
  int _selectedIndex = 1;

  void _onItemTapped(int index) async {
    String uid = await _getUID();
    if(index == 0) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => HomePage(activityManager: widget.activityManager,),
      ));
    }
    if(index == 3) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ProfilePage(userId: uid, activityManager: widget.activityManager,),
      ));
    }
    if(index == 2) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ListPage(type: 'conversation', activityManager: widget.activityManager,),
      ));
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<String> _getUID() async {
    Future<FirebaseUser> currentUser = FirebaseAuth.instance.currentUser();
    return await currentUser.then((user) async {
      return user.uid.toString();
    });
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          topPanel(context, widget.activityManager),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
                stream: Firestore.instance.collection('users').snapshots(),
                builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  switch (snapshot.connectionState) {
                    case ConnectionState.waiting:
                      return Text('Loading Users...');
                    default:
                      return ListView(
                        children: snapshot.data.documents.map((document) {
                          String thisUserId = document.reference.documentID;

                          Widget followButton = IconButton(
                              icon: Icon(Icons.person_add),
                              color: Colors.deepPurple,
                              onPressed: () {
                                ActivityManager().followUser(document.reference.documentID);
                                print('now following ${document['username']}');
                              }
                          );

                          return Column(
                              children: <Widget>[
                                ListTile(
                                    leading: StreamBuilder(
                                        stream: Firestore.instance.collection('users').document(thisUserId).snapshots(),
                                        builder: (context, snapshot) {
                                          if(snapshot.hasData){
                                            String profilePicUrl = snapshot.data['profilePicUrl'];
                                            if(profilePicUrl != null)
                                              return Container(
                                                  height: 50.0,
                                                  width: 50.0,
                                                  decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.deepPurple,
                                                      image: DecorationImage(
                                                          fit: BoxFit.cover,
                                                          image: NetworkImage(profilePicUrl.toString())
                                                      )
                                                  )
                                              );
                                          }
                                          return Container(
                                              height: 50.0,
                                              width: 50.0,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.deepPurple,
                                              )
                                          );
                                        }
                                    ),
                                    title: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: <Widget>[
                                          Expanded(
                                              child: Text(document['username'])
                                          ),
                                          Container(
                                              height: 40.0,
                                              width: 40.0,
                                              child: FutureBuilder(
                                                  future: UserManagement().getUserData(),
                                                  builder: (context, snapshot) {
                                                    if(snapshot.hasData) {
                                                      return StreamBuilder(
                                                          stream: snapshot.data.snapshots(),
                                                          builder: (context, snapshot) {
                                                            if(snapshot.hasData) {
                                                              bool isFollowing = false;
                                                              String userId = snapshot.data.reference.documentID;
                                                              bool isThisUser = userId == thisUserId;
                                                              if(snapshot.data['following'] != null) {
                                                                Map<dynamic, dynamic> followingList = snapshot.data['following'];
                                                                isFollowing = followingList.containsKey(thisUserId);
                                                              }
                                                              print('Following: $isFollowing');
                                                              if(!isThisUser && !isFollowing)
                                                                return followButton;
                                                              else
                                                                return Container();
                                                            }
                                                            return Container();
                                                          }
                                                      );
                                                    }
                                                    return Container();
                                                  })
                                          )
                                        ]
                                    ),
                                    onTap: () {
                                      print(
                                          'go to user profile: ${document['uid']}');
                                      Navigator.push(context, MaterialPageRoute(
                                        builder: (context) =>
                                            ProfilePage(
                                                userId: document['uid'], activityManager: widget.activityManager,),
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
          )
        ]
      ),
      bottomNavigationBar: bottomNavBar(_onItemTapped, _selectedIndex),
    );
  }
}