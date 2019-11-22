import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:intl/intl.dart';
import 'package:flutter_sound/android_encoder.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

import 'UserManagement.dart';

class PostAudioPlayer {
  String postAudioUrl;
  bool hasPlayed = false;
  bool isPlaying = false;
  AudioPlayer postPlayer;

  PostAudioPlayer(String audioUrl, AudioPlayer postPlayer) {
    this.postAudioUrl = audioUrl;
    this.postPlayer = postPlayer;
  }
}

class ActivityManager {
  FlutterSound soundManager = new FlutterSound();
  AudioPlayer audioPlayer = new AudioPlayer();
  AudioPlayer currentlyPlayingPlayer;
  List<PostAudioPlayer> timelinePlaylist = new List();
  StreamController _playlistStreamController = new StreamController<bool>.broadcast();
  Stream get playlistPlaying => _playlistStreamController.stream.asBroadcastStream();
  StreamSubscription<RecordStatus> recordingSubscription;

  bool isLoggedIn() {
    if (FirebaseAuth.instance.currentUser() != null) {
      return true;
    } else {
      return false;
    }
  }

  Stream<PlayStatus> getCurrentPlaying() {
    return soundManager.onPlayerStateChanged;
  }

  addPost(BuildContext context, Map<String, dynamic> postData) async {
    if (isLoggedIn()) {
      print('Starting post add');
      await Firestore.instance.runTransaction((Transaction transaction) async {
        print('awaiting post add...');
        DocumentReference ref = Firestore.instance.collection('/posts').document();
        print('Doc Ref add post: $ref');
        String docId = ref.documentID;
        print(docId);
        String userId = await FirebaseAuth.instance.currentUser().then((user) {
          return user.uid;
        });
        String username = await UserManagement().getUserData().then((DocumentReference ref) async {
          return await ref.get().then((DocumentSnapshot snapshot) {
            return snapshot.data['username'];
          });
        });
        print(userId);
        DateTime date = postData['date'];


        //Upload file to firebase storage -- need to serialize date into filename
        File audioFile = File(postData['localRecordingLocation']);
        String filename = postData['dateString'].toString().replaceAll(new RegExp(r' '), '_');
        print(filename);
        final StorageReference fsRef = FirebaseStorage.instance.ref().child(userId).child('$filename');
        final StorageUploadTask uploadTask = fsRef.putFile(audioFile);
        String fileUrl = await (await uploadTask.onComplete).ref.getDownloadURL();
        String fileUrlString = fileUrl.toString();

        Map<String, dynamic> userTimelines = new Map<String, dynamic>.from(await UserManagement().getUserData().then((DocumentReference userDoc) async {
          print('user doc in add post: $userDoc');
          return await userDoc.get().then((DocumentSnapshot userSnap){
            print('got user snap: $userSnap // ${userSnap.data.toString()}');
            print(userSnap.data['timelinesIncluded']);
            if(userSnap.data['timelinesIncluded'] != null) {
              print('user is included on timelines');
              return new Map<String, dynamic>.from(
                  userSnap.data['timelinesIncluded']);
            } else {
              return new Map<String, dynamic>();
            }
          });
        }));
        print('checking user timelines == null');
        if(userTimelines == null) {
          print('user is not on any timelines');
          userTimelines = new Map<String, dynamic>();
        }

        await transaction.set(ref, {
          'userUID':  userId,
          'username': username,
          'postTitle': postData['postTitle'],
          'postValue': postData['postValue'],
          'datePosted': postData['date'],
          'dateString': postData['dateString'],
          'audioFileLocation': fileUrlString,
          'listenCount': 0,
          'secondsLength': postData['secondsLength'],
          'streamList': postData['streamList'],
          'timelines': userTimelines.keys.toList(),
        }).then((doc) async {
          print('adding post to user');
          await UserManagement().addPost(docId).then((val) {
            Navigator.of(context).pop();
          });
        }).catchError((e) {
          print(e);
        });
      });
      print('add finished');
    } else {
      Navigator.of(context).pushReplacementNamed('/landingpage');
    }
  }

