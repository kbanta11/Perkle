import 'dart:async';
import 'dart:io';
import 'package:Perkl/AccountSettings.dart';
import 'package:Perkl/FeedbackForm.dart';
import 'package:Perkl/MainPageTemplate.dart';
import 'package:Perkl/main.dart';
import 'package:Perkl/services/models.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
//import 'package:firebase_storage/firebase_storage.dart';
//import 'package:intl/intl.dart';
import 'package:audio_service/audio_service.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:wakelock/wakelock.dart';

import 'ProfilePage.dart';
import 'SearchPage.dart';
import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';
import 'QueuePage.dart';
import 'Clipping.dart';
import 'ListeningHistory.dart';
import 'main.dart';

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
  String? searchRequestId;
  String? pageTitle;
  bool showPostButtons = true;
  TextEditingController? searchController = new TextEditingController();
  GlobalKey recordKey = new GlobalKey();
  GlobalKey viewQueueKey = new GlobalKey();
  GlobalKey createClipKey = new GlobalKey();
  GlobalKey menuKey = new GlobalKey();
  GlobalKey searchKey = new GlobalKey();

  TopPanel({
    this.showSearchBar = false,
    this.searchRequestId,
    this.pageTitle,
    this.showPostButtons = true,
    this.searchController,
  });

  @override
  build(BuildContext context) {
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    MainTemplateProvider templateProvider = Provider.of<MainTemplateProvider>(context);
    PlaybackState? playbackState = Provider.of<PlaybackState?>(context);
    //print('Current Playback State on Build: ${playbackState?.playing}');
    //print('Position in playback state: ${playbackState.currentPosition}');
    MediaItem? currentMediaItem = Provider.of<MediaItem?>(context);
    //print('Current Media Item: $currentMediaItem');
    List<MediaItem>? mediaQueue = Provider.of<List<MediaItem>?>(context);

    String playingPostText = '';
    if(currentMediaItem != null) {
      playingPostText = '${currentMediaItem.title} | ${currentMediaItem.artist}';
    }
    String getDurationString(Duration? duration) {
      int hours = duration?.inHours ?? 0;
      int minutes = duration?.inMinutes.remainder(60) ?? 0;
      int seconds = duration?.inSeconds.remainder(60) ?? 0;
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
                    DescribedFeatureOverlay(
                      tapTarget: Container(
                        height: 40.0,
                        width: 40.0,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            image: DecorationImage(
                              fit: BoxFit.cover,
                              image: AssetImage('assets/images/logo.png'),
                            )
                        ),
                      ),
                      featureId: 'menu-key',
                      backgroundColor: Colors.deepPurple,
                      //backgroundOpacity: 0.75,
                      title: Text('Menu'),
                      description: Text('Tap to access account settings, send feedback and logout.'),
                      child: MainPopMenu()
                    ),
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
                      ) : Center(child: new Text(pageTitle ?? 'Perkl')),
                    ),
                  ]
              ),
              centerTitle: true,
              automaticallyImplyLeading: false,
              titleSpacing: 5.0,
              actions: <Widget>[
                DescribedFeatureOverlay(
                  featureId: 'search-key',
                  tapTarget: Icon(Icons.search),
                  title: Text('Search'),
                  backgroundColor: Colors.deepPurple,
                  //backgroundOpacity: 0.75,
                  description: Text('Tap to search for users, podcasts and playlists.'),
                  child: IconButton(
                    icon: Icon(showSearchBar != null && showSearchBar ? Icons.cancel : Icons.search),
                    iconSize: 40.0,
                    onPressed: () {
                      showSearchBar != null && showSearchBar ? Navigator.of(context).pop() : Navigator.push(context, MaterialPageRoute(
                        builder: (context) => SearchPageMobile(),
                      ));
                    },
                  )
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
                        DescribedFeatureOverlay(
                          featureId: 'record-key',
                          tapTarget: Icon(Icons.mic),
                          backgroundColor: Colors.deepPurple,
                          contentLocation: ContentLocation.below,
                          title: Text('Record'),
                          description: Text('Tap here to record a new post!'),
                          child: RecordButton()
                        ),
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
                    Text('${playbackState == null || playbackState.position == null || playbackState.position.inMilliseconds == 0 ? '' : '${getDurationString(playbackState.position)}/'}${currentMediaItem == null || currentMediaItem.duration == null ? '' : getDurationString(currentMediaItem.duration ?? Duration(seconds: 0))}',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
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
                  items: <double>[0.5, 0.8, 1.0, 1.2, 1.5, 2.0].map((double item) {
                    return DropdownMenuItem(
                      child: Text('$item${playbackState != null && playbackState.speed == item ? 'x' : ''}',),
                      value: item
                    );
                  }).toList(),
                  onChanged: (double? value) {
                    mp.setSpeed(value ?? 1.0);
                  },
                ),
                DescribedFeatureOverlay(
                  tapTarget: Icon(Icons.queue_music),
                  featureId: 'queue-key',
                  backgroundColor: Colors.deepPurple,
                  contentLocation: ContentLocation.below,
                  overflowMode: OverflowMode.extendBackground,
                  title: Text('Queue'),
                  description: Text('Tap to view your queue.'),
                  child: IconButton(
                      icon: Icon(Icons.queue_music, color: mediaQueue != null && mediaQueue.length > 0 ? Colors.white : Colors.grey),
                      onPressed: () {
                        //Go to Queue page
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) =>
                              QueuePage(),
                        ));
                      }
                  )
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
                      //print('Button Pressed: Toggling from Current Playback State: ${playbackState.playing}');
                      if(playbackState?.playing ?? false) {
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
                ),
                DescribedFeatureOverlay(
                  tapTarget: FaIcon(FontAwesomeIcons.cut),
                  featureId: 'clip-key',
                  backgroundColor: Colors.deepPurple,
                  title: Text('Create a Clip'),
                  description: Text('Tap to create a clip of what\'s currently playing. You can save clips for later, add them to a playlist or share them with your friends.'),
                  child: IconButton(
                      icon: FaIcon(FontAwesomeIcons.cut, color: currentMediaItem != null && currentMediaItem.extras != null && currentMediaItem.extras?['type'] == 'PostType.PODCAST_EPISODE' ? Colors.white : Colors.grey),
                      onPressed: () {
                        if(currentMediaItem?.extras?['type'] == 'PostType.PODCAST_EPISODE') {
                          print('Clipping Media Item: ${currentMediaItem?.extras}');
                          if(playbackState?.playing ?? false) {
                            mp.pausePost();
                          }
                          showDialog(
                              context: context,
                              builder: (context) {
                                return CreateClipDialog(mediaItem: currentMediaItem, playbackState: playbackState);
                              }
                          );
                        }
                      }
                  )
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
  PerklUser? user;

  ProfilePic(this.user);

  @override
  build(BuildContext context) {
    return user == null || user?.profilePicUrl == null ? Container(
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
                ProfilePageMobile(userId: user?.uid,),
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
            image: NetworkImage(user?.profilePicUrl ?? ''),
          ),
        ),
        child: InkWell(
          child: Container(),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) =>
                  ProfilePageMobile(userId: user?.uid,),
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
          ),
          PopupMenuItem(
            child: Text('Listening History'),
            value: 4,
          ),
          PopupMenuItem(
            child: Text('View Tutorial'),
            value: 5,
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
            stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
            builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
              if(snapshot.hasData) {
                String? profilePicUrl = snapshot.data?.data()?['profilePicUrl'];
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
        onSelected: (value) async {
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
          if(value == 4){
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => ListeningHistoryPage(),
            ));
          }
          if(value == 5) {
            await FeatureDiscovery.clearPreferences(context, <String>{ 'menu-key', 'search-key','clip-key', 'queue-key', 'record-key','discover-key', 'playlists-key', 'messages-key', 'profile-key'});
            //Navigator.of(context).pop();
            print('Showing discovery features...');
            FeatureDiscovery.discoverFeatures(
              context,
              const <String>{ // Feature ids for every feature that you want to showcase in order.
                'menu-key',
                'search-key',
                'record-key',
                'queue-key',
                'clip-key',
                'discover-key',
                'playlists-key',
                'messages-key',
                'profile-key'
              },
            );
          }
        }
    );
  }
}

