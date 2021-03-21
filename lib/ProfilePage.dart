import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
//import 'package:firebase_auth/firebase_auth.dart';
import 'services/UserManagement.dart';
//import 'services/ActivityManagement.dart';
import 'services/models.dart';

import 'main.dart';
import 'MainPageTemplate.dart';
import 'PageComponents.dart';
import 'Timeline.dart';
import 'UserList.dart';


//--------------------------------------------------
//New Version
class ProfilePageMobile extends StatefulWidget {
  String userId;

  ProfilePageMobile({Key key, @required this.userId}) : super(key: key);

  _ProfilePageMobileState createState() => new _ProfilePageMobileState();
}

class _ProfilePageMobileState extends State<ProfilePageMobile> {
  bool toggleClips = false;

  @override
  build(BuildContext context) {
    User firebaseUser = Provider.of<User>(context);
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    return widget.userId == null ? Center(child: CircularProgressIndicator(),) : MultiProvider(
      providers: [
        StreamProvider<PerklUser>(create: (_) => UserManagement().streamUserDoc(widget.userId)),
      ],
      child: Consumer<PerklUser>(
          builder: (context, user, _) {
            return user == null ? Center(child: CircularProgressIndicator()) : MainPageTemplate(
                bottomNavIndex: 3,
                body: Column(
                  children: <Widget>[
                    UserInfoSection(user: user),
                    widget.userId == firebaseUser.uid ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        TextButton(
                          child: Text('My Posts',
                            style: TextStyle(color: !toggleClips ? Colors.white : Colors.deepPurple),
                          ),
                          style: TextButton.styleFrom(
                              backgroundColor: !toggleClips ? Colors.deepPurple : Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15.0),
                                side: BorderSide(color: Colors.deepPurple),
                              )
                          ),
                          onPressed: () {
                            setState(() {
                              toggleClips = false;
                            });
                          },
                        ),
                        TextButton(
                          child: Text('My Clips',
                            style: TextStyle(color: toggleClips ? Colors.white : Colors.deepPurple),
                          ),
                          style: TextButton.styleFrom(
                              backgroundColor: toggleClips ? Colors.deepPurple : Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15.0),
                                side: BorderSide(color: Colors.deepPurple),
                              )
                          ),
                          onPressed: () {
                            setState(() {
                              toggleClips = true;
                            });
                          },
                        )
                      ]
                    ) : Container(),
                    Expanded(
                      child: toggleClips ? Timeline(userId: user.uid, type: TimelineType.CLIPS) : Timeline(userId: user.uid, type: TimelineType.USER)
                    )
                  ],
                ),
            );
          }
      ),
    );
  }
}

class UserInfoSection extends StatefulWidget {
  final PerklUser user;

  UserInfoSection({Key key, @required this.user}) : super(key: key);

  @override
  _UserInfoSectionState createState() => _UserInfoSectionState();
}

