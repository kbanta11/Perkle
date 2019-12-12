import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'ConversationPage.dart';
import 'PageComponents.dart';
import 'HomePage.dart';
import 'ProfilePage.dart';
import 'ListPage.dart';

import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';

class DiscoverPage extends StatefulWidget {
  ActivityManager activityManager;

  DiscoverPage({Key key, this.activityManager}) : super(key: key);

  @override
  _DiscoverPageState createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  Future<FirebaseUser> currentUser = FirebaseAuth.instance.currentUser();
  DocumentReference userDoc;
  int _selectedIndex = 1;
  int selectedTab = 1;
  String tagValue;
  String selectedCat = 'StreamTag';

  void _onItemTapped(int index, {ActivityManager actManage}) async {
    print('Activity Manager: $actManage');
    String uid = await _getUID();
    if(index == 3) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ProfilePage(userId: uid, activityManager: widget.activityManager),
      ));
    }
    if(index == 2) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ListPage(type: 'conversation', activityManager: widget.activityManager),
      ));
    }
    if(index == 0) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => HomePage(activityManager: widget.activityManager,),
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

  Future<void> getTagValue(int tabIndex) async {
    String _value = await Firestore.instance.collection('discover').where('rank', isEqualTo: tabIndex).getDocuments().then((snap) {
      return snap.documents.first.data['value'];
    });
    setState(() {
      tagValue = _value;
      selectedTab = tabIndex;
    });
  }

  @override
  void initState() {
    getTagValue(selectedTab);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    print('Discover Page Activity Manager: ${widget.activityManager}');
    return new Scaffold(
      body: Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            topPanel(context, widget.activityManager),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                FlatButton(
                  child: Text('StreamTags',
                    style: TextStyle(color: selectedCat == 'StreamTag' ? Colors.white : Colors.deepPurple),
                  ),
                  color: selectedCat == 'StreamTag' ? Colors.deepPurple : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                    side: BorderSide(color: Colors.deepPurple),
                  ),
                  onPressed: () {
                    setState(() {
                      selectedCat = 'StreamTag';
                    });
                  },
                ),
                FlatButton(
                  child: Text('People',
                    style: TextStyle(color: selectedCat == 'People' ? Colors.white : Colors.deepPurple),
                  ),
                  color: selectedCat == 'People' ? Colors.deepPurple : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                    side: BorderSide(color: Colors.deepPurple),
                  ),
                  onPressed: () {
                    setState(() {
                      selectedCat = 'People';
                    });
                  },
                ),
              ]
            ),
            selectedCat == 'StreamTag' ? Expanded(
              child: Column(
                  children: <Widget>[
                    FutureBuilder(
                        future: Firestore.instance.collection('discover').where('type', isEqualTo: 'StreamTag').orderBy('rank').getDocuments(),
                        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                          if(!snapshot.hasData)
                            return Container();
                          return Container(
                              height: 35.0,
                              child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: snapshot.data.documents.map((document) {
                                    int tagRank = document.data['rank'];
                                    bool isSelected = false;
                                    if(tagRank == selectedTab)
                                      isSelected = true;
                                    return FlatButton(
                                      color: isSelected ? Colors.deepPurple : Colors.white,
                                      child: Text('#${document.data['value']}',
                                        style: TextStyle(color: isSelected ? Colors.white : Colors.deepPurple),
                                      ),
                                      onPressed: () {
                                        getTagValue(tagRank);
                                      },
                                    );
                                  }).toList()
                              )
                          );
                        }
                    ),
                    Padding(
                        padding: EdgeInsets.only(top: 5.0, right: 5.0, left: 5.0, bottom: 5.0),
                        child:Container(
                          child: new FutureBuilder(
                              future: UserManagement().getUserData().then((document) {
                                return document.get().then((snapshot) {
                                  return snapshot.data['mainFeedTimelineId'].toString();
                                });
                              }),
                              builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                                if(snapshot == null || snapshot.data == 'null')
                                  return Text('Your feed is empty! Start following users to fill your feed.');
                                print('Setting timeline id: ${snapshot.data}');
                                return  TimelineSection(streamTag: tagValue, activityManager: widget.activityManager,);
                              }
                          ),
                        )
                    )
                  ]
              ),
            ) :
            Expanded(
              child: StreamBuilder(
                  stream: Firestore.instance.collection('requests').document('discover').snapshots(),
                  builder: (BuildContext context, AsyncSnapshot snapshot) {
                    List results;
                    try {
                      results = snapshot.data['results'];
                    } catch(e) {
                      return Center(child: Text('There are no results for this search...'));
                    }

                    if(results == null)
                      return Center(child: CircularProgressIndicator());

                    if(results.length == 0)
                      return Center(child: Text('There are no results for this search...'));

                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }

                    if(snapshot == null || snapshot.data == null)
                      return Container();
                    switch (snapshot.connectionState) {
                      case ConnectionState.waiting:
                        return Center(child: CircularProgressIndicator());
                      default:
                        return ListView(
                          children: snapshot.data['results'].map<Widget>((userId) {
                            print(userId);
                            return StreamBuilder(
                                stream: Firestore.instance.collection('users').document(userId).snapshots(),
                                builder: (BuildContext context, AsyncSnapshot snapshot) {
                                  print(snapshot.data);
                                  if(!snapshot.hasData)
                                    return Container();
                                  Widget followButton = IconButton(
                                      icon: Icon(Icons.person_add),
                                      color: Colors.deepPurple,
                                      onPressed: () {
                                        ActivityManager().followUser(userId);
                                        print('now following ${snapshot.data['username']}');
                                      }
                                  );

                                  Map<dynamic, dynamic> followers = snapshot.data['followers'];
                                  int followerCnt = 0;
                                  if(followers != null)
                                    followerCnt = followers.length;

                                  return Column(
                                      children: <Widget>[
                                        ListTile(
                                            leading: StreamBuilder(
                                                stream: Firestore.instance.collection('users').document(userId).snapshots(),
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
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: <Widget>[
                                                          Text(snapshot.data['username']),
                                                          Row(
                                                            children: <Widget>[
                                                              Icon(Icons.people),
                                                              Text('$followerCnt')
                                                            ]
                                                          )
                                                        ]
                                                      )
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
                                                                      String uid = snapshot.data.reference.documentID;
                                                                      bool isThisUser = uid == userId;
                                                                      if(snapshot.data['following'] != null) {
                                                                        Map<dynamic, dynamic> followingList = snapshot.data['following'];
                                                                        isFollowing = followingList.containsKey(userId);
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
                                                  'go to user profile: ${snapshot.data['uid']}');
                                              Navigator.push(context, MaterialPageRoute(
                                                builder: (context) =>
                                                    ProfilePage(
                                                      userId: snapshot.data['uid'], activityManager: widget.activityManager,),
                                              ));
                                            }
                                        ),
                                        Divider(height: 5.0),
                                      ]
                                  );
                                }
                            );
                          }).toList(),
                        );
                    }
                  }
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: bottomNavBar(_onItemTapped, _selectedIndex, activityManager: widget.activityManager),
    );
  }
}