import 'package:Perkl/main.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
//import 'package:audioplayers/audioplayers.dart';
import 'package:just_audio/just_audio.dart';
import 'CreateGroupDialog.dart';
import 'PageComponents.dart';
import 'services/db_services.dart';
import 'services/ActivityManagement.dart';
import 'services/models.dart';

class AddPostDialog extends StatefulWidget {
  DateTime? date;
  String? recordingLocation;
  int? secondsLength;

  AddPostDialog({Key? key, this.date, this.recordingLocation, this.secondsLength}) : super(key: key);

  @override
  _AddPostDialogState createState() => new _AddPostDialogState();
}

class _AddPostDialogState extends State<AddPostDialog> {
  String? _postTitle;
  String? _postTags;
  bool _isLoading = false;
  bool showTitleTags = false;
  bool _addToTimeline = false;
  bool _sendAsGroup = false;
  bool _isPlayingRecorder = false;
  bool _isRecording = false;
  String? _recordingLocation;
  DateTime? _startDate;
  int? _secondsLength;
  AudioPlayer player = new AudioPlayer();
  Map<String, dynamic> _sendToUsers = new Map<String, dynamic>();
  Map<String, dynamic> _addToConversations = new Map<String, dynamic>();

  Widget getSelectList(PerklUser? user) {
    List<String>? selectableFollowers = user?.followers?.where((followerID) => user.following?.contains(followerID) ?? false).toList();
    return Expanded(
      child: StreamBuilder(
        stream: DBService().streamConversations(user?.uid),
        builder: (context, AsyncSnapshot<List<Conversation>> convoSnap) {
          print('Convo Snap: ${convoSnap.data}');
          if(convoSnap.hasData) {
            List<Conversation> convoList = convoSnap.data ?? [];
            List<Widget> tileList = <Widget>[];
            for(Conversation convo in convoList) {
              if(!_addToConversations.containsKey(convo.id))
                _addToConversations.addAll({(convo.id ?? ''): false});
              bool _val = _addToConversations[convo.id];
              tileList.add(CheckboxListTile(
                  title: Text(convo.getTitle(user), style: TextStyle(fontSize: 14)),
                  value: _val,
                  onChanged: (value) {
                    print(_addToConversations);
                    setState(() {
                      _addToConversations[convo.id ?? ''] = value;
                    });
                  }
              ));
            }
            if(selectableFollowers != null && selectableFollowers.length > 0) {
              tileList.insert(0, ListTile(
                title: Text('Create New Group'),
                trailing: Icon(Icons.people),
                onTap: () async {
                  await showDialog(
                    context: context,
                    builder: (context) {
                      return CreateGroupDialog(user: user);
                    }
                  ).then((val) {
                    if(val != null) {
                      //select newly created convo
                      Conversation newConvo = val;
                      setState(() {
                        _addToConversations.addAll({newConvo.id ?? '': true});
                      });
                    } else {
                      print('Group Creation Cancelled...');
                    }
                    print('Value from create group dialog: $val');
                  });
                },
              ));
              tileList.insert(1, Divider(height: 5,));
              tileList.add(Divider(height: 5));
              tileList.add(ListTile(
                title: Text('Mutual Followers...', style: TextStyle(color: Colors.deepPurple))
              ));
              tileList.add(Divider(height: 5));
            }
            for(String follower in (selectableFollowers ?? [])) {
              if(!_sendToUsers.containsKey(follower)) {
                _sendToUsers.addAll({follower: false});
              }
              bool _val = _sendToUsers[follower];
              tileList.add(CheckboxListTile(
                  title: FutureBuilder(
                      future: DBService().getPerklUser(follower),
                      builder: (context, AsyncSnapshot<PerklUser> thisUserSnap) {
                        if(!thisUserSnap.hasData)
                          return Container();
                        return Text(thisUserSnap.data?.username ?? '', style: TextStyle(fontSize: 14),);
                      }
                  ),
                  value: _val,
                  onChanged: (value) {
                    print(_sendToUsers);
                    setState(() {
                      _sendToUsers[follower] = value;
                    });
                  }
              ));
            }
            print('Tile List: $tileList');
            return ListView(
              children: tileList != null && tileList.length > 0 ? tileList : [Container()],
            );
          }
          return Container();
        }
      )
    );
  }

  @override
  initState() {
    setState(() {
      _recordingLocation = widget.recordingLocation;
      _startDate = widget.date;
      _secondsLength = widget.secondsLength;
    });
    super.initState();
  }

  @override
  dispose() {
    super.dispose();
    player.dispose();
  }

