import 'package:Perkl/main.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'PageComponents.dart';
import 'services/db_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'services/ActivityManagement.dart';

class AddPostDialog extends StatefulWidget {
  DateTime date;
  String recordingLocation;
  int secondsLength;

  AddPostDialog({Key key, this.date, this.recordingLocation, this.secondsLength}) : super(key: key);

  @override
  _AddPostDialogState createState() => new _AddPostDialogState();
}

class _AddPostDialogState extends State<AddPostDialog> {
  String _postTitle;
  String _postTags;
  bool _isLoading = false;
  bool showTitleTags = false;
  bool _addToTimeline = false;
  bool _sendAsGroup = false;
  bool _isPlayingRecorder = false;
  bool _isRecording = false;
  AudioPlayer player = new AudioPlayer(mode: PlayerMode.MEDIA_PLAYER);
  Map<String, dynamic> _sendToUsers = new Map<String, dynamic>();
  Map<String, dynamic> _addToConversations = new Map<String, dynamic>();

  @override
  build(BuildContext context) {
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    return SimpleDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15.0))),
      contentPadding: EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 10.0),
      title: Center(child: Text('Add New Post',
          style: TextStyle(color: Colors.deepPurple)
      )),
      children: <Widget>[
        _isLoading ? Center(
            child: Container(
                height: 75.0,
                width: 75.0,
                child: CircularProgressIndicator()
            )
        ) : Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      _isRecording ? Align(
                        alignment: Alignment.center,
                        child: Center(child: RecordingPulse(maxSize: 50,)),
                      ) : Container(),
                      Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.red),
                          shape: BoxShape.circle,
                          color: _isRecording ? Colors.transparent : Colors.red,
                        ),
                        child: InkWell(
                          child: Center(child: Icon(Icons.mic, color: _isRecording ? Colors.red : Colors.white,)),
                          onTap: () async {
                            if(_isRecording) {
                              List<dynamic> stopRecordVals = await mp.activityManager.stopRecordNewPost(widget.recordingLocation, widget.date);
                              String recordingLocation = stopRecordVals[0];
                              int secondsLength = stopRecordVals[1];

                              print('$recordingLocation -/- Length: $secondsLength');
                              setState(() {
                                _isRecording = !_isRecording;
                                widget.secondsLength = secondsLength;
                              });
                              print('getting date');
                              DateTime date = new DateTime.now();
                              print('date before dialog: $date');
                              //await addPostDialog(context, date, recordingLocation, secondsLength);
                            } else {
                              List<dynamic> startRecordVals = await mp.activityManager.startRecordNewPost(mp);
                              String postPath = startRecordVals[0];
                              DateTime startDate = startRecordVals[1];
                              setState(() {
                                _isRecording = !_isRecording;
                                widget.recordingLocation = postPath;
                                widget.date = startDate;
                              });
                            }
                          },
                        ),
                      )
                    ],
                  ),
                  SizedBox(width: 25),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.recordingLocation == null ? Colors.grey : Colors.deepPurple,
                    ),
                    height: 50,
                    width: 50,
                    child: InkWell(
                      borderRadius: BorderRadius.all(Radius.circular(25)),
                      child: Icon(_isPlayingRecorder ? Icons.pause : Icons.play_arrow, color: Colors.white,),
                      onTap: () {
                        if(widget.recordingLocation == null) {
                          return;
                        }
                        if(_isPlayingRecorder) {
                          player.pause();
                          setState(() {
                            _isPlayingRecorder = false;
                          });
                        } else {
                          player.play(widget.recordingLocation, isLocal: true);
                          player.onPlayerCompletion.listen((event) {
                            setState(() {
                              _isPlayingRecorder = false;
                            });
                          });
                          setState(() {
                            _isPlayingRecorder = true;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Center(child: Text('${mp.recordingTime != null ? ActivityManager().getDurationString(mp.recordingTime) : ''}')),
              SizedBox(height: 10),
              SwitchListTile(
                title: Text('Add Title or Tags'),
                activeColor: Colors.deepPurple,
                value: showTitleTags,
                onChanged: (value) {
                  setState(() {
                    showTitleTags = value;
                  });
                },
              ),
              showTitleTags ? Column(
                  children: <Widget>[
                    Container(
                        width: 700.0,
                        child: TextField(
                            style: TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: _postTitle == null ? 'Post Title (Optional)' : _postTitle,
                            ),
                            onChanged: (value) {
                              //print(_postTitle);
                              _postTitle = value;
                            }
                        )
                    ),
                    SizedBox(height: 20.0),
                    Text('Stream Tags (separated by \'#\')', style: TextStyle(fontSize: 14)),
                    Container(
                      width: 700.0,
                      child: TextField(
                        style: TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: _postTags == null ? '#TagYourTopics' : _postTags,
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.multiline,
                        maxLines: 5,
                        onChanged: (value) {
                          _postTags = value;
                        },
                      ),
                    )
                  ]
              ) : Container(),
              CheckboxListTile(
                  title: Text('My Timeline', style: TextStyle(fontSize: 14),),
                  value: _addToTimeline,
                  onChanged: (value) {
                    setState(() {
                      _addToTimeline = !_addToTimeline;
                    });
                  }
              ),
              Divider(height: 2.5),
              FutureBuilder(
                  future: FirebaseAuth.instance.currentUser(),
                  builder: (context, AsyncSnapshot<FirebaseUser> userSnap) {
                    if(!userSnap.hasData)
                      return Container(height: 180.0, width: 500.0);
                    String userId = userSnap.data.uid;
                    return StreamBuilder(
                        stream: Firestore.instance.collection('conversations').where('memberList', arrayContains: userSnap.data.uid.toString()).snapshots(),
                        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                          if(!snapshot.hasData)
                            return Container(height: 150.0, width: 500.0);

                          if(snapshot.data.documents.length == 0)
                            return Center(child: Text('You have no conversations!'));
                          else
                            return Container(
                                height: 150.0,
                                width: 500.0,
                                child: ListView(
                                  shrinkWrap: true,
                                  scrollDirection: Axis.vertical,
                                  children: snapshot.data.documents.map((convo) {
                                    String titleText = '';
                                    Map<dynamic, dynamic> memberDetails = convo.data['conversationMembers'];
                                    if(memberDetails != null){
                                      memberDetails.forEach((key, value) {
                                        if(key != userSnap.data.uid) {
                                          if(titleText.length > 0)
                                            titleText = titleText + ', ' + value['username'];
                                          else
                                            titleText = value['username'];
                                        }
                                      });
                                    }

                                    if(titleText.length > 50){
                                      titleText = titleText.substring(0,47) + '...';
                                    }
                                    if(!_addToConversations.containsKey(convo.documentID))
                                      _addToConversations.addAll({convo.documentID: false});
                                    bool _val = _addToConversations[convo.documentID];
                                    return CheckboxListTile(
                                        title: Text(titleText, style: TextStyle(fontSize: 14)),
                                        value: _val,
                                        onChanged: (value) {
                                          print(_addToConversations);
                                          setState(() {
                                            _addToConversations[convo.documentID] = value;
                                          });
                                        }
                                    );
                                  }).toList(),
                                )
                            );
                        }
                    );
                  }
              ),
              Divider(height: 2.5),
              Container(
                  child: SwitchListTile(
                    title: Text('Send as Group'),
                    activeColor: Colors.deepPurple,
                    value: _sendAsGroup,
                    onChanged: (value) {
                      setState(() {
                        _sendAsGroup = !_sendAsGroup;
                      });
                    },
                  )
              ),
              Divider(height: 2.5),
              FutureBuilder(
                  future: FirebaseAuth.instance.currentUser(),
                  builder: (context, AsyncSnapshot<FirebaseUser> userSnap) {
                    if(!userSnap.hasData)
                      return Container(height: 150.0, width: 500.0);
                    String userId = userSnap.data.uid;
                    return StreamBuilder(
                        stream: Firestore.instance.collection('users').document(userId).snapshots(),
                        builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
                          if(!snapshot.hasData)
                            return Container(height: 150.0, width: 500.0);
                          Map<dynamic, dynamic> followers = snapshot.data['followers'];
                          if(followers == null)
                            return Container(height: 150.0, width: 500.0);
                          else
                            return Container(
                                height: 150.0,
                                width: 500.0,
                                child: ListView(
                                  shrinkWrap: true,
                                  scrollDirection: Axis.vertical,
                                  children: followers.entries.map((item) {
                                    if(!_sendToUsers.containsKey(item.key))
                                      _sendToUsers.addAll({item.key: false});
                                    bool _val = _sendToUsers[item.key];
                                    return CheckboxListTile(
                                        title: FutureBuilder(
                                            future: Firestore.instance.collection('users').document(item.key).get(),
                                            builder: (context, AsyncSnapshot<DocumentSnapshot> itemDoc) {
                                              if(!itemDoc.hasData)
                                                return Container();
                                              return Text(itemDoc.data['username'], style: TextStyle(fontSize: 14),);
                                            }
                                        ),
                                        value: _val,
                                        onChanged: (value) {
                                          print(_sendToUsers);
                                          setState(() {
                                            _sendToUsers[item.key] = value;
                                          });
                                        }
                                    );
                                  }).toList(),
                                )
                            );
                        }
                    );
                  }
              ),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    FlatButton(
                        child: Text('Cancel'),
                        textColor: Colors.deepPurple,
                        onPressed: () {
                          Navigator.of(context).pop();
                        }
                    ),
                    widget.recordingLocation == null ? OutlineButton(
                      color: Colors.red,
                      borderSide: BorderSide(color: Colors.red),
                      child: Text('Record First'),
                      onPressed: () {

                      },
                    ) : FlatButton(
                        color: Colors.deepPurple,
                        child: Text('Add Post'),

                        textColor: Colors.white,
                        onPressed: () async {
                          if(widget.recordingLocation != null) {
                            List<String> tagList = processTagString(_postTags);
                            print({"postTitle": _postTitle,
                              "localRecordingLocation": widget.recordingLocation,
                              "date": widget.date,
                              "listens": 0,
                              "secondsLength": widget.secondsLength,
                              "streamList": tagList,
                              "test": "tester",
                            });
                            _sendToUsers.removeWhere((key, value) => value == false);
                            _addToConversations.removeWhere((key, value) => value == false);
                            //print('Sending to: $_sendToUsers / As Group: $_sendAsGroup / Add to Timeline: $_addToTimeline');
                            if(_addToTimeline || (_sendToUsers != null && _sendToUsers.length > 0) || (_addToConversations != null && _addToConversations.length > 0)) {
                              setState(() {
                                _isLoading = true;
                              });
                              await ActivityManager().addPost(context, {"postTitle": _postTitle,
                                "localRecordingLocation": widget.recordingLocation,
                                "date": widget.date,
                                "listens": 0,
                                "secondsLength": widget.secondsLength,
                                "streamList": tagList,
                              }, _addToTimeline, _sendAsGroup, _sendToUsers, _addToConversations);
                              print('Post added');
                            } else {
                             await showDialog(
                               context: context,
                               builder: (BuildContext context) {
                                 return AlertDialog(
                                   title: Text('No Selection'),
                                   content: Text('Please select to either add this post to your timeline or send to another user or group.'),
                                   actions: <Widget>[FlatButton(
                                     child: Text('OK'),
                                     onPressed: () {
                                       Navigator.of(context).pop();
                                     },
                                   )],
                                 );
                               }
                             );
                            }
                          }
                        }
                    )
                  ]
              )
            ]
        ),
      ],
    );
  }
}