  Future<void> sendDirectPostDialog(String recipientUserId, String recipientUsername, BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        print('Sending to $recipientUserId');
        return DirectMessageDialog(recipientUserId: recipientUserId, recipientUsername: recipientUsername);
      }
    );
  }

  Future<void> sendDirectPost(String recipientUserId, String messageTitle, String audioPath, int secondsLength) async {
    if(isLoggedIn()) {
        WriteBatch batch = Firestore.instance.batch();

        //Create document for new post
        DocumentReference directPostRef = Firestore.instance.collection('/directposts').document();
        String directPostDocId = directPostRef.documentID;

        //Get posting user id and username
        DocumentReference currentUserDoc = await UserManagement().getUserData();
        String currentUserUID = currentUserDoc.documentID;
        String currentUsername = await currentUserDoc.get().then((DocumentSnapshot snapshot) async {
          return snapshot.data['username'].toString();
        });

        //Get recipient user doc
        DocumentReference recipientDocRef = Firestore.instance.collection('/users').document(recipientUserId);
        print('Recipient User Doc: $recipientDocRef');
        String recipientUsername = await recipientDocRef.get().then((DocumentSnapshot snapshot) {
          return snapshot.data['username'].toString();
        });

        //Get audio file
        File audioFile = File(audioPath);
        DateTime date = DateTime.now();
        String dateString = DateFormat("yyyy-MM-dd_HH_mm_ss").format(date).toString();
        //Upload audio file
        final StorageReference storageRef = FirebaseStorage.instance.ref().child(currentUserUID).child('direct-posts').child(dateString);
        final StorageUploadTask uploadTask = storageRef.putFile(audioFile);
        String fileUrl = await (await uploadTask.onComplete).ref.getDownloadURL();
        String fileUrlString = fileUrl.toString();

        //Check if conversation exists
        bool conversationExists = false;
        String conversationId;
        Map<String, dynamic> conversationMap = await currentUserDoc.get().then((DocumentSnapshot snapshot) {
          return snapshot.data['directConversationMap'] == null ? null : Map<String, dynamic>.from(snapshot.data['directConversationMap']);
        });
        if(conversationMap != null){
          conversationExists = conversationMap.containsKey(recipientUserId);
          if(conversationExists)
            conversationId = conversationMap[recipientUserId]['conversationId'];
        }

        if(conversationExists) {
          DocumentReference conversationRef = Firestore.instance.collection('/conversations').document(conversationId);
          Map<String, dynamic> postMap = await conversationRef.get().then((DocumentSnapshot snapshot) {
            return Map<String, dynamic>.from(snapshot.data['postMap']);
          });

          postMap.addAll({directPostDocId: currentUserUID});
          batch.updateData(conversationRef, {'postMap': postMap});
        } else {
          //Create new conversation document and update data
          DocumentReference newConversationRef = Firestore.instance.collection('/conversations').document();
          conversationId = newConversationRef.documentID;
          Map<String, dynamic> conversationMembers = {currentUserUID: currentUsername, recipientUserId:  recipientUsername};
          Map<String, dynamic> postMap = {directPostDocId: currentUserUID};
          batch.setData(newConversationRef, {'conversationMembers': conversationMembers, 'postMap': postMap});

          //Add a new conversation to the sending user doc conversationMap - store number of unread posts and other user name
          Map<String, dynamic> senderConversationMap = await currentUserDoc.get().then((DocumentSnapshot snapshot) {
            return snapshot.data['directConversationMap'] == null ? null : Map<String, dynamic>.from(snapshot.data['directConversationMap']);
          });

          Map<String, dynamic> sendConvoData = {'conversationId': conversationId, 'targetUsername': recipientUsername, 'unreadPosts': 0};

          if(senderConversationMap != null)
            senderConversationMap.addAll({recipientUserId: sendConvoData});
          else
            senderConversationMap = {recipientUserId: sendConvoData};

          batch.updateData(currentUserDoc, {'directConversationMap': senderConversationMap});

          //Add a new conversation to the recieving user doc conversationMap - store number of unread posts and other user name
          Map<String, dynamic> recipientConversationMap = await recipientDocRef.get().then((DocumentSnapshot snapshot) {
            return snapshot.data['directConversationMap'] == null ? null : Map<String, dynamic>.from(snapshot.data['directConversationMap']);
          });

          Map<String, dynamic> recConvoData = {'conversationId': conversationId, 'targetUsername': currentUsername, 'unreadPosts': 1};

          if(recipientConversationMap != null)
            recipientConversationMap.addAll({currentUserUID: recConvoData});
          else
            recipientConversationMap = {currentUserUID: recConvoData};

          batch.updateData(recipientDocRef, {'directConversationMap': recipientConversationMap});
        }

        //Add data to new direct post document (message title, file url, length, date, sender, recipient, conversationId)
        Map<String, dynamic> newPostData = {'senderUID': currentUserUID, 'senderUsername': currentUsername,
          'recipientUID': recipientUserId, 'recipientUsername': recipientUsername, 'messageTitle': messageTitle,
          'secondsLength': secondsLength, 'audioFileLocation': fileUrlString, 'conversationId': conversationId,
          'datePosted': date
        };

        batch.setData(directPostRef, newPostData);

        batch.commit();
    }
    print('Sending $messageTitle to $recipientUserId with file $audioPath that is $secondsLength seconds long');
  }

  Future<List<dynamic>> startRecordNewPost() async {
    try {
      if(recordingSubscription == null) {
        final appDataDir = await getApplicationDocumentsDirectory();
        String localPath = appDataDir.path;
        String extension = Platform.isIOS ? '.m4a' : '.mp4';
        String filePath = '$localPath/tempAudio$extension';
        print('File Path: $filePath');
       // String length
        String newPostPath = await soundManager.startRecorder('tempAudio$extension', androidEncoder: Platform.isIOS ? null : AndroidEncoder.AMR_WB);
        print('starting Recorded at: $newPostPath');
        DateTime startRecordDateTime = DateTime.now();
        recordingSubscription = soundManager.onRecorderStateChanged.listen((e) {
          String date = DateFormat('hh:mm:ss:SS', 'en_US').format(
              DateTime.fromMillisecondsSinceEpoch(e.currentPosition.toInt()));
          print(date);
        });
        return [newPostPath, startRecordDateTime];
      }
      return null;
    } catch (e) {
      print('Start recorder error: $e');
      return null;
    }
  }

  Future<List<dynamic>> stopRecordNewPost(String postPath, DateTime startDateTime) async {
    try {
      String result = await soundManager.stopRecorder();
      print('recorder stopped: $result');

      DateTime endRecordDateTime = DateTime.now();
      Duration recordingTime = endRecordDateTime.difference(startDateTime);

      int secondsLength = recordingTime.inSeconds;
      print('$startDateTime - $endRecordDateTime');
      print(secondsLength);
      if(recordingSubscription != null) {
        recordingSubscription.cancel();
        recordingSubscription = null;
      }
      return [postPath, secondsLength];
    } catch (e) {
      print('error stopping recorder: $e');
    }
    return null;
  }

  playRecording(String fileUrl, AudioPlayer player) async {
    //final directory = await getApplicationDocumentsDirectory();
    //String localPath = directory.path;
    print('Playing file from: $fileUrl');
    if(this.currentlyPlayingPlayer != null){
      AudioPlayer oldPlayer = this.currentlyPlayingPlayer;
      oldPlayer.stop();
      PostAudioPlayer oldPost = this.timelinePlaylist.where((player) {
        return player.postPlayer.playerId == oldPlayer.playerId;
      }).toList().first;
      oldPost.isPlaying = false;
    }
    this.currentlyPlayingPlayer = player;
    int status = await player.play(fileUrl);
    print('playing recording: $status');
  }

  pausePlaying() async {
    int result = await this.currentlyPlayingPlayer.pause();
    this._playlistStreamController.add(false);
    print('pausing player');
  }

  resumePlaying() async {
    int result = await this.currentlyPlayingPlayer.resume();
    print('resume playing');
  }

  stopPlaying(AudioPlayer player) async {
    int result = await player.stop();
    this.currentlyPlayingPlayer = null;
    print('recording stopped: $result');
  }

  PostAudioPlayer addPostToPlaylist(String postAudioUrl, AudioPlayer postPlayer) {
    PostAudioPlayer postObject = new PostAudioPlayer(postAudioUrl, postPlayer);
    this.timelinePlaylist.add(postObject);
    print('Post added to timeline playlist');
    return postObject;
  }

  playPlaylist() async {
    List<PostAudioPlayer> unheardPosts = this.timelinePlaylist.where((player) {
      return player.hasPlayed == false;
    }).toList();
    PostAudioPlayer currentPost = unheardPosts[0];
    print('Current Playlist Post: $currentPost');
    if(currentPost != null) {
      print('Has Played: ${currentPost.hasPlayed}; Is Currently Playing ${currentPost.isPlaying}');
      if (!currentPost.hasPlayed && !currentPost.isPlaying) {
        print('Starting next post player');
        currentPost.isPlaying = true;
        this._playlistStreamController.add(true);
        this.playRecording(currentPost.postAudioUrl, currentPost.postPlayer);
      }
      if(this.currentlyPlayingPlayer != null) {
        this._playlistStreamController.add(true);
        this.currentlyPlayingPlayer.resume();
      }
    }
  }

  pausePlaylist() async {
    this.pausePlaying();
    this._playlistStreamController.add(false);
  }

  Future<void> followUser(String newFollowUID) async {
    WriteBatch batch = Firestore.instance.batch();

    //add newly followed user Id to current user's list of following
    DocumentReference currentUserDoc = await UserManagement().getUserData();
    String currentUserId = await currentUserDoc.get().then((snapshot) {
      return snapshot.data['uid'].toString();
    });


    Map<String, dynamic> currentFollowing = await currentUserDoc.get().then((snapshot) {
      print('setting currentFollowing');
      if(snapshot.data['following'] != null)
        return new Map<String, dynamic>.from(snapshot.data['following']);
      return null;
    });

    print('setting new following');
    Map<String, dynamic> newFollowing;
    if(currentFollowing == null) {
      newFollowing = {newFollowUID: true};
    } else {
      currentFollowing.addAll({newFollowUID: true});
      newFollowing = currentFollowing;
    }

    batch.updateData(currentUserDoc, {'following': newFollowing});
      //add current users Id to newly followed user's list of followers and add current users mainFeedTimelineId to followed users list of including timelines
    DocumentReference followedUserDoc = Firestore.instance.collection('/users').document(newFollowUID);

    Map<String, dynamic> currentFollowers = await followedUserDoc.get().then((snapshot) {
      if(snapshot.data['followers'] != null)
        return Map<String, dynamic>.from(snapshot.data['followers']);
      return null;
    });
    Map<String, dynamic> currentTimelinesIncluded = await followedUserDoc.get().then((snapshot) {
      if(snapshot.data['timelinesIncluded'] != null)
        return Map<String, dynamic>.from(snapshot.data['timelinesIncluded']);
      return null;
    });
    String currentUserMainFeedTimelineId = await currentUserDoc.get().then((snapshot) {
      return snapshot.data['mainFeedTimelineId'];
    });

    Map<String, dynamic> newFollowers;
    Map<String, dynamic> newTimelinesIncluded;

    if(currentUserMainFeedTimelineId == null) {
      print('current user does not have a main timeline id');
    } else {
      if(currentFollowers == null){
        newFollowers = {currentUserId: true};
      } else {
        currentFollowers.addAll({currentUserId: true});
        newFollowers = currentFollowers;
      }

      if(currentTimelinesIncluded == null){
        newTimelinesIncluded = {currentUserMainFeedTimelineId: true};
      } else {
        currentTimelinesIncluded.addAll({currentUserMainFeedTimelineId: true});
        newTimelinesIncluded = currentTimelinesIncluded;
      }

      batch.updateData(followedUserDoc, {'followers': newFollowers, 'timelinesIncluded': newTimelinesIncluded});
    }

      //add current user's main feed timeline to list of timelines for all posts from the newly followed
    await Firestore.instance.collection('/posts').where('userUID', isEqualTo: newFollowUID).getDocuments().then((QuerySnapshot snapshot) {
      print('post list snapshot data: ${snapshot.documents}');
      if(snapshot.documents.isEmpty) {
        print('user has no posts');
      } else {
        snapshot.documents.forEach((DocumentSnapshot postSnapshot) {
         List<dynamic> newPostTimelines = new List<dynamic>();
         if(postSnapshot.data['timelines'] != null && postSnapshot.data['timelines'].length > 0) {
           print('post has timeline field');
           List<dynamic> currentPostTimelines = postSnapshot.data['timelines'];
           newPostTimelines.addAll(currentPostTimelines);
           newPostTimelines.add(currentUserMainFeedTimelineId);
           print('set list to current timeline list');
         }
         else {
           newPostTimelines = [currentUserMainFeedTimelineId];
         }

         batch.updateData(postSnapshot.reference, {'timelines': newPostTimelines});
        });
      }
    }).catchError((e) {
      print('Error adding timeline to posts: $e');
    });

    batch.commit();
  }

  Future<void> unfollowUser(String unfollowUID) async {
    WriteBatch batch = Firestore.instance.batch();

    DocumentReference loggedInUserDoc = await UserManagement().getUserData().then((doc) => doc);
    DocumentReference unfollowedUserDoc = await Firestore.instance.collection('/users').where('uid', isEqualTo: unfollowUID).getDocuments().then((snapshot) async {
      return snapshot.documents.first.reference;
    });
    String loggedInUID = await loggedInUserDoc.get().then((snapshot) {
      return snapshot.data['uid'];
    });
    String loggedInMainFeedTimelineId = await loggedInUserDoc.get().then((snapshot) {
      return snapshot.data['mainFeedTimelineId'];
    });

    //Remove userId from logged in user's list of following
    Map<String, dynamic> currentFollowing = await loggedInUserDoc.get().then((snapshot) {
      return new Map<String, dynamic>.from(snapshot.data['following']);
    });
    print('wint');
    currentFollowing.remove(unfollowUID);

    batch.updateData(loggedInUserDoc, {'following': currentFollowing});
    //remove logged in user's userId from unfollowed user's list of followers
    Map<String, dynamic> unfollowedUserFollowers = await unfollowedUserDoc.get().then((snapshot) {
      return new Map<String, dynamic>.from(snapshot.data['followers']);
    });
    Map<String, dynamic> unfollowedTimelinesIncluded = await unfollowedUserDoc.get().then((snapshot) {
      return new Map<String, dynamic>.from(snapshot.data['timelinesIncluded']);
    });
    unfollowedUserFollowers.remove(loggedInUID);
    unfollowedTimelinesIncluded.remove(loggedInMainFeedTimelineId);

    batch.updateData(unfollowedUserDoc, {'followers': unfollowedUserFollowers, 'timelinesIncluded': unfollowedTimelinesIncluded});
    //remove logged in user's mainFeedTimelinesId from all posts of unfollowed user
    await Firestore.instance.collection('/posts').where('userUID', isEqualTo: unfollowUID).getDocuments().then((snapshot) {
      if(snapshot.documents.isEmpty){
        print('unfollowed user has no posts');
      } else {
        snapshot.documents.forEach((DocumentSnapshot docSnap) {
          List<String> postTimelines = new List<String>.from(docSnap.data['timelines']);
          postTimelines.remove(loggedInMainFeedTimelineId);

          batch.updateData(docSnap.reference, {'timelines': postTimelines});
        });
      }
    });

    batch.commit();
  }
}

