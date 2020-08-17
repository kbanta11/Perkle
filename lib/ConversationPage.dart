import 'package:Perkl/MainPageTemplate.dart';
import 'package:Perkl/services/db_services.dart';
import 'package:Perkl/services/models.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
//import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

import 'main.dart';
import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';

import 'PageComponents.dart';
import 'HomePage.dart';
import 'ListPage.dart';
import 'ProfilePage.dart';
import 'DiscoverPage.dart';

/*-------------------------------------------------------
class ConversationPage extends StatefulWidget {
  final String conversationId;
  ActivityManager activityManager;

  ConversationPage({Key key, @required this.conversationId, this.activityManager}) : super(key: key);

  @override
  _ConversationPageState createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  int _selectedIndex = 2;

  void _resetUserUnheard(String conversationId) async {
    FirebaseUser currentUser = await FirebaseAuth.instance.currentUser();
    String currentUserId = currentUser.uid.toString();
    DocumentSnapshot convoSnap = await Firestore.instance.collection('conversations').document(conversationId).get();
    Map<dynamic, dynamic> convoMembers = convoSnap.data['conversationMembers'];
    convoMembers[currentUserId]['unreadPosts'] = 0;
    print('Conversation Members: $convoMembers');
    convoSnap.reference.updateData({'conversationMembers': convoMembers}, );
  }

  void _onItemTapped(int index) async {
    if(index == 0) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => HomePage(activityManager: widget.activityManager,),
      ));
    }
    if(index == 1) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => DiscoverPage(activityManager: widget.activityManager),
      ));
    }
    if(index == 2) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ListPage(type: 'conversation', activityManager: widget.activityManager,),
      ));
    }
    if(index == 3) {
      String uid = await UserManagement().getUserData().then((DocumentReference docRef) {
        return docRef.documentID;
      });
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ProfilePage(userId: uid, activityManager: widget.activityManager),
      ));
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<String> _getUsername(String uid) async {
    return await Firestore.instance.collection('/users').document(uid).get().then((snapshot) async {
      return snapshot.data['username'].toString();
    });
  }

  @override
  void initState() {
    super.initState();
    _resetUserUnheard(widget.conversationId);
  }

  @override
  Widget build(BuildContext context) {
    ActivityManager _activityManager = widget.activityManager;
    return Scaffold(
      body: Column(
        children: <Widget>[
          topPanel(context, _activityManager),
          Expanded(
              child: StreamBuilder(
                  stream: Firestore.instance.collection('directposts').where('conversationId', isEqualTo: widget.conversationId).orderBy('datePosted', descending: true).snapshots(),
                  builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                    if(snapshot.hasData) {
                      return ListView(
                        children: snapshot.data.documents.map((DocumentSnapshot docSnap) {
                          AudioPlayer postPlayer = new AudioPlayer();
                          String sender = docSnap.data['senderUsername'];
                          int secondsLength = docSnap.data['secondsLength'];
                          String messageTitle = docSnap.data['messageTitle'];
                          DateTime datePosted = docSnap.data['datePosted'].toDate();
                          String dateString = DateFormat('MMMM dd, yyyy hh:mm:ss').format(datePosted).toString();
                          String postAudioUrl = docSnap.data['audioFileLocation'];

                          PostAudioPlayer thisPost = _activityManager.addPostToPlaylist(postAudioUrl, postPlayer);

                          String postLength = '--:--';
                          if(secondsLength != null) {
                            Duration postDuration = Duration(seconds: secondsLength);
                            if(postDuration.inHours > 0){
                              postLength = '${postDuration.inHours}:${postDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${postDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
                            } else {
                              postLength = '${postDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${postDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
                            }
                          }

                          Widget playButton = SizedBox(
                              height: 35.0,
                              width: 35.0,
                              child: StreamBuilder(
                                  stream: postPlayer.onPlayerStateChanged,
                                  builder: (BuildContext context, snapshot) {
                                    Color playBtnBG = Colors.deepPurple;
                                    if(snapshot.data == AudioPlayerState.PLAYING || snapshot.data == AudioPlayerState.PAUSED)
                                      playBtnBG = Colors.red;
                                    if(postAudioUrl == null || postAudioUrl == 'null')
                                      playBtnBG = Colors.grey;

                                    return FloatingActionButton(
                                      backgroundColor: playBtnBG,
                                      child: snapshot.data == AudioPlayerState.PLAYING ? Icon(Icons.pause) : Icon(Icons.play_arrow),
                                      heroTag: null,
                                      onPressed: () async {
                                        if(snapshot.data == AudioPlayerState.PLAYING) {
                                          _activityManager.pausePlaying();
                                        } else if(snapshot.data == AudioPlayerState.PAUSED) {
                                          _activityManager.resumePlaying();
                                        } else {
                                          if (postAudioUrl != null && postAudioUrl != 'null') {
                                            _activityManager.setCurrentPost(thisPost);
                                            thisPost.play();
                                          }
                                        }
                                      },
                                    );
                                  }
                              )
                          );

                          return Column(
                              children: <Widget>[
                                FutureBuilder(
                                    future: UserManagement().getUserData().then((DocumentReference ref) {
                                      return ref.get().then((DocumentSnapshot snapshot) {
                                        return snapshot;
                                      });
                                    }),
                                    builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
                                      if(snapshot.hasData) {
                                        Widget messageText = Column(
                                            crossAxisAlignment: docSnap.data['senderUID'] == snapshot.data.reference.documentID ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                            children: <Widget>[
                                              messageTitle != null ? Text(messageTitle) : Text(dateString),
                                              Text('@$sender'),
                                            ]
                                        );
                                        if(docSnap.data['senderUID'] == snapshot.data.reference.documentID)
                                          return Padding(
                                              padding: EdgeInsets.fromLTRB(0.0, 5.0, 0.0, 5.0),
                                              child: ListTile(
                                                leading: Column(
                                                    children: <Widget>[
                                                      playButton,
                                                      SizedBox(height: 2.0),
                                                      StreamBuilder(
                                                          stream: postPlayer.onAudioPositionChanged,
                                                          builder: (context, AsyncSnapshot<Duration> snapshot) {
                                                            if(!snapshot.hasData)
                                                              return Text(postLength);

                                                            int hours = snapshot.data.inHours;
                                                            int minutes = snapshot.data.inMinutes.remainder(60);
                                                            int seconds = snapshot.data.inSeconds.remainder(60);
                                                            String minutesString = minutes >= 10 ? '$minutes' : '0$minutes';
                                                            String secondsString = seconds >= 10 ? '$seconds' : '0$seconds';
                                                            if(hours > 0)
                                                              return Text('$hours:$minutesString:$secondsString');
                                                            return Text('$minutesString:$secondsString');
                                                          }
                                                      )
                                                    ]
                                                ),
                                                title: messageText,
                                                trailing: StreamBuilder(
                                                    stream: Firestore.instance.collection('users').document(docSnap.data['senderUID']).snapshots(),
                                                    builder: (context, snapshot) {
                                                      if(snapshot.hasData){
                                                        String profilePicUrl = snapshot.data['profilePicUrl'];
                                                        if(profilePicUrl != null)
                                                          return InkWell(
                                                              onTap: () {
                                                                Navigator.push(context, MaterialPageRoute(
                                                                  builder: (context) =>
                                                                      ProfilePage(userId: docSnap.data['senderUID'], activityManager: widget.activityManager),
                                                                ));
                                                              },
                                                              child: Container(
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
                                                              )
                                                          );
                                                      }
                                                      return InkWell(
                                                          onTap: () {
                                                            Navigator.push(context, MaterialPageRoute(
                                                              builder: (context) =>
                                                                  ProfilePage(userId: docSnap.data['senderUID'], activityManager: widget.activityManager),
                                                            ));
                                                          },
                                                          child: Container(
                                                              height: 40.0,
                                                              width: 40.0,
                                                              decoration: BoxDecoration(
                                                                shape: BoxShape.circle,
                                                                color: Colors.deepPurple,
                                                              )
                                                          )
                                                      );
                                                    }
                                                ),
                                              )
                                          );
                                        return Padding(
                                            padding: EdgeInsets.fromLTRB(0.0, 5.0, 0.0, 5.0),
                                            child: ListTile(
                                              leading: StreamBuilder(
                                                  stream: Firestore.instance.collection('users').document(docSnap.data['senderUID']).snapshots(),
                                                  builder: (context, snapshot) {
                                                    if(snapshot.hasData){
                                                      String profilePicUrl = snapshot.data['profilePicUrl'];
                                                      if(profilePicUrl != null)
                                                        return InkWell(
                                                            onTap: () {
                                                              Navigator.push(context, MaterialPageRoute(
                                                                builder: (context) =>
                                                                    ProfilePage(userId: docSnap.data['senderUID'], activityManager: widget.activityManager),
                                                              ));
                                                            },
                                                            child: Container(
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
                                                            )
                                                        );
                                                    }
                                                    return InkWell(
                                                        onTap: () {
                                                          Navigator.push(context, MaterialPageRoute(
                                                            builder: (context) =>
                                                                ProfilePage(userId: docSnap.data['senderUID'], activityManager: widget.activityManager),
                                                          ));
                                                        },
                                                        child: Container(
                                                            height: 40.0,
                                                            width: 40.0,
                                                            decoration: BoxDecoration(
                                                              shape: BoxShape.circle,
                                                              color: Colors.deepPurple,
                                                            )
                                                        )
                                                    );
                                                  }
                                              ),
                                              title: messageText,
                                              trailing: Column(
                                                  children: <Widget>[
                                                    playButton,
                                                    SizedBox(height: 2.0),
                                                    StreamBuilder(
                                                        stream: postPlayer.onAudioPositionChanged,
                                                        builder: (context, AsyncSnapshot<Duration> snapshot) {
                                                          if(!snapshot.hasData)
                                                            return Text(postLength);

                                                          int hours = snapshot.data.inHours;
                                                          int minutes = snapshot.data.inMinutes.remainder(60);
                                                          int seconds = snapshot.data.inSeconds.remainder(60);
                                                          String minutesString = minutes >= 10 ? '$minutes' : '0$minutes';
                                                          String secondsString = seconds >= 10 ? '$seconds' : '0$seconds';
                                                          if(hours > 0)
                                                            return Text('$hours:$minutesString:$secondsString');
                                                          return Text('$minutesString:$secondsString');
                                                        }
                                                    )
                                                  ]
                                              ),
                                            )
                                        );
                                      } else {
                                        return Container();
                                      }
                                    }),
                                Divider(height: 5.0),
                              ]
                          );
                        }).toList(),
                      );
                    }
                    return Container();
                  }
              )
          )
        ]
      ),
      floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.deepPurple,
            child: Icon(Icons.mail_outline),
            heroTag: null,
            onPressed: () async {
                await _activityManager.sendDirectPostDialog(context, conversationId: widget.conversationId);
            },
          ),
      bottomNavigationBar: bottomNavBar(_onItemTapped, _selectedIndex),
    );
  }
}
-------------------------------------------*/

