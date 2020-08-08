import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:podcast_search/podcast_search.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'models.dart';

class DBService {
  Firestore _db = Firestore.instance;

  Future<int> getConfigMinBuildNumber() async {
    int buildNumber = await _db.collection('config').document('config').get().then((snap) {
      return snap.data[Platform.isAndroid ? 'minimum_android_version' : 'minimum_ios_version'];
    }).catchError((e) {
      print('error: $e');
    });
    return buildNumber;
  }

  Future<List<DiscoverTag>> getDiscoverTags() async {
    return await _db.collection('discover').where('type', isEqualTo: 'StreamTag').orderBy('rank').getDocuments().then((QuerySnapshot qs) {
      return qs.documents.map((doc) => DiscoverTag.fromFirestore(doc)).toList();
    });
  }

  Stream<List<String>> streamDiscoverPods() {
    return _db.collection('requests').document('discover').snapshots().map((doc) {
      return doc.data['results'].map<String>((value) => value.toString()).toList();
    });
  }

  Stream<List<Conversation>> streamConversations(String userId) {
    return _db.collection('conversations').where('memberList', arrayContains: userId).orderBy('lastDate', descending: true).snapshots().map((qs) {
      return qs.documents.map((doc) => Conversation.fromFirestore(doc)).toList();
    });
  }
  
  Stream<List<DirectPost>> streamDirectPosts(String conversationId) {
    return _db.collection('directposts').where('conversationId', isEqualTo: conversationId).orderBy('datePosted', descending: true).snapshots().map((qs) {
      return qs.documents.map((doc) => DirectPost.fromFirestore(doc)).toList();
    });
  }

  Stream<List<Post>> streamTagPosts(String streamTag) {
    return _db.collection('posts').where('streamList', arrayContains: streamTag).orderBy('datePosted', descending: true).snapshots().map((qs) {
      return qs.documents.map((doc) => Post.fromFirestore(doc)).toList();
    });
  }

  Stream<List<Post>> streamTimelinePosts(FirebaseUser currentUser, {String timelineId, String streamTag, String userId}) {
    print('TimelineId: $timelineId ---- StreamTag: $streamTag ---- UserId: $userId');
    if(streamTag != null) {
      return _db.collection('posts').where('streamList', arrayContains: streamTag).orderBy('datePosted', descending: true).snapshots().map((qs) {
        return qs.documents.map((doc) => Post.fromFirestore(doc)).toList();
      });
    }
    if(timelineId != null) {
      return _db.collection('posts').where('timelines', arrayContains: timelineId).orderBy("datePosted", descending: true).snapshots().map((qs) {
        return qs.documents.map((doc) => Post.fromFirestore(doc)).toList();
      });
    }
    if(userId != null) {
      return _db.collection('posts').where('userUID', isEqualTo: userId).orderBy("datePosted", descending: true).snapshots().map((qs) {
        return qs.documents.map((doc) => Post.fromFirestore(doc)).toList();
      });
    }
    return _db.collection('posts').where('userUID', isEqualTo: currentUser.uid).orderBy("datePosted", descending: true).snapshots().map((qs) {
      return qs.documents.map((doc) => Post.fromFirestore(doc)).toList();
    });
  }

  Stream<List<EpisodeReply>> streamEpisodeReplies(String uniqueId) {
    print('Unique ID: $uniqueId');
    return _db.collection('episode-replies').where("unique_id", isEqualTo: uniqueId).orderBy("reply_date", descending: true).snapshots().map((qs) {
      print('Number of Replies: ${qs.documents.length}');
      return qs.documents.map((doc) => EpisodeReply.fromFirestore(doc)).toList();
    });
  }

  Future<void> updateDeviceToken(String userToken, String uid) async {
    var tokens = _db
        .collection('users')
        .document(uid)
        .collection('tokens')
        .document(userToken);

    await tokens.setData({
      'token': userToken,
      'createdAt': FieldValue.serverTimestamp(), // optional
      'platform': Platform.operatingSystem // optional
    });
  }

  void markConversationRead(String conversationId, String userId) async {
    DocumentReference conversationRef = _db.collection('conversations').document(conversationId);
    Conversation convo = await conversationRef.get().then((doc) => Conversation.fromFirestore(doc));
    print('Members before: ${convo.conversationMembers}');
    if(convo.conversationMembers != null && convo.conversationMembers.containsKey(userId)) {
      print('setting user unread to 0');
      Map userMap = convo.conversationMembers[userId];
      userMap['unreadPosts'] = 0;
      convo.conversationMembers[userId] = userMap;
    }
    print('Members after: ${convo.conversationMembers}');
    await _db.runTransaction((transaction) => transaction.update(conversationRef, {'conversationMembers': convo.conversationMembers}));
  }

  Future<void> sendFeedback(int rating, String positive, String negative, User user) async {
    DocumentReference feedbackRef = _db.collection('feedback').document('initial-testing').collection('responses').document(user.uid);
    await _db.runTransaction((trans) => trans.set(feedbackRef, {
      'userId': user.uid,
      'rating': rating,
      'positive': positive,
      'negative': negative,
      'datesent': DateTime.now(),
    }));
    return;
  }

  Future<void> postEpisodeReply({Episode episode, Podcast podcast, String filePath, Duration replyLength, DateTime replyDate, User user, String replyTitle}) async {
    String episodeId = episode.guid != null ? episode.guid : episode.link;
    String fileUrlString;

    //upload file to firebase storage
    if(filePath != null) {
      //Get audio file
      File audioFile = File(filePath);
      String dateString = DateFormat("yyyy-MM-dd_HH_mm_ss").format(replyDate).toString();
      final StorageReference storageRef = FirebaseStorage.instance.ref().child(user.uid).child('episode-replies').child('$episodeId-$dateString');
      final StorageUploadTask uploadTask = storageRef.putFile(audioFile);
      String _fileUrl = await (await uploadTask.onComplete).ref.getDownloadURL();
      fileUrlString = _fileUrl.toString();
    }

    //add document to "episode-replies" collection, key on episode ID (guid/link)
    DocumentReference replyRef = _db.collection('episode-replies').document();

    await _db.runTransaction((transaction) async {
      await transaction.set(replyRef, {
        'id': replyRef.documentID,
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
    });

    //Make sure to update username change function to also update replies
  }
}