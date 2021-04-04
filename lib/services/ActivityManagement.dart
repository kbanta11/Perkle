import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
//import 'package:audioplayers/audioplayers.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:sounds/sounds.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock/wakelock.dart';
import 'package:file_picker/file_picker.dart';

import '../main.dart';
import 'UserManagement.dart';
import 'local_services.dart';
import '../PageComponents.dart';

/*
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
*/

class ActivityManager {
  SoundRecorder recorder = new SoundRecorder(playInBackground: true,);
  LocalService localService = new LocalService();
  Timer recordingTimer;
  Duration recordingDuration;
  //StreamSubscription<RecordStatus> recordingSubscription;

  bool isLoggedIn() {
    if (FirebaseAuth.instance.currentUser != null) {
      return true;
    } else {
      return false;
    }
  }

  addPost(BuildContext context, Map<String, dynamic> postData, bool addToTimeline, bool sendAsGroup, Map<String, dynamic> sendToUsers, Map<String, dynamic> addToConversations) async {
    if (isLoggedIn()) {
      print('Starting post add');
      await FirebaseFirestore.instance.runTransaction((Transaction transaction) async {
        String userId = FirebaseAuth.instance.currentUser.uid;
        String username = await UserManagement().getUserData().then((DocumentReference ref) async {
          return await ref.get().then((DocumentSnapshot snapshot) {
            return snapshot.data()['username'];
          });
        });

        //Upload file to firebase storage -- need to serialize date into filename
        File audioFile = new File(postData['localRecordingLocation']);
        String filename = postData['date'].toString().replaceAll(new RegExp(r' '), '_');
        print('Filename: $filename');
        final Reference fsRef = FirebaseStorage.instance.ref().child(userId).child('$filename');
        print('Post storage ref: $fsRef');
        print('File ($audioFile) exists: ${audioFile.existsSync()}');
        final UploadTask uploadTask = fsRef.putFile(audioFile);
        uploadTask.snapshotEvents.listen((snap) {
          print('${snap.bytesTransferred / 1000}/${snap.totalBytes / 1000} (${snap.bytesTransferred/snap.totalBytes * 100})');
        });
        print('waiting for upload to complete...');
        await uploadTask.whenComplete(() => null).catchError((e) {
          print('Error waiting for upload task complete: $e');
        });
        String fileUrl = await fsRef.getDownloadURL().then((val) {
          return val;
        }).catchError((e) {
          print('error getting download url: $e');
        });
        String fileUrlString = fileUrl.toString();

        if(addToTimeline) {
          DocumentReference ref = FirebaseFirestore.instance.collection('/posts').doc();
          String docId = ref.id;

          Map<String, dynamic> userTimelines = new Map<String, dynamic>.from(await UserManagement().getUserData().then((DocumentReference userDoc) async {
            print('user doc in add post: $userDoc');
            return await userDoc.get().then((DocumentSnapshot userSnap){
              print('got user snap: $userSnap // ${userSnap.data.toString()}');
              print(userSnap.data()['timelinesIncluded']);
              if(userSnap.data()['timelinesIncluded'] != null) {
                print('user is included on timelines');
                return new Map<String, dynamic>.from(
                    userSnap.data()['timelinesIncluded']);
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

          transaction.set(ref, {
            'userUID':  userId,
            'username': username,
            'postTitle': postData['postTitle'],
            'datePosted': postData['date'],
            'dateString': postData['dateString'],
            'audioFileLocation': fileUrlString,
            'listenCount': 0,
            'secondsLength': postData['secondsLength'],
            'streamList': postData['streamList'],
            'timelines': userTimelines.keys.toList(),
          });
          await UserManagement().addPost(docId);
        }

        if(sendToUsers != null){
          if(sendToUsers.length > 0) {
            if(sendAsGroup) {
              //Create memberMap {uid: username} for all users in group
              Map<String, dynamic> _memberMap = new Map<String, dynamic>();
              _memberMap.addAll({userId: username});
              sendToUsers.forEach((key, value) async {
                String _username = await FirebaseFirestore.instance.collection('users').doc(key).get().then((doc) {
                  return doc.data()['username'];
                });
                _memberMap.addAll({key: _username});
              });
              print('Member Map (Send as group): $_memberMap');
              await sendDirectPost(postData['postTitle'], null, postData['secondsLength'], memberMap: _memberMap, fileUrl: fileUrlString);
            } else {
              //Iterate over users to send to and send direct post for each w/
              // memberMap of currentUser and send to user
              sendToUsers.forEach((key, value) async {
                Map<String, dynamic> _memberMap = new Map<String, dynamic>();
                _memberMap.addAll({userId: username});
                String _thisUsername = await FirebaseFirestore.instance.collection('users').doc(key).get().then((doc) {
                  return doc.data()['username'];
                });
                _memberMap.addAll({key: _thisUsername});
                //send direct post to this user
                await sendDirectPost(postData['postTitle'], null, postData['secondsLength'], memberMap: _memberMap, fileUrl: fileUrlString);
              });
            }
          }
        }

        if(addToConversations != null) {
          if(addToConversations.length > 0) {
            addToConversations.forEach((key, value) async {
              print('adding to conversation: $key');
              await sendDirectPost(postData['postTitle'], null, postData['secondsLength'], fileUrl: fileUrlString, conversationId: key);
            });
          }
        }
      });
      print('add finished');
      Navigator.of(context).pop();
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

  Future<void> sendDirectPost(String messageTitle, String audioPath, int secondsLength, {String conversationId, Map<String, dynamic> memberMap, String fileUrl}) async {
    String _conversationId = conversationId;
    if(isLoggedIn()) {
        WriteBatch batch = FirebaseFirestore.instance.batch();
        DateTime date = DateTime.now();

        //Create document for new direct post message
        DocumentReference directPostRef = FirebaseFirestore.instance.collection('/directposts').doc();
        String directPostDocId = directPostRef.id;


        //Get posting user id and username
        DocumentReference postingUserDoc = await UserManagement().getUserData();
        String postingUserID = postingUserDoc.id;
        String postingUsername = await postingUserDoc.get().then((DocumentSnapshot snapshot) async {
          return snapshot.data()['username'].toString();
        });

        //Get recipient user doc
        /*
        DocumentReference recipientDocRef = Firestore.instance.collection('/users').document(recipientUserId);
        print('Recipient User Doc: $recipientDocRef');
        String recipientUsername = await recipientDocRef.get().then((DocumentSnapshot snapshot) {
          return snapshot.data['username'].toString();
        });
        */

        //Upload audio file
        String fileUrlString;
        if(fileUrl == null) {
          //Get audio file
          File audioFile = File(audioPath);
          String dateString = DateFormat("yyyy-MM-dd_HH_mm_ss").format(date).toString();
          final Reference storageRef = FirebaseStorage.instance.ref().child(postingUserID).child('direct-posts').child(dateString);
          final UploadTask uploadTask = storageRef.putFile(audioFile);
          uploadTask.snapshotEvents.listen((snap) {
            print('${snap.bytesTransferred / 1000}/${snap.totalBytes / 1000} (${snap.bytesTransferred/snap.totalBytes * 100})');
          });
          await uploadTask.whenComplete(() => null);

          String _fileUrl = await storageRef.getDownloadURL();
          fileUrlString = _fileUrl.toString();
        } else {
          fileUrlString = fileUrl.toString();
        }


        //Check if conversation exists
        List<String> _memberList = new List<String>();
        if(memberMap != null)
          _memberList.addAll(memberMap.keys);
        _memberList.sort();
        if(_conversationId == null){
          await FirebaseFirestore.instance.collection('conversations').where('memberList', isEqualTo: _memberList).get().then((snapshot) {
            if(snapshot.docs.isNotEmpty) {
              DocumentSnapshot conversation = snapshot.docs.first;
              if(conversation != null)
                _conversationId = conversation.reference.id;
            }
          });
        }
        bool conversationExists = _conversationId != null;

        /*
        Map<String, dynamic> conversationMap = await postingUserDoc.get().then((DocumentSnapshot snapshot) {
          return snapshot.data['directConversationMap'] == null ? null : Map<String, dynamic>.from(snapshot.data['directConversationMap']);
        });
         */

        if(conversationExists) {
          print('Conversation exists: $_conversationId');
          DocumentReference conversationRef = FirebaseFirestore.instance.collection('/conversations').doc(_conversationId);
          Map<String, dynamic> postMap;
          Map<String, dynamic> conversationMembers;
          await conversationRef.get().then((DocumentSnapshot snapshot) {
            postMap = Map<String, dynamic>.from(snapshot.data()['postMap']);
            conversationMembers = Map<String, dynamic>.from(snapshot.data()['conversationMembers']);
          });

          //To-Do --increment unread posts for all users other than posting user
          //-------------------------------------------------------------------
          print('Members: $conversationMembers');
          Map<String, dynamic> newMemberMap = new Map<String, dynamic>();
          conversationMembers.forEach((uid, details) {
            Map<dynamic, dynamic> newDetails = details;
            if(uid != postingUserID) {
              int unheardCnt = details['unreadPosts'];
              if(unheardCnt != null)
                unheardCnt = unheardCnt + 1;
              newDetails['unreadPosts'] = unheardCnt;
            }
            newMemberMap[uid] = newDetails;
          });

          postMap.addAll({directPostDocId: postingUserID});
          batch.update(conversationRef, {'postMap': postMap, 'lastDate': date, 'lastPostUsername': postingUsername, 'lastPostUserId': postingUserID, 'conversationMembers': newMemberMap});
        } else {
          //Create new conversation document and update data
          DocumentReference newConversationRef = FirebaseFirestore.instance.collection('/conversations').doc();
          conversationId = newConversationRef.id;
          print('creating new conversation: $conversationId');
          Map<String, dynamic> conversationMembers = new Map<String, dynamic>();
          memberMap.forEach((uid, username) {
            if(uid == postingUserID)
              conversationMembers.addAll({uid: {'username': username, 'unreadPosts': 0}});
            else
              conversationMembers.addAll({uid: {'username': username, 'unreadPosts': 1}});
          });
          Map<String, dynamic> postMap = {directPostDocId: postingUserID};

          batch.set(newConversationRef, {'conversationMembers': conversationMembers, 'postMap': postMap, 'memberList': _memberList, 'lastDate': date, 'lastPostUsername': postingUsername, 'lastPostUserId': postingUserID});

          /*
          //Add a new conversation to the sending user doc conversationMap
          Map<String, dynamic> senderConversationMap = await postingUserDoc.get().then((DocumentSnapshot snapshot) {
            return snapshot.data['directConversationMap'] == null ? null : Map<String, dynamic>.from(snapshot.data['directConversationMap']);
          });

          Map<String, dynamic> sendConvoData = {_conversationId: true};

          if(senderConversationMap != null)
            senderConversationMap.addAll(sendConvoData);
          else
            senderConversationMap = sendConvoData;

          WriteBatch testBatch3 = Firestore.instance.batch();
          testBatch3.updateData(postingUserDoc, {'directConversationMap': senderConversationMap});
          print('');
          print('committing testBatch3');
          await testBatch3.commit();

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
          */
        }


        //Add data to new direct post document (message title, file url, length, date, sender, recipient, conversationId)
        Map<String, dynamic> newPostData = {'senderUID': postingUserID, 'senderUsername': postingUsername, 'messageTitle': messageTitle,
          'secondsLength': secondsLength, 'audioFileLocation': fileUrlString, 'conversationId': _conversationId != null ? _conversationId : conversationId,
          'datePosted': date
        };

        batch.set(directPostRef, newPostData);

        await batch.commit().catchError(((error) {
          print('Error committing testBatch4: $error');
        }));
        print('batch committed');
    }
  }

  Future<List<dynamic>> startRecordNewPost(MainAppProvider mp) async {
    if(recorder != null) {
      recorder.release();
      print('creating new sound recorder');
      recorder = new SoundRecorder(playInBackground: true);
    }
    print('start recording');
    try {
      recorder.initialize();

      //Check if have permissions for microphone or ask
      if(!(await Permission.microphone.isGranted)) {
        print('asking for mic permissions');
        await Permission.microphone.request().catchError((e) {
          print('Error request permission for microphone: $e');
        });
      }
      // String length
      //await fsRecorder.startRecorder(toFile: filePath, bitRate: 100000, codec: Codec.aacMP4);
      String tempFilePath = Track.tempFile(CustomMediaFormat());
      print('TempFilePath: $tempFilePath');
      /*
      recorder.onRequestPermissions = (Track track) async {
        print('requesting permissions');
        return true;
      };
       */
      Wakelock.enable();
      await recorder.record(Track.fromFile(tempFilePath, mediaFormat: CustomMediaFormat()));
      recordingDuration = Duration(milliseconds: 0);
      mp.setRecordingTime(recordingDuration);
      recorder.dispositionStream().listen((disposition) {
        mp.setRecordingTime(disposition.duration);
      });
      recorder.onStopped = ({bool wasUser = true}) {
        print('recorder stopped, duration: ${recorder.duration}');
        mp.setRecordingTime(recorder.duration);
      };
      /*
      recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        recordingDuration = Duration(seconds: recordingDuration.inSeconds + 1);
        mp.setRecordingTime(recordingDuration);
      });
       */
      DateTime startRecordDateTime = DateTime.now();
      print('Recording started at: $startRecordDateTime at $tempFilePath');
      return [Platform.isIOS ? tempFilePath.replaceAll('file://', '') : tempFilePath, startRecordDateTime];
    } catch (e) {
      print('Start recorder error: $e');
      return null;
    }
  }

  Future<List<dynamic>> stopRecordNewPost(String postPath, DateTime startDateTime) async {
    Wakelock.disable();
    try {
      //await fsRecorder.stopRecorder();
      await recorder.stop();
      recorder.release();
      //recordingTimer.cancel();
      recorder = new SoundRecorder();
      DateTime endRecordDateTime = DateTime.now();
      Duration recordingTime = endRecordDateTime.difference(startDateTime);

      int secondsLength = recordingTime.inSeconds;
      print('$startDateTime - $endRecordDateTime');
      print(secondsLength);
      return [postPath, secondsLength];
    } catch (e) {
      print('error stopping recorder: $e');
    }
    return null;
  }

  Future<void> followUser(String newFollowUID) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();

    //add newly followed user Id to current user's list of following
    DocumentReference currentUserDoc = await UserManagement().getUserData();
    String currentUserId = await currentUserDoc.get().then((snapshot) {
      return snapshot.data()['uid'].toString();
    });


    Map<String, dynamic> currentFollowing = await currentUserDoc.get().then((snapshot) {
      print('setting currentFollowing');
      if(snapshot.data()['following'] != null)
        return new Map<String, dynamic>.from(snapshot.data()['following']);
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

    batch.update(currentUserDoc, {'following': newFollowing});
      //add current users Id to newly followed user's list of followers and add current users mainFeedTimelineId to followed users list of including timelines
    DocumentReference followedUserDoc = FirebaseFirestore.instance.collection('/users').doc(newFollowUID);

    Map<String, dynamic> currentFollowers = await followedUserDoc.get().then((snapshot) {
      if(snapshot.data()['followers'] != null)
        return Map<String, dynamic>.from(snapshot.data()['followers']);
      return null;
    });
    Map<String, dynamic> currentTimelinesIncluded = await followedUserDoc.get().then((snapshot) {
      if(snapshot.data()['timelinesIncluded'] != null)
        return Map<String, dynamic>.from(snapshot.data()['timelinesIncluded']);
      return null;
    });
    String currentUserMainFeedTimelineId = await currentUserDoc.get().then((snapshot) {
      return snapshot.data()['mainFeedTimelineId'];
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

      batch.update(followedUserDoc, {'followers': newFollowers, 'timelinesIncluded': newTimelinesIncluded});
    }

      //add current user's main feedL timeline to list of timelines for all posts from the newly followed
    await FirebaseFirestore.instance.collection('/posts').where('userUID', isEqualTo: newFollowUID).get().then((QuerySnapshot snapshot) {
      print('post list snapshot data: ${snapshot.docs}');
      if(snapshot.docs.isEmpty) {
        print('user has no posts');
      } else {
        snapshot.docs.forEach((DocumentSnapshot postSnapshot) {
         List<dynamic> newPostTimelines = new List<dynamic>();
         if(postSnapshot.data()['timelines'] != null && postSnapshot.data()['timelines'].length > 0) {
           print('post has timeline field');
           List<dynamic> currentPostTimelines = postSnapshot.data()['timelines'];
           newPostTimelines.addAll(currentPostTimelines);
           newPostTimelines.add(currentUserMainFeedTimelineId);
           print('set list to current timeline list');
         }
         else {
           newPostTimelines = [currentUserMainFeedTimelineId];
         }

         batch.update(postSnapshot.reference, {'timelines': newPostTimelines});
        });
      }
    }).catchError((e) {
      print('Error adding timeline to posts: $e');
    });

    batch.commit();
  }

  Future<void> unfollowUser(String unfollowUID) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();

    DocumentReference loggedInUserDoc = await UserManagement().getUserData().then((doc) => doc);
    DocumentReference unfollowedUserDoc = await FirebaseFirestore.instance.collection('/users').where('uid', isEqualTo: unfollowUID).get().then((snapshot) async {
      return snapshot.docs.first.reference;
    });
    String loggedInUID = await loggedInUserDoc.get().then((snapshot) {
      return snapshot.data()['uid'];
    });
    String loggedInMainFeedTimelineId = await loggedInUserDoc.get().then((snapshot) {
      return snapshot.data()['mainFeedTimelineId'];
    });

    //Remove userId from logged in user's list of following
    Map<String, dynamic> currentFollowing = await loggedInUserDoc.get().then((snapshot) {
      return new Map<String, dynamic>.from(snapshot.data()['following']);
    });
    print('wint');
    currentFollowing.remove(unfollowUID);

    batch.update(loggedInUserDoc, {'following': currentFollowing});
    //remove logged in user's userId from unfollowed user's list of followers
    Map<String, dynamic> unfollowedUserFollowers = await unfollowedUserDoc.get().then((snapshot) {
      return new Map<String, dynamic>.from(snapshot.data()['followers']);
    });
    Map<String, dynamic> unfollowedTimelinesIncluded = await unfollowedUserDoc.get().then((snapshot) {
      return new Map<String, dynamic>.from(snapshot.data()['timelinesIncluded']);
    });
    unfollowedUserFollowers.remove(loggedInUID);
    unfollowedTimelinesIncluded.remove(loggedInMainFeedTimelineId);

    batch.update(unfollowedUserDoc, {'followers': unfollowedUserFollowers, 'timelinesIncluded': unfollowedTimelinesIncluded});
    //remove logged in user's mainFeedTimelinesId from all posts of unfollowed user
    await FirebaseFirestore.instance.collection('/posts').where('userUID', isEqualTo: unfollowUID).get().then((snapshot) {
      if(snapshot.docs.isEmpty){
        print('unfollowed user has no posts');
      } else {
        snapshot.docs.forEach((DocumentSnapshot docSnap) {
          List<String> postTimelines = new List<String>.from(docSnap.data()['timelines']);
          postTimelines.remove(loggedInMainFeedTimelineId);

          batch.update(docSnap.reference, {'timelines': postTimelines});
        });
      }
    });

    batch.commit();
  }

  String getDurationString(Duration duration) {
    bool isNegative = false;
    int hours = duration.inHours;
    int minutes = duration.inMinutes.remainder(60);
    int seconds = duration.inSeconds.remainder(60);
    if(hours < 0 || minutes < 0 || seconds < 0) {
      isNegative = true;
    }
    String minutesString = minutes.abs() >= 10 ? '${minutes.abs()}' : '0${minutes.abs()}';
    String secondsString = seconds.abs() >= 10 ? '${seconds.abs()}' : '0${seconds.abs()}';
    //print('Hours: $hours/Minutes: $minutes/Seconds: $seconds');
    if(hours > 0)
      return '${isNegative ? '-' : ''}${hours.abs()}:$minutesString:$secondsString';
    return '${isNegative ? '-' : ''}$minutesString:$secondsString';
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
      contentPadding: EdgeInsets.fromLTRB(10.0, 5.0, 10.0, 5.0),
      title: Center(child: Text('Upload Post', style: TextStyle(color: Colors.deepPurple),)),
      children: <Widget>[
        SizedBox(height: 10),
        TextField(
          decoration: InputDecoration(
            hintText: 'Post Title (optional)',
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

            String path = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['mp3', 'aac', 'm4a'], allowMultiple: false).then((result) => result.files.first.path);
            File uploadFile = File(path);
            print('Selected File Path: $path');
            print('File: $uploadFile: ${await uploadFile.exists()}');
            AudioPlayer tempPlayer = new AudioPlayer();
            await tempPlayer.setFilePath(path);
            //int audioDuration = await Future.delayed(Duration(seconds: 2), () => tempPlayer.duration);
            Duration postDuration = await Future.delayed(Duration(seconds: 2), () => tempPlayer.duration);
            //print('Duration: $audioDuration/Seconds: ${postDuration.inSeconds}');
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
                  }, true, false, null, null);
                  //print('Post added');
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
  bool _isPlaybackRecording = false;
  String _postAudioPath;
  DateTime _startRecordDate;
  int _secondsLength;
  ActivityManager activityManager = new ActivityManager();
  AudioPlayer audioPlayer = new AudioPlayer();
  bool _isLoading = false;

  @override
  dispose() {
    activityManager.recorder.release();
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    PlaybackState playbackState = Provider.of<PlaybackState>(context);
    return SimpleDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
      contentPadding: EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 10.0),
      title: Center(child: Text('New Message',
          style: TextStyle(color: Colors.deepPurple),
        textAlign: TextAlign.center,
      )),
      children: <Widget>[
        _isLoading ? Center(child: Container(height: 75.0, width: 75.0, child: CircularProgressIndicator())) : Column(
          children: <Widget>[
            SizedBox(height: 10),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    _isRecording ? RecordingPulse(maxSize: 56.0,) : Container(),
                    FloatingActionButton(
                        backgroundColor: _isRecording ? Colors.transparent : Colors.red,
                        child: Icon(Icons.mic, color: _isRecording ? Colors.red : Colors.white,),
                        shape: CircleBorder(side: BorderSide(color: Colors.red)),
                        heroTag: null,
                        elevation: _isRecording ? 0.0 : 5.0,
                        onPressed: () async {
                          if(playbackState != null && playbackState.playing) {
                            mp.pausePost();
                          }
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
                            List<dynamic> startRecordVals = await activityManager.startRecordNewPost(mp);
                            String postPath = startRecordVals[0];
                            DateTime startDate = startRecordVals[1];
                            setState(() {
                              _isRecording = !_isRecording;
                              _postAudioPath = postPath;
                              _startRecordDate = startDate;
                            });
                          }
                        }
                    )
                  ],
                ),
                SizedBox(width: 50),
                FloatingActionButton(
                  heroTag: 2,
                  backgroundColor: _postAudioPath == null || _isRecording ? Colors.grey : _isPlaybackRecording ? Colors.red : Colors.deepPurple,
                  child: Icon(_isPlaybackRecording ? Icons.pause : Icons.play_arrow, color: Colors.white),
                  onPressed: () async {
                    if(_postAudioPath == null || _isRecording)
                      return;
                    if(_isPlaybackRecording) {
                      audioPlayer.pause();
                      setState(() {
                        _isPlaybackRecording = false;
                      });
                    } else {
                      await audioPlayer.setFilePath(_postAudioPath);
                      audioPlayer.play();
                      //audioPlayer.play(_postAudioPath, isLocal: true);
                      audioPlayer.processingStateStream.listen((ProcessingState state) {
                        if(state == ProcessingState.completed) {
                          setState(() {
                            _isPlaybackRecording = false;
                          });
                        }
                      });
                      /*
                      audioPlayer.onPlayerCompletion.listen((event) {
                        setState(() {
                          _isPlaybackRecording = false;
                        });
                      });
                       */
                      setState(() {
                        _isPlaybackRecording = true;
                      });
                    }
                  },
                )
              ]
            ),
            SizedBox(height: 10.0),
            Center(
              child: _postAudioPath == null || mp.recordingTime == null ? Text('Audio Recording Missing',
                style: TextStyle(color: Colors.red),
              ) : Text(ActivityManager().getDurationString(mp.recordingTime)),
            ),
            SizedBox(height: 10.0),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  FlatButton(
                      child: Text('Cancel'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      }
                  ),
                  _isLoading ? Container() : FlatButton(
                    child: Text('Send', style: TextStyle(color: _postAudioPath != null && _secondsLength != null ? Colors.white : Colors.grey)),
                    color: _postAudioPath != null && _secondsLength != null ? Colors.deepPurple : Colors.transparent,
                    onPressed: () async {
                      if(_postAudioPath != null && _secondsLength != null){
                        setState(() {
                          _isLoading = true;
                        });
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
            )
          ]
        ),
      ],
    );
  }

}

//
class CustomMediaFormat extends NativeMediaFormat {
  /// ctor
  const CustomMediaFormat({
    int sampleRate = 16000,
    int numChannels = 1,
    int bitRate = 16000,
  }) : super.detail(
    name: 'aac',
    sampleRate: 16000,
    numChannels: 1,
    bitRate: 16000,
  );

  @override
  String get extension => 'mp4';

  // Whilst the actual index is MediaRecorder.AudioEncoder.AAC (3)
  @override
  int get androidEncoder => 3;

  /// MediaRecorder.OutputFormat.MP4
  @override
  int get androidFormat => 2;

  /// kAudioFormatMPEG4AAC
  @override
  int get iosFormat => 1633772320;
}