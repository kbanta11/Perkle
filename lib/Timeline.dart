import 'dart:math';
import 'package:Perkl/services/ActivityManagement.dart';
import 'package:Perkl/services/UserManagement.dart';
import 'package:audio_service/audio_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:podcast_search/podcast_search.dart';
import 'package:path_provider/path_provider.dart';
import 'PodcastPage.dart';
import 'ProfilePage.dart';
import 'StreamTagPage.dart';
import 'services/models.dart';
import 'services/db_services.dart';
import 'main.dart';
//import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'services/local_services.dart';

enum TimelineType {
  STREAMTAG,
  MAINFEED,
  STATION,
  USER,
  CLIPS,
}

class Timeline extends StatelessWidget {
  String timelineId;
  Stream tagStream;
  String userId;
  TimelineType type;
  LocalService _historyService = LocalService(filename: 'history.json');
  Timeline({this.timelineId, this.tagStream, this.userId, this.type});

  Future<List<MediaItem>> getHistory() async {
    List<MediaItem> listeningHistory = await _historyService.getData('items').then((dynamic itemList) {
      if(itemList == null) {
        return null;
      }
      List<MediaItem> mediaItemList = (itemList as List).map((item) => MediaItem.fromJson(item)).toList();
      if(mediaItemList != null) {
        mediaItemList.sort((MediaItem a, MediaItem b) {
          //print('${a.extras['listenDate'] ?? 0} >>> ${b.extras['listenDate'] ?? 0}');
          return Comparable.compare(b.extras['listenDate'] ?? 0, a.extras['listenDate'] ?? 0);
        });
      }
      return mediaItemList.reversed.toList();
    });
    return listeningHistory;
  }

