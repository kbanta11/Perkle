import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';

import 'ProfilePage.dart';
import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';

class TimerDialog extends StatefulWidget {
  @override _TimerDialogState createState() => _TimerDialogState();
}

class _TimerDialogState extends State<TimerDialog> {
  Timer _timer;
  int _start = 3000;
  int _printTime;
  Color _backgroundColor = Colors.white10;

  void startTimer() {
    Duration period = Duration(milliseconds: 1);
    _timer = new Timer.periodic(
      period,
        (Timer timer) {
          setState(() {
            if(_start < 1) {
              _timer.cancel();
            }
            if(_start % 1000 == 0)
              _backgroundColor = Colors.white70;
            _printTime = (_start / 1000).ceil();
            _start = _start - 1;
          });
        }
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  void initState() {
    _printTime = (_start / 1000).ceil();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    startTimer();
    if(_start < 1)
      Navigator.pop(context);
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Center(
        child: Container(
          height: 100.0,
          width: 100.0,
          child: Text('$_printTime',
            style: TextStyle(
              fontSize: 64.0
            ),
          )
        )
      )
    );
  }
}

class RecordButton extends StatefulWidget {
  @override
  _RecordButtonState createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton> {
  ActivityManager activityManager = new ActivityManager();
  bool _isRecording = false;
  String _postAudioPath;
  DateTime _startRecordDate;

  Future<void> showTimer() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return TimerDialog();
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: 40.0,
      icon: Icon(
        Icons.mic,
        color: _isRecording ? Colors.red : Colors.white,
      ),
        onPressed: () async {
          if(_isRecording) {
            List<dynamic> stopRecordVals = await activityManager.stopRecordNewPost(_postAudioPath, _startRecordDate);
            String recordingLocation = stopRecordVals[0];
            int secondsLength = stopRecordVals[1];

            print('$recordingLocation -/- Length: $secondsLength');
            setState(() {
              _isRecording = !_isRecording;
            });
            DateTime date = new DateTime.now();
            await addPostDialog(context, date, recordingLocation, secondsLength);
          } else {
            //await showTimer();
            List<dynamic> startRecordVals = await activityManager.startRecordNewPost();
            String postPath = startRecordVals[0];
            DateTime startDate = startRecordVals[1];
            setState(() {
              _isRecording = !_isRecording;
              _postAudioPath = postPath;
              _startRecordDate = startDate;
            });
          }
        }
    );
  }
}

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
  DateTime _startRecordDate;

  Future<bool> _isCurrentUser(String userId) async {
    return await FirebaseAuth.instance.currentUser().then((user) {
        return user.uid.toString() == userId.toString();
    });
  }


    @override
    void initState() {
      Stream picStream = Firestore.instance.collection('users').document(widget.userId).snapshots();
      super.initState();
    }

    @override
    Widget build(BuildContext context) {
      Widget floatingRightButtons = FutureBuilder(
          future: _isCurrentUser(widget.userId),
          initialData: false,
          builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
            if(!snapshot.data)
              return Center(
                  child: Container(
                      height: 45.0,
                      width: 45.0,
                      child: FloatingActionButton(
                        backgroundColor: Colors.deepPurple,
                        child: Icon(Icons.mail_outline),
                        heroTag: null,
                        onPressed: () async {
                          await Firestore.instance.collection('users').document(widget.userId).get().then((DocumentSnapshot snapshot) async {
                            String username = snapshot.data['username'].toString();
                            await activityManager.sendDirectPostDialog(widget.userId, username, context);
                          });
                        },
                      )
                  )
              );
            return Center(
                child: Container(
                    height: 45.0,
                    width: 45.0,
                    child: FloatingActionButton(
                        child: Icon(Icons.edit),
                        backgroundColor: Colors.deepPurple,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onPressed: () {
                          showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return UpdateProfileDialog();
                              });
                        }
                    )
                )
            );
          }
      );

      Widget profileImage = StreamBuilder(
        stream: Firestore.instance.collection('users').document(widget.userId).snapshots(),
        builder: (context, snapshot) {
          if(snapshot.hasData) {
            print('Pic URL: ${snapshot.data['profilePicUrl']}');
            if(snapshot.data['profilePicUrl'] != null) {
              String profilePicUrl = snapshot.data['profilePicUrl'].toString();
              return Container(
                height: 75.0,
                width: 75.0,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.deepPurple,
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: NetworkImage(profilePicUrl),
                    )
                ),
              );
            }
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
      );

      Widget profilePic = FutureBuilder(
          future: _isCurrentUser(widget.userId),
          initialData: false,
          builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
            if(!snapshot.data){
              print('not logged in user profile pic');
              return profileImage;
            }
            print('logged in user profile pic');
            return Stack(
              children: <Widget>[
                StreamBuilder(
                    stream: Firestore.instance.collection('users').document(widget.userId).snapshots(),
                    builder: (context, snapshot) {
                      if(snapshot.hasData) {
                        print('Pic URL: ${snapshot.data['profilePicUrl']}');
                        if(snapshot.data['profilePicUrl'] != null) {
                          String profilePicUrl = snapshot.data['profilePicUrl'].toString();
                          return Container(
                            height: 75.0,
                            width: 75.0,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.deepPurple,
                                image: DecorationImage(
                                  fit: BoxFit.cover,
                                  image: NetworkImage(profilePicUrl),
                                )
                            ),
                          );
                        }
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
                ),
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
                                 return ProfilePicDialog(userId: widget.userId);
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
      );

      return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            Padding(
                child: profilePic,
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
            ),
            Padding(
                child: floatingRightButtons,
                padding: EdgeInsets.fromLTRB(0.0, 5.0, 5.0, 0.0)
            ),
          ].where((item) => item != null).toList()
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
      // print('Passed userId: $userId / Current User UID: ${user.uid}');
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
        if(snapshot.data) {
          return Container();
        } else {
          return StreamBuilder(
            stream: Firestore.instance.collection('/users').document(currentUserId).snapshots(),
            builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
              // print('$currentUserId ----::---- ${snapshot.data}');
              bool isFollowing = false;
              Map<dynamic, dynamic> following;
              if(snapshot.hasData) {
                switch (snapshot.connectionState) {
                  case ConnectionState.waiting:
                    return SizedBox();
                  default:
                    following = snapshot.data['following'];

                    // print(following == null);
                    if(following != null) {
                      // print('user has following list');
                      // print('User already followed: ${following.containsKey(widget.userId)}');
                      isFollowing = following.containsKey(widget.userId);
                    }

                    if(isFollowing){
                      return OutlineButton(
                        child: Text('Unfollow'),
                        padding: EdgeInsets.all(0.0),
                        shape: new RoundedRectangleBorder(borderRadius: new BorderRadius.circular(5.0)),
                        borderSide: BorderSide(
                          color: Colors.deepPurple,
                        ),
                        textColor: Colors.deepPurple,
                        onPressed: () async {
                          ActivityManager().unfollowUser(widget.userId);
                        },
                      );
                    } else {
                      return FlatButton(
                        child: Text('Follow'),
                        padding: EdgeInsets.all(0.0),
                        shape: new RoundedRectangleBorder(borderRadius: new BorderRadius.circular(5.0)),
                        color: Colors.deepPurple,
                        textColor: Colors.white,
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
      //width: 200.0,
      child: StreamBuilder<QuerySnapshot>(
          stream: Firestore.instance.collection('users').where("uid", isEqualTo: widget.userId).snapshots(),
          builder: (context, snapshot) {
            String bio = 'Please enter a short biography. Let everyone know who you are and what you enjoy!';
            String _bio;
            if(snapshot.hasData)
              _bio = snapshot.data.documents.first.data['bio'].toString();

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
                  Row(
                      children: <Widget>[
                        leftButton,
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
  bool _isPlaying = false;
  String _playingPostId;

  Future<Query> setStream() async {
    String timelineId = widget.idMap['timelineId'];
    String userId = widget.idMap['userId'];

    Query ref;
    if(timelineId != null) {
      // print('setting reference to timlineid');
      ref = Firestore.instance.collection('posts').where('timelines', arrayContains: timelineId).orderBy("datePosted", descending: true);
    } else {
      // print('setting reference to user id');
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
              return Text('Loading posts...');
            return StreamBuilder(
                stream: stream,
                builder: (context, AsyncSnapshot<QuerySnapshot>snapshot) {
                  //print(snapshot.data);
                  if(!snapshot.hasData || snapshot.data.documents.length == 0)
                    return Text('Users has no posts');

                  switch(snapshot.connectionState){
                    case ConnectionState.none:
                      return Text('Connection Lost');
                    case ConnectionState.waiting:
                      return Center(
                          child: Container(
                            height: 50.0,
                            width: 50.0,
                            child: CircularProgressIndicator(),
                          )
                        );
                    default:
                      return ListView(
                          scrollDirection: Axis.vertical,
                          shrinkWrap: true,
                          children: snapshot.data.documents.map((document) {
                            String title;
                            String postDate;

                            Timestamp timestamp = document.data['datePosted'];
                            DateTime time = DateTime.fromMillisecondsSinceEpoch(timestamp.millisecondsSinceEpoch);
                            DateFormat dateFormat = new DateFormat('MMMM d, y H:mm');
                            postDate = dateFormat.format(time);

                            if(document.data['postTitle'] == null){
                              title = postDate;
                              postDate = '';
                            } else {
                              title = document.data['postTitle'].toString();
                            }
                            String postAudioUrl = document.data['audioFileLocation'].toString();
                            String username = 'no_username';
                            if(document.data['username'] != null)
                              username = document.data['username'].toString();
                            // print(postAudioUrl);
                            String postId = document.documentID;
                            Color bgColor = Colors.deepPurple;
                            if(_playingPostId == postId)
                              bgColor = Colors.red;
                            if(postAudioUrl == null || postAudioUrl == 'null')
                              bgColor = Colors.grey;

                            int postLengthSeconds = document.data['secondsLength'];
                            String postLength = '--:--';
                            if(postLengthSeconds != null) {
                              Duration postDuration = Duration(seconds: postLengthSeconds);
                              if(postDuration.inHours > 0){
                                postLength = '${postDuration.inHours}:${postDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${postDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
                              } else {
                                postLength = '${postDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${postDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
                              }
                            }

                            String userId = document.data['userUID'];
                            Map<String, dynamic> postInfo = {
                              'userId': userId,
                              'username': username,
                              'postTitle': title,
                              'postDate': postDate,
                              'playBtnBG': bgColor,
                              'thisPostId': postId,
                              'playingPostId': _playingPostId,
                              'postAudioUrl': postAudioUrl,
                              'isPlaying': _isPlaying,
                              'postLengthString': postLength,
                              'activityManager': activityManager,
                            };
                            return Column(
                                children: <Widget>[
                                  TimelineListItem(params: postInfo),
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

class TimelineListItem extends StatefulWidget {
  Map<String, dynamic> params;

  TimelineListItem({Key key, @required this.params}) : super(key: key);

  @override
  _TimelineListItemState createState() => new _TimelineListItemState();
}

class _TimelineListItemState extends State<TimelineListItem> {
  bool _thisPlaying = false;
  AudioPlayer postPlayer = new AudioPlayer();

  @override
  Widget build(BuildContext context) {
    String userId = widget.params['userId'];
    String username = widget.params['username'];
    String postTitle = widget.params['postTitle'];
    String postDate = widget.params['postDate'];
    String postAudioUrl = widget.params['postAudioUrl'];
    String postLengthString = widget.params['postLengthString'];
    ActivityManager activityManager = widget.params['activityManager'];

    return ListTile(
      leading: StreamBuilder(
          stream: Firestore.instance.collection('users').document(userId).snapshots(),
          builder: (context, snapshot) {
            if(snapshot.hasData) {
              String picUrl = snapshot.data['profilePicUrl'];
              if(picUrl != null)
                return InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) =>
                          ProfilePage(userId: userId),
                    ));
                  },
                  child: Container(
                    height: 60.0,
                    width: 60.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.deepPurple,
                      image: DecorationImage(
                        fit: BoxFit.cover,
                        image: NetworkImage(picUrl.toString()),
                      ),
                    ),
                  )
                );
            }
            return InkWell(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) =>
                      ProfilePage(userId: userId),
                ));
              },
              child: Container(
                  height: 60.0,
                  width: 60.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.deepPurple,
                  )
              )
            );
          }
      ),
      title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('@${username}',
              style: TextStyle(
                fontSize: 18.0,
                color: Color(0xFF7B7B7B),
              ),
            ),
            SizedBox(height: 2.5),
            Text(postTitle,
              style: TextStyle(
                fontSize: 18.0,
              ),
            ),
            SizedBox(height: 2.5),
            Text(postDate,
              style: TextStyle(
                fontSize: 14.0,
                color: Color(0xFF7B7B7B),
              ),
            ),
          ]
      ),
      trailing:  Column(
          children: <Widget>[
            SizedBox(
              width: 35.0,
              height: 35.0,
              child: StreamBuilder(
                stream: postPlayer.onPlayerStateChanged,
                builder: (BuildContext context, snapshot) {
                  print('State: ${snapshot.data}');

                  Color playBtnBG = Colors.deepPurple;
                  if(snapshot.data == AudioPlayerState.PLAYING)
                    playBtnBG = Colors.red;
                  if(postAudioUrl == null || postAudioUrl == 'null')
                    playBtnBG = Colors.grey;

                  return FloatingActionButton(
                    backgroundColor: playBtnBG,
                    child: snapshot.data == AudioPlayerState.PLAYING ? Icon(Icons.stop) : Icon(Icons.play_arrow),
                    heroTag: null,
                    onPressed: () async {
                      if(snapshot.data == AudioPlayerState.PLAYING) {
                        activityManager.stopPlaying(postPlayer);
                      } else {
                        if (postAudioUrl != null && postAudioUrl != 'null') {
                          activityManager.playRecording(postAudioUrl, postPlayer);
                        }
                      }
                    },
                  );
                }
              ),
            ),
            SizedBox(height: 2.0),
            Text(postLengthString),
          ]
      ),
      onTap: () {

      },
    );
  }
}

Widget mainPopMenu(BuildContext context) {
  return PopupMenuButton(
      itemBuilder: (context) => [
        PopupMenuItem(
          child: Text('Logout'),
          value: 1,
        )
      ],
    child: FutureBuilder(
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
    onSelected: (value) {
        if(value == 1){
          FirebaseAuth.instance.signOut().then((value) {
            Navigator.of(context).pushReplacementNamed('/landingpage');
          })
              .catchError((e) {
            print(e);
          });
        }
    }
  );
}



//Bottom Navigation Bar
Widget bottomNavBar(Function tapFunc, int selectedIndex) {
  return BottomNavigationBar(
    items: <BottomNavigationBarItem> [
      BottomNavigationBarItem(
        icon: Icon(Icons.home),
        title: Text('Home'),
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.surround_sound),
        title: Text('Discover'),
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.mail_outline),
        title: Text('Messages'),
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.account_circle),
        title: Text('Profile'),
      ),
    ],
    currentIndex: selectedIndex,
    onTap: tapFunc,
    fixedColor: Colors.deepPurple,
    type: BottomNavigationBarType.fixed,
  );
}