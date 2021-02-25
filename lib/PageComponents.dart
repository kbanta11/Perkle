import 'dart:async';
import 'dart:io';
import 'package:Perkl/AccountSettings.dart';
import 'package:Perkl/FeedbackForm.dart';
import 'package:Perkl/MainPageTemplate.dart';
import 'package:Perkl/main.dart';
import 'package:Perkl/services/models.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:firebase_storage/firebase_storage.dart';
//import 'package:intl/intl.dart';
import 'package:audio_service/audio_service.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:wakelock/wakelock.dart';

import 'ProfilePage.dart';
import 'SearchPage.dart';
import 'UserList.dart';
import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';
import 'QueuePage.dart';

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

  @override
  Widget build(BuildContext context) {
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        mp.isRecording ? RecordingPulse(maxSize: 65.0,) : Container(),
        Container(
          height: mp.isRecording ? 65.0 : 75.0,
          width:mp.isRecording ? 65.0 : 75.0,
          child: FittedBox(
              child: FloatingActionButton(
                  heroTag: null,
                  shape: CircleBorder(side: BorderSide(color: Colors.red)),
                  child: Icon(
                    Icons.mic,
                    color: mp.isRecording ? Colors.red : Colors.white,
                  ),
                  backgroundColor:  mp.isRecording ? Colors.transparent : Colors.red,
                  onPressed: () async {
                    if(mp.isRecording) {
                      Wakelock.disable();
                      mp.stopRecording(context);
                    } else {
                      //await showTimer();
                      //if(widget.activityManager.currentlyPlayingPlayer != null) {
                      //  widget.activityManager.pausePlaying();
                      //}
                      Wakelock.enable();
                      mp.startRecording();
                    }
                  }
              )
          )
      )
      ],
    );
  }
}

//New Version
class TopPanel extends StatelessWidget {
  bool showSearchBar = false;
  String searchRequestId;
  String pageTitle;
  bool showPostButtons = true;
  TextEditingController searchController = new TextEditingController();

  TopPanel({
    this.showSearchBar,
    this.searchRequestId,
    this.pageTitle,
    this.showPostButtons,
    this.searchController,
  });

