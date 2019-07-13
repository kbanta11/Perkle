import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:intl/intl.dart';

import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';


class UserInfoSection extends StatefulWidget {
  final String userId;

  UserInfoSection({Key key, @required this.userId}) : super(key: key);

  @override
  _UserInfoSectionState createState() => _UserInfoSectionState();
}

class _UserInfoSectionState extends State<UserInfoSection> {
  ActivityManager activityManager = new ActivityManager();
  bool _isRecording = false;
  String _postAudioPath;

  Future<bool> _isCurrentUser(String userId) async {
    return await FirebaseAuth.instance.currentUser().then((user) {
        return user.uid.toString() == userId.toString();
    });
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Widget floatingRightButtons = FutureBuilder(
      future: _isCurrentUser(widget.userId),
      initialData: false,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        if(!snapshot.data)
          return Container();
        return Row(
            children: <Widget> [
              FloatingActionButton(
                backgroundColor: Colors.deepPurple,
                child: Icon(Icons.add),
                heroTag: null,
                onPressed: () async {
                  //addPostDialog(context);
                },
              ),
              SizedBox(width: 5.0),
              Column(
                children: <Widget>[
                  FloatingActionButton(
                      backgroundColor: _isRecording ? Colors.red : Colors.deepPurple,
                      child: Icon(Icons.mic),
                      heroTag: null,
                      onPressed: () async {
                        if(_isRecording) {
                          String recordingLocation = await activityManager.stopRecordNewPost(_postAudioPath);
                          setState(() {
                            _isRecording = !_isRecording;
                          });
                          print('getting date');
                          DateTime date = new DateTime.now();
                          print('date before dialog: $date');
                          await addPostDialog(context, date, recordingLocation);
                        } else {
                          String postPath = await activityManager.startRecordNewPost();
                          setState(() {
                            _isRecording = !_isRecording;
                            _postAudioPath = postPath;
                          });
                        }
                      }
                  ),
                ]
              ),
            ]
        );
      }
    );

    return Padding(
      padding: EdgeInsets.only(top: 10.0, left: 5.0, right: 5.0, bottom: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CircleAvatar(
                    backgroundColor: Colors.deepPurple,
                    child: Icon(
                      Icons.add_a_photo,
                      size: 30.0,
                    ),
                    radius: 30.0,
                  ),
                  SizedBox(width: 5.0),
                  Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(height: 10.0),
                        StreamBuilder(
                            stream: Firestore.instance.collection('users').where("uid", isEqualTo: widget.userId).snapshots(),
                            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                              print(snapshot.data.toString());
                              if (!snapshot.hasData) {
                                return Text('@',
                                  style: TextStyle(fontSize: 18.0),
                                );
                              }

                              String username = snapshot.data.documents.first.data['username'].toString();
                              if(username == null || username == 'null')
                                username = '@';

                              return Text('@$username',
                                style: TextStyle(
                                  fontSize: 18.0,
                                ),
                              );
                            }
                        ),
                        BioTextSection(userId: widget.userId),
                      ]
                  ),
                ]
            ),
            floatingRightButtons,
            ].where((item) => item != null).toList()
          ),
        ]
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
  Future<FirebaseUser> currentUser = FirebaseAuth.instance.currentUser();
  String currentUserId;
  bool showMore = false;

  Future<bool> _isCurrentUser(String userId) async {
    return await FirebaseAuth.instance.currentUser().then((user) {
      print('Passed userId: $userId / Current User UID: ${user.uid}');
      return user.uid.toString() == userId.toString();
    });
  }

  void _getCurrentUserId() async {
    await currentUser.then((user) {
      setState((){
        currentUserId = user.uid.toString();
      });
    });

  }

  @override
  void initState() {
    _getCurrentUserId();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Widget leftButton = FutureBuilder(
      future: _isCurrentUser(widget.userId),
      initialData: false,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        print('is current user: ${snapshot.data}');
        if(snapshot.data) {
          return FlatButton(
              child: Text('Edit Profile'),
              padding: EdgeInsets.all(0.0),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return UpdateProfileDialog();
                    });
              }
          );
        } else {
          print('building follow button streambuilder');
          return StreamBuilder(
            stream: Firestore.instance.collection('/users').document(currentUserId).snapshots(),
            builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
              print('$currentUserId ----::---- ${snapshot.data}');
              bool isFollowing = false;
              Map<dynamic, dynamic> following;
              if(snapshot.hasData) {
                switch (snapshot.connectionState) {
                  case ConnectionState.waiting:
                    return SizedBox();
                  default:
                    following = snapshot.data['following'];

                    print('following list: $following :: page uid: ${widget.userId}');
                    print(following == null);
                    if(following != null) {
                      print('user has following list');
                      print('User already followed: ${following.containsKey(widget.userId)}');
                      isFollowing = following.containsKey(widget.userId);
                    }

                    if(isFollowing){
                      return FlatButton(
                        child: Text('Unfollow'),
                        padding: EdgeInsets.all(0.0),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onPressed: () async {
                          ActivityManager().unfollowUser(widget.userId);
                        },
                      );
                    } else {
                      return FlatButton(
                        child: Text('Follow'),
                        padding: EdgeInsets.all(0.0),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onPressed: () async {
                          ActivityManager().followUser(widget.userId);
                        },
                      );
                    }
                }
              } else {
                return FlatButton(
                  child: Text('Unfollow'),
                  padding: EdgeInsets.all(0.0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onPressed: () async {
                    ActivityManager().unfollowUser(widget.userId);
                  }
                );
              }
            },
          );
        }
      }
    );

    return Container(
      width: 200.0,
      alignment: Alignment(-1.0, -1.0),
      child: StreamBuilder<QuerySnapshot>(
          stream: Firestore.instance.collection('users').where("uid", isEqualTo: widget.userId).snapshots(),
          builder: (context, snapshot) {
            String bio = 'Please enter a short biography. Let everyone know who you are and what you enjoy!';
            String printBio;
            String _bio;
            if(snapshot.hasData)
              _bio = snapshot.data.documents.first.data['bio'].toString();

            Widget showMoreButton = FlatButton(
              child: Text('Show More'),
              padding: EdgeInsets.all(0.0),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );

            if(_bio != 'null' && _bio != null) {
              bio = _bio;
            }

            if(bio.length > 50 && !showMore){
              printBio = bio.substring(0, 50) + '...';
              showMoreButton = FlatButton(
                child: Text('Show More'),
                padding: EdgeInsets.all(0.0),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onPressed: () {
                  setState(() {
                    showMore = !showMore;
                  });
                },
              );
            } else {
              printBio = bio;
              if(bio.length > 50){
                showMoreButton = FlatButton(
                  child: Text('Show Less'),
                  padding: EdgeInsets.all(0.0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onPressed: () {
                    setState(() {
                      showMore = !showMore;
                    });
                  },
                );
              }
            }

            Widget content = Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget> [
                  Text(
                    printBio,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 5,
                    textAlign: TextAlign.left,
                  ),
                  Row(
                      children: <Widget>[
                        leftButton,
                        showMoreButton,
                      ]
                  )
                ]
            );

            return content;
          }
      ),
    );
  }
}

