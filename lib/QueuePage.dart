import 'package:Perkl/ConversationPage.dart';
import 'package:Perkl/MainPageTemplate.dart';
import 'package:Perkl/PodcastPage.dart';
import 'package:audio_service/audio_service.dart';
import 'package:podcast_search/podcast_search.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'main.dart';
import 'services/models.dart';
import 'StreamTagPage.dart';
import 'EpisodePage.dart';

class QueuePage extends StatelessWidget {

  @override
  build(BuildContext context) {
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    PlaybackState playbackState = Provider.of<PlaybackState>(context);
    MediaItem currentMediaItem = Provider.of<MediaItem>(context);
    List<MediaItem> queueItems = Provider.of<List<MediaItem>>(context);
    List<Widget> queueWidgets = <Widget>[];

    tapItemTile(MediaItem item) async {
      print('item tapped: $item');
      if(item.extras['type'] == 'PostType.PODCAST_EPISODE') {
        showDialog(
          context: context,
          builder: (context) {
            return Center(child: CircularProgressIndicator());
          }
        );
        Podcast podcast = await Podcast.loadFeed(url: item.extras['podcast_url']);
        Map<String, dynamic> episodeMap = item.extras['episode'];
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
      if(item.extras['type'] == 'PostType.EPISODE_REPLY'){
        showDialog(
            context: context,
            builder: (context) {
              return Center(child: CircularProgressIndicator());
            }
        );
        Podcast podcast = await Podcast.loadFeed(url: item.extras['podcast_url']);
        Map<String, dynamic> episodeMap = item.extras['episode'];
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
      if(item.extras['type'] == 'PostType.POST') {
        Map<String, dynamic> postMap = item.extras['post'];
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
                title: Center(child: Text(post.postTitle ?? DateFormat("MMMM dd, yyyy @ hh:mm").format(post.datePosted).toString())),
                contentPadding: EdgeInsets.all(10),
                children: <Widget>[
                  Text('Posted By:\n@${post.username}', textAlign: TextAlign.center, style: TextStyle(fontSize: 16),),
                  post.postValue != null ? Text('${post.postValue ?? ''}') : Container(),
                  SizedBox(height: 10),
                  Text('Date Posted:\n${DateFormat("MMMM dd, yyyy @ hh:mm").format(post.datePosted).toString()}', textAlign: TextAlign.center, style: TextStyle(fontSize: 16),),
                  SizedBox(height: 10),
                  post.streamList != null && post.streamList.length > 0 ? Wrap(
                    spacing: 8,
                    children: post.streamList.map((tag) => InkWell(
                        child: Text('#$tag', style: TextStyle(color: Colors.lightBlue)),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                              builder: (context) => StreamTagPageMobile(tag: tag,)
                          ));
                        }
                    )).toList(),
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
      if(item.extras['type'] == 'PostType.DIRECT_POST') {
        if(item.extras['clip'] != null ? item.extras['clip'] : false) {
          await showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      child: Text('Go To Episode', style: TextStyle(color: Colors.white)),
                      style: TextButton.styleFrom(backgroundColor: Colors.deepPurple),
                      onPressed: () async {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return Center(child: CircularProgressIndicator());
                          }
                        );
                        print('Episode: ${item.extras['episode']}');
                        Episode ep = Episode.fromJson(item.extras['episode']);
                        Podcast podcast = await Podcast.loadFeed(url: item.extras['podcast_url']);
                        Navigator.of(context).pop();
                        Navigator.push(context, MaterialPageRoute(
                            builder: (context) => EpisodePage(ep, podcast)
                        ));
                      }
                    ),
                    TextButton(
                        child: Text('Go To Conversation', style: TextStyle(color: Colors.white)),
                        style: TextButton.styleFrom(backgroundColor: Colors.deepPurple),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(
                              builder: (context) => ConversationPageMobile(conversationId: item.extras['conversationId'],)
                          ));
                        }
                    ),
                    OutlinedButton(
                        child: Text('Cancel', style: TextStyle(color: Colors.deepPurple)),
                        style: OutlinedButton.styleFrom(primary: Colors.deepPurple),
                        onPressed: () {
                          Navigator.of(context).pop();
                        }
                    ),
                  ]
                )
              );
            }
          );
        } else {
          Navigator.push(context, MaterialPageRoute(
              builder: (context) => ConversationPageMobile(conversationId: item.extras['conversationId'],)
          ));
        }
      }
    }

    if(currentMediaItem != null) {
      queueWidgets.add(Card(
          color: Colors.greenAccent[100],
          margin: EdgeInsets.all(5),
          child: Padding(
            padding: EdgeInsets.all(5),
            child: ListTile(
              title: Text(currentMediaItem.title),
              subtitle: Text(currentMediaItem.artist),
              onTap: () {
                tapItemTile(currentMediaItem);
              },
            ),
          )
      ));
    }
    queueWidgets.addAll(queueItems.map((MediaItem item) {
      return Card(
          color: Colors.deepPurple[50],
          margin: EdgeInsets.all(5),
          elevation: 5,
          child: Padding(
              padding: EdgeInsets.all(5),
              child: ListTile(
                title: Text(item.title),
                subtitle: Text(item.artist),
                trailing: Container(
                  width: 85,
                  child: Column(
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
                                  color: currentMediaItem != null && currentMediaItem.id == item.id ? Colors.red : Colors.deepPurple
                              ),
                              child: Center(child: FaIcon(currentMediaItem != null && currentMediaItem.id == item.id && playbackState.playing != null && playbackState.playing ? FontAwesomeIcons.pause : FontAwesomeIcons.play, color: Colors.white, size: 16)),
                            ),
                            onTap: () {
                              playbackState.playing != null && playbackState.playing && mp.currentPostPodId == item.id ? mp.pausePost() : mp.playMediaItem(item);
                            },
                          ),
                          SizedBox(width: 5,),
                          InkWell(
                            child: Container(
                              height: 35,
                              width: 35,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.redAccent,
                              ),
                              child: Center(child: FaIcon(FontAwesomeIcons.minus, color: Colors.white, size: 16)),
                            ),
                            onTap: () {
                              mp.removeQueueItem(item);
                            },
                          )
                        ],
                      )
                    ],
                  ),
                ),
                onTap: () {
                  tapItemTile(item);
                },
              )
          )
      );
    }).toList());
    return MainPageTemplate(
      bottomNavIndex: 1,
      noBottomNavSelected: true,
      body: queueWidgets.length == 0 ? Center(child: Text('Your queue is empty...')) : ListView(
        children: queueWidgets,
      ),
    );
  }
}