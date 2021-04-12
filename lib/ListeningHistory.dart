import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:audio_service/audio_service.dart';
import 'package:podcast_search/podcast_search.dart';
import 'MainPageTemplate.dart';
import 'PodcastPage.dart';
import 'StreamTagPage.dart';
import 'EpisodePage.dart';
import 'ConversationPage.dart';
import 'services/ActivityManagement.dart';
import 'services/local_services.dart';
import 'services/models.dart';
import 'main.dart';

class ListeningHistoryPage extends StatefulWidget {

  _ListeningHistoryPageState createState() => _ListeningHistoryPageState();
}

class _ListeningHistoryPageState extends State<ListeningHistoryPage> {
  LocalService _historyLocalService = new LocalService(filename: 'history.json');

  Future<List<MediaItem>> getHistory() async {
    List<MediaItem> listeningHistory = await _historyLocalService.getData('items').then((dynamic itemList) {
      if(itemList == null) {
        return null;
      }
      List<MediaItem> mediaItemList = (itemList as List).map((item) => MediaItem.fromJson(item)).toList();
      if(mediaItemList != null) {
        mediaItemList.sort((MediaItem a, MediaItem b) {
          //print('${a.extras['listenDate'] ?? 0} >>> ${b.extras['listenDate'] ?? 0}');
          return Comparable.compare(a.extras['listenDate'] ?? 0, b.extras['listenDate'] ?? 0);
        });
      }
      return mediaItemList.reversed.toList();
    });
    return listeningHistory;
  }

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

  @override
  build(BuildContext context) {
    List<Widget> historyWidgets = <Widget>[];
    return MainPageTemplate(
      bottomNavIndex: 1,
      noBottomNavSelected: true,
      body: FutureBuilder(
        future: getHistory(),
        builder: (context, AsyncSnapshot<List<MediaItem>> historySnap) {
          if(historySnap.hasData) {
            historyWidgets.addAll(historySnap.data.map((MediaItem item) {
              print('Position: ${item.extras['position']}');
              print('Duration: ${item.duration}');
              return Card(
                  color: Colors.deepPurple[50],
                  margin: EdgeInsets.all(5),
                  elevation: 5,
                  child: Padding(
                      padding: EdgeInsets.all(5),
                      child: ListTile(
                        title: Text(item.title),
                        subtitle: Text(item.artist),
                        trailing: Text('${ActivityManager().getDurationString(Duration(milliseconds: item.extras['position']))}/${ActivityManager().getDurationString(item.duration)}'),
                        onTap: () {
                          tapItemTile(item);
                        },
                      )
                  )
              );
            }).toList());
            return ListView(
                children: historyWidgets
            );
          }
          return Center(child: Text('Your listening history is still empty! Try listening to some podcasts or posts.', textAlign: TextAlign.center,));
        },
      ),
    );
  }
}