class _UserInfoSectionState extends State<UserInfoSection> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    User currentUser = Provider.of<User>(context);
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    Widget editMessageButton(PerklUser user, User currentUser) {
      if(user.uid != currentUser.uid) {
        //Send Message Button
        return ButtonTheme(
            height: 25,
            minWidth: 50,
            child: TextButton(
                child: Text('Message'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                  shape: new RoundedRectangleBorder(borderRadius: new BorderRadius.circular(5.0)),
                  backgroundColor: Colors.deepPurple,
                  primary: Colors.white,
                ),
                onPressed: () async {
                  String currentUsername;
                  String currentUserId;
                  await UserManagement().getUserData().then((docRef) async {
                    currentUserId = docRef.id;
                    await docRef.get().then((snapshot) {
                      currentUsername = snapshot.data()['username'].toString();
                    });
                  });
                  await mp.activityManager.sendDirectPostDialog(context, memberMap: {widget.user.uid: widget.user.username, currentUserId: currentUsername});
                }
            )
        );
      }
      return ButtonTheme(
          height: 25,
          minWidth: 50,
          child: OutlinedButton(
              child: Text('Edit Profile'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                shape: new RoundedRectangleBorder(borderRadius: new BorderRadius.circular(5.0)),
                primary: Colors.deepPurple,
                side: BorderSide(color: Colors.deepPurple,),
              ),
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return UpdateProfileDialog();
                    });
              }
          )
      );
    }

    //Left button under profile description: Follow/Unfollow if not own profile
    Widget followUnfollowButton(User currentUser, PerklUser pageUser)  {
      if(currentUser.uid == pageUser.uid) {
        return Container();
      }
      if(pageUser.followers.contains(currentUser.uid)) {
        return ButtonTheme(
            height: 25,
            minWidth: 50,
            child: OutlinedButton(
              child: Text('Unfollow'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                shape: new RoundedRectangleBorder(borderRadius: new BorderRadius.circular(5.0)),
                primary: Colors.deepPurple,
                side: BorderSide(color: Colors.deepPurple,),
              ),
              onPressed: () async {
                mp.activityManager.unfollowUser(widget.user.uid);
              },
            )
        );
      }
      return ButtonTheme(
        height: 25,
        minWidth: 50,
        child: TextButton(
          child: Text('Follow'),
          style: TextButton.styleFrom(
            padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
            shape: RoundedRectangleBorder(borderRadius: new BorderRadius.circular(5.0)),
            backgroundColor: Colors.deepPurple,
            primary: Colors.white,
          ),
          onPressed: () async {
            mp.activityManager.followUser(widget.user.uid);
          },
        ),
      );
    }

    Widget profileImage(PerklUser user) {
      if(user != null && user.profilePicUrl != null) {
        return Container(
          height: 75.0,
          width: 75.0,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.deepPurple,
              image: DecorationImage(
                fit: BoxFit.cover,
                image: NetworkImage(user.profilePicUrl),
              )
          ),
        );
      }
      return Container(
        height: 75.0,
        width: 75.0,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.deepPurple,
        ),
      );
    }

    Widget profilePic(PerklUser user, User currentUser) {
      if(user.uid != currentUser.uid) {
        return profileImage(user);
      }
      return Stack(
        children: <Widget>[
          profileImage(user),
          Positioned(
              bottom: 0.0,
              right: 0.0,
              child: Container(
                  height: 20.0,
                  width: 20.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.deepPurpleAccent),
                    boxShadow: [BoxShadow(
                      offset: Offset(-1.0, -1.0),
                      blurRadius: 2.5,
                    )],
                  ),
                  child: RawMaterialButton(
                      shape: CircleBorder(),
                      child: Icon(Icons.add_a_photo,
                        color: Colors.deepPurpleAccent,
                        size: 12.5,
                      ),
                      fillColor: Colors.white,
                      onPressed: () async {
                        await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return ProfilePicDialog(userId: user.uid);
                            }
                        ).then((_) {
                          setState(() {});
                        });
                      }
                  )
              )
          ),
        ],
      );
    }

    return Card(
        elevation: 5,
        margin: EdgeInsets.all(5),
        child: Padding(
            padding: EdgeInsets.all(5),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  Padding(
                      child: profilePic(widget.user, currentUser),
                      padding: EdgeInsets.fromLTRB(5.0, 5.0, 0.0, 0.0)
                  ), //Profile Pic with or without add photo if own profile
                  SizedBox(width: 5.0),
                  Expanded(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SizedBox(height: 10.0),
                          Text('@${widget.user.username ?? ''}',
                            style: TextStyle(
                              fontSize: 18.0,
                            ),
                          ),
                          BioTextSection(userId: widget.user.uid),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [followUnfollowButton(currentUser, widget.user), editMessageButton(widget.user, currentUser)]
                          ),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: <Widget>[
                                Column(
                                  children: <Widget>[
                                    InkWell(
                                      child: Text('${widget.user.followers == null ? 0 : widget.user.followers.length}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent)),
                                      onTap: () {
                                        if(widget.user.followers != null && widget.user.followers.length > 0) {
                                          Navigator.push(context, MaterialPageRoute(
                                            builder: (context) =>
                                                UserList(widget.user.followers, UserListType.FOLLOWERS),
                                          ));
                                        }
                                      },
                                    ),
                                    Text('Followers'),
                                  ],
                                ),
                                Column(
                                  children: <Widget>[
                                    InkWell(
                                        child: Text('${widget.user.following == null ? 0 : widget.user.following.length}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent)),
                                        onTap: () {
                                          if(widget.user.following != null && widget.user.following.length > 0) {
                                            Navigator.push(context, MaterialPageRoute(
                                              builder: (context) =>
                                                  UserList(widget.user.following, UserListType.FOLLOWING),
                                            ));
                                          }
                                        }
                                    ),
                                    Text('Following'),
                                  ],
                                ),
                                Column(
                                  children: <Widget>[
                                    InkWell(
                                      child: Text('${widget.user.posts == null ? 0 : widget.user.posts.length}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent)),
                                    ),
                                    Text('Posts'),
                                  ],
                                ),
                              ]
                          )
                        ]
                    ),
                  ),
                ].where((item) => item != null).toList()
            )
        )
    );
  }
}

// bio text section------------------------------------
class BioTextSection extends StatefulWidget {
  final String userId;

  BioTextSection({Key key, @required this.userId}) : super(key: key);

  @override
  _BioTextSectionState createState() => _BioTextSectionState();
}

class _BioTextSectionState extends State<BioTextSection> {
  User currentUser = FirebaseAuth.instance.currentUser;
  String currentUserId;
  bool showMore = false;

  void _getCurrentUserId() {
    setState((){
      currentUserId = currentUser.uid.toString();
    });
  }

  @override
  void initState() {
    _getCurrentUserId();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {

    return Container(
      //width: 200.0,
      child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').where("uid", isEqualTo: widget.userId).snapshots(),
          builder: (context, snapshot) {
            String bio = 'Please enter a short biography. Let everyone know who you are and what you enjoy!';
            String _bio;
            if(snapshot.hasData)
              _bio = snapshot.data.docs.first.data()['bio'].toString();

            if(_bio != 'null' && _bio != null) {
              bio = _bio;
            }

            Widget content = Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget> [
                  Text(
                    bio,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 5,
                    textAlign: TextAlign.left,
                  ),
                ]
            );

            return content;
          }
      ),
    );
  }
}