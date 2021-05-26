import 'dart:math';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'MainPageTemplate.dart';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:podcast_search/podcast_search.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'services/db_services.dart';
import 'services/models.dart';
import 'services/ActivityManagement.dart';
import 'services/local_services.dart';
import 'services/Helper.dart';
import 'PodcastPage.dart';
import 'StreamTagPage.dart';
import 'main.dart';


class PlaylistListPage extends StatefulWidget {

  _PlaylistListPageState createState() => _PlaylistListPageState();
}

class _PlaylistListPageState extends State<PlaylistListPage> {
  bool toggleSubscribed = false;

  @override
  build(BuildContext context) {
    User? firebaseUser = Provider.of<User?>(context);
    return MainPageTemplate(
      bottomNavIndex: 2,
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  backgroundColor: toggleSubscribed ? Colors.transparent : Colors.deepPurple,
                  side: BorderSide(color: Colors.deepPurple)
                ),
                child: Text('My Playlists', style: TextStyle(color: toggleSubscribed ? Colors.deepPurple : Colors.white)),
                onPressed: () {
                  setState(() {
                    toggleSubscribed = false;
                  });
                }
              ),
              TextButton(
                  style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    backgroundColor: toggleSubscribed ? Colors.deepPurple : Colors.transparent,
                      side: BorderSide(color: Colors.deepPurple)
                  ),
                  child: Text('Subscribed', style: TextStyle(color: toggleSubscribed ? Colors.white : Colors.deepPurple)),
                  onPressed: () {
                    setState(() {
                      toggleSubscribed = true;
                    });
                  }
              ),
            ]
          ),
          Expanded(
            child: StreamBuilder<List<Playlist>?>(
              stream: toggleSubscribed ? DBService().streamSubscribedPlaylists(firebaseUser?.uid) : DBService().streamMyPlaylists(firebaseUser?.uid),
              builder: (BuildContext context, AsyncSnapshot<List<Playlist>?> listSnap) {
                print('Playlist Snap Data: ${listSnap.data}');
                return Stack(
                  children: [
                    ListView(
                        children: listSnap.data?.map((playlist) => Card(
                            color: Colors.deepPurple[50],
                            child: ListTile(
                              title: Text('${playlist.title}'),
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (context) => PlaylistPage(playlist: playlist,),
                                ));
                              },
                            )
                        )).toList() ?? [Center(child: Text(toggleSubscribed ? 'Subscribe to some playlists first!' : 'Create a Playlist First!'))]
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          backgroundColor: Colors.deepPurple,
                        ),
                        child: Text('New Playlist', style: TextStyle(color: Colors.white)),
                        onPressed: () async {
                          await showDialog(
                            context: context,
                            builder: (context) {
                              return CreatePlaylistDialog();
                            }
                          );
                        },
                      ),
                    )
                  ]
                );
              }
            )
          ),
        ]
      ),
    );
  }
}

class PlaylistPage extends StatefulWidget {
  Playlist? playlist;

  PlaylistPage({Key? key, @required this.playlist});

  _PlaylistPageState createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  LocalService _historyService = LocalService(filename: 'history.json');
  bool loadingSubscribeIndicator = false;

  Future<List<MediaItem>> getHistory() async {
    List<MediaItem> listeningHistory = await _historyService.getData('items').then((dynamic itemList) {
      if(itemList == null) {
        return Future.value();
      }
      List<MediaItem> mediaItemList = (itemList as List).map((item) => Helper().getMediaItemFromJson(item)).toList();
      if(mediaItemList != null) {
        mediaItemList.sort((MediaItem a, MediaItem b) {
          //print('${a.extras['listenDate'] ?? 0} >>> ${b.extras['listenDate'] ?? 0}');
          return Comparable.compare(b.extras?['listenDate'] ?? 0, a.extras?['listenDate'] ?? 0);
        });
      }
      return mediaItemList.reversed.toList();
    });
    return listeningHistory;
  }

