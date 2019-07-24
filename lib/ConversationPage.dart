import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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

  @override
  Widget build(BuildContext context) {
    print('Conversation with ${widget.targetUID}');
    return Scaffold(
      appBar: new AppBar(
          title: Text(widget.targetUsername),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            color: Colors.white,
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          actions: <Widget>[
            FlatButton(
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
            ),
          ]
      ),
      body: Container(
        child: StreamBuilder(
          stream: Firestore.instance.collection('directposts').where('conversationId', isEqualTo: widget.conversationId).snapshots(),
          builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if(snapshot.hasData) {
              return ListView(
                children: snapshot.data.documents.map((DocumentSnapshot docSnap) {
                  String sender = docSnap.data['senderUsername'];
                  int secondsLength = docSnap.data['secondsLength'];
                  String messageTitle = docSnap.data['messageTitle'];
                  DateTime datePosted = docSnap.data['datePosted'].toDate();
                  String dateString = DateFormat('MMMM dd, yyyy hh:mm:ss').format(datePosted).toString();
                  String postId = docSnap.reference.documentID;
                  String postAudioUrl = docSnap.data['audioFileLocation'];

                  Widget playButton = SizedBox(
                    height: 35.0,
                    width: 35.0,
                    child: FloatingActionButton(
                      backgroundColor: _playingId == docSnap.reference.documentID ? Colors.red : Colors.deepPurple,
                      child: _playingId == docSnap.reference.documentID ? Icon(Icons.stop) : Icon(Icons.play_arrow),
                      heroTag: null,
                      onPressed: () async {
                        if(_isPlaying) {
                          _activityManager.stopPlaying();
                          bool isPlaying = false;
                          String playingPostId;

                          if(_playingId != postId){
                            _activityManager.playRecording(postAudioUrl);
                            isPlaying = true;
                            playingPostId = postId;
                          }
                          setState(() {
                            _isPlaying = isPlaying;
                            _playingId = playingPostId;
                          });
                        } else {
                          if (postAudioUrl != null && postAudioUrl != 'null') {
                            _activityManager.playRecording(
                                postAudioUrl);
                            setState(() {
                              _isPlaying = true;
                              _playingId = postId;
                            });
                          }
                        }
                      },
                    )
                  );

                  Widget messageText = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        messageTitle != null ? Text(messageTitle) : Text(dateString),
                        Text(sender),
                      ]
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
                            return ListTile(
                              leading: docSnap.data['senderUID'] == snapshot.data.reference.documentID
                                  ? playButton
                                  : messageText,
                              trailing: docSnap.data['senderUID'] == snapshot.data.reference.documentID
                                  ? messageText
                                  : playButton,
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