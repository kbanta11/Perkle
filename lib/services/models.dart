import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:podcast_search/podcast_search.dart';
import 'package:audio_service/audio_service.dart';
import 'Helper.dart';

class PerklUser {
  String? uid;
  String? email;
  String? bio;
  String? username;
  List<String>? followers;
  List<String>? following;
  String? profilePicUrl;
  String? mainFeedTimelineId;
  List<String>? followedPodcasts;
  List<String>? timelinesIncluded;
  Map<String, dynamic>? directConversationMap;
  List<String>? posts;
  List<Podcast>? podcastList;

  PerklUser({
    this.uid,
    this.email,
    this.bio,
    this.username,
    this.followers,
    this.following,
    this.profilePicUrl,
    this.mainFeedTimelineId,
    this.timelinesIncluded,
    this.directConversationMap,
    this.posts,
    this.followedPodcasts,
  });

  factory PerklUser.fromFirestore(DocumentSnapshot snapshot) {
    Map? data = snapshot.data();
    PerklUser newUser = new PerklUser(
      uid: snapshot.reference.id,
      email: data?['email'],
      bio: data?['bio'],
      username: data?['username'],
      followers: data?['followers'] == null ? null : data?['followers'].entries.map<String>((entry) {
        String userId = entry.key;
        return userId;
      }).toList(),
      following: data?['following'] == null ? null : data?['following'].entries.map<String>((entry) {
        String userId = entry.key;
        return userId;
      }).toList(),
      profilePicUrl: data?['profilePicUrl'],
      mainFeedTimelineId: data?['mainFeedTimelineId'],
      followedPodcasts: data?['followedPodcasts'] == null ? null : data?['followedPodcasts'].map<String>((entry) {
        String podcastUrl = entry;
        return podcastUrl.replaceFirst('http:', 'https:');
      }).toList(),
      timelinesIncluded: data?['timelinesIncluded'] == null ? null : snapshot.data()?['timelinesIncluded'].entries.map<String>((entry) {
        //print('timelines');
        String timelineId = entry.key;
        return timelineId;
      }).toList(),
      directConversationMap: data?['directConversationMap'] == null ? null : Map.from(data?['directConversationMap']),
      posts: data?['posts'] == null ? null : data?['posts'].entries.map<String>((entry) {
        String postId = entry.key;
        return postId;
      }).toList(),
    );
    return newUser;
  }
}

class CurrentUser {
  PerklUser? user;
  bool isLoaded = true;

  CurrentUser({this.user, this.isLoaded = true});
}

class DiscoverTag {
  String? value;
  int? rank;
  String? type;

  DiscoverTag({this.value, this.rank, this.type});

  factory DiscoverTag.fromFirestore(DocumentSnapshot snap) {
    return DiscoverTag(
      value: snap.data()?['value'],
      rank: snap.data()?['rank'],
      type: snap.data()?['type'],
    );
  }
}

class Conversation {
  String? id;
  String? name;
  List<String>? memberList;
  DateTime? lastDate;
  String? lastPostUsername;
  String? lastPostUserId;
  Map<String, dynamic>? conversationMembers;
  Map<String, dynamic>? postMap;

  Conversation({
    this.id,
    this.name,
    this.memberList,
    this.lastDate,
    this.lastPostUsername,
    this.lastPostUserId,
    this.conversationMembers,
    this.postMap,
  });

  factory Conversation.fromFirestore(DocumentSnapshot snapshot) {
    return Conversation(
      id: snapshot.reference.id,
      name: snapshot.data()?['name'],
      memberList: snapshot.data()?['memberList'] == null ? null : snapshot.data()?['memberList'].map<String>((value) => value.toString()).toList(),
      lastDate: snapshot.data()?['lastDate'] == null ? null : DateTime.fromMillisecondsSinceEpoch(snapshot.data()?['lastDate'].millisecondsSinceEpoch),
      lastPostUsername: snapshot.data()?['lastPostUsername'],
      lastPostUserId: snapshot.data()?['lastPostUserId'],
      conversationMembers: snapshot.data()?['conversationMembers'] == null ? null : Map<String, dynamic>.from(snapshot.data()?['conversationMembers']),
      postMap: snapshot.data()?['postMap'] == null ? null : Map<String, dynamic>.from(snapshot.data()?['postMap']),
    );
  }