  @override
  build(BuildContext context) {
    User firebaseUser = Provider.of<User>(context);
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    PlaybackState playbackState = Provider.of<PlaybackState>(context);
    MediaItem currentMediaItem = Provider.of<MediaItem>(context);
    List<MediaItem> mediaQueue = Provider.of<List<MediaItem>>(context);
    PerklUser currentUser = Provider.of<PerklUser>(context);
    //print('TimelineId: $timelineId/StreamTag: $tagStream/UserId: $userId');
    //print('Current Media Item: $currentMediaItem/Playback State: $playbackState');
    Stream postStream;
    if(tagStream != null) {
      postStream = tagStream;
      //print('Grabbed stream for tag: $tagStream');
    } else if (type == TimelineType.CLIPS)  {
      postStream = DBService().streamEpisodeClips(userId);
    } else {
      postStream = DBService().streamTimelinePosts(currentUser, timelineId: timelineId, userId: userId, type: type,);
    }

    //User currentUser = Provider.of<User>(context);
    return StreamBuilder<bool>(
      stream: DBService().streamTimelineLoading(timelineId),
      builder: (context, snap) {
        bool isLoading = false;
        print('Stream Timeline Loading: $snap');
        if(snap != null && snap.data != null && snap.data) {
          isLoading = true;
        }
        return FutureBuilder(
          future: getHistory(),
          builder: (context, AsyncSnapshot<List<MediaItem>> snap) {
            List<MediaItem> listeningHistory = [];
            if(snap.hasData) {
              listeningHistory = snap.data;
            }
            return StreamBuilder<List<PostPodItem>>(
              stream: postStream,
              builder: (context, AsyncSnapshot<List<PostPodItem>> postListSnap) {
                print('Post snap: $postListSnap');
                print('Post Stream: ${postStream.toString()}/Post List: ${postListSnap.data}');
                List<PostPodItem> postList = postListSnap.data;
                //print('Post List: $postList');
                String emptyText = 'Looks like there are\'nt any posts to show here!';
                if(type == TimelineType.MAINFEED)
                  emptyText = 'Your Timeline is Empty! Try following some users!';
                if(type == TimelineType.USER && currentUser != null && userId == currentUser.uid)
                  emptyText = 'You have no posts! Try recording and say hello!';
                if(type == TimelineType.USER && currentUser != null && userId != currentUser.uid)
                  emptyText = 'This user hasn\'t posted yet!';
                if(type == TimelineType.STREAMTAG)
                  emptyText = 'There aren\'t any posts for this tag yet!';
                if(type == TimelineType.CLIPS)
                  emptyText = 'You haven\'t created any clips yet';

                //Get Days in timeline and group daily posts together
                List<DayPosts> days = <DayPosts>[];
                DateTime minDate;
                if(postList != null) {
                  postList.forEach((post) {
                    DateTime postDate;
                    if(post.type == PostType.POST) {
                      postDate = post.post.datePosted;
                      if(days.where((d) => d.date.year == post.post.datePosted.year && d.date.month == post.post.datePosted.month && d.date.day == post.post.datePosted.day).length > 0) {
                        days.where((d) => d.date.year == post.post.datePosted.year && d.date.month == post.post.datePosted.month && d.date.day == post.post.datePosted.day).first.list.add(post.post);
                      } else {
                        List list = [];
                        list.add(post.post);
                        days.add(DayPosts(date: DateTime(post.post.datePosted.year, post.post.datePosted.month, post.post.datePosted.day), list: list));
                      }
                    }
                    if(post.type == PostType.PODCAST_EPISODE) {
                      postDate = post.episode.publicationDate;
                      if(days.where((d) => d.date.year == post.episode.publicationDate.year && d.date.month == post.episode.publicationDate.month && d.date.day == post.episode.publicationDate.day).length > 0) {
                        days.where((d) => d.date.year == post.episode.publicationDate.year && d.date.month == post.episode.publicationDate.month && d.date.day == post.episode.publicationDate.day).first.list.add(post.episode);
                      } else {
                        List list = [];
                        list.add(post.episode);
                        days.add(DayPosts(date: DateTime(post.episode.publicationDate.year, post.episode.publicationDate.month, post.episode.publicationDate.day), list: list));
                      }
                    }
                    if(post.type == PostType.EPISODE_CLIP) {
                      postDate = post.episodeClip.createdDate;
                      if(days.where((d) => d.date.year == post.episodeClip.createdDate.year && d.date.month == post.episodeClip.createdDate.month && d.date.day == post.episodeClip.createdDate.day).length > 0) {
                        days.where((d) => d.date.year == post.episodeClip.createdDate.year && d.date.month == post.episodeClip.createdDate.month && d.date.day == post.episodeClip.createdDate.day).first.list.add(post.episodeClip);
                      } else {
                        List list = [];
                        list.add(post.episodeClip);
                        days.add(DayPosts(date: DateTime(post.episodeClip.createdDate.year, post.episodeClip.createdDate.month, post.episodeClip.createdDate.day), list: list));
                      }
                    }
                    if(minDate == null) {
                      minDate = postDate;
                    } else if (postDate.isBefore(minDate)) {
                      minDate = postDate;
                    }
                  });
                }
                days.sort((a, b) => b.date.compareTo(a.date));

                List<Widget> itemList = <Widget>[];
                itemList.addAll(days.map((day) {
                  return Container(
                    margin: EdgeInsets.only(left: 10, bottom: 10),
                    padding: EdgeInsets.only(left: 10),
                    decoration: BoxDecoration(
                        border: Border(
                            left: BorderSide(color: Colors.deepPurple[500], width: 2)
                        )
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(day.date.year == DateTime.now().year && day.date.month == DateTime.now().month && day.date.day == DateTime.now().day ? 'Today' : DateFormat('MMMM dd, yyyy').format(day.date), style: TextStyle(fontSize: 16, color: Colors.deepPurple[500]),),
                        Column(
                          children: day.list.map((post) {
                            if(post is Episode) {
                              Episode _post = post;
                              MediaItem thisItem = listeningHistory.firstWhere((element) => element.id == post.contentUrl, orElse: () => null);
                              int pctComplete = 0;
                              if(thisItem != null) {
                               int position = thisItem.extras['position'] ?? 0;
                               int duration = thisItem.duration.inMilliseconds;
                               pctComplete = ((position/duration) * 100).round();
                              }
                              return Card(
                                  elevation: 5,
                                  color: Colors.pink[50],
                                  margin: EdgeInsets.all(5),
                                  child: ClipRRect(
                                    child: Slidable(
                                      actionPane: SlidableDrawerActionPane(),
                                      actionExtentRatio: 0.2,
                                      child: Padding(
                                          padding: EdgeInsets.all(5),
                                          child: InkWell(
                                            child: Row(
                                              children: [
                                                Container(
                                                  height: 65.0,
                                                  width: 65.0,
                                                  decoration: BoxDecoration(
                                                      shape: BoxShape.rectangle,
                                                      color: Colors.deepPurple,
                                                      image: DecorationImage(
                                                          fit: BoxFit.cover,
                                                          image: NetworkImage(_post.podcast.image ?? 'gs://flutter-fire-test-be63e.appspot.com/FCMImages/logo.png')
                                                      )
                                                  ),
                                                  child: InkWell(
                                                    child: Container(),
                                                    onTap: () async {
                                                      showDialog(
                                                          context: context,
                                                          builder: (context) {
                                                            return Center(child: CircularProgressIndicator());
                                                          }
                                                      );
                                                      Podcast pod = await Podcast.loadFeed(url: _post.podcast.url);
                                                      Navigator.of(context).pop();
                                                      Navigator.push(context, MaterialPageRoute(
                                                        builder: (context) =>
                                                            PodcastPage(pod,),
                                                      ));
                                                    },
                                                  ),
                                                ),
                                                SizedBox(width: 5),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(_post.title, textAlign: TextAlign.start,),
                                                      Text('${_post.podcast.title}', textAlign: TextAlign.start, style: TextStyle(fontSize: 12, color: Colors.black45),),
                                                    ],
                                                  )
                                                ),
                                                SizedBox(width: 5),
                                                Container(
                                                    width: 85,
                                                    child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.center,
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: <Widget>[
                                                          Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: <Widget>[
                                                              InkWell(
                                                                  child: Container(
                                                                    height: 35,
                                                                    width: 35,
                                                                    decoration: BoxDecoration(
                                                                      shape: BoxShape.circle,
                                                                      color: currentMediaItem != null && currentMediaItem.id == _post.contentUrl ? Colors.red : Colors.deepPurple,
                                                                    ),
                                                                    child: Center(child: FaIcon(currentMediaItem != null && currentMediaItem.id == _post.contentUrl && playbackState.playing ? FontAwesomeIcons.pause : FontAwesomeIcons.play, color: Colors.white, size: 16,)),
                                                                  ),
                                                                  onTap: () {
                                                                    if(currentMediaItem != null && currentMediaItem.id == _post.contentUrl && playbackState.playing) {
                                                                      mp.pausePost();
                                                                      return;
                                                                    }
                                                                    mp.playPost(PostPodItem.fromEpisode(post, post.podcast));
                                                                  }
                                                              ),
                                                              SizedBox(width: 5),
                                                              InkWell(
                                                                  child: Container(
                                                                    height: 35,
                                                                    width: 35,
                                                                    decoration: BoxDecoration(
                                                                      shape: BoxShape.circle,
                                                                      color: mediaQueue != null && mediaQueue.where((item) => item.id == _post.contentUrl).length > 0  ? Colors.grey : Colors.deepPurple,
                                                                    ),
                                                                    child: Center(child: FaIcon(FontAwesomeIcons.plus, color: Colors.white, size: 16,)),
                                                                  ),
                                                                  onTap: () {
                                                                    if(mediaQueue == null || mediaQueue.where((item) => item.id == _post.contentUrl).length == 0)
                                                                      mp.addPostToQueue(PostPodItem.fromEpisode(post, post.podcast));
                                                                  }
                                                              )
                                                            ],
                                                          ),
                                                          SizedBox(height: 3),
                                                          post.duration == null ? Text('') : Text(ActivityManager().getDurationString(post.duration)),
                                                          pctComplete > 0 ? Text('${min(pctComplete, 100)}%', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)) : Container(),
                                                        ]
                                                    )
                                                )
                                              ],
                                            ),
                                            onTap: () async {
                                              showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return EpisodeDialog(ep: post, podcast: post.podcast);
                                                  }
                                              );
                                            }
                                          ),
                                      ),
                                      secondaryActions: <Widget>[
                                        new SlideAction(
                                          color: Colors.red[300],
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: <Widget>[
                                              FaIcon(FontAwesomeIcons.comments, color: Colors.white),
                                              Text('Discuss', style: TextStyle(color: Colors.white))
                                            ],
                                          ),
                                          onTap: () async {
                                            showDialog(
                                                context: context,
                                                builder: (context) {
                                                  return Center(child: CircularProgressIndicator());
                                                }
                                            );
                                            post.podcast = await Podcast.loadFeed(url: post.podcast.url);
                                            Navigator.of(context).pop();
                                            mp.replyToEpisode(post, post.podcast, context);
                                          },
                                        ),
                                        new SlideAction(
                                          color: Colors.deepPurple[300],
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: <Widget>[
                                              FaIcon(FontAwesomeIcons.share, color: Colors.white),
                                              Text('Share', style: TextStyle(color: Colors.white))
                                            ],
                                          ),
                                          onTap: () {
                                            mp.shareToConversation(context, episode: post, podcast: post.podcast, user: currentUser);
                                          },
                                        ),
                                      ],
                                    ),
                                  )
                              );
                            }
                            if(post is EpisodeClip) {
                              EpisodeClip _post = post;
                              return Card(
                                  elevation: 5,
                                  color: Colors.pink[50],
                                  margin: EdgeInsets.all(5),
                                  child: ClipRRect(
                                    child: Slidable(
                                      actionPane: SlidableDrawerActionPane(),
                                      actionExtentRatio: 0.2,
                                      child: Padding(
                                          padding: EdgeInsets.all(5),
                                          child: ListTile(
                                            leading: Container(
                                              height: 50.0,
                                              width: 50.0,
                                              decoration: BoxDecoration(
                                                  shape: BoxShape.rectangle,
                                                  color: Colors.deepPurple,
                                                  image: DecorationImage(
                                                      fit: BoxFit.cover,
                                                      image: NetworkImage(_post.podcastImage ?? 'gs://flutter-fire-test-be63e.appspot.com/FCMImages/logo.png')
                                                  )
                                              ),
                                              child: InkWell(
                                                child: Container(),
                                                onTap: () async {
                                                  showDialog(
                                                      context: context,
                                                      builder: (context) {
                                                        return Center(child: CircularProgressIndicator());
                                                      }
                                                  );
                                                  Podcast pod = await Podcast.loadFeed(url: _post.podcastUrl);
                                                  Navigator.of(context).pop();
                                                  Navigator.push(context, MaterialPageRoute(
                                                    builder: (context) =>
                                                        PodcastPage(pod,),
                                                  ));
                                                },
                                              ),
                                            ),
                                            title: Text(_post.clipTitle ?? _post.episode.title),
                                            subtitle: Text('${_post.podcastTitle}'),
                                            trailing: Container(
                                                width: 85,
                                                child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.center,
                                                    children: <Widget>[
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: <Widget>[
                                                          InkWell(
                                                              child: Container(
                                                                height: 35,
                                                                width: 35,
                                                                decoration: BoxDecoration(
                                                                  shape: BoxShape.circle,
                                                                  color: currentMediaItem != null && currentMediaItem.id == _post.episode.contentUrl ? Colors.red : Colors.deepPurple,
                                                                ),
                                                                child: Center(child: FaIcon(currentMediaItem != null && currentMediaItem.id == _post.episode.contentUrl && playbackState.playing ? FontAwesomeIcons.pause : FontAwesomeIcons.play, color: Colors.white, size: 16,)),
                                                              ),
                                                              onTap: () {
                                                                if(currentMediaItem != null && currentMediaItem.id == _post.episode.contentUrl && playbackState.playing) {
                                                                  mp.pausePost();
                                                                  return;
                                                                }
                                                                mp.playPost(PostPodItem.fromEpisodeClip(_post));
                                                              }
                                                          ),
                                                          SizedBox(width: 5),
                                                          InkWell(
                                                              child: Container(
                                                                height: 35,
                                                                width: 35,
                                                                decoration: BoxDecoration(
                                                                  shape: BoxShape.circle,
                                                                  color: mediaQueue != null && mediaQueue.where((item) => item.id == _post.episode.contentUrl).length > 0  ? Colors.grey : Colors.deepPurple,
                                                                ),
                                                                child: Center(child: FaIcon(FontAwesomeIcons.plus, color: Colors.white, size: 16,)),
                                                              ),
                                                              onTap: () {
                                                                if(mediaQueue == null || mediaQueue.where((item) => item.id == _post.episode.contentUrl).length == 0)
                                                                  mp.addPostToQueue(PostPodItem.fromEpisodeClip(_post));
                                                              }
                                                          )
                                                        ],
                                                      ),
                                                      _post.startDuration == null || _post.endDuration == null ? Text('') : Text(ActivityManager().getDurationString(Duration(milliseconds: _post.endDuration.inMilliseconds - _post.startDuration.inMilliseconds))),
                                                    ]
                                                )
                                            ),
                                            onTap: () async {
                                              showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return Center(child: CircularProgressIndicator());
                                                  }
                                              );
                                              Podcast podcast = await Podcast.loadFeed(url: _post.podcastUrl);
                                              Navigator.of(context).pop();
                                              showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return EpisodeDialog(ep: _post.episode, podcast: podcast);
                                                  }
                                              );
                                            },
                                          )
                                      ),
                                      /*
                                  secondaryActions: <Widget>[
                                    new SlideAction(
                                      color: Colors.red[300],
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: <Widget>[
                                          FaIcon(FontAwesomeIcons.comments, color: Colors.white),
                                          Text('Discuss', style: TextStyle(color: Colors.white))
                                        ],
                                      ),
                                      onTap: () async {
                                        showDialog(
                                            context: context,
                                            builder: (context) {
                                              return Center(child: CircularProgressIndicator());
                                            }
                                        );
                                        post.podcast = await Podcast.loadFeed(url: post.podcast.url);
                                        Navigator.of(context).pop();
                                        mp.replyToEpisode(post, post.podcast, context);
                                      },
                                    ),
                                    new SlideAction(
                                      color: Colors.deepPurple[300],
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: <Widget>[
                                          FaIcon(FontAwesomeIcons.share, color: Colors.white),
                                          Text('Share', style: TextStyle(color: Colors.white))
                                        ],
                                      ),
                                      onTap: () {
                                        mp.shareToConversation(context, episode: post, podcast: post.podcast, user: currentUser);
                                      },
                                    ),
                                  ],
                                   */
                                    ),
                                  )
                              );
                            }

                            Post _post = post;
                            return StreamProvider<PerklUser>(
                              create: (context) => UserManagement().streamUserDoc(_post.userUID),
                              child: Consumer<PerklUser>(
                                builder: (context, poster, _) {
                                  return Card(
                                    elevation: 5,
                                    color: Colors.deepPurple[50],
                                    margin: EdgeInsets.all(5),
                                    child: ClipRect(
                                      child: Slidable(
                                        actionPane: SlidableDrawerActionPane(),
                                        actionExtentRatio: 0.2,
                                        child: Padding(
                                          padding: EdgeInsets.all(5),
                                          child: ExpansionTile(
                                            leading: poster == null || poster.profilePicUrl == null ? Container(
                                              height: 60.0,
                                              width: 60.0,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.deepPurple,
                                              ),
                                              child: InkWell(
                                                child: Container(),
                                                onTap: () {
                                                  Navigator.push(context, MaterialPageRoute(
                                                    builder: (context) =>
                                                        ProfilePageMobile(userId: post.userUID,),
                                                  ));
                                                },
                                              ),
                                            ) : Container(
                                                height: 60.0,
                                                width: 60.0,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.deepPurple,
                                                  image: DecorationImage(
                                                    fit: BoxFit.cover,
                                                    image: NetworkImage(poster.profilePicUrl),
                                                  ),
                                                ),
                                                child: InkWell(
                                                  child: Container(),
                                                  onTap: () {
                                                    Navigator.push(context, MaterialPageRoute(
                                                      builder: (context) =>
                                                          ProfilePageMobile(userId: post.userUID,),
                                                    ));
                                                  },
                                                )
                                            ),
                                            title: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Text('@${_post.username}'),
                                                Text('${_post.postTitle != null ? _post.postTitle : DateFormat('MMMM dd, yyyy h:mm a').format(_post.datePosted)}', style: TextStyle(fontSize: 14)),
                                                _post.postTitle != null ? Text(DateFormat('MMMM dd, yyyy h:mm a').format(_post.datePosted), style: TextStyle(fontSize: 14, color: Colors.black45))  : Container(),
                                              ],
                                            ),
                                            trailing: Column(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: <Widget>[
                                                Container(
                                                  width: 80,
                                                  child: Row(
                                                    children: <Widget>[
                                                      InkWell(
                                                        child: Container(
                                                          height: 35,
                                                          width: 35,
                                                          decoration: BoxDecoration(
                                                              shape: BoxShape.circle,
                                                              color: currentMediaItem != null && currentMediaItem.id == _post.audioFileLocation ? Colors.red : Colors.deepPurple
                                                          ),
                                                          child: Center(child: FaIcon(currentMediaItem != null && currentMediaItem.id == _post.audioFileLocation && playbackState.playing != null && playbackState.playing ? FontAwesomeIcons.pause : FontAwesomeIcons.play, color: Colors.white, size: 16)),
                                                        ),
                                                        onTap: () {
                                                          playbackState != null && playbackState.playing != null && playbackState.playing && currentMediaItem.id == _post.audioFileLocation ? mp.pausePost() : mp.playPost(PostPodItem.fromPost(post));
                                                        },
                                                      ),
                                                      SizedBox(width: 5,),
                                                      InkWell(
                                                        child: Container(
                                                          height: 35,
                                                          width: 35,
                                                          decoration: BoxDecoration(
                                                              shape: BoxShape.circle,
                                                              color: mediaQueue != null && mediaQueue.where((p) => p.id == _post.audioFileLocation).length > 0 ? Colors.grey : Colors.deepPurple
                                                          ),
                                                          child: Center(child: FaIcon(FontAwesomeIcons.plus, color: Colors.white, size: 16)),
                                                        ),
                                                        onTap: () {
                                                          if(mediaQueue == null || mediaQueue.where((p) => p.id == _post.audioFileLocation).length <= 0)
                                                            mp.addPostToQueue(PostPodItem.fromPost(post));
                                                        },
                                                      )
                                                    ],
                                                  ),
                                                ),
                                                Text(post.getLengthString())
                                              ],
                                            ),
                                            children: <Widget>[
                                              Row(
                                                children: <Widget>[
                                                  SizedBox(width: 90),
                                                  Expanded(
                                                    child: post.streamList != null && post.streamList.length > 0 ? Wrap(
                                                      spacing: 8,
                                                      children: post.streamList.map<Widget>((String tag) {
                                                        return InkWell(
                                                            child: Text('#$tag', style: TextStyle(color: Colors.lightBlue)),
                                                            onTap: () {
                                                              Navigator.push(context, MaterialPageRoute(
                                                                  builder: (context) => StreamTagPageMobile(tag: tag,)
                                                              ));
                                                            }
                                                        );
                                                      }).toList(),
                                                    ) : Container(),
                                                  ),
                                                ],
                                              )
                                            ],
                                          ),
                                        ),
                                        secondaryActions: <Widget>[
                                          SlideAction(
                                            color: Colors.deepPurple[300],
                                            child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.file_download, color: Colors.grey[400]),
                                                  Text('Download', style: TextStyle(color: Colors.grey[400]))
                                                ]
                                            ),
                                          ),
                                          currentUser != null && post.userUID == currentUser.uid ? SlideAction(
                                            color: Colors.red[300],
                                            child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.delete_forever, color: Colors.white),
                                                  Text('Delete', style: TextStyle(color: Colors.white))
                                                ]
                                            ),
                                            onTap: () {
                                              showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return AlertDialog(
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(25))),
                                                      title: Text('Are you sure?'),
                                                      content: Text('You are about to delete this post forever. Are you sure you\'d like to remove this post?'),
                                                      actions: [
                                                        TextButton(
                                                          child: Text('Cancel'),
                                                          onPressed: () {
                                                            Navigator.of(context).pop();
                                                          },
                                                        ),
                                                        TextButton(
                                                          child: Text('Delete'),
                                                          onPressed: () async {
                                                            await DBService().deletePost(post);
                                                            //await DBService().deletePost(post.);
                                                            Navigator.of(context).pop();
                                                          },
                                                        )],
                                                    );
                                                  }
                                              );
                                            },
                                          ) : null
                                        ].where((element) => element != null).toList(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          }).toList(),
                        )
                      ],
                    ),
                  );
                }).toList());
                if(type == TimelineType.MAINFEED || type == TimelineType.STATION) {
                  itemList.add(
                      ListTile(
                        title: Center(
                          child: isLoading ? CircularProgressIndicator() : Text('Load More'),
                        ),
                        onTap: () {
                          if(!isLoading) {
                            print('Loading more posts from: $minDate');
                            DBService().updateTimeline(timelineId: timelineId, user: currentUser, minDate: minDate);
                          }
                        },
                      )
                  );
                }

                print('currentUser: $currentUser/post list: $postList');
                print('days length: ${days.length}/is loading: $isLoading');
                return RefreshIndicator(
                  onRefresh: () async {
                    if(type == TimelineType.MAINFEED || type == TimelineType.STATION) {
                      await DBService().updateTimeline(timelineId: timelineId, reload: false, setLoading: false);
                    }
                  },
                  child: ListView(
                    children: currentUser == null || postList == null ? [Center(child: CircularProgressIndicator())] : days.length == 0  && !isLoading ? [Center(child: Text(emptyText))] : days.length == 0 && isLoading ? [Center(child: CircularProgressIndicator())] : itemList,
                  ),
                );
              },
            );
          },
        );
      }
    );
  }
}