//  Timeline Component
class TimelineSection extends StatefulWidget {
  final Map<String, dynamic> idMap;

  TimelineSection({Key key, @required this.idMap}) : super(key: key);

  @override
  _TimelineSectionState createState() => _TimelineSectionState();
}

class _TimelineSectionState extends State<TimelineSection> {
  ActivityManager activityManager = new ActivityManager();
  String timelineId;
  String userId;

  Future<Query> setStream() async {
    String timelineId = widget.idMap['timelineId'];
    String userId = widget.idMap['userId'];

    Query ref;
    if(timelineId != null) {
      print('setting reference to timlineid');
      ref = Firestore.instance.collection('posts').where('timelines', arrayContains: timelineId).orderBy("datePosted", descending: true);
    } else {
      print('setting reference to user id');
      ref = Firestore.instance.collection('posts').where('userUID', isEqualTo: userId).orderBy("datePosted", descending: true);
    }
    return ref;
  }

  @override
  void initState() {
    super.initState();
  }


  @override build(BuildContext context) {
    return Container(
        child: FutureBuilder(
          future: setStream(),
          builder: (BuildContext context, AsyncSnapshot<Query> snapshot) {
            Stream<QuerySnapshot> stream;
            if(snapshot.hasData)
              stream = snapshot.data.snapshots();
            else
              return Text('User has not posts yet!');
            return StreamBuilder(
                stream: stream,
                builder: (context, AsyncSnapshot<QuerySnapshot>snapshot) {
                  print(snapshot.data);
                  if(!snapshot.hasData || snapshot.data.documents.length == 0)
                    return Text('Users has no posts');

                  switch(snapshot.connectionState){
                    case ConnectionState.none:
                      return Text('Connection Lost');
                    case ConnectionState.waiting:
                      return CircularProgressIndicator();
                    default:
                      return ListView(
                          scrollDirection: Axis.vertical,
                          shrinkWrap: true,
                          children: snapshot.data.documents.map((document) {
                            String title;
                            if(document.data['postTitle'] == null){
                              Timestamp timestamp = document.data['datePosted'];
                              DateTime time = DateTime.fromMillisecondsSinceEpoch(timestamp.millisecondsSinceEpoch);
                              DateFormat dateFormat = new DateFormat('MMMM d, y H:m:s');
                              title = dateFormat.format(time);
                            } else {
                              title = document.data['postTitle'].toString();
                            }
                            String postAudioUrl = document.data['audioFileLocation'].toString();
                            print(postAudioUrl);
                            return Column(
                                        children: <Widget>[
                                        ListTile(
                                          title: Text(title),
                                          trailing:  FloatingActionButton(
                                            backgroundColor: postAudioUrl != null && postAudioUrl != 'null' ? Colors.deepPurple : Colors.grey,
                                            child: Icon(Icons.play_circle_outline),
                                            heroTag: null,
                                            onPressed: () async {
                                              if (postAudioUrl != null && postAudioUrl != 'null')
                                                activityManager.playRecording(postAudioUrl);
                                            },
                                          ),
                                        ),
                                        Divider(height: 5.0),
                                       ]
                                      );
                          }).toList()
                      );
                  }
                }
            );
          }
        ),
    );
  }
}