  tapItemTile(MediaItem item) async {
    print('item tapped: $item');
    if(item.extras?['type'] == 'PostType.PODCAST_EPISODE') {
      showDialog(
          context: context,
          builder: (context) {
            return Center(child: CircularProgressIndicator());
          }
      );
      Podcast podcast = await Podcast.loadFeed(url: item.extras?['podcast_url']);
      Map<String, dynamic> episodeMap = item.extras?['episode'];
      Episode ep = Episode.of(
          guid: episodeMap['guid'],
          title: episodeMap['title'],
          description: episodeMap['description'],
          link: episodeMap['link'],
          publicationDate: DateTime.fromMillisecondsSinceEpoch(episodeMap['publicationDate']),
          author: episodeMap['author'],
          duration: Duration(milliseconds: episodeMap['duration']),
          contentUrl: episodeMap['contentUrl'],
          season: episodeMap['season'],
          episode: episodeMap['episode'],
          podcast: podcast
      );
      Navigator.of(context).pop();
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return EpisodeDialog(ep: ep, podcast: podcast,);
          }
      );
    }
    if(item.extras?['type'] == 'PostType.EPISODE_CLIP') {
      showDialog(
          context: context,
          builder: (context) {
            return Center(child: CircularProgressIndicator());
          }
      );
      Podcast podcast = await Podcast.loadFeed(url: item.extras?['podcast_url']);
      Map<String, dynamic> episodeMap = item.extras?['episode'];
      Episode ep = Episode.of(
          guid: episodeMap['guid'],
          title: episodeMap['title'],
          description: episodeMap['description'],
          link: episodeMap['link'],
          publicationDate: DateTime.fromMillisecondsSinceEpoch(episodeMap['publicationDate']),
          author: episodeMap['author'],
          duration: Duration(milliseconds: episodeMap['duration']),
          contentUrl: episodeMap['contentUrl'],
          season: episodeMap['season'],
          episode: episodeMap['episode'],
          podcast: podcast
      );
      Navigator.of(context).pop();
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return EpisodeDialog(ep: ep, podcast: podcast,);
          }
      );
    }
    if(item.extras?['type'] == 'PostType.EPISODE_REPLY'){
      showDialog(
          context: context,
          builder: (context) {
            return Center(child: CircularProgressIndicator());
          }
      );
      Podcast podcast = await Podcast.loadFeed(url: item.extras?['podcast_url']);
      Map<String, dynamic> episodeMap = item.extras?['episode'];
      Episode ep = Episode.of(
          guid: episodeMap['guid'],
          title: episodeMap['title'],
          description: episodeMap['description'],
          link: episodeMap['link'],
          publicationDate: DateTime.fromMillisecondsSinceEpoch(episodeMap['publicationDate']),
          author: episodeMap['author'],
          duration: Duration(milliseconds: episodeMap['duration']),
          contentUrl: episodeMap['contentUrl'],
          season: episodeMap['season'],
          episode: episodeMap['episode'],
          podcast: podcast
      );
      Navigator.of(context).pop();
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return EpisodeDialog(ep: ep, podcast: podcast);
          }
      );
    }
    if(item.extras?['type'] == 'PostType.POST') {
      Map<String, dynamic> postMap = item.extras?['post'];
      Post post = Post(
        id: postMap['id'],
        userUID: postMap['userUID'],
        username: postMap['username'],
        postTitle: postMap['postTitle'],
        datePosted: postMap['datePosted'],
        postValue: postMap['postValue'],
        audioFileLocation: postMap['audioFileLocation'],
        listenCount: postMap['listenCount'],
        secondsLength: postMap['secondsLength'],
        streamList: postMap['streamList'],
        timelines: postMap['timelines'],
      );
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return SimpleDialog(
              title: Center(child: Text(post.postTitle ?? DateFormat("MMMM dd, yyyy @ hh:mm").format(post.datePosted ?? DateTime(1900, 1, 1)).toString())),
              contentPadding: EdgeInsets.all(10),
              children: <Widget>[
                Text('Posted By:\n@${post.username}', textAlign: TextAlign.center, style: TextStyle(fontSize: 16),),
                post.postValue != null ? Text('${post.postValue ?? ''}') : Container(),
                SizedBox(height: 10),
                Text('Date Posted:\n${DateFormat("MMMM dd, yyyy @ hh:mm").format(post.datePosted ?? DateTime(1900,1,1)).toString()}', textAlign: TextAlign.center, style: TextStyle(fontSize: 16),),
                SizedBox(height: 10),
                post.streamList != null && (post.streamList?.length ?? 0) > 0 ? Wrap(
                  spacing: 8,
                  children: post.streamList?.map((tag) => InkWell(
                      child: Text('#$tag', style: TextStyle(color: Colors.lightBlue)),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(
                            builder: (context) => StreamTagPageMobile(tag: tag,)
                        ));
                      }
                  )).toList() ?? [Container()],
                ) : Container(),
                Row(
                  children: <Widget>[
                    TextButton(
                      child: Text('Cancel'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    )
                  ],
                )
              ],
            );
          }
      );
    }
  }

  @override
  build(BuildContext context) {
    MediaItem? currentMediaItem = Provider.of<MediaItem?>(context);
    PlaybackState? playbackState = Provider.of<PlaybackState?>(context);
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    List<MediaItem>? mediaQueue = Provider.of<List<MediaItem>?>(context);
    PerklUser? currentUser = Provider.of<PerklUser?>(context);

    return FutureBuilder(
      future: getHistory(),
      builder: (context, AsyncSnapshot<List<MediaItem>> snap) {
        List<MediaItem>? listeningHistory = [];
        if(snap.hasData) {
          listeningHistory = snap.data;
        }
        return MainPageTemplate(
            bottomNavIndex: 2,
            body: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(10, 5, 10, 0),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${widget.playlist?.title}', style: TextStyle(fontSize: 24.0)),
                                Text('@${widget.playlist?.creatorUsername}', style: TextStyle(fontSize: 16.0)),
                              ]
                          ),
                          widget.playlist?.creatorUID == currentUser?.uid ? Row(
                            children: [
                              InkWell(
                                  child: Container(
                                    height: 35,
                                    width: 35,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.deepPurple,
                                    ),
                                    child: Center(child: FaIcon(FontAwesomeIcons.edit, color: Colors.white, size: 16,)),
                                  ),
                                  onTap: () async {
                                    await showDialog(
                                      context: context,
                                      builder: (context) {
                                        return EditPlaylistDialog(playlist: widget.playlist);
                                      }
                                    ).then((playlist) {
                                      if(playlist != null) {
                                        setState(() {
                                          widget.playlist = playlist;
                                        });
                                      }
                                    });
                                  }
                              ),
                              SizedBox(width: 5),
                              InkWell(
                                  child: Container(
                                    height: 35,
                                    width: 35,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.deepPurple,
                                    ),
                                    child: Center(child: FaIcon(FontAwesomeIcons.trash, color: Colors.white, size: 16,)),
                                  ),
                                  onTap: () async {
                                    await showDialog(
                                        context: context,
                                        builder: (context) {
                                          return SimpleDialog(
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
                                              insetPadding: EdgeInsets.all(20),
                                              contentPadding: EdgeInsets.all(15),
                                              title: Center(child: Text('Are you sure?')),
                                              children: [
                                                Text('Are you sure you want to delete this playlist forever?', textAlign: TextAlign.center),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    TextButton(
                                                      child: Text('Cancel'),
                                                      onPressed: () {
                                                        Navigator.of(context).pop();
                                                      }
                                                    ),
                                                    TextButton(
                                                        style: TextButton.styleFrom(
                                                          backgroundColor: Colors.deepPurple
                                                        ),
                                                        child: Text('Delete', style: TextStyle(color: Colors.white)),
                                                        onPressed: () async {
                                                          await DBService().deletePlaylist(widget.playlist?.id);
                                                          Navigator.of(context).pop();
                                                          Navigator.of(context).pop();
                                                        }
                                                    ),
                                                  ]
                                                ),
                                              ]
                                          );
                                        }
                                    );
                                  }
                              )
                            ]
                          ) : widget.playlist?.subscribers?.contains(currentUser?.uid) ?? false ?
                          OutlinedButton(
                              style: TextButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                side: BorderSide(color: Colors.deepPurple),
                              ),
                              child: loadingSubscribeIndicator ? SpinKitThreeBounce(color: Colors.deepPurple, size: 16,) : Text('Unsubscribe'),
                              onPressed: () async {
                                setState(() {
                                  loadingSubscribeIndicator = true;
                                });
                                await DBService().unsubscribeToPlaylist(currentUser?.uid, widget.playlist?.id);
                                widget.playlist?.subscribers?.remove(currentUser!.uid);
                                setState(() {
                                  loadingSubscribeIndicator = false;
                                });
                              }
                          ) : TextButton(
                              child: loadingSubscribeIndicator ? SpinKitThreeBounce(color: Colors.white, size: 16,) : Text('Subscribe', style: TextStyle(color: Colors.white)),
                              style: TextButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                backgroundColor: Colors.deepPurple,
                              ),
                              onPressed: () async {
                                setState(() {
                                  loadingSubscribeIndicator = true;
                                });
                                await DBService().subscribeToPlaylist(currentUser?.uid, widget.playlist?.id);
                                widget.playlist?.subscribers?.add(currentUser!.uid ?? '');
                                setState(() {
                                  loadingSubscribeIndicator = false;
                                });
                              }
                          )
                        ]
                    )
                  ),
                  Divider(),
                  Expanded(
                      child: StreamBuilder<List<MediaItem>>(
                          stream: widget.playlist!.getItems(),
                          builder: (context, AsyncSnapshot<List<MediaItem>> listSnap) {
                            return ListView(
                                children: listSnap.data?.map((item) {
                                  //get image url
                                  Future<Widget> itemImage() async {
                                    String? imageUrl = item.extras?['podcast_image'];
                                    bool isUser = imageUrl == null;
                                    if(isUser) {
                                      String? posterId = item.extras?['post']?['userUID'];
                                      imageUrl = await DBService().getPerklUser(posterId).then((user) => user.profilePicUrl);
                                    }
                                    return Container(
                                      height: 65.0,
                                      width: 65.0,
                                      decoration: BoxDecoration(
                                          shape: isUser ? BoxShape.circle : BoxShape.rectangle,
                                          color: Colors.deepPurple,
                                          image: DecorationImage(
                                              fit: BoxFit.cover,
                                              image: NetworkImage(imageUrl ?? 'gs://flutter-fire-test-be63e.appspot.com/FCMImages/logo.png')
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
                                          Podcast pod = await Podcast.loadFeed(url: item.extras?['podcast_url']);
                                          Navigator.of(context).pop();
                                          Navigator.push(context, MaterialPageRoute(
                                            builder: (context) =>
                                                PodcastPage(pod,),
                                          ));
                                        },
                                      ),
                                    );
                                  }

                                  //get progress
                                  MediaItem? thisItem = listeningHistory?.firstWhereOrNull((element) {
                                    if(item.extras?['clipId'] != null) {
                                      return item.extras?['clipId'] == element.extras?['clipId'];
                                    }
                                    return element.id == item.id
                                  });
                                  int pctComplete = 0;
                                  if(thisItem != null) {
                                    //print('This Item Duration: ${thisItem.duration}');
                                    int position = thisItem.extras?['position'] ?? 0;
                                    int duration = thisItem.duration?.inMilliseconds ?? 1;
                                    pctComplete = duration > 0 ? ((position/duration) * 100).round() : 0;
                                  }

                                  return Card(
                                      elevation: 5,
                                      color: item.extras?['type'] == 'PostType.POST' ? Colors.deepPurple[50] : Colors.pink[50],
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
                                                    FutureBuilder<Widget>(
                                                        future: itemImage(),
                                                        builder: (context, widgetSnap) {
                                                          return widgetSnap.data ?? Container();
                                                        }
                                                    ),
                                                    SizedBox(width: 5),
                                                    Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text('${item.title}', textAlign: TextAlign.start,),
                                                            Text('${item.artist}', textAlign: TextAlign.start, style: TextStyle(fontSize: 12, color: Colors.black45),),
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
                                                                          color: currentMediaItem != null && currentMediaItem.id == item.id ? Colors.red : Colors.deepPurple,
                                                                        ),
                                                                        child: Center(child: FaIcon(currentMediaItem != null && currentMediaItem.id == item.id && (playbackState?.playing ?? false) ? FontAwesomeIcons.pause : FontAwesomeIcons.play, color: Colors.white, size: 16,)),
                                                                      ),
                                                                      onTap: () {
                                                                        if(currentMediaItem != null && currentMediaItem.id == item.id && (playbackState?.playing ?? false)) {
                                                                          mp.pausePost();
                                                                          return;
                                                                        }
                                                                        mp.playPostFromMediaItem(item);
                                                                      }
                                                                  ),
                                                                  SizedBox(width: 5),
                                                                  PopupMenuButton(
                                                                    child: Container(
                                                                      height: 35,
                                                                      width: 35,
                                                                      decoration: BoxDecoration(
                                                                        shape: BoxShape.circle,
                                                                        color: Colors.deepPurple,
                                                                      ),
                                                                      child: Center(child: FaIcon(FontAwesomeIcons.plus, color: Colors.white, size: 16,)),
                                                                    ),
                                                                    itemBuilder: (context) => [
                                                                      PopupMenuItem(
                                                                        child: Text('Add to Queue'),
                                                                        value: 'queue',
                                                                      ),
                                                                      PopupMenuItem(
                                                                        child: Text('Add to Playlist'),
                                                                        value: 'playlist',
                                                                      )
                                                                    ],
                                                                    onSelected: (value) async {
                                                                      if(value == 'queue') {
                                                                        if(mediaQueue == null || mediaQueue.where((item) => item.id == item.id).length == 0) {
                                                                          mp.addMediaItemToQueue(item);
                                                                        }
                                                                      }

                                                                      if(value == 'playlist') {
                                                                        await showDialog(
                                                                            context: context,
                                                                            builder: (context) {
                                                                              return AddToPlaylistDialog(item: item,);
                                                                            }
                                                                        );
                                                                      }
                                                                    },
                                                                  ),
                                                                ],
                                                              ),
                                                              SizedBox(height: 3),
                                                              item.duration == null ? Text('') : Text(ActivityManager().getDurationString(item.duration)),
                                                              pctComplete > 0 ? Text('${min(pctComplete, 100)}%', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)) : Container(),
                                                            ]
                                                        )
                                                    )
                                                  ],
                                                ),
                                                onTap: () async {
                                                  tapItemTile(item);
                                                }
                                            ),
                                          ),
                                          actions: widget.playlist?.creatorUID == currentUser?.uid ? [
                                            SlideAction(
                                              color: Colors.red[300],
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: <Widget>[
                                                  FaIcon(FontAwesomeIcons.minusCircle, color: Colors.white),
                                                  Text('Remove', style: TextStyle(color: Colors.white))
                                                ],
                                              ),
                                              onTap: () async {
                                                String? documentId = item.extras?['document_id'];
                                                await DBService().removeFromPlaylist(documentId, widget.playlist?.id);
                                              }
                                            ),
                                          ] : null,
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
                                                if(item.extras?['type'] == 'PostType.PODCAST_EPISODE' || item.extras?['type'] == 'PostType.EPISODE_CLIP') {
                                                  showDialog(
                                                      context: context,
                                                      builder: (context) {
                                                        return Center(child: CircularProgressIndicator());
                                                      }
                                                  );
                                                  Podcast pod = await Podcast.loadFeed(url: item.extras?['podcast_url']);
                                                  Navigator.of(context).pop();
                                                  mp.replyToEpisode(Episode.fromJson(item.extras?['episode']), pod, context);
                                                }
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
                                              onTap: () async {
                                                if(item.extras?['type'] == 'PostType.PODCAST_EPISODE' || item.extras?['type'] == 'PostType.EPISODE_CLIP') {
                                                  showDialog(
                                                      context: context,
                                                      builder: (context) {
                                                        return Center(child: CircularProgressIndicator());
                                                      }
                                                  );
                                                  Podcast pod = await Podcast.loadFeed(url: item.extras?['podcast_url']);
                                                  Navigator.of(context).pop();
                                                  mp.shareToConversation(context, episode: Episode.fromJson(item.extras?['episode']), podcast: pod, user: currentUser);
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      )
                                  );
                                }).toList() ?? [Center(child: Text('Oh No! This Playlist is Empty!', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)))]
                            );
                          }
                      )
                  )
                ]
            )
        );
      }
    );
  }
}