List<String> processTagString(String postTags) {
  if(postTags != null) {
    String strippedSpaces = postTags.replaceAll(new RegExp(r' '), '');
    List<String> tagList = strippedSpaces.split("#");
    tagList.removeWhere((item) => item == '');
    return tagList;
  }
  return null;
}

// Add Post dialog
Future<void> addPostDialog(BuildContext context, DateTime date, String recordingLocation, int secondsLength) async {
  print('starting set date format');
  String dateString = new DateFormat('yyyy-mm-dd hh:mm:ss').format(date);
  print(dateString);
  String _postTitle;
  String _postTags;

  showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
            contentPadding: EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 10.0),
            title: Center(child: Text('Add New Post',
              style: TextStyle(color: Colors.deepPurple)
            )),
            children: <Widget>[
              Text('Post Title (optional)'),
              Container(
                width: 700.0,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: dateString,
                  ),
                  onChanged: (value) {
                    print(_postTitle);
                    _postTitle = value;
                  }
                )
              ),
              SizedBox(height: 20.0),
              Text('Post Description (optional)'),
              SizedBox(height: 20.0),
              Text('Stream Tags (separated by \'#\')'),
              Container(
                width: 700.0,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '#TagYourTopics',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.multiline,
                  maxLines: 5,
                  onChanged: (value) {
                    _postTags = value;
                  },
                ),
              ),
              /*
              Placeholder for adding field for capturing streams/tags for the post as well as public/private
               */
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  FlatButton(
                    child: Text('Cancel'),
                    textColor: Colors.deepPurple,
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  FlatButton(
                      child: Text('Add Post'),
                      textColor: Colors.deepPurple,
                      onPressed: () async {
                        String postError;
                        String postErrorTitle;
                        if(_postTags != null){
                          int numTags = '#'.allMatches(_postTags).length;
                          if(numTags > 15) {
                            postError = 'The limit for the number of stream tags on a post is 15.';
                            postErrorTitle = 'Too Many Stream Tags!';
                          }
                        }
                        if(postError != null){
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text(postErrorTitle),
                                content: Text(postError),
                                actions: <Widget>[
                                  FlatButton(
                                    child: Text('Ok'),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        } else {
                          List<String> tagList = processTagString(_postTags);
                          print({"postTitle": _postTitle,
                            "localRecordingLocation": recordingLocation,
                            "date": date,
                            "dateString": dateString,
                            "listens": 0,
                            "secondsLength": secondsLength,
                            "streamList": tagList,
                            "test": "tester",
                          });
                          await ActivityManager().addPost(context, {"postTitle": _postTitle,
                            "localRecordingLocation": recordingLocation,
                            "date": date,
                            "dateString": dateString,
                            "listens": 0,
                            "secondsLength": secondsLength,
                            "streamList": tagList,
                          });
                          print('Post added');
                        }
                      }
                  )
                ],
              ),
            ],
        );
      }
  );
}

