import 'package:Perkl/main.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:podcast_search/podcast_search.dart';
import 'package:flutter_html/flutter_html.dart';

import 'MainPageTemplate.dart';

class PodcastPage extends StatelessWidget {
  Podcast podcast;

  PodcastPage(this.podcast);

  @override
  build(BuildContext context) {
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    return podcast == null ? Center(child: CircularProgressIndicator()) : MainPageTemplate(
      bottomNavIndex: 3,
      noBottomNavSelected: true,
      body: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.all(5),
                  child: Container(
                    height: 75,
                    width: 75,
                    decoration: podcast.image == null ? BoxDecoration(color: Colors.purple) : BoxDecoration(
                      image: DecorationImage(image: NetworkImage(podcast.image), fit: BoxFit.cover,),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      SizedBox(height: 10),
                      Text(podcast.title, style: TextStyle(fontSize: 18, color: Colors.black)),
                      Container(
                        height: 100,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: Html(
                            data: podcast.description,
                          ),
                        ),
                      ),
                    ],
                  )
                )
              ],
            ),
            Expanded(
              child: ListView(
                children: podcast.episodes.map((Episode ep) {
                  if(ep.author == null)
                    ep.author = podcast.title;
                  return ListTile(
                    title: Text(ep.title),
                    subtitle: Text('${DateFormat().format(ep.publicationDate)}'),
                    trailing: Column(
                      children: <Widget>[
                        InkWell(
                          child: Container(
                            height: 35,
                            width: 35,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: mp.currentPostId == ep.contentUrl ? Colors.red : Colors.deepPurple,
                            ),
                            child: Center(child: FaIcon(mp.currentPostId == ep.contentUrl && mp.isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play, color: Colors.white, size: 16,)),
                          ),
                          onTap: () {
                            if(mp.currentPostId == ep.contentUrl && mp.isPlaying) {
                              mp.pausePost();
                              return;
                            }
                            mp.playPost(episode: ep);
                          }
                        ),
                        ep.duration == null ? Text('') : Text(Duration(seconds: ep.duration).inSeconds.toString()),
                      ]
                    ),
                  );
                }).toList(),
              )
            )
          ]
      ),
    );
  }
}