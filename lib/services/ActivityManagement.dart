import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound/ios_quality.dart';
import 'package:intl/intl.dart';
import 'package:flutter_sound/android_encoder.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';

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

  play() {
    this.isPlaying = true;
    this.postPlayer.play(postAudioUrl);
  }

  stop() {
    this.isPlaying = false;
    this.postPlayer.stop();
  }
}

class ActivityManager {
  FlutterSound soundManager = new FlutterSound();
  PostAudioPlayer currentPost;
  AudioPlayer currentlyPlayingPlayer;
  List<PostAudioPlayer> timelinePlaylist = new List();
  StreamController playlistStreamController = new StreamController<bool>.broadcast();
  Stream get playlistPlaying => playlistStreamController.stream.asBroadcastStream();
  StreamSubscription<RecordStatus> recordingSubscription;

  bool isLoggedIn() {
    if (FirebaseAuth.instance.currentUser() != null) {
      return true;
    } else {
      return false;
    }
  }

  setCurrentPost(PostAudioPlayer player) {
    if(this.currentPost != null) {
      this.currentPost.stop();
      this.currentPost.isPlaying = false;
    }
    this.currentPost = player;
    this.currentlyPlayingPlayer = player.postPlayer;
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
        print(postData['localRecordingLocation']);
        File audioFile = new File(postData['localRecordingLocation']);
        String filename = postData['dateString'].toString().replaceAll(new RegExp(r' '), '_');
        print(filename);
        final StorageReference fsRef = FirebaseStorage.instance.ref().child(userId).child('$filename');
        print('Post storage ref: ${fsRef}');
        print('File (${audioFile}) exists: ${audioFile.existsSync()}');
        final StorageUploadTask uploadTask = fsRef.putFile(audioFile);
        print('$uploadTask');
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

  Future<void> sendDirectPostDialog(BuildContext context, {String conversationId, Map<String,dynamic> memberMap}) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DirectMessageDialog(conversationId: conversationId, memberMap: memberMap);
      }
    );
  }

  Future<void> sendDirectPost(String messageTitle, String audioPath, int secondsLength, {String conversationId, Map<String, dynamic> memberMap}) async {
    String _conversationId = conversationId;
    if(isLoggedIn()) {
        WriteBatch batch = Firestore.instance.batch();

        //Create document for new direct post message
        DocumentReference directPostRef = Firestore.instance.collection('/directposts').document();
        String directPostDocId = directPostRef.documentID;

        //Get posting user id and username
        DocumentReference postingUserDoc = await UserManagement().getUserData();
        String postingUserID = postingUserDoc.documentID;
        String postingUsername = await postingUserDoc.get().then((DocumentSnapshot snapshot) async {
          return snapshot.data['username'].toString();
        });

        //Get recipient user doc
        /*
        DocumentReference recipientDocRef = Firestore.instance.collection('/users').document(recipientUserId);
        print('Recipient User Doc: $recipientDocRef');
        String recipientUsername = await recipientDocRef.get().then((DocumentSnapshot snapshot) {
          return snapshot.data['username'].toString();
        });
        */

        //Get audio file
        File audioFile = File(audioPath);
        DateTime date = DateTime.now();
        String dateString = DateFormat("yyyy-MM-dd_HH_mm_ss").format(date).toString();

        //Upload audio file
        final StorageReference storageRef = FirebaseStorage.instance.ref().child(postingUserID).child('direct-posts').child(dateString);
        final StorageUploadTask uploadTask = storageRef.putFile(audioFile);
        String fileUrl = await (await uploadTask.onComplete).ref.getDownloadURL();
        String fileUrlString = fileUrl.toString();

        //Check if conversation exists
        List<String> _memberList = new List<String>();
        if(memberMap != null)
          _memberList.addAll(memberMap.keys);
        _memberList.sort();
        if(_conversationId == null){
          await Firestore.instance.collection('conversations').where('memberList', isEqualTo: _memberList).getDocuments().then((snapshot) {
            DocumentSnapshot conversation = snapshot.documents.first;
            if(conversation != null)
              _conversationId = conversation.reference.documentID;
          });
        }
        bool conversationExists = _conversationId != null;

        Map<String, dynamic> conversationMap = await postingUserDoc.get().then((DocumentSnapshot snapshot) {
          return snapshot.data['directConversationMap'] == null ? null : Map<String, dynamic>.from(snapshot.data['directConversationMap']);
        });

        if(conversationExists) {
          DocumentReference conversationRef = Firestore.instance.collection('/conversations').document(_conversationId);
          Map<String, dynamic> postMap = await conversationRef.get().then((DocumentSnapshot snapshot) {
            return Map<String, dynamic>.from(snapshot.data['postMap']);
          });

          //To-Do --increment unread posts for all users other than posting user
          //--------------------------------------------------------------------

          postMap.addAll({directPostDocId: postingUserID});
          batch.updateData(conversationRef, {'postMap': postMap, 'lastDate': date});
        } else {
          //Create new conversation document and update data
          DocumentReference newConversationRef = Firestore.instance.collection('/conversations').document();
          conversationId = newConversationRef.documentID;
          Map<String, dynamic> conversationMembers = new Map<String, dynamic>();
          memberMap.forEach((uid, username) {
            if(uid == postingUserID)
              conversationMembers.addAll({uid: {'username': username, 'unreadPosts': 0}});
            else
              conversationMembers.addAll({uid: {'username': username, 'unreadPosts': 1}});
          });
          Map<String, dynamic> postMap = {directPostDocId: postingUserID};
          batch.setData(newConversationRef, {'conversationMembers': conversationMembers, 'postMap': postMap, 'memberList': _memberList, 'lastDate': date});

          //Add a new conversation to the sending user doc conversationMap
          Map<String, dynamic> senderConversationMap = await postingUserDoc.get().then((DocumentSnapshot snapshot) {
            return snapshot.data['directConversationMap'] == null ? null : Map<String, dynamic>.from(snapshot.data['directConversationMap']);
          });

          Map<String, dynamic> sendConvoData = {_conversationId: true};

          if(senderConversationMap != null)
            senderConversationMap.addAll(sendConvoData);
          else
            senderConversationMap = sendConvoData;

          batch.updateData(postingUserDoc, {'directConversationMap': senderConversationMap});

          //Add a new conversation to the recieving user doc conversationMap - store number of unread posts and other user name
          /*
          Map<String, dynamic> recipientConversationMap = await recipientDocRef.get().then((DocumentSnapshot snapshot) {
            return snapshot.data['directConversationMap'] == null ? null : Map<String, dynamic>.from(snapshot.data['directConversationMap']);
          });

          Map<String, dynamic> recConvoData = {'conversationId': conversationId, 'targetUsername': currentUsername, 'unreadPosts': 1};

          if(recipientConversationMap != null)
            recipientConversationMap.addAll({currentUserUID: recConvoData});
          else
            recipientConversationMap = {currentUserUID: recConvoData};

          batch.updateData(recipientDocRef, {'directConversationMap': recipientConversationMap});
          */
        }


        //Add data to new direct post document (message title, file url, length, date, sender, recipient, conversationId)
        Map<String, dynamic> newPostData = {'senderUID': postingUserID, 'senderUsername': postingUsername, 'messageTitle': messageTitle,
          'secondsLength': secondsLength, 'audioFileLocation': fileUrlString, 'conversationId': _conversationId,
          'datePosted': date
        };

        batch.setData(directPostRef, newPostData);

        batch.commit();
    }
    //print('Sending $messageTitle to $recipientUserId with file $audioPath that is $secondsLength seconds long');
  }

  Future<List<dynamic>> startRecordNewPost() async {
    try {
      if(recordingSubscription == null) {
        final appDataDir = await getApplicationDocumentsDirectory();
        String localPath = appDataDir.path;
        String extension = Platform.isIOS ? '.m4a' : '.mp3';
        String filePath = '$localPath/tempAudio$extension';
        print('File Path: $filePath');
       // String length
        String newPostPath = await soundManager.startRecorder('tempAudio$extension', androidEncoder: Platform.isIOS ? null : AndroidEncoder.AAC, bitRate: 100000, iosQuality: IosQuality.HIGH);
        print('starting Recorded at: $newPostPath');
        DateTime startRecordDateTime = DateTime.now();
        recordingSubscription = soundManager.onRecorderStateChanged.listen((e) {
          String date = DateFormat('hh:mm:ss:SS', 'en_US').format(
              DateTime.fromMillisecondsSinceEpoch(e.currentPosition.toInt()));
          print(date);
        });
        return [Platform.isIOS ? 'sound.m4a' : newPostPath, startRecordDateTime];
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

  pausePlaying() async {
    int result = await this.currentPost.postPlayer.pause();
    this.playlistStreamController.add(false);
    print('pausing player');
  }

  resumePlaying() async {
    int result = await this.currentPost.postPlayer.resume();
    print('resume playing');
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
        this.setCurrentPost(currentPost);
        this.playlistStreamController.add(true);
        currentPost.play();
      }
      if(this.currentlyPlayingPlayer != null) {
        this.playlistStreamController.add(true);
        this.currentlyPlayingPlayer.resume();
      }
    }
  }

  pausePlaylist() async {
    this.pausePlaying();
    this.playlistStreamController.add(false);
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
                    //print(_postTitle);
                    _postTitle = value;
                  }
                )
              ),
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