  String getTitle(PerklUser? user) {
    String titleText = '';
    //Map<dynamic, dynamic> memberDetails = this.conversationMembers;
    if(this.conversationMembers != null){
      this.conversationMembers?.forEach((key, value) {
        if(key != user?.uid) {
          if(titleText.length > 0)
            titleText = titleText + ', ' + value['username'];
          else
            titleText = value['username'];
        }
      });
    }

    if(this.name != null) {
      titleText = this.name ?? '';
    }

    if(titleText.length > 50){
      titleText = titleText.substring(0,47) + '...';
    }
    return titleText;
  }
}

class DirectPost {
  String? id;
  String? conversationId;
  String? senderUID;
  String? senderUsername;
  String? audioFileLocation;
  DateTime? datePosted;
  String? messageTitle;
  int? secondsLength;
  int? msLength;
  String? author;
  String? podcastLink;
  String? podcastUrl;
  String? podcastTitle;
  String? podcastImage;
  String? episodeGuid;
  String? episodeDescription;
  String? episodeLink;
  bool? shared;
  bool? clip;
  Duration? startDuration;
  Duration? endDuration;
  Episode? episode;

  DirectPost({
    this.id,
    this.conversationId,
    this.senderUID,
    this.senderUsername,
    this.audioFileLocation,
    this.datePosted,
    this.messageTitle,
    this.secondsLength,
    this.author,
    this.podcastLink,
    this.podcastUrl,
    this.podcastTitle,
    this.episodeDescription,
    this.episodeGuid,
    this.episodeLink,
    this.episode,
    this.msLength,
    this.shared,
    this.clip,
    this.startDuration,
    this.endDuration,
    this.podcastImage,
  });

  factory DirectPost.fromFirestore(DocumentSnapshot? snap) {
    if(snap?.data()?['episode'] != null) {
      return DirectPost(
        id: snap?.reference.id,
        conversationId: snap?.data()?['conversationId'],
        senderUID: snap?.data()?['senderUID'],
        senderUsername: snap?.data()?['senderUsername'],
        audioFileLocation: snap?.data()?['audioFileLocation'],
        datePosted: DateTime.fromMillisecondsSinceEpoch(snap?.data()?['datePosted'].millisecondsSinceEpoch),
        messageTitle: snap?.data()?['messageTitle'],
        secondsLength: snap?.data()?['secondsLength'],
        author: snap?.data()?['author'],
        podcastLink: snap?.data()?['podcast-link'],
        podcastUrl: snap?.data()?['podcast-url'],
        podcastTitle: snap?.data()?['podcast-title'],
        podcastImage: snap?.data()?['podcast-image'],
        episodeGuid: snap?.data()?['episode-guid'],
        episodeLink: snap?.data()?['episode-link'],
        episodeDescription: snap?.data()?['episode-description'],
        msLength: snap?.data()?['ms-length'],
        shared: snap?.data()?['shared'],
        clip: snap?.data()?['clip'],
        startDuration: snap?.data()?['start-ms'] != null ? Duration(milliseconds: snap?.data()?['start-ms']) : null,
        endDuration: snap?.data()?['end-ms'] != null ? Duration(milliseconds: snap?.data()?['end-ms']) : null,
        episode: snap?.data()?['episode'] != null ? Episode.fromJson(snap?.data()?['episode']) : null,
      );
    }
    return DirectPost(
      id: snap?.reference.id,
      conversationId: snap?.data()?['conversationId'],
      senderUID: snap?.data()?['senderUID'],
      senderUsername: snap?.data()?['senderUsername'],
      audioFileLocation: snap?.data()?['audioFileLocation'],
      datePosted: DateTime.fromMillisecondsSinceEpoch(snap?.data()?['datePosted'].millisecondsSinceEpoch),
      messageTitle: snap?.data()?['messageTitle'],
      secondsLength: snap?.data()?['secondsLength'],
      author: snap?.data()?['author'],
      podcastLink: snap?.data()?['podcast-link'],
      podcastUrl: snap?.data()?['podcast-url'],
      podcastTitle: snap?.data()?['podcast-title'],
      podcastImage: snap?.data()?['podcast-image'],
      episodeGuid: snap?.data()?['episode-guid'],
      episodeLink: snap?.data()?['episode-link'],
      episodeDescription: snap?.data()?['episode-description'],
      msLength: snap?.data()?['ms-length'],
      shared: snap?.data()?['shared']
    );
  }

