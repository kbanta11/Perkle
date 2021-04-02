import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:podcast_search/podcast_search.dart';
import 'main.dart';
import 'CreateGroupDialog.dart';
import 'services/ActivityManagement.dart';
import 'services/models.dart';
import 'services/db_services.dart';

class CreateClipDialog extends StatefulWidget {
  MediaItem mediaItem;
  PlaybackState playbackState;

  CreateClipDialog({Key key, @required this.mediaItem, @required this.playbackState}) : super(key: key);

  @override
  _CreateClipDialogState createState() => new _CreateClipDialogState();
}

class _CreateClipDialogState extends State<CreateClipDialog> {
  Duration startDuration = Duration(milliseconds: 0);
  Duration endDuration = Duration(milliseconds: 5000);
  AudioPlayer clipPlayer = AudioPlayer();
  int displayPage = 1;
  Map<String, dynamic> _sendToUsers = new Map<String, dynamic>();
  Map<String, dynamic> _addToConversations = new Map<String, dynamic>();
  bool _savePrivate = false;
  TextEditingController _clipTitleController = TextEditingController();

  Widget setClipColumn()  {
    return Column(
        children: [
          RangeSlider(
            values: RangeValues(startDuration.inSeconds.toDouble(), endDuration.inSeconds.toDouble()),
            min: 0,
            max: widget.mediaItem.duration.inSeconds.toDouble(),
            onChanged: (RangeValues vals) async {
              //await clipPlayer.setClip(start: startDuration, end: endDuration);
              setState(() {
                startDuration = Duration(seconds: vals.start.toInt());
                endDuration = Duration(seconds: vals.end.toInt());
              });
            },
          ),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Start', style: TextStyle(fontSize: 18)),
                Text('End', style: TextStyle(fontSize: 18)),
              ]
          ),
          SizedBox(height: 10),
          Center(child: Text('Adjust Clip Start')),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                    iconSize: 40,
                    icon: Icon(Icons.replay_30, color: Colors.deepPurple),
                    onPressed: () {
                      Duration newDuration;
                      if(startDuration.inMilliseconds - 30000 > 0) {
                        newDuration = Duration(milliseconds: startDuration.inMilliseconds - 30000);
                      } else {
                        newDuration = Duration(milliseconds: 0);
                      }
                      setState(() {
                        startDuration = newDuration;
                      });
                    }
                ),
                IconButton(
                    iconSize: 40,
                    icon: Icon(Icons.replay_5, color: Colors.deepPurple),
                    onPressed: () {
                      Duration newDuration;
                      if(startDuration.inMilliseconds - 5000 > 0) {
                        newDuration = Duration(milliseconds: startDuration.inMilliseconds - 5000);
                      } else {
                        newDuration = Duration(milliseconds: 0);
                      }
                      setState(() {
                        startDuration = newDuration;
                      });
                    }
                ),
                IconButton(
                    iconSize: 40,
                    icon: Icon(Icons.forward_5, color: Colors.deepPurple),
                    onPressed: () {
                      Duration newDuration;
                      if(startDuration.inMilliseconds + 5000 > endDuration.inMilliseconds) {
                        newDuration = Duration(milliseconds: endDuration.inMilliseconds - 5000);
                      } else {
                        newDuration = Duration(milliseconds: startDuration.inMilliseconds + 5000);
                      }
                      setState(() {
                        startDuration = newDuration;
                      });
                    }
                ),
                IconButton(
                    iconSize: 40,
                    icon: Icon(Icons.forward_30, color: Colors.deepPurple),
                    onPressed: () {
                      Duration newDuration;
                      if(startDuration.inMilliseconds + 30000 > endDuration.inMilliseconds) {
                        newDuration = Duration(milliseconds: endDuration.inMilliseconds - 5000);
                      } else {
                        newDuration = Duration(milliseconds: startDuration.inMilliseconds + 30000);
                      }
                      setState(() {
                        startDuration = newDuration;
                      });
                    }
                ),
              ]
          ),
          Center(child: Text('Adjust Clip End')),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                    iconSize: 40,
                    icon: Icon(Icons.replay_30, color: Colors.deepPurple),
                    onPressed: () {
                      Duration newDuration;
                      if(endDuration.inMilliseconds - 30000 > startDuration.inMilliseconds) {
                        newDuration = Duration(milliseconds: endDuration.inMilliseconds - 30000);
                      } else {
                        newDuration = Duration(milliseconds: startDuration.inMilliseconds + 5000);
                      }
                      setState(() {
                        endDuration = newDuration;
                      });
                    }
                ),
                IconButton(
                    iconSize: 40,
                    icon: Icon(Icons.replay_5, color: Colors.deepPurple),
                    onPressed: () {
                      Duration newDuration;
                      if(endDuration.inMilliseconds - 5000 > startDuration.inMilliseconds) {
                        newDuration = Duration(milliseconds: endDuration.inMilliseconds - 5000);
                      } else {
                        newDuration = Duration(milliseconds: startDuration.inMilliseconds + 5000);
                      }
                      setState(() {
                        endDuration = newDuration;
                      });
                    }
                ),
                IconButton(
                    iconSize: 40,
                    icon: Icon(Icons.forward_5, color: Colors.deepPurple),
                    onPressed: () {
                      Duration newDuration;
                      if(endDuration.inMilliseconds + 5000 > widget.mediaItem.duration.inMilliseconds) {
                        newDuration = Duration(milliseconds: widget.mediaItem.duration.inMilliseconds);
                      } else {
                        newDuration = Duration(milliseconds: endDuration.inMilliseconds + 5000);
                      }
                      setState(() {
                        endDuration = newDuration;
                      });
                    }
                ),
                IconButton(
                    iconSize: 40,
                    icon: Icon(Icons.forward_30, color: Colors.deepPurple),
                    onPressed: () {
                      Duration newDuration;
                      if(endDuration.inMilliseconds + 30000 > widget.mediaItem.duration.inMilliseconds) {
                        newDuration = Duration(milliseconds: widget.mediaItem.duration.inMilliseconds);
                      } else {
                        newDuration = Duration(milliseconds: endDuration.inMilliseconds + 30000);
                      }
                      setState(() {
                        endDuration = newDuration;
                      });
                    }
                ),
              ]
          )
        ]
    );
  }

  Widget sendToColumn(PerklUser user) {
    List<String> selectableFollowers = user.followers.where((followerID) => user.following.contains(followerID)).toList();
    return Expanded(
        child: StreamBuilder(
            stream: DBService().streamConversations(user.uid),
            builder: (context, AsyncSnapshot<List<Conversation>> convoSnap) {
              //print('Convo Snap: ${convoSnap.data}');
              if(convoSnap.hasData) {
                List<Conversation> convoList = convoSnap.data;
                List<Widget> tileList = <Widget>[];
                for(Conversation convo in convoList) {
                  if(!_addToConversations.containsKey(convo.id))
                    _addToConversations.addAll({convo.id: false});
                  bool _val = _addToConversations[convo.id];
                  tileList.add(CheckboxListTile(
                      title: Text(convo.getTitle(user), style: TextStyle(fontSize: 14)),
                      value: _val,
                      onChanged: (value) {
                        print(_addToConversations);
                        setState(() {
                          _addToConversations[convo.id] = value;
                        });
                      }
                  ));
                }
                tileList.insert(0, CheckboxListTile(
                  title: Text('My Private Clips'),
                  value: _savePrivate,
                  onChanged: (value) {
                    setState(() {
                      _savePrivate = value;
                    });
                  }
                ));
                if(selectableFollowers != null && selectableFollowers.length > 0) {
                  tileList.insert(1, ListTile(
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
                            _addToConversations.addAll({newConvo.id: true});
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
                for(String follower in selectableFollowers) {
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
                            return Text(thisUserSnap.data.username, style: TextStyle(fontSize: 14),);
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
    super.initState();
    setState(() {
      if(widget.playbackState != null && widget.playbackState.position != null && widget.playbackState.position.inMilliseconds - 60000 > 0) {
        startDuration = Duration(milliseconds: widget.playbackState.position.inMilliseconds - 60000);
      }
      if(widget.playbackState != null && widget.playbackState.position != null) {
        endDuration = widget.playbackState.position;
      }
    });
    clipPlayer.setUrl(widget.mediaItem.id);
  }

  @override
  dispose() {
    super.dispose();
    clipPlayer.dispose();
  }

  @override
  build(BuildContext context) {
    PerklUser perklUser = Provider.of<PerklUser>(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Center(child: Text('Create a Clip')),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: 200,
          maxHeight: MediaQuery.of(context).size.height - 20,
          minWidth: MediaQuery.of(context).size.height - 20,
          maxWidth: MediaQuery.of(context).size.height - 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: Icon(Icons.replay_30),
                    color: Colors.deepPurple,
                    onPressed: () async {
                      print('Current Position: ${clipPlayer.position.inMilliseconds} - 30000 = ${clipPlayer.position.inMilliseconds - 30000}/End: ${startDuration.inMilliseconds}/Duration: ${clipPlayer.duration.inMilliseconds}');
                      await clipPlayer.seek(Duration(milliseconds: clipPlayer.position.inMilliseconds - 30000));
                    },
                  ),
                  Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.deepPurple
                      ),
                      child: InkWell(
                        child: Icon(clipPlayer.playing ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 45),
                        onTap: () async {
                          if(clipPlayer.playing) {
                            clipPlayer.pause();
                          } else {
                            await clipPlayer.setClip(start: startDuration, end: endDuration);
                            clipPlayer.play();
                            clipPlayer.positionStream.listen((d) {
                              setState(() {});
                            });
                            clipPlayer.durationStream.listen((d) {
                              setState(() {});
                            });
                          }
                          setState(() {});
                        },
                      )
                  ),
                  IconButton(
                    icon: Icon(Icons.forward_30),
                    color: Colors.deepPurple,
                    onPressed: () async {
                      print('Current Position: ${clipPlayer.position.inMilliseconds} + 30000 = ${clipPlayer.position.inMilliseconds + 30000}/End: ${endDuration.inMilliseconds}/Duration: ${clipPlayer.duration.inMilliseconds}');
                      await clipPlayer.seek(Duration(milliseconds: clipPlayer.position.inMilliseconds + 30000));
                    }
                  ),
                ]
              ),
              Text('${ActivityManager().getDurationString(clipPlayer.position)}/${ActivityManager().getDurationString(Duration(milliseconds: endDuration.inMilliseconds - startDuration.inMilliseconds))}'),
              Text('${widget.mediaItem.title != null && widget.mediaItem.title.length > 60 ? '${widget.mediaItem.title.substring(0, 60)}...' : widget.mediaItem.title}', textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
              Text('${widget.mediaItem.artist != null && widget.mediaItem.artist.length > 60 ? '${widget.mediaItem.artist.substring(0, 60)}' : widget.mediaItem.artist}', textAlign: TextAlign.center),
              SizedBox(height: 10),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(ActivityManager().getDurationString(startDuration), style: TextStyle(fontSize: 18)),
                    Text(ActivityManager().getDurationString(endDuration), style: TextStyle(fontSize: 18)),
                  ]
              ),
              displayPage == 2 ? TextField(
                decoration: InputDecoration(
                  hintText: 'Clip Title (optional)'
                ),
                controller: _clipTitleController,
                onChanged: (value) {},
              ) : Container(),
              displayPage == 1 ? setClipColumn() : sendToColumn(perklUser),
              SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    child: Text(displayPage == 2 ? 'Back' : 'Cancel'),
                    onPressed: () async {
                      if(displayPage == 1) {
                        clipPlayer.dispose();
                        Navigator.of(context).pop();
                        return;
                      } else {
                        FocusScope.of(context).unfocus();
                        await Future.delayed(Duration(milliseconds: 500), () {});
                        setState(() {
                          displayPage = 1;
                        });
                      }
                    }
                  ),
                  TextButton(
                    child: Text(displayPage == 1 ? 'Send To...' : 'Create Clip', style: TextStyle(color: Colors.white)),
                    style: TextButton.styleFrom(backgroundColor: Colors.deepPurple),
                    onPressed: () async {
                      if(startDuration.inMilliseconds < endDuration.inMilliseconds) {
                        if(displayPage == 1) {
                          setState(() {
                            displayPage = 2;
                          });
                          return;
                        } else {
                          print('creating clip: ${widget.mediaItem.extras['episode']}');
                          //save clip as private if selected
                          if(_savePrivate) {
                            await DBService().saveEpisodeClip(creator: perklUser,
                                startDuration: startDuration,
                                endDuration: endDuration,
                                clipTitle: _clipTitleController?.value?.text,
                                public: false,
                                podcastTitle: widget?.mediaItem?.extras['podcast_title'],
                                podcastImage: widget?.mediaItem?.extras['podcast_image'],
                                podcastUrl: widget?.mediaItem?.extras['podcast_url'],
                                episode: widget.mediaItem != null && widget.mediaItem.extras != null && widget.mediaItem.extras['episode'] != null ? Episode.fromJson(widget.mediaItem.extras['episode']) : null,);
                          }
                          _sendToUsers.removeWhere((key, value) => value == false);
                          _addToConversations.removeWhere((key, value) => value == false);
                          //send clip to conversations
                          if(_sendToUsers != null && _sendToUsers.length > 0){
                            //Iterate over users to send to and send direct post for each w/
                            // memberMap of currentUser and send to user
                            _sendToUsers.forEach((key, value) async {
                              Map<String, dynamic> _memberMap = new Map<String, dynamic>();
                              _memberMap.addAll({perklUser.uid: perklUser.username});
                              String _thisUsername = await DBService().getPerklUser(key).then((PerklUser user) => user.username);
                              _memberMap.addAll({key: _thisUsername});
                              //send direct post to this user
                              await DBService().sendEpisodeClipToConversation(sender: perklUser,
                                  startDuration: startDuration,
                                  endDuration: endDuration,
                                  clipTitle: _clipTitleController?.value?.text,
                                  public: false,
                                  podcastTitle: widget?.mediaItem?.extras['podcast_title'],
                                  podcastImage: widget?.mediaItem?.extras['podcast_image'],
                                  podcastUrl: widget?.mediaItem?.extras['podcast_url'],
                                  episode: widget.mediaItem != null && widget.mediaItem.extras != null && widget.mediaItem.extras['episode'] != null ? Episode.fromJson(widget.mediaItem.extras['episode']) : null,
                                  memberMap: _memberMap);
                            });
                          }

                          if(_addToConversations != null && _addToConversations.length > 0) {
                            _addToConversations.forEach((key, value) async {
                              print('adding to conversation: $key');
                              await DBService().sendEpisodeClipToConversation(sender: perklUser,
                                  startDuration: startDuration,
                                  endDuration: endDuration,
                                  clipTitle: _clipTitleController?.value?.text,
                                  public: false,
                                  podcastTitle: widget?.mediaItem?.extras['podcast_title'],
                                  podcastImage: widget?.mediaItem?.extras['podcast_image'],
                                  podcastUrl: widget?.mediaItem?.extras['podcast_url'],
                                  episode: widget.mediaItem != null && widget.mediaItem.extras != null && widget.mediaItem.extras['episode'] != null ? Episode.fromJson(widget.mediaItem.extras['episode']) : null,
                                  conversationId: key);
                            });
                          }
                          Navigator.of(context).pop();
                        }
                      }
                    }
                  )
                ]
              )
            ]
        )
      ),
    );
  }
}