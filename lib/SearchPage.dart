import 'package:Perkl/MainPageTemplate.dart';
import 'package:Perkl/main.dart';
import 'package:Perkl/services/db_services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:podcast_search/podcast_search.dart';

import 'ProfilePage.dart';
import 'PodcastPage.dart';
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
        StreamProvider<User>(create: (_) => UserManagement().streamCurrentUser(firebaseUser)),
        ChangeNotifierProvider<SearchPageProvider>(create: (_) => SearchPageProvider()),
      ],
      child: Consumer<User>(
        builder: (context, currentUser, _) {
          SearchPageProvider spp = Provider.of<SearchPageProvider>(context);
          return MainPageTemplate(
            bottomNavIndex: 1,
            noBottomNavSelected: true,
            showSearchBar: true,
            searchRequestId: searchRequestDoc.documentID,
            body: Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    FlatButton(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10)), side: BorderSide(color: Colors.deepPurple, width: 2)),
                      child: Text('People', style: TextStyle(color: spp.type == SearchType.PEOPLE ? Colors.white : Colors.deepPurple)),
                      color: spp.type == SearchType.PEOPLE ? Colors.deepPurple : Colors.transparent,
                      onPressed: () {
                        spp.changeSearchType(SearchType.PEOPLE);
                      },
                    ),
                    FlatButton(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10)), side: BorderSide(color: Colors.deepPurple, width: 2)),
                      child: Text('Podcasts', style: TextStyle(color: spp.type == SearchType.PODCASTS ? Colors.white : Colors.deepPurple)),
                      color: spp.type == SearchType.PODCASTS ? Colors.deepPurple : Colors.transparent,
                      onPressed: () {
                        spp.changeSearchType(SearchType.PODCASTS);
                      }
                    )
                  ]
                ),
                Expanded(
                  child: StreamBuilder(
                      stream: searchRequestDoc.snapshots(),
                      builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> asyncSearchDocSnap) {
                        if(spp.type == SearchType.PODCASTS && asyncSearchDocSnap.hasData) {
                          if(asyncSearchDocSnap.data == null || asyncSearchDocSnap.data.data == null)
                            return Center(child: CircularProgressIndicator());
                          return FutureBuilder<SearchResult>(
                            future: Search().search(asyncSearchDocSnap.data.data['searchTerm'], limit: 50),
                            builder: (context, AsyncSnapshot<SearchResult> searchResultSnap) {
                              if(!searchResultSnap.hasData)
                                return Center(child: Text('Sorry...No results for this search'));
                              return ListView(
                                children: searchResultSnap.data.items.map((Item item) {
                                  return Card(
                                    margin: EdgeInsets.all(5),
                                    child: Padding(
                                      padding: EdgeInsets.all(5),
                                      child: ListTile(
                                        leading: Container(
                                          height: 50,
                                          width: 50,
                                          decoration: BoxDecoration(
                                              color: Colors.deepPurple,
                                              image: item.artworkUrl60 == null ? null : DecorationImage(
                                                  image: NetworkImage(item.artworkUrl60)
                                              )
                                          ),
                                        ),
                                        title: Text(item.trackName),
                                        onTap: () async {
                                          showDialog(
                                              context: context,
                                              builder: (context) {
                                                return Center(child: CircularProgressIndicator());
                                              }
                                          );
                                          Podcast podcast = await Podcast.loadFeed(url: item.feedUrl);
                                          Navigator.of(context).pop();
                                          Navigator.push(context, MaterialPageRoute(
                                            builder: (context) => PodcastPage(podcast),
                                          ));
                                        },
                                      )
                                    )
                                  );
                                }).toList(),
                              );
                            },
                          );
                        }

                        List<String> results;
                        if(asyncSearchDocSnap.data == null || asyncSearchDocSnap.data.data == null)
                          return Center(child: Text('There are no results for this search...'));
                        print('Snapshot: $asyncSearchDocSnap/Snapshot term: ${asyncSearchDocSnap.data.data['searchTerm']}/Results: ${asyncSearchDocSnap.data.data["results"]}');
                        results = asyncSearchDocSnap.data.data['results'] == null ? null : asyncSearchDocSnap.data.data['results'].map<String>((value) => value.toString()).toList();
                        print('Query Results: $results');


                        if(results == null)
                          return Center(child: CircularProgressIndicator());

                        if(results.length == 0)
                          return Center(child: Text('There are no results for this search...'));

                        if (asyncSearchDocSnap.hasError) {
                          return Center(child: Text('Oops! We Messed Something Up... We\'re Sorry!'));
                          //return Text('Error: ${snapshot.error}');
                        }

                        if(asyncSearchDocSnap == null || asyncSearchDocSnap.data == null)
                          return Container();
                        switch (asyncSearchDocSnap.connectionState) {
                          case ConnectionState.waiting:
                            return Center(child: CircularProgressIndicator());
                          default:
                            return ListView(
                              children: asyncSearchDocSnap.data['results'].map<Widget>((userId) {
                                print(userId);
                                return StreamBuilder<User>(
                                    stream: Firestore.instance.collection('users').document(userId).snapshots().map((snap) => User.fromFirestore(snap)),
                                    builder: (BuildContext context, AsyncSnapshot<User> userSnap) {
                                      if(!asyncSearchDocSnap.hasData)
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

                                      return user == null ? Container() : Card(
                                        margin: EdgeInsets.all(5),
                                        child: Padding(
                                          padding: EdgeInsets.all(5),
                                          child: ListTile(
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
                                        )
                                      );
                                    }
                                );
                              }).toList(),
                            );
                        }
                      }
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}

enum SearchType {
  PEOPLE,
  PODCASTS
}

class SearchPageProvider extends ChangeNotifier {
  SearchType type = SearchType.PEOPLE;

  changeSearchType(SearchType newType) {
    type = newType;
    notifyListeners();
  }
}