  String getLengthString() {
    String postLength = '--:--';
    if(msLength != null) {
      Duration postDuration = Duration(milliseconds: msLength ?? 0);
      if(postDuration.inHours > 0){
        postLength = '${postDuration.inHours}:${postDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${postDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
      } else {
        postLength = '${postDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${postDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
      }
    } else if(secondsLength != null) {
      Duration postDuration = Duration(seconds: secondsLength ?? 0);
      if(postDuration.inHours > 0){
        postLength = '${postDuration.inHours}:${postDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${postDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
      } else {
        postLength = '${postDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${postDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
      }
    }
    return postLength;
  }
}

class Post {
  String? id;
  String? userUID;
  String? username;
  String? postTitle;
  DateTime? datePosted;
  String? postValue;
  String? audioFileLocation;
  int? listenCount;
  int? secondsLength;
  int? msLength;
  List<String>? streamList;
  List<String>? timelines;

  Post({
    this.id,
    this.userUID,
    this.username,
    this.postTitle,
    this.datePosted,
    this.postValue,
    this.audioFileLocation,
    this.listenCount,
    this.secondsLength,
    this.streamList,
    this.timelines,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': this.id,
      'userUID': this.userUID,
      'username': this.username,
      'postTitle': this.postTitle,
      'datePosted': this.datePosted?.millisecondsSinceEpoch,
      'postValue': this.postValue,
      'audioFileLocation': this.audioFileLocation,
      'listenCount': this.listenCount,
      'secondsLength': this.secondsLength,
      'streamList': this.streamList,
      'timelines': this.timelines,
    };
  }

  factory Post.fromFirestore(DocumentSnapshot snap) {
    return Post(
      id: snap.reference.id,
      userUID: snap.data()?['userUID'],
      username: snap.data()?['username'],
      postTitle: snap.data()?['postTitle'],
      datePosted: DateTime.fromMillisecondsSinceEpoch(snap.data()?['datePosted'].millisecondsSinceEpoch),
      postValue: snap.data()?['postValue'],
      audioFileLocation: snap.data()?['audioFileLocation'],
      listenCount: snap.data()?['listenCount'],
      secondsLength: snap.data()?['secondsLength'],
      streamList: snap.data()?['streamList'] == null ? null : snap.data()?['streamList'].map<String>((item) => item.toString()).toList(),
      timelines: snap.data()?['timelines'] == null ? null : snap.data()?['timelines'].map<String>((item) => item.toString()).toList(),
    );
  }

  String getLengthString() {
    String postLength = '--:--';
    if(secondsLength != null) {
      Duration postDuration = Duration(seconds: secondsLength ?? 0);
      if(postDuration.inHours > 0){
        postLength = '${postDuration.inHours}:${postDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${postDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
      } else {
        postLength = '${postDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${postDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
      }
    }
    return postLength;
  }
}

enum PostType {
  POST,
  DIRECT_POST,
  PODCAST_EPISODE,
  EPISODE_REPLY,
  EPISODE_CLIP,
}

class PostPodItem {
  String? id;
  Duration? duration;
  PostType? type;
  String? imageUrl;
  Post? post;
  DirectPost? directPost;
  Episode? episode;
  Podcast? podcast;
  String? podcastUrl;
  EpisodeReply? episodeReply;
  EpisodeClip? episodeClip;
  String? audioUrl;
  String? displayText;

  PostPodItem({this.id, this.type, this.duration, this.imageUrl, this.post, this.directPost, this.episode, this.podcastUrl, this.audioUrl, this.displayText, this.episodeReply, this.episodeClip, this.podcast});

  Widget titleText() {
    if(type == PostType.POST) {
      return Text(post?.postTitle ?? DateFormat("MMMM dd, yyyy").format(post?.datePosted ?? DateTime(1900,1,1)).toString());
    }
    if(type == PostType.DIRECT_POST) {
      return directPost?.podcastTitle != null ? Text('${directPost?.podcastTitle} | ${directPost?.messageTitle}') : directPost?.messageTitle != null ? Text('${directPost?.messageTitle}') : directPost?.datePosted != null ? Text(DateFormat('MMMM dd, yyyy h:mm a').format(directPost?.datePosted ?? DateTime(1900,1,1))) : Container();
    }
    if(type == PostType.PODCAST_EPISODE) {
      return Text(episode?.title ?? '');
    }
    if(type == PostType.EPISODE_REPLY) {
      return Text(episodeReply?.replyTitle ?? DateFormat("MMMM dd, yyyy").format(episodeReply?.replyDate ?? DateTime(1900,1,1)).toString());
    }
    if(type == PostType.EPISODE_CLIP) {
      return Text(episodeClip?.clipTitle ?? episodeClip?.episode?.title ?? '');
    }
    return Text('Error Finding Title!');
  }

