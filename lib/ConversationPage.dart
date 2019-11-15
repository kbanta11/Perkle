import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';

import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';

import 'PageComponents.dart';
import 'HomePage.dart';
import 'ListPage.dart';
import 'ProfilePage.dart';

class ConversationPage extends StatefulWidget {
  final String conversationId;
  final String targetUsername;
  final String targetUID;

  ConversationPage({Key key, @required this.conversationId, this.targetUsername, this.targetUID}) : super(key: key);

  @override
  _ConversationPageState createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  int _selectedIndex = 2;
  ActivityManager _activityManager = new ActivityManager();
  bool _isPlaying = false;
  String _playingId;

  void _onItemTapped(int index) async {
    if(index == 0) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => HomePage(),
      ));
    }
    if(index == 3) {
      String uid = await UserManagement().getUserData().then((DocumentReference docRef) {
        return docRef.documentID;
      });
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ProfilePage(userId: uid),
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
  Widget build(BuildContext context) {
    print('Conversation with ${widget.targetUID}');
    return Scaffold(
      appBar: new AppBar(
        title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              mainPopMenu(context),
              IconButton(
                icon: Icon(Icons.search),
                iconSize: 40.0,
                onPressed: () {
                  Navigator.of(context).pushNamed('/searchpage');
                },
              ),
              Expanded(
                child: Center(
                  child: FutureBuilder(
                      future: _getUsername(widget.targetUID),
                      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                        switch (snapshot.connectionState) {
                          case ConnectionState.done:
                            if(snapshot.hasError)
                              return null;
                            return Text(snapshot.data);
                          default:
                            return Text('Loading...');
                        }
                      }),
                ),
              ),
            ]
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        titleSpacing: 5.0,
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: Colors.white),
            iconSize: 40.0,
          ),
          RecordButton(),
          /*new FlatButton(
              child: Text('Logout'),
              textColor: Colors.white,
              onPressed: () {
                FirebaseAuth.instance.signOut().then((value) {
                  Navigator.of(context).pushReplacementNamed('/landingpage');
                })
                    .catchError((e) {
                  print(e);
                });
              }
          ),*/
        ],
      ),
      body: Container(
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

                  Widget playButton = SizedBox(
                    height: 35.0,
                    width: 35.0,
                    child: StreamBuilder(
                      stream: postPlayer.onPlayerStateChanged,
                      builder: (BuildContext context, snapshot) {
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
                              _activityManager.stopPlaying(postPlayer);
                            } else {
                              if (postAudioUrl != null && postAudioUrl != 'null') {
                                _activityManager.playRecording(postAudioUrl, postPlayer);
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
                                  leading: playButton,
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
                                                    ProfilePage(userId: docSnap.data['senderUID']),
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
                                                  ProfilePage(userId: docSnap.data['senderUID']),
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
                                                    ProfilePage(userId: docSnap.data['senderUID']),
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
                                                  ProfilePage(userId: docSnap.data['senderUID']),
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
                                trailing: playButton,
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
      ),
      floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.deepPurple,
            child: Icon(Icons.mail_outline),
            heroTag: null,
            onPressed: () async {
              print('Sending to ${widget.targetUID}');
                await _activityManager.sendDirectPostDialog(widget.targetUID, widget.targetUsername, context);
            },
          ),
      bottomNavigationBar: bottomNavBar(_onItemTapped, _selectedIndex),
    );
  }
}