  @override
  build(BuildContext context) {
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    MainTemplateProvider templateProvider = Provider.of<MainTemplateProvider>(context);
    PlaybackState playbackState = Provider.of<PlaybackState>(context);
    //print('Current Playback State on Build: ${playbackState?.playing}');
    //print('Position in playback state: ${playbackState.currentPosition}');
    MediaItem currentMediaItem = Provider.of<MediaItem>(context);
    //print('Current Media Item: $currentMediaItem');
    List<MediaItem> mediaQueue = Provider.of<List<MediaItem>>(context);

    String playingPostText = '';
    if(currentMediaItem != null) {
      playingPostText = '${currentMediaItem.title} | ${currentMediaItem.artist}';
    }
    String getDurationString(Duration duration) {
      int hours = duration.inHours;
      int minutes = duration.inMinutes.remainder(60);
      int seconds = duration.inSeconds.remainder(60);
      String minutesString = minutes >= 10 ? '$minutes' : '0$minutes';
      String secondsString = seconds >= 10 ? '$seconds' : '0$seconds';
      if(hours > 0)
        return '$hours:$minutesString:$secondsString';
      return '$minutesString:$secondsString';
    }
    return Container(
      height: 265.0 + MediaQuery.of(context).viewPadding.top,
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        color: Colors.deepPurple,
        boxShadow: [
          BoxShadow(
            color: Colors.black,
            offset: Offset(0.0, 5.0),
            blurRadius: 20.0,
          )
        ],
        borderRadius: BorderRadius.only(bottomLeft: Radius.elliptical(35.0, 25.0), bottomRight: Radius.elliptical(35.0, 25.0)),
        image: DecorationImage(
          fit: BoxFit.cover,
          image: AssetImage('assets/images/mic-stage.jpg'),
        ),
      ),
      child: Column(
          children: <Widget>[
            AppBar(
              backgroundColor: Colors.transparent,
              title: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    MainPopMenu(),
                    Expanded(
                      child: showSearchBar != null && showSearchBar ? Padding(
                          padding: EdgeInsets.only(left: 20.0),
                          child: TextField(
                            controller: searchController,
                              autofocus: true,
                              decoration: InputDecoration(hintText: 'Search...', hintStyle: TextStyle(color: Colors.white), border: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              )),
                              style: TextStyle(color: Colors.white),
                              cursorColor: Colors.white,
                              onChanged: (value) async {
                                DateTime date = DateTime.now();
                                templateProvider.setSearchTerm(value);
                                if(searchRequestId != null)
                                  await FirebaseFirestore.instance.collection('requests').doc(searchRequestId).set({'searchTerm': value, "searchDateTime": date});
                              }
                          )
                      ) : Center(child: new Text(pageTitle != null ? pageTitle : 'Perkl')),
                    ),
                  ]
              ),
              centerTitle: true,
              automaticallyImplyLeading: false,
              titleSpacing: 5.0,
              actions: <Widget>[
                IconButton(
                  icon: Icon(showSearchBar != null && showSearchBar ? Icons.cancel : Icons.search),
                  iconSize: 40.0,
                  onPressed: () {
                    showSearchBar != null && showSearchBar ? Navigator.of(context).pop() : Navigator.push(context, MaterialPageRoute(
                      builder: (context) => SearchPageMobile(),
                    ));
                  },
                ),
              ],
            ),
            showPostButtons != null && !showPostButtons ? Container() : Padding(
              padding: EdgeInsets.fromLTRB(10, 5, 10, 0),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    Container(
                      height: 75.0,
                      width: 75.0,
                      child: InkWell(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.deepPurple,
                          ),
                          child: Icon(
                            Icons.cloud_upload,
                            color: Colors.white,
                          ),
                        ),
                        onTap: () async {
                          await showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return UploadPostDialog();
                              }
                          );
                        },
                      ),
                    ),
                    Column(
                      children: <Widget>[
                        RecordButton(),
                        mp.isRecording && mp.recordingTime != null ? Text('${getDurationString(mp.recordingTime)}', style: TextStyle(color: Colors.white)) : Container(),
                      ],
                    )
                  ]
              )
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    //Text(playingPostText, style: TextStyle(color: Colors.white, fontSize: 16)),
                    Expanded(
                      child: playingPostText.length > 0 ? Marquee(
                        text: playingPostText,
                        style: TextStyle(color: Colors.white, fontSize: 18),
                        velocity: 10,
                        blankSpace: 20,
                      ) : Container()
                    ),
                    SizedBox(width: 5),
                    Text('${playbackState == null || playbackState.position == null || playbackState.position.inMilliseconds == 0 ? '' : '${getDurationString(playbackState.position)}/'}${currentMediaItem == null || currentMediaItem.duration == null ? '' : getDurationString(currentMediaItem.duration)}',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    /*
                    StreamBuilder(
                      stream: mp.player.onDurationChanged,
                      builder: (context, AsyncSnapshot<Duration> durationSnap) {
                        Duration duration = durationSnap.data;
                        return StreamBuilder(
                          stream: mp.player.onAudioPositionChanged,
                          builder: (context, AsyncSnapshot<Duration> positionSnap) {
                            Duration position = positionSnap.data;
                            //print('Duration: $duration/Position: $position');
                            if (duration == null || position == null)
                              return Container();
                            return Text('${getDurationString(position)}/${getDurationString(duration)}',
                                style: TextStyle(color: Colors.white, fontSize: 16));
                          });
                      },
                    ),
                    */
                    //mp.position == null || mp.postLength == null ? Container() : Text('${mp.position.getPostPosition()}/${mp.postLength.getPostDuration()}', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              )
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  icon: Icon(Icons.queue_music, color: mediaQueue != null && mediaQueue.length > 0 ? Colors.white : Colors.grey),
                  onPressed: () {
                    //Go to Queue page
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) =>
                          QueuePage(),
                    ));
                  }
                ),
                IconButton(
                    icon: Icon(Icons.replay_30, color: currentMediaItem != null ? Colors.white : Colors.grey),
                    onPressed: () async {
                      if(currentMediaItem != null && playbackState != null && playbackState.position != null) {
                        await AudioService.rewind();
                      }
                    }
                ),
                IconButton(
                    icon: Icon(playbackState != null && playbackState.playing ? Icons.pause : Icons.play_arrow, color: (mediaQueue != null && mediaQueue.length > 0) || currentMediaItem != null ? Colors.white : Colors.grey,),
                    onPressed: () {
                      print('Button Pressed: Toggling from Current Playback State: ${playbackState.playing}');
                      if(playbackState.playing) {
                        //print('pausing post');
                        AudioService.pause();
                        return;
                      }
                      if(currentMediaItem != null) {
                        AudioService.play();
                        return;
                      }
                      if(mediaQueue != null && mediaQueue.length > 0) {
                        AudioService.skipToNext();
                        return;
                      }
                    }
                ),
                IconButton(
                  icon: Icon(Icons.forward_30, color: currentMediaItem != null ? Colors.white : Colors.grey),
                  onPressed: () async {
                    if(currentMediaItem != null && playbackState != null && playbackState.position != null) {
                      await AudioService.fastForward();
                    }
                  }
                ),
                IconButton(
                    icon: Icon(Icons.skip_next, color: mediaQueue != null && mediaQueue.length > 0 ? Colors.white : Colors.grey),
                    onPressed: () {
                      if(mediaQueue != null && mediaQueue.length > 0) {
                        AudioService.skipToNext();
                      }
                    }
                )
              ],
            ),
            Center(
              child: showPostButtons != null && showPostButtons ? Icon(Icons.keyboard_arrow_up, color: Colors.white) : Icon(Icons.keyboard_arrow_down, color: Colors.white,),
            )
          ]
      )
    );
  }
}