  Widget subtitleText() {
    if(type == PostType.POST) {
      return Text('@${post?.username}');
    }
    if(type == PostType.DIRECT_POST) {
      return Text('@${directPost?.senderUsername}');
    }
    if(type == PostType.PODCAST_EPISODE) {
      return Text(episode?.author ?? '');
    }
    if(type == PostType.EPISODE_REPLY) {
      return Text(episodeReply?.posterUsername ?? '');
    }
    if(type == PostType.EPISODE_CLIP){
      return Text('@${episodeClip?.creatorUsername}');
    }
    return Text('Error getting username!');
  }

  String titleTextString() {
    if(type == PostType.POST) {
      return post?.postTitle ?? DateFormat("MMMM dd, yyyy").format(post?.datePosted ?? DateTime(1900,1,1)).toString();
    }
    if(type == PostType.DIRECT_POST) {
      return directPost?.messageTitle != null ? '${directPost?.messageTitle}' : DateFormat('MMMM dd, yyyy h:mm a').format(directPost?.datePosted ?? DateTime(1900, 1,1));
    }
    if(type == PostType.PODCAST_EPISODE) {
      return episode?.title ?? episode?.author ?? '';
    }
    if(type == PostType.EPISODE_REPLY) {
      return episodeReply?.replyTitle ?? DateFormat("MMMM dd, yyyy").format(episodeReply?.replyDate ?? DateTime(1900, 1, 1)).toString();
    }
    if(type == PostType.EPISODE_CLIP) {
      return episodeClip?.clipTitle ?? episodeClip?.episode?.title ?? '';
    }
    return 'untitled';
  }

  String subtitleTextString() {
    if(type == PostType.POST) {
      return '@${post?.username}';
    }
    if(type == PostType.DIRECT_POST) {
      return '@${directPost?.senderUsername}';
    }
    if(type == PostType.PODCAST_EPISODE) {
      return podcast?.title ?? episode?.author ?? '';
    }
    if(type == PostType.EPISODE_REPLY) {
      return episodeReply?.posterUsername ?? '';
    }
    if(type == PostType.EPISODE_CLIP) {
      return episodeClip?.podcastTitle ?? '';
    }
    return '';
  }

  Duration? getDuration() {
    if(post != null && post?.secondsLength != null) {
      return Duration(seconds: post?.secondsLength ?? 0);
    }
    if(directPost != null && (directPost?.secondsLength != null || directPost?.msLength != null)) {
      return directPost?.msLength != null ? Duration(milliseconds: directPost?.msLength ?? 0) : Duration(seconds: directPost?.secondsLength ?? 0);
    }
    if(episode != null && episode?.duration != null) {
      return episode?.duration;
    }
    if(episodeReply != null && episodeReply?.replyDuration != null) {
      return episodeReply?.replyDuration;
    }
    return Duration(seconds: 0);
  }

  factory PostPodItem.fromPost(Post? post) {
    print('MS: ${post?.msLength}/Seconds: ${post?.secondsLength}');
    return PostPodItem(
      id: post?.id,
      type: PostType.POST,
      post: post,
      duration: post?.msLength != null ? Duration(milliseconds: post?.msLength ?? 0) : Duration(seconds: post?.secondsLength ?? 0),
      audioUrl: post?.audioFileLocation,
      displayText: '@${post?.username} | ${post?.postTitle != null ? post?.postTitle : DateFormat('MMMM dd, yyyy hh:mm').format(post?.datePosted ?? DateTime(1900, 1, 1))}'
    );
  }

  factory PostPodItem.fromDirectPost(DirectPost? post) {
    return PostPodItem(
      id: post?.id,
      type: PostType.DIRECT_POST,
      episode: post?.episode,
      podcastUrl: post?.podcastUrl,
      directPost: post,
      duration: post?.msLength != null ? Duration(milliseconds: post?.msLength ?? 0) : Duration(seconds: post?.secondsLength ?? 0),
      audioUrl: post?.audioFileLocation,
      displayText: '@${post?.senderUsername} | ${post?.messageTitle != null ? post?.messageTitle : DateFormat('MMMM dd, yyyy hh:mm').format(post?.datePosted ?? DateTime(1900,1,1))}'
    );
  }