//------------------------------AddToPlaylistDialog--------------------------------------
class AddToPlaylistDialog extends StatefulWidget {
  MediaItem? item;

  AddToPlaylistDialog({Key? key, @required this.item});

  _AddToPlaylistDialogState createState() => _AddToPlaylistDialogState();
}

class _AddToPlaylistDialogState extends State<AddToPlaylistDialog> {
  List<String> _playlistsToAdd = [];

  @override
  build(BuildContext context) {
    User? firebaseUser = Provider.of<User?>(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
      insetPadding: EdgeInsets.all(20),
      child: Container(
        padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add to Playlist', style: TextStyle(fontSize: 24)),
              SizedBox(height: 5),
              Text('${widget.item?.title}', textAlign: TextAlign.center),
              Text('${widget.item?.artist}'),
              Divider(),
              ListTile(
                title: Text('Create New Playlist'),
                trailing: Icon(Icons.add_box_rounded, color: Colors.deepPurple),
                onTap: () async {
                  await showDialog(
                    context: context,
                    builder: (context) {

                      return CreatePlaylistDialog();
                    }
                  );
                },
              ),
              Divider(),
              StreamBuilder<List<Playlist>?>(
                stream: DBService().streamMyPlaylists(firebaseUser?.uid),
                builder: (BuildContext context, AsyncSnapshot<List<Playlist>?> listSnap) {
                  print('List of Playlists: ${listSnap.data}');
                  return Expanded(
                    child: ListView(
                        children: listSnap.data?.map((playlist) => CheckboxListTile(
                            title: Text('${playlist.title}'),
                            value: _playlistsToAdd.contains(playlist.id),
                            onChanged: (value) {
                              if(value ?? false) {
                                if(!_playlistsToAdd.contains(playlist.id)) {
                                  _playlistsToAdd.add(playlist.id!);
                                }
                              } else {
                                if(_playlistsToAdd.contains(playlist.id)) {
                                  _playlistsToAdd.remove(playlist.id!);
                                }
                              }
                              setState(() {});
                            }
                        )).toList() ?? [Center(child: Text('Create a Playlist First!'))]
                    )
                  );
                }
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    child: Text('Cancel'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    }
                  ),
                  TextButton(
                    child: Text('Add', style: TextStyle(color: Colors.white)),
                    style: TextButton.styleFrom(backgroundColor: Colors.deepPurple),
                    onPressed: () async {
                      if(_playlistsToAdd.length > 0) {
                        //add item to all playlists in the list (store items as docs in subcollection)
                        await DBService().addItemToPlaylist(item: widget.item, playlists: _playlistsToAdd);
                        Navigator.of(context).pop();
                      } else {
                        await showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              content: Text('You haven\'t selected any playlists!'),
                              actions: [
                                TextButton(
                                  child: Text('OK'),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  }
                                )
                              ],
                            );
                          }
                        );
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

class CreatePlaylistDialog extends StatefulWidget {

  _CreatePlaylistDialogState createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<CreatePlaylistDialog> {
  String playlistGenre = 'General';
  String? playlistTitle;
  String? playlistTags;
  bool? private = false;
  String? playlistTitleError;

  @override
  build(BuildContext context) {
    return SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
        contentPadding: EdgeInsets.all(10),
        title: Text('Create Playlist', textAlign: TextAlign.center),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DropdownButton<String>(
                items: ['General', 'Business', 'Comedy', 'Entertainment', 'Music', 'News', 'Politics', 'Science', 'Sports', 'True Crime', 'Variety']
                    .map((String s) => DropdownMenuItem<String>(
                  value: s,
                  child: Text('$s'),
                )).toList(),
                value: playlistGenre,
                onChanged: (value) {
                  setState(() {
                    playlistGenre = value ?? 'General';
                  });
                },
              ),
              Row(
                children: [
                  Text('Private:'),
                  Checkbox(
                    value: private,
                    onChanged: (val) {
                      setState(() {
                        private = val;
                      });
                  })
                ]
              )

            ]
          ),
          TextField(
            decoration: InputDecoration(
              hintText: 'Playlist Title',
              errorText: playlistTitleError,
            ),
            onChanged: (value) {
              setState(() {
                playlistTitle = value;
              });
            },
          ),
          TextField(
            decoration: InputDecoration(
              hintText: 'Tags (separate by #)',
            ),
            maxLines: 2,
            onChanged: (value) {
              setState(() {
                playlistTags = value;
              });
            }
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
             TextButton(
               child: Text('Cancel'),
               onPressed: () {
                 Navigator.of(context).pop();
               }
             ),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  textStyle: TextStyle(color: Colors.white),
                ),
                child: Text('Create', style: TextStyle(color: Colors.white)),
                onPressed: () async {
                  //Validate form and create playlist
                  if(playlistTitle == null || playlistTitle?.length == 0) {
                    setState(() {
                      playlistTitleError = 'Please enter a title';
                    });
                  } else {
                    await DBService().createPlaylist(title: playlistTitle, genre: playlistGenre, tags: playlistTags, private: private);
                    Navigator.of(context).pop();
                  }
                }
              )
            ]
          )
        ]
    );
  }
}

