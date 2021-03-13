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
              brightness: Brightness.dark,
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
                DropdownButton(
                  underline: Container(),
                  icon: Text('${playbackState == null ? '' : playbackState.speed}x', style: TextStyle(color: currentMediaItem != null ? Colors.white : Colors.grey)),
                  items: [0.5, 0.8, 1.0, 1.2, 1.5, 2.0].map((item) {
                    return DropdownMenuItem(
                      child: Text('$item${playbackState != null && playbackState.speed == item ? 'x' : ''}',),
                      value: item
                    );
                  }).toList(),
                  onChanged: (value) {
                    mp.setSpeed(value);
                  },
                ),
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
                        await mp.rewind();
                      }
                    }
                ),
                IconButton(
                    icon: Icon(playbackState != null && playbackState.playing ? Icons.pause : Icons.play_arrow, color: (mediaQueue != null && mediaQueue.length > 0) || currentMediaItem != null ? Colors.white : Colors.grey,),
                    onPressed: () {
                      print('Button Pressed: Toggling from Current Playback State: ${playbackState.playing}');
                      if(playbackState.playing) {
                        //print('pausing post');
                        mp.pausePost();
                        return;
                      }
                      if(currentMediaItem != null) {
                        mp.resume();
                        return;
                      }
                      if(mediaQueue != null && mediaQueue.length > 0) {
                        mp.skipToNext();
                        return;
                      }
                    }
                ),
                IconButton(
                  icon: Icon(Icons.forward_30, color: currentMediaItem != null ? Colors.white : Colors.grey),
                  onPressed: () async {
                    if(currentMediaItem != null && playbackState != null && playbackState.position != null) {
                      await mp.fastForward();
                    }
                  }
                ),
                IconButton(
                    icon: Icon(Icons.skip_next, color: mediaQueue != null && mediaQueue.length > 0 ? Colors.white : Colors.grey),
                    onPressed: () {
                      if(mediaQueue != null && mediaQueue.length > 0) {
                        mp.skipToNext();
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