  factory PostPodItem.fromEpisode(Episode? episode, Podcast? podcast) {
    return PostPodItem(
      id: episode?.guid != null ? episode?.guid : episode?.link,
      type: PostType.PODCAST_EPISODE,
      episode: episode,
      imageUrl: podcast?.image,
      audioUrl: episode?.contentUrl,
      duration: episode?.duration,
      displayText: '${episode?.author} | ${episode?.title}',
      podcast: podcast,
    );
  }

  factory PostPodItem.fromEpisodeReply(EpisodeReply? reply, Episode? ep, Podcast? podcast) {
    return PostPodItem(
      id: reply?.id,
      type: PostType.EPISODE_REPLY,
      episodeReply: reply,
      episode: ep,
      podcast: podcast,
      duration: reply?.replyDuration,
      audioUrl: reply?.audioFileLocation,
      displayText: '${reply?.posterUsername} | ${reply?.replyTitle != null ? reply?.replyTitle : DateFormat("MMMM dd, yyyy @HH:mm").format(reply?.replyDate ?? DateTime(1900,1,1)).toString()}'
    );
  }

  factory PostPodItem.fromEpisodeClip(EpisodeClip? clip) {
    return PostPodItem(
      id: clip?.id,
      type: PostType.EPISODE_CLIP,
      episodeClip: clip,
      imageUrl: clip?.podcastImage,
      duration: Duration(milliseconds: (clip?.endDuration?.inMilliseconds ?? 1000) - (clip?.startDuration?.inMilliseconds ?? 0)),
      audioUrl: clip?.episode?.contentUrl,
      displayText: '${clip?.clipTitle ?? clip?.episode?.title} | ${clip?.podcastTitle}'
    );
  }

  MediaItem toMediaItem({String? currentUserId}) {
    return MediaItem(
      id: this.audioUrl ?? '',
      title: this.titleTextString(),
      artist: this.subtitleTextString(),
      album: '',
      duration: this.duration,
      extras: {
        'type': this.type.toString(),
        'episode': this.episode != null ? this.episode?.toJson() : null,
        'podcast_url': this.podcast!= null ? this.podcast?.url : this.podcastUrl,
        'podcast_title': this.podcast != null ? this.podcast?.title : null,
        'podcast_image': this.imageUrl,
        'isDirect': this.type == PostType.DIRECT_POST ? true : false,
        'conversationId': this.directPost != null ? this.directPost?.conversationId : null,
        'userId': this.type == PostType.DIRECT_POST ? currentUserId : null,
        'postId': this.directPost != null ? this.directPost?.id : null,
        'post': this.post != null ? this.post?.toJson() : null,
        'clip': this.directPost != null && this.directPost?.clip != null && (this.directPost?.clip ?? false) ? this.directPost?.clip : this.episodeClip != null ? true : null,
        'clipId': this.episodeClip != null ? this.episodeClip?.id : this.directPost != null && this.directPost?.clip != null && (this.directPost?.clip ?? false) ? this.directPost?.id : null,
        'startDuration': this.episodeClip != null ? this.episodeClip?.startDuration?.inMilliseconds : this.directPost?.startDuration?.inMilliseconds,
        'endDuration': this.episodeClip != null ? this.episodeClip?.endDuration?.inMilliseconds : this.directPost?.endDuration?.inMilliseconds
      },
    );
  }
}

class EpisodeClip {
  String? id;
  String? creatorUsername;
  String? creatorUID;
  String? clipTitle;
  DateTime? createdDate;
  Duration? startDuration;
  Duration? endDuration;
  bool? public;
  String? podcastTitle;
  String? podcastUrl;
  String? podcastImage;
  Episode? episode;

  EpisodeClip({
    this.id,
    this.creatorUsername,
    this.creatorUID,
    this.clipTitle,
    this.createdDate,
    this.startDuration,
    this.endDuration,
    this.public,
    this.podcastTitle,
    this.podcastUrl,
    this.podcastImage,
    this.episode
  });

  factory EpisodeClip.fromFirestore(DocumentSnapshot snap) {
    return EpisodeClip(
      id: snap.reference.id,
      creatorUsername: snap.data()?['creator_username'],
      creatorUID: snap.data()?['creator_uid'],
      clipTitle: snap.data()?['clip_title'],
      createdDate: DateTime.fromMillisecondsSinceEpoch(snap.data()?['created_date'].millisecondsSinceEpoch),
      startDuration: Duration(milliseconds: snap.data()?['start_ms']),
      endDuration: Duration(milliseconds: snap.data()?['end_ms']),
      public: snap.data()?['public'],
      podcastTitle: snap.data()?['podcast_title'],
      podcastUrl: snap.data()?['podcast_url'],
      podcastImage: snap.data()?['podcast_image'],
      episode: Episode.fromJson(snap.data()?['episode'])
    );
  }
}