//New Bottom Nav Bar
Widget bottomNavBarMobile(Function tapFunc, int selectedIndex, {ActivityManager? activityManager, bool? noSelection}) {
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
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: DescribedFeatureOverlay(
              tapTarget: ClipRect(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.surround_sound, color: Colors.deepPurple),
                      Text('Discover', style: TextStyle(color: Colors.deepPurple))
                    ]
                )
              ),
              featureId: 'discover-key',
              title: Text('Discover'),
              description: Text('Discover featured playlists, top podcasts and our most popular users!'),
              backgroundColor: Colors.deepPurple,
              child: Icon(Icons.surround_sound)
            ),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: DescribedFeatureOverlay(
              tapTarget: ClipRect(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.playlist_play, color: Colors.deepPurple),
                      Text('Playlists', style: TextStyle(color: Colors.deepPurple)),
                    ]
                )
              ),
              featureId: 'playlists-key',
              title: Text('Playlists'),
              description: Text('View your playlists and the playlists you\'re subscribed to or create a new playlist! Playlists are your way to organize what you listen to, made up of posts and podcast episodes and clips.'),
              backgroundColor: Colors.deepPurple,
              child: Icon(Icons.playlist_play)
            ),
            label: 'Playlists'
          ),
          BottomNavigationBarItem(
            icon: DescribedFeatureOverlay(
              tapTarget: ClipRect(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mail_outline, color: Colors.deepPurple),
                      Text('Messages', style: TextStyle(color: Colors.deepPurple))
                    ]
                )
              ),
              featureId: 'messages-key',
              title: Text('Messages'),
              description: Text('Listen to and send direct voice messages to your friends or groups of friends. You can send your own recordings, share playlists, or share podcast clips and episodes!'),
              backgroundColor: Colors.deepPurple,
              child: Icon(Icons.mail_outline)
            ),
            label: 'Messages'
          ),
          BottomNavigationBarItem(
            icon: DescribedFeatureOverlay(
              tapTarget: ClipRect(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_circle, color: Colors.deepPurple),
                      Text('Profile', style: TextStyle(color: Colors.deepPurple))
                    ]
                )
              ),
              featureId: 'profile-key',
              title: Text('Profile'),
              description: Text('View and edit your profile and see your posts and saved clips.'),
              backgroundColor: Colors.deepPurple,
              child: Icon(Icons.account_circle)
            ),
            label: 'Profile'
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
  double? maxSize;

  RecordingPulse({Key? key, @required this.maxSize}) : super(key: key);

  @override
  _RecordingPulseState createState() => new _RecordingPulseState();
}

class _RecordingPulseState extends State<RecordingPulse> with SingleTickerProviderStateMixin {
  AnimationController? _animationController;
  Animation? _animation;

  @override
  initState() {
    _animationController = AnimationController(duration: Duration(seconds: 2), vsync: this);
    _animationController?.repeat();
    if(_animationController != null) {
      _animation =  Tween(begin: 2.0, end: widget.maxSize).animate(_animationController ?? AnimationController(vsync: this))..addListener((){
        setState(() {

        });
      });
    }
    super.initState();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  @override
  build(BuildContext context) {
    return Container(
      height: _animation?.value,
      width: _animation?.value,
      decoration: ShapeDecoration(
        shape: CircleBorder(side: BorderSide(color: Colors.red, width: 2)),
      ),
    );
  }
}