class DirectMessageDialog extends StatefulWidget {
  final String recipientUserId;
  final String recipientUsername;

  DirectMessageDialog({Key key, @required this.recipientUserId, this.recipientUsername}) : super(key: key);

  @override
  _DirectMessageDialogState createState() => _DirectMessageDialogState();
}

class _DirectMessageDialogState extends State<DirectMessageDialog> {
  String _messageTitle;
  bool _isRecording = false;
  String _postAudioPath;
  DateTime _startRecordDate;
  int _secondsLength;
  ActivityManager activityManager = new ActivityManager();

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      contentPadding: EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 10.0),
      title: Center(child: Text('Direct Messaging ${widget.recipientUsername}',
          style: TextStyle(color: Colors.deepPurple),
        textAlign: TextAlign.center,
      )),
      children: <Widget>[
        Text('Message Title', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
        Container(
            width: 700.0,
            child: TextField(
                decoration: InputDecoration(
                  hintText: 'Message Title (Optional)',
                ),
                onChanged: (value) {
                  _messageTitle = value;
                }
            )
        ),
        SizedBox(height: 20.0),
        FloatingActionButton(
            backgroundColor: _isRecording ? Colors.red : Colors.deepPurple,
            child: Icon(Icons.mic),
            heroTag: null,
            onPressed: () async {
              if(_isRecording) {
                List<dynamic> stopRecordVals = await activityManager.stopRecordNewPost(_postAudioPath, _startRecordDate);
                String recordingLocation = stopRecordVals[0];
                int secondsLength = stopRecordVals[1];

                print('$recordingLocation -/- Length: $secondsLength');
                setState(() {
                  _isRecording = !_isRecording;
                  _secondsLength = secondsLength;
                });
                print('getting date');
                DateTime date = new DateTime.now();
                print('date before dialog: $date');
                //await addPostDialog(context, date, recordingLocation, secondsLength);
              } else {
                List<dynamic> startRecordVals = await activityManager.startRecordNewPost();
                String postPath = startRecordVals[0];
                DateTime startDate = startRecordVals[1];
                setState(() {
                  _isRecording = !_isRecording;
                  _postAudioPath = postPath;
                  _startRecordDate = startDate;
                });
              }
            }
        ),
        SizedBox(height: 10.0),
        Center(
          child: _postAudioPath == null ? Text('Audio Recording Missing',
            style: TextStyle(color: Colors.red),
          ) : null,
        ),
        SizedBox(height: 10.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            FlatButton(
              child: Text('Cancel'),
            ),
            FlatButton(
              child: Text('Send'),
              onPressed: () async {
                if(_postAudioPath != null && _secondsLength != null){
                  await activityManager.sendDirectPost(widget.recipientUserId, _messageTitle, _postAudioPath, _secondsLength);
                  Navigator.of(context).pop();
                }
              },
            ),
          ]
        ),
      ],
    );
  }
}