//Old Version
/*-----------------------------------
Widget topPanel(BuildContext context, ActivityManager activityManager, {String pageTitle, bool showSearchBar = false, String searchRequestId}) {
  return Container(
    height: 250.0,
    width: MediaQuery.of(context).size.width,
    decoration: BoxDecoration(
      color: Colors.deepPurple,
      boxShadow: [
        BoxShadow(
          color: Colors.black,
          offset: Offset(0.0, 5.0),
          blurRadius: 20.0,
        )
      ],
      borderRadius: BorderRadius.only(bottomLeft: Radius.elliptical(35.0, 25.0), bottomRight: Radius.elliptical(35.0, 25.0)),
      image: DecorationImage(
        fit: BoxFit.cover,
        image: AssetImage('assets/images/mic-stage.jpg'),
      ),
    ),
    child: Column(
      children: <Widget>[
        AppBar(
          backgroundColor: Colors.transparent,
          title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                mainPopMenu(context),
                Expanded(
                  child: showSearchBar ? Padding(
                      padding: EdgeInsets.only(left: 20.0),
                      child: TextField(
                        autofocus: true,
                        decoration: InputDecoration(hintText: 'Search...', hintStyle: TextStyle(color: Colors.white), border: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        )),
                        style: TextStyle(color: Colors.white),
                        cursorColor: Colors.white,
                        onChanged: (value) async {
                          DateTime date = DateTime.now();
                          await Firestore.instance.collection('requests').document(searchRequestId).setData({'searchTerm': value, "searchDateTime": date});
                        }
                      )
                  ) : Center(child: new Text(pageTitle != null ? pageTitle : 'Perkl')),
                ),
              ]
          ),
          centerTitle: true,
          automaticallyImplyLeading: false,
          titleSpacing: 5.0,
          actions: <Widget>[
            IconButton(
              icon: Icon(showSearchBar ? Icons.cancel : Icons.search),
              iconSize: 40.0,
              onPressed: () {
                showSearchBar ? Navigator.of(context).pop() : Navigator.push(context, MaterialPageRoute(
                  builder: (context) => SearchPage(activityManager: activityManager),
                ));
              },
            ),
          ],
        ),
        SizedBox(height: 15.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            Container(
              height: 75.0,
              width: 75.0,
              child: FittedBox(
                child: FloatingActionButton(
                  child: Icon(
                    Icons.cloud_upload,
                    color: Colors.white,
                  ),
                  heroTag: null,
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return UploadPostDialog();
                      }
                    );
                  },
                )
              ),
            ),
            RecordButton(activityManager: activityManager,)
          ]
        ),
      ]
    ),
  );
}
 -------------------------------------------*/
