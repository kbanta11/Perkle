import 'package:Perkl/Timeline.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:podcast_search/podcast_search.dart';
import 'package:intl/intl.dart';
import 'package:podcast_search/podcast_search.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'local_services.dart';
import 'dart:io';
import 'models.dart';
import 'Helper.dart';

class DBService {
  FirebaseFirestore _db = FirebaseFirestore.instance;
  LocalService _localService = new LocalService();
  Future<int> getConfigMinBuildNumber() async {
    int buildNumber = await _db.collection('config').doc('config').get().then((snap) {
      return snap.data()[Platform.isAndroid ? 'minimum_android_version' : 'minimum_ios_version'];
    }).catchError((e) {
      print('error: $e');
    });
    return buildNumber;
  }

  Future<List<DiscoverTag>> getDiscoverTags() async {
    return await _db.collection('discover').where('type', isEqualTo: 'StreamTag').orderBy('rank').get().then((QuerySnapshot qs) {
      return qs.docs.map((doc) => DiscoverTag.fromFirestore(doc)).toList();
    });
  }

  Stream<List<String>> streamDiscoverPods() {
    return _db.collection('requests').doc('discover').snapshots().map((doc) {
      return doc.data()['results'].map<String>((value) => value.toString()).toList();
    });
  }

  Stream<List<Conversation>> streamConversations(String userId) {
    return _db.collection('conversations').where('memberList', arrayContains: userId).orderBy('lastDate', descending: true).snapshots().map((qs) {
      return qs.docs.map((doc) => Conversation.fromFirestore(doc)).toList();
    });
  }
  
  Stream<List<DirectPost>> streamDirectPosts(String conversationId) {
    return _db.collection('directposts').where('conversationId', isEqualTo: conversationId).orderBy('datePosted', descending: true).snapshots().map((qs) {
      return qs.docs.map((doc) => DirectPost.fromFirestore(doc)).toList();
    });
  }

  Stream<List<Post>> streamTagPosts(String streamTag) {
    return _db.collection('posts').where('streamList', arrayContains: streamTag).orderBy('datePosted', descending: true).snapshots().map((qs) {
      return qs.docs.map((doc) => Post.fromFirestore(doc)).toList();
    });
  }

  Stream<List<PostPodItem>> streamTimelinePosts(PerklUser currentUser, {String timelineId, String streamTag, String userId, TimelineType type, bool reload}) {
    //print('TimelineId: $timelineId ---- StreamTag: $streamTag ---- UserId: $userId');
    if(streamTag != null) {
      return _db.collection('posts').where('streamList', arrayContains: streamTag).orderBy('datePosted', descending: true).snapshots().map((qs) {
        return qs.docs.map((doc) => PostPodItem.fromPost(Post.fromFirestore(doc))).toList();
      });
    }
    if(timelineId != null && type == TimelineType.MAINFEED) {
      //updateTimeline(timelineId: timelineId, user: currentUser, reload: reload);
      return _db.collection('timelines').doc(timelineId).collection('items').orderBy("date", descending: true).snapshots().map((qs) {
        print(qs.docs.length);
        List<PostPodItem> list = qs.docs.map((DocumentSnapshot doc) {
          String itemType = doc.data()['type'];
          Map data = doc.data();
          //print(data.toString());
          PostPodItem newItem;
          if(itemType == 'PODCAST_EPISODE') {
            //Map data = doc.data;
            //data['description'] = data['description'].toString();
            //print(data);
            String feedUrl = data['podcast_feed'];
            if(feedUrl != null)
              feedUrl = feedUrl.replaceFirst('https:', 'http:');
            //print('feedUrl: $feedUrl');
            Podcast pod = new Podcast.of(url: feedUrl, description: data['podcast_description'] != null ? data['podcast_description'].toString() : null, title: doc.data()['podcast_title'], image: doc.data()['image_url']);
            //print('$itemType: ${data['audio_url']} | Episode: ${data['episode']} | Guid: ${data['episode_guid']} | Title: ${data['title']} | Author: ${pod.title} | Duration: ${data['itunes_duration']} | Description: ${data['description']}');
            Episode ep = new Episode.of(guid: doc.data()['episode_guid'],
                title: doc.data()['title'],
                podcast: pod,
                author: pod.title,
                duration: Helper().parseItunesDuration(doc.data()['itunes_duration']),
                description: doc.data()['description'],
                publicationDate: doc.data()['date'] == null ? null : DateTime.fromMillisecondsSinceEpoch(doc.data()['date'].millisecondsSinceEpoch),
                contentUrl: doc.data()['audio_url'],
                episode: doc.data()['episode'] != null ? int.parse(doc.data()['episode']) : null);
            newItem = PostPodItem.fromEpisode(ep, pod);
            //print('${newItem.podcast.title} : ${newItem.episode.title}');
          } else if (itemType == 'POST') {
            Post post = new Post(id: doc.data()['post_id'],
                audioFileLocation: doc.data()['audio_url'],
                userUID: doc.data()['userUID'],
                username: doc.data()['username'],
                secondsLength: doc.data()['seconds_length'],
                datePosted: doc.data()['date'] == null ? null : DateTime.fromMillisecondsSinceEpoch(doc.data()['date'].millisecondsSinceEpoch),
                listenCount: doc.data()['listenCount'],
                streamList: doc.data()['streamList'] != null ? doc.data()['streamList'].map<String>((item) => item.toString()).toList() : null,
                postTitle: doc.data()['title']);
            newItem = PostPodItem.fromPost(post);
          }
          //print(newItem);
          return newItem;
        }).toList();
        return list;
      }).handleError((error) {print('Error getting timeline items: $error');});
    }
    if(userId != null) {
      return _db.collection('posts').where('userUID', isEqualTo: userId).orderBy("datePosted", descending: true).snapshots().map((qs) {
        return qs.docs.map((doc) => PostPodItem.fromPost(Post.fromFirestore(doc))).toList();
      });
    }
    return _db.collection('posts').where('userUID', isEqualTo: currentUser.uid).orderBy("datePosted", descending: true).snapshots().map((qs) {
      return qs.docs.map((doc) => PostPodItem.fromPost(Post.fromFirestore(doc))).toList();
    });
  }