class EditPlaylistDialog extends StatefulWidget {
  Playlist? playlist;

  EditPlaylistDialog({Key? key, @required this.playlist});

  _EditPlaylistDialogState createState() => _EditPlaylistDialogState();
}

class _EditPlaylistDialogState extends State<EditPlaylistDialog> {
  //String playlistGenre = 'General';
  //String? playlistTitle;
  //String? playlistTags;
  //bool? private = false;
  String? playlistTitleError;

  @override
  build(BuildContext context) {
    return SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
        contentPadding: EdgeInsets.all(10),
        title: Text('Edit Playlist', textAlign: TextAlign.center),
        children: [
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<String>(
                  items: ['General', 'Business', 'Comedy', 'Entertainment', 'Music', 'News', 'Politics', 'Science', 'Sports', 'True Crime', 'Variety']
                      .map((String s) => DropdownMenuItem<String>(
                    value: s,
                    child: Text('$s'),
                  )).toList(),
                  value: widget.playlist?.genre,
                  onChanged: (value) {
                    setState(() {
                      widget.playlist?.genre = value ?? 'General';
                    });
                  },
                ),
                Row(
                    children: [
                      Text('Private:'),
                      Checkbox(
                          value: widget.playlist?.private,
                          onChanged: (val) {
                            setState(() {
                              widget.playlist?.private = val;
                            });
                          })
                    ]
                )

              ]
          ),
          TextFormField(
            decoration: InputDecoration(
              hintText: 'Playlist Title',
              errorText: playlistTitleError,
            ),
            initialValue: '${widget.playlist?.title}',
            onChanged: (value) {
              setState(() {
                widget.playlist?.title = value;
              });
            },
          ),
          TextFormField(
              decoration: InputDecoration(
                hintText: 'Tags (separate by #)',
              ),
              maxLines: 2,
              initialValue: '#${widget.playlist?.tagList?.join(' #')}',
              onChanged: (value) {
                RegExp tagChars = RegExp('[#0-9A-Za-z]*');
                String? tagString = tagChars.allMatches(value).map((match) => match[0]).join();
                //print('tagString: $tagString');
                List<String> tagList = tagString.split('#').toList().where((element) => element.length > 0).toList();
                setState(() {
                  widget.playlist?.tagList = tagList;
                });
              }
          ),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                    child: Text('Cancel'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    }
                ),
                TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      textStyle: TextStyle(color: Colors.white),
                    ),
                    child: Text('Save', style: TextStyle(color: Colors.white)),
                    onPressed: () async {
                      //Validate form and create playlist
                      if(widget.playlist?.title == null || widget.playlist?.title?.length == 0) {
                        setState(() {
                          playlistTitleError = 'Please enter a title';
                        });
                      } else {
                        await DBService().editPlaylist(widget.playlist);
                        Navigator.of(context).pop(widget.playlist);
                      }
                    }
                )
              ]
          )
        ]
    );
  }
}