/*
class PlaylistControls extends StatefulWidget {
  ActivityManager activityManager;

  PlaylistControls({Key key, @required this.activityManager}) : super(key: key);

  @override
  _PlaylistControlsState createState() => new _PlaylistControlsState();
}

class _PlaylistControlsState extends State<PlaylistControls> {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
            child: Text('<<', style: TextStyle(color: Colors.white70, fontSize: 60.0),)
        ),
        SizedBox(width: 15.0),
        Container(
          height: 120.0,
          width: 120.0,
          child: StreamBuilder(
            stream: widget.activityManager.playlistPlaying,
            builder: (context, snapshot) {
              if(snapshot.hasData && snapshot.data == true) {
                return FloatingActionButton(
                  elevation: 20,
                  backgroundColor: Colors.deepPurpleAccent,
                  child: Icon(Icons.pause, color: Colors.white, size: 90.0,),
                  onPressed: () {
                    widget.activityManager.pausePlaylist();
                  },
                );
              }
              return FloatingActionButton(
                child: Icon(Icons.play_arrow, color: Colors.white, size: 90.0,),
                onPressed: () {
                  widget.activityManager.playPlaylist();
                },
              );
            }
          )
        ),
        SizedBox(width: 15.0),
        InkWell(
          child: Text('>>', style: TextStyle(color: Colors.white70, fontSize: 60.0),)
        ),
      ]
    );
  }
}
 */

class UserInfoSection extends StatefulWidget {
  final PerklUser user;

  UserInfoSection({Key key, @required this.user}) : super(key: key);

  @override
  _UserInfoSectionState createState() => _UserInfoSectionState();
}

class _UserInfoSectionState extends State<UserInfoSection> {
  ActivityManager activityManager = new ActivityManager();

    @override
    void initState() {
      super.initState();
    }

    @override
    Widget build(BuildContext context) {
      User currentUser = Provider.of<User>(context);

      Widget editMessageButton(PerklUser user, User currentUser) {
        if(user.uid != currentUser.uid) {
          //Send Message Button
          return ButtonTheme(
            height: 25,
            minWidth: 50,
            child: FlatButton(
              child: Text('Message'),
              padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
              shape: new RoundedRectangleBorder(borderRadius: new BorderRadius.circular(5.0)),
              color: Colors.deepPurple,
              textColor: Colors.white,
              onPressed: () async {
                String currentUsername;
                String currentUserId;
                await UserManagement().getUserData().then((docRef) async {
                  currentUserId = docRef.id;
                  await docRef.get().then((snapshot) {
                    currentUsername = snapshot.data()['username'].toString();
                  });
                });
                await activityManager.sendDirectPostDialog(context, memberMap: {widget.user.uid: widget.user.username, currentUserId: currentUsername});
              }
            )
          );
        }
        return ButtonTheme(
          height: 25,
          minWidth: 50,
          child: OutlineButton(
            child: Text('Edit Profile'),
            padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
            shape: new RoundedRectangleBorder(borderRadius: new BorderRadius.circular(5.0)),
            borderSide: BorderSide(
              color: Colors.deepPurple,
            ),
            textColor: Colors.deepPurple,
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
      Widget followUnfollowButton = StreamBuilder(
        stream: FirebaseFirestore.instance.collection('/users').doc(currentUser.uid).snapshots(),
        builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
          // print('$currentUserId ----::---- ${snapshot.data}');
          bool isFollowing = false;
          Map<dynamic, dynamic> following;
          if(snapshot.hasData) {
            switch (snapshot.connectionState) {
              case ConnectionState.waiting:
                return SizedBox();
              default:
                following = snapshot.data.data()['following'];

                // print(following == null);
                if(following != null) {
                  // print('user has following list');
                  // print('User already followed: ${following.containsKey(widget.userId)}');
                  isFollowing = following.containsKey(widget.user.uid);
                }

                if(isFollowing){
                  return ButtonTheme(
                      height: 25,
                      minWidth: 50,
                      child: OutlineButton(
                        child: Text('Unfollow'),
                        padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                        shape: new RoundedRectangleBorder(borderRadius: new BorderRadius.circular(5.0)),
                        borderSide: BorderSide(
                          color: Colors.deepPurple,
                        ),
                        textColor: Colors.deepPurple,
                        onPressed: () async {
                          ActivityManager().unfollowUser(widget.user.uid);
                        },
                      )
                  );
                }
            }
          }
          return ButtonTheme(
            height: 25,
            minWidth: 50,
            child: FlatButton(
              child: Text('Follow'),
              padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
              shape: new RoundedRectangleBorder(borderRadius: new BorderRadius.circular(5.0)),
              color: Colors.deepPurple,
              textColor: Colors.white,
              onPressed: () async {
                ActivityManager().followUser(widget.user.uid);
              },
            ),
          );
        },
      );

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
                              children: [followUnfollowButton, editMessageButton(widget.user, currentUser)]
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

class ProfilePic extends StatelessWidget {
  PerklUser user;

  ProfilePic(this.user);

  @override
  build(BuildContext context) {
    return user == null || user.profilePicUrl == null ? Container(
      height: 60.0,
      width: 60.0,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.deepPurple,
      ),
      child: InkWell(
        child: Container(),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) =>
                ProfilePageMobile(userId: user.uid,),
          ));
        },
      ),
    ) : Container(
        height: 60.0,
        width: 60.0,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.deepPurple,
          image: DecorationImage(
            fit: BoxFit.cover,
            image: NetworkImage(user.profilePicUrl),
          ),
        ),
        child: InkWell(
          child: Container(),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) =>
                  ProfilePageMobile(userId: user.uid,),
            ));
          },
        )
    );
  }
}