//New Version
class ConversationPageMobile extends StatelessWidget {
  String conversationId;

  ConversationPageMobile({this.conversationId});

  @override
  build(BuildContext context) {
    FirebaseUser firebaseUser = Provider.of<FirebaseUser>(context);
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    return MultiProvider(
      providers: [
        StreamProvider<List<DirectPost>>(create: (_) => DBService().streamDirectPosts(conversationId)),
        StreamProvider<User>(create: (_) => UserManagement().streamCurrentUser(firebaseUser))
      ],
      child: Consumer<List<DirectPost>>(
        builder: (context, postList, _) {
          User user = Provider.of<User>(context);
          return MainPageTemplate(
            isConversation: true,
            conversationId: conversationId,
            bottomNavIndex: 2,
            body: postList == null ? Center(child: CircularProgressIndicator()) : ListView(
              children: postList.map((post) {
                return StreamProvider<User>(
                  create: (context) => UserManagement().streamUserDoc(post.senderUID),
                  child: Consumer<User>(
                    builder: (context, sender, _) {
                      if(sender == null)
                        return Container();

                      //Return list tile for this direct message
                      //Create picUrl widget
                      Widget picButton = InkWell(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (context) =>
                                  ProfilePageMobile(userId: sender.uid),
                            ));
                          },
                          child: sender.profilePicUrl != null ? Container(
                              height: 50.0,
                              width: 50.0,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.deepPurple,
                                  image: DecorationImage(
                                      fit: BoxFit.cover,
                                      image: NetworkImage(sender.profilePicUrl)
                                  )
                              )
                          ) : Container(
                              height: 50.0,
                              width: 50.0,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.deepPurple,
                              )
                          )
                      );

                      //Create play button column
                      Widget playColumn = Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          InkWell(
                            child: Container(
                              height: 35,
                              width: 35,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: mp.currentPostPodId == post.id ? Colors.red : Colors.deepPurple
                              ),
                              child: Center(child: FaIcon(mp.currentPostPodId == post.id && mp.isPlaying != null && mp.isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play, color: Colors.white, size: 16)),
                            ),
                            onTap: () {
                              mp.isPlaying != null && mp.isPlaying && mp.currentPostPodId == post.id ? mp.pausePost() : mp.playPost(PostPodItem.fromDirectPost(post));
                            },
                          ),
                          Text(post.getLengthString())
                        ],
                      );

                      return Card(
                        elevation: 5,
                        color: Colors.deepPurple[50],
                        margin: EdgeInsets.all(5),
                        child: Padding(
                          padding: EdgeInsets.all(5),
                          child: ListTile(
                            leading: user.uid == sender.uid ? playColumn : picButton,
                            trailing: user.uid == sender.uid ? picButton : playColumn,
                            title: Text(post.messageTitle ?? DateFormat('MMMM dd, yyyy hh:mm').format(post.datePosted).toString(), style: TextStyle(fontSize: 16), textAlign: user.uid == sender.uid ? TextAlign.right : TextAlign.left),
                            subtitle: Text('@${post.senderUsername}', style: TextStyle(fontSize: 16), textAlign: user.uid == sender.uid ? TextAlign.right : TextAlign.left,),
                            onTap: () async {
                              await ActivityManager().sendDirectPostDialog(context, conversationId: conversationId);
                            },
                          ),
                        )
                      );
                    },
                  ),
                );
              }).toList()
            ),
          );
        },
      ),
    );
  }
}