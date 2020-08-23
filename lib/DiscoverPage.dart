import 'package:Perkl/services/db_services.dart';
import 'package:Perkl/services/models.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:podcast_search/podcast_search.dart';

import 'ConversationPage.dart';
import 'MainPageTemplate.dart';
import 'PageComponents.dart';
import 'HomePage.dart';
import 'ProfilePage.dart';
import 'ListPage.dart';
import 'Timeline.dart';
import 'DiscoverPodcasts.dart';

import 'main.dart';
import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';

/*---------------------------------------------
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
-------------------------------------------------*/

//--------------------------------------------------------------------------
//-----------------New Version----------------------------------------------
class DiscoverPageMobile extends StatelessWidget {

  @override
  build(BuildContext context) {
    FirebaseUser firebaseUser = Provider.of<FirebaseUser>(context);
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    return MultiProvider(
      providers: [
        StreamProvider<User>(create: (_) => UserManagement().streamCurrentUser(firebaseUser)),
        ChangeNotifierProvider<DiscoverPageMobileProvider>(create: (_) => DiscoverPageMobileProvider()),
        FutureProvider<List<DiscoverTag>>(create: (_) => DBService().getDiscoverTags()),
      ],
      child: Consumer<User>(
          builder: (context, user, _) {
            DiscoverPageMobileProvider pageProvider = Provider.of<DiscoverPageMobileProvider>(context);
            List<DiscoverTag> discoverTags = Provider.of<List<DiscoverTag>>(context);
            MainAppProvider mp = Provider.of<MainAppProvider>(context);
            print('DiscoverTags: $discoverTags');
            String firstTag = discoverTags != null ? discoverTags.first.value : null;
            print('Current Tag: ${pageProvider.selectedTag ?? firstTag}');
            return user == null ? Center(child: CircularProgressIndicator()) : MainPageTemplate(
              bottomNavIndex: 1,
              body: Column(
                children: <Widget>[
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        FlatButton(
                          child: Text('Tags',
                            style: TextStyle(color: pageProvider.selectedCat == 'Tags' ? Colors.white : Colors.deepPurple),
                          ),
                          color: pageProvider.selectedCat == 'Tags' ? Colors.deepPurple : Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15.0),
                            side: BorderSide(color: Colors.deepPurple),
                          ),
                          onPressed: () {
                            pageProvider.selectCategory('Tags');
                          },
                        ),
                        FlatButton(
                          child: Text('Pods',
                            style: TextStyle(color: pageProvider.selectedCat == 'Pods' ? Colors.white : Colors.deepPurple),
                          ),
                          color: pageProvider.selectedCat == 'Pods' ? Colors.deepPurple : Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15.0),
                            side: BorderSide(color: Colors.deepPurple),
                          ),
                          onPressed: () {
                            pageProvider.selectCategory('Pods');
                          },
                        ),
                        FlatButton(
                          child: Text('People',
                            style: TextStyle(color: pageProvider.selectedCat == 'People' ? Colors.white : Colors.deepPurple),
                          ),
                          color: pageProvider.selectedCat == 'People' ? Colors.deepPurple : Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15.0),
                            side: BorderSide(color: Colors.deepPurple),
                          ),
                          onPressed: () {
                            pageProvider.selectCategory('People');
                          },
                        ),
                      ]
                  ),
                  pageProvider.selectedCat == 'Tags' ? Expanded(
                    child: Column(
                      children: <Widget>[
                        Container(
                          height: 35,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: discoverTags == null ? [Container()]
                                : discoverTags.map((tag) {
                                  if(pageProvider.selectedTag == null && tag.rank == 1)
                                    firstTag = tag.value;
                                  return FlatButton(
                                    color: pageProvider.selectedTag == null && tag.rank == 1 ? Colors.deepPurple : pageProvider.selectedTag == tag.value ? Colors.deepPurple : Colors.white,
                                    child: Text('#${tag.value}', style: TextStyle(color: pageProvider.selectedTag == null && tag.rank == 1 ? Colors.white : pageProvider.selectedTag == tag.value ? Colors.white : Colors.deepPurple)),
                                    onPressed: () {
                                      pageProvider.selectTag(tag.value);
                                    },
                                  );
                            }).toList(),
                          ),
                        ),
                        Expanded(
                          child: (pageProvider == null || pageProvider.selectedTag == null) && firstTag == null ? Center(child: CircularProgressIndicator()) : Timeline(tagStream: DBService().streamTagPosts(pageProvider.selectedTag ?? firstTag), type: TimelineType.STREAMTAG,),
                        )
                      ],
                    ),
                  ) : pageProvider.selectedCat == 'People' ? Expanded(
                    child: StreamProvider<List<String>>(
                      create: (context) => DBService().streamDiscoverPods(),
                      child: Consumer<List<String>>(
                        builder: (context, userList, _) {
                          if(userList == null)
                            return Center(child: CircularProgressIndicator());
                          return ListView(
                            children: userList.map((userId) => StreamProvider<User>(
                              create: (context) => UserManagement().streamUserDoc(userId),
                              child: Consumer<User>(
                                builder: (context, user, _) {
                                  return user == null ? Container()
                                      : Card(
                                    elevation: 5,
                                    margin: EdgeInsets.all(5),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.fromLTRB(5, 5, 5, 5),
                                      //Leading of list tile for pods
                                      leading: user.profilePicUrl != null ? Container(
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
                                      ) : Container(
                                          height: 50.0,
                                          width: 50.0,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.deepPurple,
                                          )
                                      ),
                                      title: Text('${user.username}', style: TextStyle(fontSize: 18)),
                                      trailing: Container(
                                        width: 50,
                                        child: Row(
                                          children: <Widget>[
                                            FaIcon(FontAwesomeIcons.users, color: Colors.black, size: 16,),
                                            SizedBox(width: 5),
                                            Text('${user.followers != null ? user.followers.length.toString() : '0'}', style: TextStyle(fontSize: 16))
                                          ],
                                        ),
                                      ),
                                      onTap: () {
                                        Navigator.push(context, MaterialPageRoute(
                                          builder: (context) =>
                                              ProfilePageMobile(userId: user.uid,),
                                        ));
                                      },
                                    ),
                                  );
                                }
                              )
                            )).toList(),
                          );
                        }
                      )
                    )
                  ) : Expanded(
                    child: DiscoverPodcasts(),
                  ),
                ],
              ),
            );
          }
      ),
    );
  }
}

class DiscoverPageMobileProvider extends ChangeNotifier {
  String selectedCat = 'Pods';
  String selectedTag;

  void selectCategory(String value) {
    selectedCat = value;
    notifyListeners();
  }

  void selectTag(String value) {
    selectedTag = value;
    notifyListeners();
  }


}