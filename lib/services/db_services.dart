import 'package:Perkl/Timeline.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:podcast_search/podcast_search.dart';
import 'package:audio_service/audio_service.dart';
import 'package:intl/intl.dart';
import 'package:podcast_search/podcast_search.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'local_services.dart';
import 'UserManagement.dart';
import 'dart:io';
import 'models.dart';
import 'Helper.dart';

class DBService {
  FirebaseFirestore _db = FirebaseFirestore.instance;
  LocalService _localService = new LocalService();
  Future<int> getConfigMinBuildNumber() async {
    int buildNumber = await _db.collection('config').doc('config').get().then((snap) {
      return snap.data()?[Platform.isAndroid ? 'minimum_android_version' : 'minimum_ios_version'];
    }).catchError((e) {
      print('error: $e');
    });
    return buildNumber;
  }

  Future<void> checkOrCreateUserDoc(User? firebaseUser) async {
    //get user doc if exists
    bool userDocExists = await _db.collection('users').doc(firebaseUser?.uid).get().then((snap) => snap.exists);
    if(!userDocExists) {
      print('User not yet created, creating user doc');
      await UserManagement().storeNewUser(firebaseUser, tosAccepted: false);
    }
  }

  Future<List<DiscoverTag>> getDiscoverTags() async {
    return await _db.collection('discover').where('type', isEqualTo: 'StreamTag').orderBy('rank').get().then((QuerySnapshot qs) {
      return qs.docs.map((doc) => DiscoverTag.fromFirestore(doc)).toList();
    });
  }

  Stream<List<String>> streamDiscoverPods() {
    return _db.collection('requests').doc('discover').snapshots().map((doc) {
      return doc.data()?['results'].map<String>((value) => value.toString()).toList();
    });
  }

  Stream<List<Conversation>> streamConversations(String? userId) {
    return _db.collection('conversations').where('memberList', arrayContains: userId).orderBy('lastDate', descending: true).snapshots().map((qs) {
      return qs.docs.map((doc) => Conversation.fromFirestore(doc)).toList();
    });
  }
  
  Stream<List<DirectPost>?> streamDirectPosts(String? conversationId) {
    return _db.collection('directposts').where('conversationId', isEqualTo: conversationId).orderBy('datePosted', descending: true).snapshots().map((qs) {
      return qs.docs.map((doc) {
        print('Doc: ${doc.data()}');
        return DirectPost.fromFirestore(doc);
      }).toList();
    });
  }

  Stream<List<Post>> streamTagPosts(String? streamTag) {
    return _db.collection('posts').where('streamList', arrayContains: streamTag).orderBy('datePosted', descending: true).snapshots().map((qs) {
      return qs.docs.map((doc) => Post.fromFirestore(doc)).toList();
    });
  }