class MainPopMenu extends StatelessWidget {
  @override
  build(BuildContext context) {
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    return PopupMenuButton(
        itemBuilder: (context) => [
          PopupMenuItem(
            child: Text('Logout'),
            value: 1,
          ),
          PopupMenuItem(
              child: Text('Feedback'),
              value: 2
          ),
          PopupMenuItem(
            child: Text('Account Settings'),
            value: 3,
          )
        ],
        child: Navigator.canPop(context) ? IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            if(Navigator.canPop(context)) {
              Navigator.of(context).pop();
            } else {
              mp.notifyListeners();
            }
          },
        ) : StreamBuilder(
            stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser.uid).snapshots(),
            builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
              if(snapshot.hasData) {
                String profilePicUrl = snapshot.data.data()['profilePicUrl'];
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
        ),
        onSelected: (value) {
          if(value == 1){
            FirebaseAuth.instance.signOut().then((value) {
              Navigator.of(context).pushNamedAndRemoveUntil('/landingpage', (Route<dynamic> route) => false);
            })
                .catchError((e) {
              print(e);
            });
          }
          if(value == 2) {
            showDialog(
                context: context,
                builder: (BuildContext context) {
                  return FeedbackForm();
                }
            );
          }
          if(value == 3) {
            showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AccountSettings();
                }
            );
          }
        }
    );
  }
}

//Bottom Navigation Bar
Widget bottomNavBar(Function tapFunc, int selectedIndex, {ActivityManager activityManager, bool noSelection}) {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.only(topLeft: Radius.elliptical(10, 10), topRight: Radius.elliptical(10, 10)),
      image: DecorationImage(
        image: AssetImage('assets/images/mic-stage.jpg'),
        fit: BoxFit.cover,
        alignment: Alignment(-.5,-.75)
      )
    ),
    child: BottomNavigationBar(
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
      onTap: (index) {
        activityManager != null ? tapFunc(index, actManage: activityManager) : tapFunc(index);
      },
      fixedColor: noSelection == true ? Colors.white : Colors.deepPurple,
      unselectedItemColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.transparent,
    )
  );
}

//New Bottom Nav Bar
Widget bottomNavBarMobile(Function tapFunc, int selectedIndex, {ActivityManager activityManager, bool noSelection}) {
  return Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.only(topLeft: Radius.elliptical(10, 10), topRight: Radius.elliptical(10, 10)),
          image: DecorationImage(
              image: AssetImage('assets/images/mic-stage.jpg'),
              fit: BoxFit.cover,
              alignment: Alignment(-.5,-.75)
          )
      ),
      child: BottomNavigationBar(
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
        onTap: (index) {
          activityManager != null ? tapFunc(index, actManage: activityManager) : tapFunc(index);
        },
        fixedColor: noSelection == true ? Colors.white : Colors.deepPurple,
        unselectedItemColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
      )
  );
}

class RecordingPulse extends StatefulWidget {
  double maxSize;

  RecordingPulse({Key key, @required this.maxSize}) : super(key: key);

  @override
  _RecordingPulseState createState() => new _RecordingPulseState();
}

class _RecordingPulseState extends State<RecordingPulse> with SingleTickerProviderStateMixin {
  AnimationController _animationController;
  Animation _animation;

  @override
  initState() {
    _animationController = AnimationController(duration: Duration(seconds: 2), vsync: this);
    _animationController.repeat();
    _animation =  Tween(begin: 2.0, end: widget.maxSize).animate(_animationController)..addListener((){
      setState(() {

      });
    });
    super.initState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  build(BuildContext context) {
    return Container(
      height: _animation.value,
      width: _animation.value,
      decoration: ShapeDecoration(
        shape: CircleBorder(side: BorderSide(color: Colors.red, width: 2)),
      ),
    );
  }
}