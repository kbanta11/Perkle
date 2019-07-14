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

import 'UserManagement.dart';

class ActivityManager {
  FlutterSound soundManager = new FlutterSound();
  StreamSubscription<RecordStatus> recordingSubscription;

  bool isLoggedIn() {
    if (FirebaseAuth.instance.currentUser() != null) {
      return true;
    } else {
      return false;
    }
  }

  addPost(BuildContext context, Map<String, dynamic> postData) async {
    if (isLoggedIn()) {

      await Firestore.instance.runTransaction((Transaction transaction) async {
        DocumentReference ref = Firestore.instance.collection('/posts').document();
        print('Doc Ref add post: $ref');
        String docId = ref.documentID;
        print(docId);
        String userId = await FirebaseAuth.instance.currentUser().then((user) {
          return user.uid;
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
    } else {
      Navigator.of(context).pushReplacementNamed('/landingpage');
    }
  }

  Future<List<dynamic>> startRecordNewPost() async {
    try {
      if(recordingSubscription == null) {
        final appDataDir = await getApplicationDocumentsDirectory();
        String localPath = appDataDir.path;
        print('Local Path: $localPath');
       // String length
        String newPostPath = await soundManager.startRecorder('$localPath/tempAudio', androidEncoder: AndroidEncoder.AMR_WB);
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

  playRecording(String fileUrl) async {
    //final directory = await getApplicationDocumentsDirectory();
    //String localPath = directory.path;
    print('Playing file from: $fileUrl');
    String path = await soundManager.startPlayer(fileUrl);
    print('playing recording: $path');
  }

  stopPlaying() async {
    String result = await soundManager.stopPlayer();
    print('recording stopped: $result');
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
         List<String> newPostTimelines;
         if(postSnapshot.data['timelines'] != null && postSnapshot.data['timelines'].length > 0) {
           print('post has timeline field');
           List<String> currentPostTimelines = postSnapshot.data['timelines'];
           newPostTimelines = currentPostTimelines;
           print('set list to current timeline list');
         }
         else {
           newPostTimelines = [currentUserMainFeedTimelineId];
         }

         batch.updateData(postSnapshot.reference, {'timelines': newPostTimelines});
        });
      }
    }).catchError((e) {
      print('Error adding timeline to posts');
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
  showDialog(
      context: context,
      builder: (BuildContext context) {
        print('starting set date format');
        String dateString = new DateFormat('yyyy-mm-dd hh:mm:ss').format(date);
        print(dateString);
        String _postDescription;
        String _postTitle;
        String _postTags;

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
                    _postTitle = value;
                  }
                )
              ),
              SizedBox(height: 20.0),
              Text('Post Description (optional)'),
              Container(
                width: 700.0,
                child: TextField(
                  decoration: InputDecoration(
                      hintText: 'A short description of this post...',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.multiline,
                  maxLines: 5,
                  onChanged: (value) {
                    _postDescription = value;
                  },
                ),
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
                        int numTags = '#'.allMatches(_postTags).length;
                        if(numTags > 15){
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Too Many Stream Tags!'),
                                content: const Text('The limit for the number of stream tags on a post is 15.'),
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
                            "postValue": _postDescription,
                            "localRecordingLocation": recordingLocation,
                            "date": date,
                            "dateString": dateString,
                            "listens": 0,
                            "secondsLength": secondsLength,
                            "streamList": tagList,
                          });
                          ActivityManager().addPost(context, {"postTitle": _postTitle,
                            "postValue": _postDescription,
                            "localRecordingLocation": recordingLocation,
                            "date": date,
                            "dateString": dateString,
                            "listens": 0,
                            "secondsLength": secondsLength,
                            "streamList": tagList,
                          });
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