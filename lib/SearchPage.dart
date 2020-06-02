import 'package:Perkl/MainPageTemplate.dart';
import 'package:Perkl/main.dart';
import 'package:Perkl/services/db_services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'ProfilePage.dart';
import 'PageComponents.dart';
import 'ListPage.dart';
import 'HomePage.dart';
import 'DiscoverPage.dart';
import 'MainPageTemplate.dart';

import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';
import 'services/models.dart';

/*-------------------------------
class SearchPage extends StatefulWidget {
  ActivityManager activityManager;

  SearchPage({Key key, this.activityManager}) : super(key: key);

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  DocumentReference userDoc;
  int _selectedIndex = 1;
  DocumentReference requestDoc = Firestore.instance.collection('/requests').document();

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
    if(index == 1) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => DiscoverPage(activityManager: widget.activityManager),
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
          topPanel(context, widget.activityManager, showSearchBar: true, searchRequestId: requestDoc == null ? null : requestDoc.documentID),
          requestDoc == null ? Center(child: CircularProgressIndicator()) : Expanded(
            child: StreamBuilder(
                stream: requestDoc.snapshots(),
                builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
                  List results;
                  try {
                    results = snapshot.data['results'];
                    print(results);
                  } catch(e) {
                    print('No Results: ${snapshot.data.documentID}');
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
                                                  child: Text(snapshot.data['username'])
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
          )
        ]
      ),
      bottomNavigationBar: bottomNavBar(_onItemTapped, _selectedIndex, noSelection: true),
    );
  }
}
----------------------------------------------*/

//New Version
class SearchPageMobile extends StatelessWidget {
  DocumentReference searchRequestDoc = Firestore.instance.collection('requests').document();
  @override
  build(BuildContext context) {
    FirebaseUser firebaseUser = Provider.of<FirebaseUser>(context);
    return MultiProvider(
      providers: [
        StreamProvider<User>(create: (_) => UserManagement().streamCurrentUser(firebaseUser))
      ],
      child: Consumer<User>(
        builder: (context, currentUser, _) {
          return MainPageTemplate(
            bottomNavIndex: 1,
            noBottomNavSelected: true,
            showSearchBar: true,
            searchRequestId: searchRequestDoc.documentID,
            body: StreamBuilder(
                stream: searchRequestDoc.snapshots(),
                builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
                  List<String> results;
                  if(snapshot.data.data == null)
                    return Center(child: Text('There are no results for this search...'));
                  print('Snapshot: $snapshot/Snapshot term: ${snapshot.data.data['searchTerm']}/Results: ${snapshot.data.data["results"]}');
                  results = snapshot.data.data['results'] == null ? null : snapshot.data.data['results'].map<String>((value) => value.toString()).toList();
                  print('Query Results: $results');


                  if(results == null)
                    return Center(child: CircularProgressIndicator());

                  if(results.length == 0)
                    return Center(child: Text('There are no results for this search...'));

                  if (snapshot.hasError) {
                    return Center(child: Text('Oops! We Messed Something Up... We\'re Sorry!'));
                    //return Text('Error: ${snapshot.error}');
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
                          return StreamBuilder<User>(
                              stream: Firestore.instance.collection('users').document(userId).snapshots().map((snap) => User.fromFirestore(snap)),
                              builder: (BuildContext context, AsyncSnapshot<User> userSnap) {
                                if(!snapshot.hasData)
                                  return Container();
                                User user = userSnap.data;
                                Widget followButton = IconButton(
                                    icon: Icon(Icons.person_add),
                                    color: Colors.deepPurple,
                                    onPressed: () {
                                      ActivityManager().followUser(userId);
                                      print('now following ${user.username}');
                                    }
                                );

                                return user == null ? Container() : Column(
                                    children: <Widget>[
                                      ListTile(
                                          leading: user == null || user.profilePicUrl == null  ? Container(
                                              height: 50.0,
                                              width: 50.0,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.deepPurple,
                                              )
                                          ) : Container(
                                              height: 50.0,
                                              width: 50.0,
                                              decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.deepPurple,
                                                  image: DecorationImage(
                                                      fit: BoxFit.cover,
                                                      image: NetworkImage(user.profilePicUrl)
                                                  )
                                              )
                                          ),
                                          title: Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: <Widget>[
                                                Expanded(
                                                    child: Text(user.username)
                                                ),
                                                Container(
                                                    height: 40.0,
                                                    width: 40.0,
                                                    child: currentUser == null || user == null || currentUser.uid == user.uid || currentUser.following.contains(user.uid) ? Container() : followButton
                                                )
                                              ]
                                          ),
                                          onTap: () {
                                            print(
                                                'go to user profile: ${user.username}');
                                            Navigator.push(context, MaterialPageRoute(
                                              builder: (context) =>
                                                  ProfilePageMobile(
                                                    userId: user.uid,),
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
          );
        },
      ),
    );
  }
}