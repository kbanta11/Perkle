import 'package:Perkl/services/db_services.dart';
import 'package:Perkl/services/models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:podcast_search/podcast_search.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'main.dart';


class ShareToDialog extends StatefulWidget {
  Post post;
  Episode episode;
  Podcast podcast;
  PerklUser currentUser;
  String recordingLocation;

  ShareToDialog({Key key, this.post, this.episode, this.podcast, this.currentUser, @required this.recordingLocation,}) : super(key: key);

  @override
  _ShareToDialogState createState() => new _ShareToDialogState();
}

class _ShareToDialogState extends State<ShareToDialog> {
  bool _isLoading = false;
  bool _addToTimeline = false;
  bool _sendAsGroup = false;
  Map<String, dynamic> _sendToUsers = new Map<String, dynamic>();
  Map<String, dynamic> _addToConversations = new Map<String, dynamic>();

  @override
  build(BuildContext context) {
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    return SimpleDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15.0))),
      contentPadding: EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 10.0),
      title: Center(child: Text('Share and Discuss',
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
              Center(child: Text('${widget.episode.title}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),),
              Center(child: Text('${widget.podcast.title}', style: TextStyle(fontSize: 16), textAlign: TextAlign.center)),
              SizedBox(height: 10),
              Text('Existing Conversations'),
              Divider(height: 2.5),
              StreamBuilder(
                  stream: FirebaseFirestore.instance.collection('conversations').where('memberList', arrayContains: FirebaseAuth.instance.currentUser.uid.toString()).snapshots(),
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
                                  if(key != FirebaseAuth.instance.currentUser.uid) {
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
              StreamBuilder(
                  stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser.uid).snapshots(),
                  builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
                    if(!snapshot.hasData)
                      return Container(height: 150.0, width: 500.0);
                    Map<dynamic, dynamic> followers = snapshot.data.data()['followers'];
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
                                      future: FirebaseFirestore.instance.collection('users').doc(item.key).get(),
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
                                      _sendToUsers[item.key] = value;
                                    });
                                  }
                              );
                            }).toList(),
                          )
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
                            _sendToUsers.removeWhere((key, value) => value == false);
                            _addToConversations.removeWhere((key, value) => value == false);
                            //print('Sending to: $_sendToUsers / As Group: $_sendAsGroup / Add to Timeline: $_addToTimeline');
                            if(_addToTimeline || (_sendToUsers != null && _sendToUsers.length > 0) || (_addToConversations != null && _addToConversations.length > 0)) {
                              setState(() {
                                _isLoading = true;
                              });

                              await DBService().shareEpisodeToDiscussion(episode: widget.episode, podcast: widget.podcast, sender: widget.currentUser, sendAsGroup: _sendAsGroup, sendToUsers: _sendToUsers, addToConversations: _addToConversations,);
                              Navigator.of(context).pop();

                              print('Post/Episode shared');
                            } else {
                              await showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text('No Selection'),
                                      content: Text('Please select which user(s) or group(s) to share with.'),
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