class EpisodeReply {
  String? id;
  String? uniqueId;
  String? episodeName;
  DateTime? episodeDate;
  String? podcastName;
  String? audioFileLocation;
  String? posterUid;
  String? posterUsername;
  DateTime? replyDate;
  Duration? replyDuration;
  String? replyTitle;

  EpisodeReply({
    this.id,
    this.uniqueId,
    this.episodeName,
    this.episodeDate,
    this.podcastName,
    this.audioFileLocation,
    this.posterUid,
    this.posterUsername,
    this.replyDate,
    this.replyDuration,
    this.replyTitle
  });

  factory EpisodeReply.fromFirestore(DocumentSnapshot snap) {
    return EpisodeReply(
      id: snap.reference.id,
      uniqueId: snap.data()?['unique_id'],
      episodeName: snap.data()?['episode_name'],
      episodeDate: DateTime.fromMillisecondsSinceEpoch(snap.data()?['episode_date'].millisecondsSinceEpoch),
      podcastName: snap.data()?['podcast_name'],
      audioFileLocation: snap.data()?['audioFileLocation'],
      posterUid: snap.data()?['posting_uid'],
      posterUsername: snap.data()?['posting_username'],
      replyDate: DateTime.fromMillisecondsSinceEpoch(snap.data()?['reply_date'].millisecondsSinceEpoch),
      replyDuration: Duration(milliseconds: snap.data()?['reply_ms']),
      replyTitle: snap.data()?['reply_title'],
    );
  }
}

class Playlist {
  String? id;
  String? creatorUID;
  String? creatorUsername;
  String? title;
  String? genre;
  List<String>? tagList;
  DateTime? createdDatetime;
  DateTime? lastModified;
  bool? private;
  List<String>? subscribers;
  List<MediaItem>? items;

  Playlist({
    this.id,
    this.creatorUID,
    this.creatorUsername,
    this.title,
    this.genre,
    this.tagList,
    this.createdDatetime,
    this.private,
    this.subscribers,
    this.items,
    this.lastModified
  });

  Stream<List<MediaItem>> getItems() {
    return FirebaseFirestore.instance.collection('playlists').doc(id).collection('items').orderBy('date_added').snapshots().map((qs) {
      return qs.docs.map((doc) {
        MediaItem i = Helper().getMediaItemFromJson(doc.data());
        i.extras?['date_added'] = DateTime.fromMillisecondsSinceEpoch(doc.data()['date_added'].millisecondsSinceEpoch);
        i.extras?['document_id'] = doc.data()['document_id'];
        return i;
      }).toList();
    });
  }

  factory Playlist.fromFirestore(DocumentSnapshot snap) {
    return Playlist(
      id: snap.id,
      creatorUID: snap.data()?['creator_uid'],
      creatorUsername: snap.data()?['creator_username'],
      title: snap.data()?['title'],
      genre: snap.data()?['genre'],
      private: snap.data()?['private'],
      tagList: (snap.data()?['tags'] as List?)?.map((item) => item as String).toList(),
      createdDatetime: DateTime.fromMillisecondsSinceEpoch(snap.data()?['created_datetime'].millisecondsSinceEpoch),
      lastModified: DateTime.fromMillisecondsSinceEpoch(snap.data()?['last_modified'].millisecondsSinceEpoch),
      subscribers: (snap.data()?['subscribers'] as List?)?.map((item) => item as String).toList(),
    );
  }
}

enum UserListType {
  FOLLOWERS,
  FOLLOWING
}

class DayPosts {
  DateTime? date;
  List? list;

  DayPosts({this.date, this.list});
}

class FeaturedPlaylistCategory {
  String? name;
  List<String>? playlists;

  FeaturedPlaylistCategory({this.name, this.playlists});

  factory FeaturedPlaylistCategory.fromFirestore(DocumentSnapshot snap) {
    print('Feature Playlist Snap: ${snap.data()}');
    return FeaturedPlaylistCategory(
      name: snap.data()?['name'],
      playlists: (snap.data()?['playlists'] as List).map((item) => item as String).toList(),
    );
  }
}