  Stream<List<EpisodeReply>> streamEpisodeReplies(String uniqueId) {
    print('Unique ID: $uniqueId');
    return _db.collection('episode-replies').where("unique_id", isEqualTo: uniqueId).orderBy("reply_date", descending: true).snapshots().map((qs) {
      //print('Number of Replies: ${qs.docs.length}');
      return qs.docs.map((doc) => EpisodeReply.fromFirestore(doc)).toList();
    });
  }

  updateTimeline({String timelineId, PerklUser user, DateTime minDate, bool reload, bool setLoading = true}) async {
    DocumentReference timelineRef = _db.collection('timelines').doc(timelineId);
    DateTime lastUpdateTime = await timelineRef.get().then((snap) => snap.data()['last_updated'] == null ? null : DateTime.fromMillisecondsSinceEpoch(snap.data()['last_updated'].millisecondsSinceEpoch));
    //print('Time since last update ($lastUpdateTime to ${DateTime.now()}): ${DateTime.now().difference(lastUpdateTime).inSeconds}');
    if(lastUpdateTime == null || (lastUpdateTime != null && DateTime.now().difference(lastUpdateTime).inSeconds > 90) || minDate != null) {
      if(setLoading){
        await _db.runTransaction((transaction) {
          transaction.update(timelineRef, {'is_loading': true});
          return;
        });
      }
      if(user != null) {
        await _db.runTransaction((transaction) {
          transaction.update(timelineRef, {'last_updated': DateTime.now(), 'podcasts_included': user.followedPodcasts, 'last_min_date': minDate, 'reload': reload});
          return;
        });
      } else {
        await _db.runTransaction((transaction) {
          transaction.update(timelineRef, {'last_updated': DateTime.now(), 'last_min_date': minDate, 'reload': reload});
          return;
        });
      }
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'getTimeline',
      );
      dynamic resp = await callable.call(<String, dynamic>{
        'timelineId': timelineId,
        'reload': reload ?? false
      });
      if(setLoading) {
        await _db.runTransaction((transaction) {
          transaction.update(timelineRef, {'is_loading': false});
          return;
        });
      }
      print('Response: $resp');
    }
  }

  Stream<bool> streamTimelineLoading(String timelineId) {
    return _db.collection('timelines').doc(timelineId).snapshots().map((snap) {
      return snap.data()['is_loading'] ?? false;
    });
  }

  Future<void> updateDeviceToken(String userToken, String uid) async {
    var tokens = _db
        .collection('users')
        .doc(uid)
        .collection('tokens')
        .doc(userToken);

    await tokens.set({
      'token': userToken,
      'createdAt': FieldValue.serverTimestamp(), // optional
      'platform': Platform.operatingSystem // optional
    });
  }

  void markConversationRead(String conversationId, String userId) async {
    DocumentReference conversationRef = _db.collection('conversations').doc(conversationId);
    Conversation convo = await conversationRef.get().then((doc) => Conversation.fromFirestore(doc));
    print('Members before: ${convo.conversationMembers}');
    if(convo.conversationMembers != null && convo.conversationMembers.containsKey(userId)) {
      print('setting user unread to 0');
      Map userMap = convo.conversationMembers[userId];
      userMap['unreadPosts'] = 0;
      convo.conversationMembers[userId] = userMap;
    }
    print('Members after: ${convo.conversationMembers}');
    await _db.runTransaction((transaction) {
      transaction.update(conversationRef, {'conversationMembers': convo.conversationMembers});
      return;
    });
  }

  Future<void> sendFeedback(int rating, String positive, String negative, PerklUser user) async {
    DocumentReference feedbackRef = _db.collection('feedback').doc('initial-testing').collection('responses').doc(user.uid);
    await _db.runTransaction((trans) {
      trans.set(feedbackRef, {
        'userId': user.uid,
        'rating': rating,
        'positive': positive,
        'negative': negative,
        'datesent': DateTime.now(),
      });
      return;
    });
    return;
  }

  Future<void> postEpisodeReply({Episode episode, Podcast podcast, String filePath, Duration replyLength, DateTime replyDate, PerklUser user, String replyTitle}) async {
    String episodeId = episode.guid != null ? episode.guid : episode.link;
    String fileUrlString;

    //upload file to firebase storage
    if(filePath != null) {
      //Get audio file
      File audioFile = File(filePath);
      String dateString = DateFormat("yyyy-MM-dd_HH_mm_ss").format(replyDate).toString();
      final Reference storageRef = FirebaseStorage.instance.ref().child(user.uid).child('episode-replies').child('$episodeId-$dateString');
      final UploadTask uploadTask = storageRef.putFile(audioFile);
      await uploadTask.whenComplete(() => null);
      String _fileUrl = await storageRef.getDownloadURL();//await (await uploadTask.onComplete).ref.getDownloadURL();
      fileUrlString = _fileUrl.toString();
    }

    //add document to "episode-replies" collection, key on episode ID (guid/link)
    DocumentReference replyRef = _db.collection('episode-replies').doc();

    await _db.runTransaction((transaction) {
      transaction.set(replyRef, {
        'id': replyRef.id,
        'unique_id': episodeId,
        'podcast_name': podcast.title,
        'episode_name': episode.title,
        'episode_date': episode.publicationDate,
        'posting_username': user.username,
        'posting_uid': user.uid,
        'reply_title': replyTitle,
        'reply_date': replyDate,
        'reply_ms': replyLength.inMilliseconds,
        'audioFileLocation': fileUrlString,
      });
      return;
    });

    //Make sure to update username change function to also update replies
  }

  Future<List<String>> getHeardPostIds({String conversationId, String userId}) async {
    return await _db.collection('conversations').doc(conversationId).collection('heard-posts').doc(userId).get().then((DocumentSnapshot docSnap) {
      if(!docSnap.exists) {
        return null;
      }
      List<String> idList = List<String>();
      idList.addAll(docSnap.data()['id_list'].cast<String>());
      return idList;
    });
  }

  markDirectPostHeard({String conversationId, String userId, String postId}) async {
    print('marking direct post heard');
    DocumentReference docRef = _db.collection('conversations').doc(conversationId).collection('heard-posts').doc(userId);
    List<String> idList = List<String>();
    bool docExists = false;
    print('Heard Posts doc: $docRef');
    await docRef.get().then((docSnap) {
      print('heard posts doc data: ${docSnap.data()}');
      if(docSnap.exists) {
        docExists = true;
        idList.addAll(docSnap.data()['id_list'].cast<String>());
      }
    });
    idList.add(postId);

    await _db.runTransaction((transaction) {
      if(docExists) {
        transaction.update(docRef, {
          'id_list': idList,
        });
      } else {
        transaction.set(docRef, {'id_list': idList});
      }
      return;
    });
  }

  Future<void> syncConversationPostsHeard() async {
    Map<String, dynamic> heardPostMap = await LocalService(filename: 'conversations.json').getData('conversation-heard-posts');
    String currentUserId = FirebaseAuth.instance.currentUser.uid;
    if(heardPostMap != null) {
      heardPostMap.forEach((key, val) async {
        String conversationId = key;
        List<String> localPostsHeard;
        if(val[currentUserId] != null)  {
          localPostsHeard = val[currentUserId].cast<String>();
        } else {
          print('This user is not in this conversation or doesn\'t have any posts listened to currently');
          return;
        }
        DocumentReference docRef = _db.collection('conversations').doc(conversationId).collection('heard-posts').doc(currentUserId);
        List<String> fbPostsHeard = await docRef.get().then((snap) => snap.data() != null ? snap.data()['id_list'].cast<String>() : null);
        if(fbPostsHeard == null) {
          //set posts heard for this conversation to the local list
          print('setting new list of posts heard to local list');
          _db.runTransaction((transaction) {
            transaction.set(docRef, {'id_list': localPostsHeard});
            return;
          });
          return;
        } else {
          localPostsHeard.forEach((postId) async {
            if(!fbPostsHeard.contains(postId)) {
              print('adding post ($postId) to heard for conversation: $conversationId');
              await markDirectPostHeard(conversationId: conversationId, userId: currentUserId, postId: postId);
            }
          });
          return;
        }
      });
    }
  }

  Future<List<DirectPost>> getDirectPosts(String conversationId) {
    return _db.collection('directposts').where('conversationId', isEqualTo: conversationId).orderBy('datePosted', descending: true).get().then((QuerySnapshot qs) {
      if(qs.docs.length > 0) {
        return qs.docs.map((docSnap) => DirectPost.fromFirestore(docSnap)).toList();
      }
      return null;
    });
  }

  //Share podcast episodes in conversations
  Future<void> shareEpisodeToDiscussion({Episode episode, Podcast podcast, PerklUser sender, bool sendAsGroup, Map<String, dynamic> sendToUsers, Map<String, dynamic> addToConversations}) async {
    if(sendToUsers != null){
      if(sendToUsers.length > 0) {
        if(sendAsGroup) {
          //Create memberMap {uid: username} for all users in group
          Map<String, dynamic> _memberMap = new Map<String, dynamic>();
          _memberMap.addAll({sender.uid: sender.username});
          print('Send To Users: $sendToUsers');
          for(String user in sendToUsers.keys) {
            String _username = await _db.collection('users').doc(user).get().then((doc) {
              return doc.data()['username'];
            });
            _memberMap.addAll({user: _username});
          }
          print('Member Map (Send as group): $_memberMap');
          await shareDirectPost(episode, podcast, sender, memberMap: _memberMap);
        } else {
          //Iterate over users to send to and send direct post for each w/
          // memberMap of currentUser and send to user
          sendToUsers.forEach((key, value) async {
            Map<String, dynamic> _memberMap = new Map<String, dynamic>();
            _memberMap.addAll({sender.uid: sender.username});
            String _thisUsername = await _db.collection('users').doc(key).get().then((doc) {
              return doc.data()['username'];
            });
            _memberMap.addAll({key: _thisUsername});
            //send direct post to this user
            await shareDirectPost(episode, podcast, sender, memberMap: _memberMap);
          });
        }
      }
    }

    if(addToConversations != null) {
      if(addToConversations.length > 0) {
        addToConversations.forEach((key, value) async {
          print('adding to conversation: $key');
          await shareDirectPost(episode, podcast, sender, conversationId: key);
        });
      }
    }
  }

  Future<void> shareDirectPost(Episode episode, Podcast podcast, PerklUser sender, {String conversationId, Map<dynamic, dynamic> memberMap}) async {
    DocumentReference conversationRef;
    DocumentReference postRef = _db.collection('directposts').doc();
    String convoId = conversationId;
    WriteBatch batch = _db.batch();
    print('Member Map passed in: $memberMap');
    if(podcast.episodes == null) {
      podcast = await Podcast.loadFeed(url: podcast.url);
    }
    //Check if conversation with these members exists
    List<String> _memberList = new List<String>();
    if(memberMap != null) {
      _memberList.addAll(memberMap.keys);
    }
    _memberList.sort();
    if(convoId == null){
      await _db.collection('conversations').where('memberList', isEqualTo: _memberList).get().then((snapshot) {
        if(snapshot.docs.isNotEmpty) {
          DocumentSnapshot conversation = snapshot.docs.first;
          if(conversation != null)
            conversationRef = conversation.reference;
            convoId = conversation.reference.id;
        }
      });
    }

    //If conversation exists, add post to conversation, otherwise create new conversation and add post
    if(convoId != null) {
      print('Conversation exists: $convoId');
      conversationRef = _db.collection('conversations').doc(convoId);
      //Get post map and conversationMembers
      Map<String, dynamic> postMap;
      Map<String, dynamic> conversationMembers;
      await conversationRef.get().then((DocumentSnapshot snapshot) {
        postMap = Map<String, dynamic>.from(snapshot.data()['postMap']);
        conversationMembers = Map<String, dynamic>.from(snapshot.data()['conversationMembers']);
      });

      //-increment unread posts for all users other than posting user
      print('Members: $conversationMembers');
      Map<String, dynamic> newMemberMap = new Map<String, dynamic>();
      conversationMembers.forEach((uid, details) {
        Map<dynamic, dynamic> newDetails = details;
        if(uid != sender.uid) {
          int unheardCnt = details['unreadPosts'];
          if(unheardCnt != null)
            unheardCnt = unheardCnt + 1;
          newDetails['unreadPosts'] = unheardCnt;
        }
        newMemberMap[uid] = newDetails;
      });

      postMap.addAll({postRef.id: sender.uid});
      //update conversation document
      batch.update(conversationRef, {'postMap': postMap, 'lastDate': DateTime.now(), 'lastPostUsername': sender.username, 'lastPostUserId': sender.uid, 'conversationMembers': newMemberMap});
    } else {
      //Create new conversation document and update data
      conversationRef = _db.collection('/conversations').doc();
      convoId = conversationRef.id;
      print('creating new conversation: $conversationId');
      Map<String, dynamic> conversationMembers = new Map<String, dynamic>();
      memberMap.forEach((uid, username) {
        if(uid == sender.uid)
          conversationMembers.addAll({uid: {'username': username, 'unreadPosts': 0}});
        else
          conversationMembers.addAll({uid: {'username': username, 'unreadPosts': 1}});
      });
      Map<String, dynamic> postMap = {postRef.id: sender.uid};
      print('member list: $_memberList/Conversation Members: $conversationMembers');

      batch.set(conversationRef, {'conversationMembers': conversationMembers, 'postMap': postMap, 'memberList': _memberList, 'lastDate': DateTime.now(), 'lastPostUsername': sender.username, 'lastPostUserId': sender.uid});
    }

    //Add data to new direct post document (message title, contentUrl, length (ms), date, sender, conversationId, shared, podcast and episode info)
    Map<String, dynamic> newPostData = {
      'senderUID': sender.uid,
      'senderUsername': sender.username,
      'author': podcast.title,
      'podcast-link': podcast.link,
      'podcast-url': podcast.url,
      'podcast-title': podcast.title,
      'podcast-image': podcast.image,
      'episode-guid': episode.guid,
      'episode-description': episode.description,
      'episode-link': episode.link,
      'messageTitle': episode.title,
      'ms-length': episode.duration.inMilliseconds,
      'audioFileLocation': episode.contentUrl,
      'conversationId': convoId,
      'datePosted': DateTime.now(),
      'shared': true,
    };

    batch.set(postRef, newPostData);

    await batch.commit().catchError(((error) {
      print('Error committing batch: $error');
    }));
    print('batch committed');
  }

  //Delete a regular post document (does not delete the audio file)
  Future<void> deletePost(Post post) async {
    print('deleting post: ${post.id}');
    await _db.collection('posts').doc(post.id).delete();
    return;
  }

  Future<void> followPodcast({PerklUser user, String podcastUrl}) async {
    List<String> newList = new List<String>();
    if(user.followedPodcasts != null) {
      newList.addAll(user.followedPodcasts);
    }
    newList.add(podcastUrl);
    DocumentReference userRef = _db.collection('users').doc(user.uid);
    await _db.runTransaction((transaction) {
      transaction.update(userRef, {'followedPodcasts': newList});
      return;
    });
  }

  Future<void> unfollowPodcast({PerklUser user, String podcastUrl}) async {
    List<String> newList = new List<String>();
    if(user.followedPodcasts != null) {
      newList.addAll(user.followedPodcasts);
      newList.removeWhere((item) => item == podcastUrl);
    }

    DocumentReference userRef = _db.collection('users').doc(user.uid);
    await _db.runTransaction((transaction) {
      transaction.update(userRef, {'followedPodcasts': newList});
      return;
    });
  }
}