  Stream<List<PostPodItem?>> streamTimelinePosts(PerklUser? currentUser, {String? timelineId, String? streamTag, String? userId, TimelineType? type, bool? reload}) {
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
        List<PostPodItem?> list = qs.docs.map((DocumentSnapshot doc) {
          String? itemType = doc.data()?['type'];
          Map? data = doc.data();
          //print(data.toString());
          PostPodItem? newItem;
          if(itemType == 'PODCAST_EPISODE') {
            //Map data = doc.data;
            //data['description'] = data['description'].toString();
            //print(data);
            String feedUrl = data?['podcast_feed'];
            if(feedUrl != null)
              feedUrl = feedUrl.replaceFirst('https:', 'http:');
            //print('feedUrl: $feedUrl');
            Podcast pod = new Podcast.of(url: feedUrl, description: data?['podcast_description']?.toString(), title: doc.data()?['podcast_title'], image: doc.data()?['image_url']);
            //print('$itemType: ${data['audio_url']} | Episode: ${data['episode']} | Guid: ${data['episode_guid']} | Title: ${data['title']} | Author: ${pod.title} | Duration: ${data['itunes_duration']} | Description: ${data['description']}');
            Episode ep = new Episode.of(guid: doc.data()?['episode_guid'],
                title: doc.data()?['title'],
                podcast: pod,
                author: pod.title,
                duration: Helper().parseItunesDuration(doc.data()?['itunes_duration']),
                description: doc.data()?['description'],
                publicationDate: doc.data()?['date'] == null ? null : DateTime.fromMillisecondsSinceEpoch(doc.data()?['date'].millisecondsSinceEpoch),
                contentUrl: doc.data()?['audio_url'],
                episode: doc.data()?['episode'] != null ? int.parse(doc.data()?['episode']) : null);
            newItem = PostPodItem.fromEpisode(ep, pod);
            //print('${newItem.podcast.title} : ${newItem.episode.title}');
          } else if (itemType == 'POST') {
            Post post = new Post(id: doc.data()?['post_id'],
                audioFileLocation: doc.data()?['audio_url'],
                userUID: doc.data()?['userUID'],
                username: doc.data()?['username'],
                secondsLength: doc.data()?['seconds_length'],
                datePosted: doc.data()?['date'] == null ? null : DateTime.fromMillisecondsSinceEpoch(doc.data()?['date'].millisecondsSinceEpoch),
                listenCount: doc.data()?['listenCount'],
                streamList: doc.data()?['streamList']?.map<String>((item) => item.toString()).toList(),
                postTitle: doc.data()?['title']);
            newItem = PostPodItem.fromPost(post);
          }
          //print(newItem);
          return newItem;
        }).toList();
        return list;
      });//.handleError((error) {print('Error getting timeline items: $error');});
    }
    if(userId != null) {
      return _db.collection('posts').where('userUID', isEqualTo: userId).orderBy("datePosted", descending: true).snapshots().map((qs) {
        print('Timeline QuerySnap: ${qs.docs}');
        return qs.docs.map((doc) {
          print('PostPodItem: ${PostPodItem.fromPost(Post.fromFirestore(doc))}');
          return PostPodItem.fromPost(Post.fromFirestore(doc));
        }).toList();
      });
    }
    return _db.collection('posts').where('userUID', isEqualTo: currentUser?.uid).orderBy("datePosted", descending: true).snapshots().map((qs) {
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

  Stream<List<PostPodItem>> streamEpisodeClips(String? userId) {
    return _db.collection('episode-clips').where('creator_uid', isEqualTo: userId).orderBy('created_date', descending: true).snapshots().map((qs) {
      print('Episode Clips: ${qs.docs}');
      return qs.docs.map((doc) => PostPodItem.fromEpisodeClip(EpisodeClip.fromFirestore(doc))).toList();
    });
  }

  Stream<List<Playlist>> streamMyPlaylists(String? userId) {
    return _db.collection('playlists').where('creator_uid', isEqualTo: userId).orderBy('last_modified', descending: true).snapshots().map((qs) {
      print('Playlist Docs: ${qs.docs}');
      return qs.docs.map((doc) {
        print('Playlist item: ${doc.data()}');
        Playlist playlist = Playlist.fromFirestore(doc);
        print('Playlist: $playlist');
        return playlist;
      }).toList();
    });
  }

  Stream<List<Playlist>> streamSubscribedPlaylists(String? userId) {
    return _db.collection('playlists').where('subscribers', arrayContains: userId).orderBy('last_modified', descending: true).snapshots().map((qs) {
      print('Playlist Docs: ${qs.docs}');
      return qs.docs.map((doc) {
        print('Playlist item: ${doc.data()}');
        Playlist playlist = Playlist.fromFirestore(doc);
        print('Playlist: $playlist');
        return playlist;
      }).toList();
    });
  }

  Stream<List<FeaturedPlaylistCategory>> streamFeaturedPlaylists() {
    return _db.collection('featured-playlists').orderBy('rank').snapshots().map((qs) {
      return qs.docs.map((doc) {
        print('Featured Playlist Doc: $doc');
        return FeaturedPlaylistCategory.fromFirestore(doc);
      }).toList();
    });
  }

  Future<void> updateTimeline({String? timelineId, PerklUser? user, DateTime? minDate, bool? reload, bool setLoading = true}) async {
    DocumentReference timelineRef = _db.collection('timelines').doc(timelineId);
    DateTime? lastUpdateTime = await timelineRef.get().then((snap) => snap.data()?['last_updated'] == null ? null : DateTime.fromMillisecondsSinceEpoch(snap.data()?['last_updated'].millisecondsSinceEpoch));
    //print('Time since last update ($lastUpdateTime to ${DateTime.now()}): ${DateTime.now().difference(lastUpdateTime).inSeconds}');
    if(lastUpdateTime == null || (lastUpdateTime != null && DateTime.now().difference(lastUpdateTime).inSeconds > 90) || minDate != null) {
      if(setLoading){
        await _db.runTransaction((transaction) {
          transaction.update(timelineRef, {'is_loading': true});
          return Future.value();
        });
      }
      if(user != null) {
        await _db.runTransaction((transaction) {
          transaction.update(timelineRef, {'last_updated': DateTime.now(), 'podcasts_included': user.followedPodcasts, 'last_min_date': minDate, 'reload': reload});
          return Future.value();
        });
      } else {
        await _db.runTransaction((transaction) {
          transaction.update(timelineRef, {'last_updated': DateTime.now(), 'last_min_date': minDate, 'reload': reload});
          return Future.value();
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
          return Future.value();
        });
      }
      print('Response: $resp');
    }
  }

  Stream<bool> streamTimelineLoading(String? timelineId) {
    print('timeline id: $timelineId');
    if(timelineId == null) {
      return Stream.value(false).asBroadcastStream();
    }
    return _db.collection('timelines').doc(timelineId).snapshots().map((snap) {
      return snap.data()?['is_loading'] ?? false;
    });
  }

  Future<PerklUser> getPerklUser(String? uid) async {
    return await _db.collection('users').doc(uid).get().then((snap) => PerklUser.fromFirestore(snap));
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

  void markConversationRead(String conversationId, String? userId) async {
    DocumentReference conversationRef = _db.collection('conversations').doc(conversationId);
    Conversation convo = await conversationRef.get().then((doc) => Conversation.fromFirestore(doc));
    print('Members before: ${convo.conversationMembers}');
    if(convo.conversationMembers != null && (convo.conversationMembers?.containsKey(userId) ?? false)) {
      print('setting user unread to 0');
      Map userMap = convo.conversationMembers?[userId];
      userMap['unreadPosts'] = 0;
      if(userId != null) convo.conversationMembers?[userId] = userMap;
    }
    print('Members after: ${convo.conversationMembers}');
    await _db.runTransaction((transaction) {
      transaction.update(conversationRef, {'conversationMembers': convo.conversationMembers});
      return Future.value();
    });
  }

  Future<void> sendFeedback(int? rating, String? positive, String? negative, PerklUser? user) async {
    DocumentReference feedbackRef = _db.collection('feedback').doc('initial-testing').collection('responses').doc(user?.uid);
    await _db.runTransaction((trans) {
      trans.set(feedbackRef, {
        'userId': user?.uid,
        'rating': rating,
        'positive': positive,
        'negative': negative,
        'datesent': DateTime.now(),
      });
      return Future.value();
    });
    return;
  }

  Future<void> postEpisodeReply({Episode? episode, Podcast? podcast, String? filePath, Duration? replyLength, DateTime? replyDate, PerklUser? user, String? replyTitle}) async {
    String? episodeId = episode?.guid != null ? episode?.guid : episode?.link;
    String? fileUrlString;
    if(user == null) {
      return;
    }

    //upload file to firebase storage
    if(filePath != null) {
      //Get audio file
      File audioFile = File(filePath);
      String dateString = DateFormat("yyyy-MM-dd_HH_mm_ss").format(replyDate ?? DateTime(1900, 1, 1)).toString();
      Reference? storageRef;
      if(user.uid != null) {
        storageRef = FirebaseStorage.instance.ref().child(user.uid ?? '').child('episode-replies').child('$episodeId-$dateString');
      }
      final UploadTask? uploadTask = storageRef?.putFile(audioFile);
      await uploadTask?.whenComplete(() => null);
      String? _fileUrl = await storageRef?.getDownloadURL();//await (await uploadTask.onComplete).ref.getDownloadURL();
      fileUrlString = _fileUrl.toString();
    }

    //add document to "episode-replies" collection, key on episode ID (guid/link)
    DocumentReference replyRef = _db.collection('episode-replies').doc();

    await _db.runTransaction((transaction) {
      transaction.set(replyRef, {
        'id': replyRef.id,
        'unique_id': episodeId,
        'podcast_name': podcast?.title,
        'episode_name': episode?.title,
        'episode_date': episode?.publicationDate,
        'posting_username': user.username,
        'posting_uid': user.uid,
        'reply_title': replyTitle,
        'reply_date': replyDate,
        'reply_ms': replyLength?.inMilliseconds,
        'audioFileLocation': fileUrlString,
      });
      return Future.value();
    });

    //Make sure to update username change function to also update replies
  }

  Future<List<String>> getHeardPostIds({String? conversationId, String? userId}) async {
    return await _db.collection('conversations').doc(conversationId).collection('heard-posts').doc(userId).get().then((DocumentSnapshot docSnap) {
      if(!docSnap.exists) {
        return Future.value();
      }
      List<String> idList = <String>[];
      idList.addAll(docSnap.data()?['id_list'].cast<String>());
      return idList;
    });
  }

  markDirectPostHeard({String? conversationId, String? userId, String? postId}) async {
    print('marking direct post heard');
    DocumentReference docRef = _db.collection('conversations').doc(conversationId).collection('heard-posts').doc(userId);
    List<String> idList = <String>[];
    bool docExists = false;
    print('Heard Posts doc: $docRef');
    await docRef.get().then((docSnap) {
      print('heard posts doc data: ${docSnap.data()}');
      if(docSnap.exists) {
        docExists = true;
        idList.addAll(docSnap.data()?['id_list'].cast<String>());
      }
    });
    if(postId != null) {
      idList.add(postId);
    }

    await _db.runTransaction((transaction) {
      if(docExists) {
        transaction.update(docRef, {
          'id_list': idList,
        });
      } else {
        transaction.set(docRef, {'id_list': idList});
      }
      return Future.value();
    });
  }

  Future<void> syncConversationPostsHeard() async {
    Map<String, dynamic> heardPostMap = await LocalService(filename: 'conversations.json').getData('conversation-heard-posts');
    String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
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
        List<String>? fbPostsHeard = await docRef.get().then((snap) => snap.data()?['id_list'].cast<String>() ?? null);
        if(fbPostsHeard == null) {
          //set posts heard for this conversation to the local list
          print('setting new list of posts heard to local list');
          _db.runTransaction((transaction) {
            transaction.set(docRef, {'id_list': localPostsHeard});
            return Future.value();
          });
          return Future.value();
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

  Future<List<DirectPost>> getDirectPosts(String? conversationId) {
    return _db.collection('directposts').where('conversationId', isEqualTo: conversationId).orderBy('datePosted', descending: true).get().then((QuerySnapshot qs) {
      if(qs.docs.length > 0) {
        return qs.docs.map((docSnap) => DirectPost.fromFirestore(docSnap)).toList();
      }
      return Future.value();
    });
  }

  //Share podcast episodes in conversations
  Future<void> shareEpisodeToDiscussion({Episode? episode, Podcast? podcast, PerklUser? sender, bool? sendAsGroup, Map<String, dynamic>? sendToUsers, Map<String, dynamic>? addToConversations}) async {
    if(sendToUsers != null){
      if(sendToUsers.length > 0) {
        //Iterate over users to send to and send direct post for each w/
        // memberMap of currentUser and send to user
        sendToUsers.forEach((key, value) async {
          Map<String?, dynamic> _memberMap = new Map<String, dynamic>();
          _memberMap.addAll({sender?.uid: sender?.username});
          String _thisUsername = await _db.collection('users').doc(key).get().then((doc) {
            return doc.data()?['username'];
          });
          _memberMap.addAll({key: _thisUsername});
          //send direct post to this user
          await shareDirectPost(episode, podcast, sender, memberMap: _memberMap);
        });
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

  Future<void> shareDirectPost(Episode? episode, Podcast? podcast, PerklUser? sender, {String? conversationId, Map<dynamic, dynamic>? memberMap}) async {
    DocumentReference conversationRef;
    DocumentReference postRef = _db.collection('directposts').doc();
    String? convoId = conversationId;
    WriteBatch batch = _db.batch();
    print('Member Map passed in: $memberMap');
    if(podcast?.episodes == null) {
      podcast = await Podcast.loadFeed(url: podcast?.url);
    }
    //Check if conversation with these members exists
    List<String> _memberList = <String>[];
    if(memberMap != null) {
      _memberList.addAll(memberMap.keys.cast<String>());
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
      Map<String, dynamic>? postMap;
      Map<String, dynamic>? conversationMembers;
      await conversationRef.get().then((DocumentSnapshot snapshot) {
        postMap = Map<String, dynamic>.from(snapshot.data()?['postMap']);
        conversationMembers = Map<String, dynamic>.from(snapshot.data()?['conversationMembers']);
      });

      //-increment unread posts for all users other than posting user
      //print('Members: $conversationMembers');
      Map<String, dynamic> newMemberMap = new Map<String, dynamic>();
      conversationMembers?.forEach((uid, details) {
        Map<dynamic, dynamic> newDetails = details;
        if(uid != sender?.uid) {
          int unheardCnt = details['unreadPosts'];
          if(unheardCnt != null)
            unheardCnt = unheardCnt + 1;
          newDetails['unreadPosts'] = unheardCnt;
        }
        newMemberMap[uid] = newDetails;
      });

      postMap?.addAll({postRef.id: sender?.uid});
      //update conversation document
      batch.update(conversationRef, {'postMap': postMap, 'lastDate': DateTime.now(), 'lastPostUsername': sender?.username, 'lastPostUserId': sender?.uid, 'conversationMembers': newMemberMap});
    } else {
      //Create new conversation document and update data
      conversationRef = _db.collection('/conversations').doc();
      convoId = conversationRef.id;
      //print('creating new conversation: $conversationId');
      Map<String, dynamic> conversationMembers = new Map<String, dynamic>();
      memberMap?.forEach((uid, username) {
        if(uid == sender?.uid)
          conversationMembers.addAll({uid: {'username': username, 'unreadPosts': 0}});
        else
          conversationMembers.addAll({uid: {'username': username, 'unreadPosts': 1}});
      });
      Map<String, dynamic> postMap = {postRef.id: sender?.uid};
      print('member list: $_memberList/Conversation Members: $conversationMembers');

      batch.set(conversationRef, {'conversationMembers': conversationMembers, 'postMap': postMap, 'memberList': _memberList, 'lastDate': DateTime.now(), 'lastPostUsername': sender?.username, 'lastPostUserId': sender?.uid});
    }

    //Add data to new direct post document (message title, contentUrl, length (ms), date, sender, conversationId, shared, podcast and episode info)
    Map<String, dynamic> newPostData = {
      'senderUID': sender?.uid,
      'senderUsername': sender?.username,
      'author': podcast?.title,
      'podcast-link': podcast?.link,
      'podcast-url': podcast?.url,
      'podcast-title': podcast?.title,
      'podcast-image': podcast?.image,
      'episode-guid': episode?.guid,
      'episode-description': episode?.description,
      'episode-link': episode?.link,
      'messageTitle': episode?.title,
      'ms-length': episode?.duration?.inMilliseconds,
      'audioFileLocation': episode?.contentUrl,
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

  Future<void> saveEpisodeClip({PerklUser? creator, Duration? startDuration, Duration? endDuration, String? clipTitle, bool? public, String? podcastTitle, String? podcastUrl, String? podcastImage, Episode? episode}) async {
    DocumentReference clipRef = _db.collection('episode-clips').doc();
    await _db.runTransaction((transaction) async {
      return transaction.set(clipRef, {
        'created_date': DateTime.now(),
        'creator_username': creator?.username,
        'creator_uid': creator?.uid,
        'clip_title': clipTitle,
        'start_ms': startDuration?.inMilliseconds,
        'end_ms': endDuration?.inMilliseconds,
        'public': public,
        'podcast_title': podcastTitle,
        'podcast_url': podcastUrl,
        'podcast_image': podcastImage,
        'episode': episode?.toJson(),
      });
    });
  }

  Future<void> sendEpisodeClipToConversation({PerklUser? sender, Duration? startDuration, Duration? endDuration, String? clipTitle, bool? public, String? podcastTitle, String? podcastUrl, String? podcastImage, Episode? episode, String? conversationId, Map<dynamic, dynamic>? memberMap}) async {
    DocumentReference conversationRef;
    DocumentReference postRef = _db.collection('directposts').doc();
    String? convoId = conversationId;
    WriteBatch batch = _db.batch();
    //check if conversation exists with these users
    List<String> _memberList = <String>[];
    if(memberMap != null) {
      _memberList.addAll(memberMap.keys.cast<String>());
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

    if(convoId != null) {
      print('Conversation exists: $convoId');
      conversationRef = _db.collection('conversations').doc(convoId);
      //Get post map and conversationMembers
      Map<String, dynamic>? postMap;
      Map<String, dynamic>? conversationMembers;
      await conversationRef.get().then((DocumentSnapshot snapshot) {
        postMap = Map<String, dynamic>.from(snapshot.data()?['postMap']);
        conversationMembers = Map<String, dynamic>.from(snapshot.data()?['conversationMembers']);
      });

      //-increment unread posts for all users other than posting user
      //print('Members: $conversationMembers');
      Map<String, dynamic> newMemberMap = new Map<String, dynamic>();
      conversationMembers?.forEach((uid, details) {
        Map<dynamic, dynamic> newDetails = details;
        if(uid != sender?.uid) {
          int unheardCnt = details['unreadPosts'];
          if(unheardCnt != null)
            unheardCnt = unheardCnt + 1;
          newDetails['unreadPosts'] = unheardCnt;
        }
        newMemberMap[uid] = newDetails;
      });

      postMap?.addAll({postRef.id: sender?.uid});
      //update conversation document
      batch.update(conversationRef, {'postMap': postMap, 'lastDate': DateTime.now(), 'lastPostUsername': sender?.username, 'lastPostUserId': sender?.uid, 'conversationMembers': newMemberMap});
    } else {
      //Create new conversation document and update data
      conversationRef = _db.collection('/conversations').doc();
      convoId = conversationRef.id;
      //print('creating new conversation: $conversationId');
      Map<String, dynamic> conversationMembers = new Map<String, dynamic>();
      memberMap?.forEach((uid, username) {
        if(uid == sender?.uid)
          conversationMembers.addAll({uid: {'username': username, 'unreadPosts': 0}});
        else
          conversationMembers.addAll({uid: {'username': username, 'unreadPosts': 1}});
      });
      Map<String, dynamic> postMap = {postRef.id: sender?.uid};
      print('member list: $_memberList/Conversation Members: $conversationMembers');

      batch.set(conversationRef, {'conversationMembers': conversationMembers, 'postMap': postMap, 'memberList': _memberList, 'lastDate': DateTime.now(), 'lastPostUsername': sender?.username, 'lastPostUserId': sender?.uid});
    }

    //Add data to new direct post document (message title, contentUrl, length (ms), date, sender, conversationId, shared, podcast and episode info)
    Map<String, dynamic> newPostData = {
      'senderUID': sender?.uid,
      'senderUsername': sender?.username,
      'author': podcastTitle,
      'podcast-link': podcastUrl,
      'podcast-url': podcastUrl,
      'podcast-title': podcastTitle,
      'podcast-image': podcastImage,
      'episode': episode?.toJson(),
      'episode-guid': episode?.guid,
      'episode-description': episode?.description,
      'episode-link': episode?.link,
      'messageTitle': clipTitle ?? episode?.title,
      'ms-length': (endDuration?.inMilliseconds ?? 1000) - (startDuration?.inMilliseconds ?? 0),
      'audioFileLocation': episode?.contentUrl,
      'conversationId': convoId,
      'datePosted': DateTime.now(),
      'shared': true,
      'clip': true,
      'start-ms': startDuration?.inMilliseconds,
      'end-ms': endDuration?.inMilliseconds,
    };

    batch.set(postRef, newPostData);

    await batch.commit().catchError(((error) {
      print('Error committing batch: $error');
    }));
  }

  Future<Conversation> createNewGroup(String? groupName, List<String> memberIds) async {
    DocumentReference conversationRef = _db.collection('/conversations').doc();
    String convoId = conversationRef.id;
    print('creating new conversation: $convoId');
    List<PerklUser> members = <PerklUser>[];
    for(String id in memberIds) {
      members.add(await getPerklUser(id));
    }
    Map<String, dynamic> conversationMembers = new Map<String, dynamic>();
    members.forEach((dynamic member) {
      conversationMembers.addAll({member.uid: {'username': member.username, 'unreadPosts': 0}});
    });
    Map<String, dynamic> postMap = Map<String, dynamic>();
    await _db.runTransaction((transaction) async {
      return transaction.set(conversationRef, {
        'name': groupName,
        'conversationMembers': conversationMembers,
        'postMap': postMap,
        'memberList': members.map((user) => user.uid).toList(),
        'lastDate': DateTime.now(),
      });
    });
    return await conversationRef.get().then((ds) => Conversation.fromFirestore(ds));
  }

  //Delete a regular post document (does not delete the audio file)
  Future<void> deletePost(Post post) async {
    print('deleting post: ${post.id}');
    await _db.collection('posts').doc(post.id).delete();
    return;
  }

  Future<void> followPodcast({PerklUser? user, String? podcastUrl}) async {
    List<String>? newList = <String>[];
    if(user != null && user.followedPodcasts != null) {
      newList.addAll(user.followedPodcasts ?? []);
    }
    if(podcastUrl != null) {
      newList.add(podcastUrl);
    }
    DocumentReference userRef = _db.collection('users').doc(user?.uid);
    await _db.runTransaction((transaction) {
      transaction.update(userRef, {'followedPodcasts': newList});
      return Future.value();
    });
  }

  Future<void> unfollowPodcast({PerklUser? user, String? podcastUrl}) async {
    List<String>? newList = <String>[];
    if(user != null && user.followedPodcasts != null) {
      newList.addAll(user.followedPodcasts ?? []);
      newList.removeWhere((item) => item == podcastUrl);
    }

    DocumentReference userRef = _db.collection('users').doc(user?.uid);
    await _db.runTransaction((transaction) {
      transaction.update(userRef, {'followedPodcasts': newList});
      return Future.value();
    });
  }

  Future<Playlist> getPlaylist(String id) async {
    return await _db.collection('playlists').doc(id).get().then((snap) => Playlist.fromFirestore(snap));
  }

  //Create Playlist
  Future<void> createPlaylist({String? title, String? genre, String? tags, bool? private}) async {
    //Get current user id and username
    String? currentUid = FirebaseAuth.instance.currentUser?.uid;
    String? username = await _db.collection('users').doc(currentUid).get().then((snap) => snap.data()?['username']);
    //Parse tag string into a list split by # (remove spaces and other special characters)
    RegExp tagChars = RegExp('[#0-9A-Za-z]*');
    String? tagString = tagChars.allMatches(tags ?? '').map((match) => match[0]).join();
    //print('tagString: $tagString');
    List<String> tagList = tagString.split('#').toList().where((element) => element.length > 0).toList();
    Map<String, dynamic> playlistData = {
      'creator_uid': currentUid,
      'creator_username': username,
      'created_datetime': DateTime.now(),
      'last_modified': DateTime.now(),
      'title': title,
      'genre': genre,
      'private': private,
      'tags': tagList,
    };
    print('New playlist data: $playlistData');
    await _db.runTransaction((Transaction t) async {
      //create new playlist doc and upload new playlist data
      DocumentReference newPlaylistRef = _db.collection('playlists').doc();
      t.set(newPlaylistRef, playlistData);
    });
  }

  Future<void> editPlaylist(Playlist? playlist) async {
    await _db.runTransaction((Transaction t) async {
      DocumentReference ref = _db.collection('playlists').doc(playlist?.id);
      t.update(ref, {
        'genre': playlist?.genre,
        'title': playlist?.title,
        'private': playlist?.private,
        'tags': playlist?.tagList
      });
    });
  }

  Future<void> deletePlaylist(String? playlistId) async {
    await _db.runTransaction((Transaction t) async {
      DocumentReference ref = _db.collection('playlists').doc(playlistId);
      t.delete(ref);
    });
  }

  //Add Item to Playlist
  Future<void>? addItemToPlaylist({MediaItem? item, List<String>? playlists}) async {
    Map<String, dynamic> data = Helper().mediaItemToJson(item);
    print('New Item Data: $data');
    data['date_added'] = DateTime.now();
    WriteBatch batch = _db.batch();
    for(String p in (playlists ?? [])) {
      DocumentReference playlistDoc = _db.collection('playlists').doc(p);
      int currentItems = await playlistDoc.get().then((snap) => snap.data()?['num_items'] ?? 0);
      DocumentReference newItem = _db.collection('playlists').doc(p).collection('items').doc();
      data['document_id'] = newItem.id;
      batch.set(newItem, data);
      batch.update(playlistDoc, {'last_modified': DateTime.now(), 'num_items': currentItems + 1});
    }
    await batch.commit();
  }

  //Remove item from playlist
  Future<void>? removeFromPlaylist(String? documentId, String? playlistId) async {
    WriteBatch batch = _db.batch();
    DocumentReference playlistDoc = _db.collection('playlists').doc(playlistId);
    DocumentReference itemDoc = playlistDoc.collection('items').doc(documentId);
    int currentItems = await playlistDoc.get().then((snap) => snap.data()?['num_items'] ?? 0);
    batch.update(playlistDoc, {'last_modified': DateTime.now(), 'num_items': currentItems + 1});
    print('Remove item from playlist: ${itemDoc.id}');
    batch.delete(itemDoc);
    await batch.commit();
  }

  //Subscribe to playlist
  Future<void>? subscribeToPlaylist(String? userId, String? playlistId) async {
    DocumentReference playlistDoc = _db.collection('playlists').doc(playlistId);
    Playlist playlist = await playlistDoc.get().then((snap) => Playlist.fromFirestore(snap));
    List<String?> subscribers = playlist.subscribers ?? [];
    if(!subscribers.contains(userId)) {
      subscribers.add(userId);
    }
    await _db.runTransaction((t) async {
      t.update(playlistDoc, {'subscribers': subscribers, 'num_subscribers': subscribers.length});
    });
  }

  //Unsubscribe to playlist
  Future<void>? unsubscribeToPlaylist(String? userId, String? playlistId) async {
    DocumentReference playlistDoc = _db.collection('playlists').doc(playlistId);
    Playlist playlist = await playlistDoc.get().then((snap) => Playlist.fromFirestore(snap));
    List<String?> subscribers = playlist.subscribers ?? [];
    if(subscribers.contains(userId)) {
      subscribers.remove(userId);
    }
    await _db.runTransaction((t) async {
      t.update(playlistDoc, {'subscribers': subscribers, 'num_subscribers': subscribers.length});
    });
  }
}
