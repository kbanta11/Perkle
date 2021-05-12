import 'package:flutter/material.dart';
import 'MainPageTemplate.dart';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'services/db_services.dart';
import 'services/models.dart';

class PlaylistListPage extends StatelessWidget {
  @override
  build(BuildContext context) {
    User? firebaseUser = Provider.of<User?>(context);
    return MainPageTemplate(
      bottomNavIndex: 2,
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Playlist>?>(
              stream: DBService().streamMyPlaylists(firebaseUser?.uid),
              builder: (BuildContext context, AsyncSnapshot<List<Playlist>?> listSnap) {
                return ListView(
                    children: listSnap.data?.map((playlist) => Card(
                      child: ListTile(
                        title: Text('${playlist.title}'),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => PlaylistPage(playlist: playlist,),
                          ));
                        },
                      )
                    )).toList() ?? [Center(child: Text('Create a Playlist First!'))]
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
  @override
  build(BuildContext context) {
    return MainPageTemplate(
      bottomNavIndex: 2,
      body: Column(
        children: [
          Text('${widget.playlist?.title}', style: TextStyle(fontSize: 18.0)),
          Text('@${widget.playlist?.creatorUsername}'),
          Divider(),
          Expanded(
            child: StreamBuilder<List<MediaItem>>(
              stream: widget.playlist!.getItems(),
              builder: (context, AsyncSnapshot<List<MediaItem>> listSnap) {
                return ListView(
                  children: listSnap.data?.map((item) {
                    //get image url
                    Widget itemImage() {
                      String? imageUrl = item.extras?['podcast_image'];
                      bool isUser = imageUrl == null;
                      if(isUser) {

                      }
                      return Container(
                        height: 65.0,
                        width: 65.0,
                        decoration: BoxDecoration(
                            shape: BoxShape.rectangle,
                            color: Colors.deepPurple,
                            image: DecorationImage(
                                fit: BoxFit.cover,
                                image: NetworkImage(_post.podcast?.image ?? 'gs://flutter-fire-test-be63e.appspot.com/FCMImages/logo.png')
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
                            Podcast pod = await Podcast.loadFeed(url: _post.podcast?.url);
                            Navigator.of(context).pop();
                            Navigator.push(context, MaterialPageRoute(
                              builder: (context) =>
                                  PodcastPage(pod,),
                            ));
                          },
                        ),
                      );
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
                                      itemImage(),
                                      SizedBox(width: 5),
                                      Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('${_post.title}', textAlign: TextAlign.start,),
                                              Text('${_post.podcast?.title}', textAlign: TextAlign.start, style: TextStyle(fontSize: 12, color: Colors.black45),),
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
                                                          child: Center(child: FaIcon(currentMediaItem != null && currentMediaItem.id == _post.contentUrl && (playbackState?.playing ?? false) ? FontAwesomeIcons.pause : FontAwesomeIcons.play, color: Colors.white, size: 16,)),
                                                        ),
                                                        onTap: () {
                                                          if(currentMediaItem != null && currentMediaItem.id == _post.contentUrl && (playbackState?.playing ?? false)) {
                                                            mp.pausePost();
                                                            return;
                                                          }
                                                          mp.playPost(PostPodItem.fromEpisode(post, post.podcast));
                                                        }
                                                    ),
                                                    SizedBox(width: 5),
                                                    PopupMenuButton(
                                                      child: Container(
                                                        height: 35,
                                                        width: 35,
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          color: mediaQueue != null && mediaQueue.where((item) => item.id == _post.contentUrl).length > 0  ? Colors.grey : Colors.deepPurple,
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
                                                          if(mediaQueue == null || mediaQueue.where((item) => item.id == _post.contentUrl).length == 0) {
                                                            mp.addPostToQueue(PostPodItem.fromEpisode(post, post.podcast));
                                                          }
                                                        }

                                                        if(value == 'playlist') {
                                                          await showDialog(
                                                              context: context,
                                                              builder: (context) {
                                                                return AddToPlaylistDialog(item: PostPodItem.fromEpisode(post, post.podcast).toMediaItem(),);
                                                              }
                                                          );
                                                        }
                                                      },
                                                    ),
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
                                  post.podcast = await Podcast.loadFeed(url: post.podcast?.url);
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
                  }).toList() ?? [Center(child: Text('Oh No! This Playlist is Empty!', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)))]
                );
              }
            )
          )
        ]
      )
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
        contentPadding: EdgeInsets.all(10),
        title: Text('Create Playlist', textAlign: TextAlign.center),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DropdownButton<String>(
                items: ['General', 'Business', 'Comedy', 'Entertainment', 'Music', 'News', 'Politics', 'Science', 'Sports', 'Variety']
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