class DiscoverPlaylists extends StatelessWidget {
  @override
  build(context) {
    return StreamBuilder<List<FeaturedPlaylistCategory>>(
      stream: DBService().streamFeaturedPlaylists(),
      builder: (context, AsyncSnapshot<List<FeaturedPlaylistCategory>> listSnap) {
        print('Stream featured playlist: ${listSnap.data}');
        if(!listSnap.hasData) {
          return Container();
        }
        return ListView(
            children: listSnap.data?.where((e) => (e.playlists?.length ?? 0) > 0).map((cat) {
              List<Widget> catWidgets = [
                Text('${cat.name}', style: TextStyle(fontSize: 24.0)),
                Divider(color: Colors.black,),
              ];
              catWidgets.addAll(cat.playlists?.map((id) {
                return FutureBuilder(
                    future: DBService().getPlaylist(id),
                    builder: (context, AsyncSnapshot<Playlist> playlistSnap) {
                      if(!playlistSnap.hasData) {
                        return Container();
                      }
                      Playlist? playlist = playlistSnap.data;
                      return Card(
                          color: Colors.deepPurple[50],
                          child: ListTile(
                            title: Text('${playlist?.title}'),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (context) => PlaylistPage(playlist: playlist,),
                              ));
                            },
                          )
                      );
                    }
                );
              }).toList() ?? []);
              return Column(
                  children: catWidgets
              );
            }).toList() ?? [Container()]
        );
      }
    );
  }
}