class UploadPostDialog extends StatefulWidget {
  @override
  _UploadPostDialogState createState() => new _UploadPostDialogState();
}

class _UploadPostDialogState extends State<UploadPostDialog> {
  DateTime date = DateTime.now();
  String dateString = new DateFormat('yyyy-mm-dd hh:mm:ss').format(DateTime.now());
  String fileName;
  String filepath;
  Duration duration;
  String postTitle;
  String postTags;
  String noFileError;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      contentPadding: EdgeInsets.fromLTRB(10.0, 5.0, 10.0, 5.0),
      title: Center(child: Text('Upload Post', style: TextStyle(color: Colors.deepPurple),)),
      children: <Widget>[
        Text('Post Title',
          style: TextStyle(
            fontSize: 16.0
          )
        ),
        TextField(
          decoration: InputDecoration(
            hintText: dateString,
          ),
          onChanged: (value) {
            postTitle = value;
          }
        ),
        SizedBox(height: 15.0),
        Text('Stream Tags (separated by "#")',
          style: TextStyle(
            fontSize: 16.0
          )
        ),
        SizedBox(height: 5.0),
        TextField(
          decoration: InputDecoration(
            hintText: '#TagYourTopics',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.multiline,
          maxLines: 5,
          onChanged: (value) {
            postTags = value;
          },
        ),
        SizedBox(height: 10.0),
        FlatButton(
          color: Colors.deepPurple,
          textColor: Colors.white,
          child: Center(child: fileName == null ? Text('Choose a file...') : Text(fileName)),
          onPressed: () async {
            String path = await FilePicker.getFilePath(type: FileType.AUDIO, fileExtension: 'mp3');
            File uploadFile = File(path);
            print('Selected File Path: $path');
            print('File: ${uploadFile}: ${await uploadFile.exists()}');
            AudioPlayer tempPlayer = new AudioPlayer();
            await tempPlayer.setUrl(path);
            int audioDuration = await Future.delayed(Duration(seconds: 2), () => tempPlayer.getDuration());
            Duration postDuration = Duration(milliseconds: audioDuration);
            print('Duration: $audioDuration/Seconds: ${postDuration.inSeconds}');
            setState(() {
              filepath = path;
              fileName = path.split('/').last;
              duration = postDuration;
            });
          },
        ),
        Center(child: noFileError == null ? Container() : Text(noFileError, style: TextStyle(color: Colors.red),)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            FlatButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            OutlineButton(
              borderSide: BorderSide(
                color: Colors.deepPurple
              ),
              child: Text('Upload Post', style: TextStyle(color: Colors.deepPurple),),
              onPressed: () async {
                if(filepath == null) {
                  setState(() {
                    noFileError = 'Please select an audio file!';
                  });
                } else {
                  noFileError = null;
                  List<String> tagList = processTagString(postTags);
                  await ActivityManager().addPost(context, {"postTitle": postTitle,
                    "localRecordingLocation": filepath,
                    "date": date,
                    "dateString": dateString,
                    "listens": 0,
                    "secondsLength": duration.inSeconds,
                    "streamList": tagList,
                  });
                  print('Post added');
                }
              },
            ),
          ]
        ),
      ],

    );
  }
}

class DirectMessageDialog extends StatefulWidget {
  final String conversationId;
  final Map<String, dynamic> memberMap;

  DirectMessageDialog({Key key, @required this.conversationId, this.memberMap}) : super(key: key);

  @override
  _DirectMessageDialogState createState() => new _DirectMessageDialogState();
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
      title: Center(child: Text('New Message',
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
                  if(widget.conversationId != null) {
                    await activityManager.sendDirectPost(_messageTitle, _postAudioPath, _secondsLength, conversationId: widget.conversationId);
                    Navigator.of(context).pop();
                  } else {
                    await activityManager.sendDirectPost(_messageTitle, _postAudioPath, _secondsLength, memberMap: widget.memberMap);
                    Navigator.of(context).pop();
                  }
                }
              },
            ),
          ]
        ),
      ],
    );
  }
}