  @override
  build(BuildContext context) {
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    //User user = Provider.of<User>(context);
    PerklUser? perklUser = Provider.of<PerklUser?>(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15.0))),
      contentPadding: EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 10.0),
      title: Center(child: Text('Add New Post',
          style: TextStyle(color: Colors.deepPurple)
      )),
      content: Container(
        height: MediaQuery.of(context).size.height - 20,
        width: MediaQuery.of(context).size.width - 20,
        child: _isLoading ? Center(
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
                                print('recording location when stopping: ${_recordingLocation}');
                                List<dynamic>? stopRecordVals = await mp.activityManager.stopRecordNewPost(_recordingLocation, _startDate);
                                String recordingLocation = stopRecordVals?[0];
                                int secondsLength = stopRecordVals?[1];

                                print('$recordingLocation -/- Length: $secondsLength');
                                setState(() {
                                  _isRecording = !_isRecording;
                                  _secondsLength = secondsLength;
                                });
                                //print('getting date');
                                DateTime date = new DateTime.now();
                                //print('date before dialog: $date');
                                //await addPostDialog(context, date, recordingLocation, secondsLength);
                              } else {
                                List<dynamic>? startRecordVals = await mp.activityManager.startRecordNewPost(mp);
                                String postPath = startRecordVals?[0];
                                DateTime startDate = startRecordVals?[1];
                                print('Post Path of new recording: $postPath');
                                setState(() {
                                  _isRecording = !_isRecording;
                                  _recordingLocation = postPath;
                                  _startDate = startDate;
                                });
                                print('recording location after state set: ${_recordingLocation}');
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
                        color: _recordingLocation == null ? Colors.grey : Colors.deepPurple,
                      ),
                      height: 50,
                      width: 50,
                      child: InkWell(
                        borderRadius: BorderRadius.all(Radius.circular(25)),
                        child: Icon(_isPlayingRecorder ? Icons.pause : Icons.play_arrow, color: Colors.white,),
                        onTap: () async {
                          if(_recordingLocation == null) {
                            return;
                          }
                          if(_isPlayingRecorder) {
                            player.pause();
                            setState(() {
                              _isPlayingRecorder = false;
                            });
                          } else {
                            print('Playing recording at: ${_recordingLocation}');
                            player.dispose();
                            player = new AudioPlayer();
                            print('Setting file path');
                            await player.setFilePath(_recordingLocation ?? '');
                            //await Future.delayed(Duration(milliseconds: 500));
                            print('Starting to play local file');
                            player.play();
                            print('player started....');
                            //player.play(_recordingLocation, isLocal: true);
                            player.processingStateStream.listen((ProcessingState state) {
                              if(state == ProcessingState.completed) {
                                setState(() {
                                  _isPlayingRecorder = false;
                                });
                              }
                            });
                            /*
                            player.onPlayerCompletion.listen((event) {
                              setState(() {
                                _isPlayingRecorder = false;
                              });
                            });
                            */
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
                Center(child: Text('${mp.recordingTime != null ? mp.activityManager.getDurationString(mp.recordingTime) : ''}')),
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
                                setState(() {
                                  _postTitle = value;
                                });
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
                            setState(() {
                              _postTags = value;
                            });
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
                getSelectList(perklUser),
                /*
                StreamBuilder(
                    stream: FirebaseFirestore.instance.collection('conversations').where('memberList', arrayContains: user.uid.toString()).snapshots(),
                    builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                      if(!snapshot.hasData)
                        return Container(height: 150.0, width: 500.0);

                      if(snapshot.data.docs.length == 0)
                        return Center(child: Text('You have no conversations!'));
                      else
                        return Container(
                            height: 150.0,
                            width: 500.0,
                            child: ListView(
                              shrinkWrap: true,
                              scrollDirection: Axis.vertical,
                              children: snapshot.data.docs.map((convo) {
                                String titleText = '';
                                Map<dynamic, dynamic> memberDetails = convo.data()['conversationMembers'];
                                if(memberDetails != null){
                                  memberDetails.forEach((key, value) {
                                    if(key != user.uid) {
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
                                if(!_addToConversations.containsKey(convo.id))
                                  _addToConversations.addAll({convo.id: false});
                                bool _val = _addToConversations[convo.id];
                                return CheckboxListTile(
                                    title: Text(titleText, style: TextStyle(fontSize: 14)),
                                    value: _val,
                                    onChanged: (value) {
                                      print(_addToConversations);
                                      setState(() {
                                        _addToConversations[convo.id] = value;
                                      });
                                    }
                                );
                              }).toList(),
                            )
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
                Container(
                    height: 150.0,
                    width: 500.0,
                    child: ListView(
                      shrinkWrap: true,
                      scrollDirection: Axis.vertical,
                      children: perklUser.followers.map((item) {
                        if(!_sendToUsers.containsKey(item))
                          _sendToUsers.addAll({item: false});
                        bool _val = _sendToUsers[item];
                        return CheckboxListTile(
                            title: FutureBuilder(
                                future: FirebaseFirestore.instance.collection('users').doc(item).get(),
                                builder: (context, AsyncSnapshot<DocumentSnapshot> itemDoc) {
                                  if(!itemDoc.hasData)
                                    return Container();
                                  return Text(itemDoc.data.data()['username'], style: TextStyle(fontSize: 14),);
                                }
                            ),
                            value: _val,
                            onChanged: (value) {
                              print(_sendToUsers);
                              setState(() {
                                _sendToUsers[item] = value;
                              });
                            }
                        );
                      }).toList(),
                    )
                ),
                */
                Row(
                  children: <Widget>[
                    FlatButton(
                        child: Text('Cancel'),
                        textColor: Colors.deepPurple,
                        onPressed: () {
                          Navigator.of(context).pop();
                        }
                    ),
                    Expanded(child: Container()),
                    _recordingLocation == null ? OutlineButton(
                      color: Colors.red,
                      borderSide: BorderSide(color: Colors.red),
                      child: Text('Record First', style: TextStyle(color: Colors.red)),
                      onPressed: () {

                      },
                    ) : TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          textStyle: TextStyle(color: Colors.white),
                        ),
                        child: Text('Add Post', style: TextStyle(color: Colors.white)),
                        onPressed: () async {
                          if(_recordingLocation != null) {
                            List<String>? tagList = processTagString(_postTags ?? '');
                            print({"postTitle": _postTitle,
                              "localRecordingLocation": _recordingLocation,
                              "date": _startDate,
                              "listens": 0,
                              "secondsLength": _secondsLength,
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
                                "localRecordingLocation": _recordingLocation,
                                "date": _startDate,
                                "listens": 0,
                                "secondsLength": _secondsLength,
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
          ],
        )
      ),
    );
  }
}