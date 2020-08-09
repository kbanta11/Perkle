import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:podcast_search/podcast_search.dart';
import 'PodcastPage.dart';

class DiscoverPodcasts extends StatelessWidget {
  Genre genres = new Genre();

  @override
  build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DiscoverPodcastsProvider>(create: (_) => DiscoverPodcastsProvider())
      ],
      child: Consumer<DiscoverPodcastsProvider>(
        builder: (context, dpp, _) {
          return Column(
              children: <Widget>[
                DropdownButton(
                    icon: Icon(Icons.arrow_drop_down),
                    items: [
                      DropdownMenuItem(child: Text('All'), value: null),
                      DropdownMenuItem(child: Text('Arts'), value: genres.arts),
                      DropdownMenuItem(child: Text('Business'), value: genres.business),
                      DropdownMenuItem(child: Text('Comedy'), value: genres.comedy),
                      DropdownMenuItem(child: Text('Education'), value: genres.education),
                      DropdownMenuItem(child: Text('Fiction'), value: genres.fiction),
                      DropdownMenuItem(child: Text('Government'), value: genres.government),
                      DropdownMenuItem(child: Text('Health & Fitness'), value: genres.health_fitness),
                      DropdownMenuItem(child: Text('History'), value: genres.history),
                      DropdownMenuItem(child: Text('Kids & Family'), value: genres.kids_family),
                      DropdownMenuItem(child: Text('Leisure'), value: genres.leisure),
                      DropdownMenuItem(child: Text('Music'), value: genres.music),
                      DropdownMenuItem(child: Text('News'), value: genres.news),
                      DropdownMenuItem(child: Text('Religion & Spirituality'), value: genres.religion_spirituality),
                      DropdownMenuItem(child: Text('Science'), value: genres.science),
                      DropdownMenuItem(child: Text('Society & Culture'), value: genres.society_culture),
                      DropdownMenuItem(child: Text('Sports'), value: genres.sports),
                      DropdownMenuItem(child: Text('TV & Film'), value: genres.tv_film),
                      DropdownMenuItem(child: Text('Technology'), value: genres.technology),
                      DropdownMenuItem(child: Text('True Crime'), value: genres.true_crime)
                    ],
                  value: dpp.selectedGenre,
                  onChanged: (value) {
                      print('Selected Genre ID: $value');
                      dpp.changeGenre(value);
                  },
                ),
                Expanded(
                  child: FutureProvider<void>(
                      create: (_) => dpp.getPodcasts(),
                      child: Consumer<void>(
                        builder: (context, none, _) {
                          print('Podcasts Num: ${dpp.podcasts == null ? '' : dpp.podcasts.length}');
                          return dpp.podcasts == null ? Center(child: CircularProgressIndicator()) : ListView(
                            children: dpp.podcasts.map((pod) {
                              return Card(
                                margin: EdgeInsets.all(5),
                                elevation: 5,
                                child: Padding(
                                  padding: EdgeInsets.all(5),
                                  child: ListTile(
                                    leading: Container(
                                      height: 50,
                                      width: 50,
                                      decoration: pod != null && pod.collectionName != null ? BoxDecoration(
                                          image: DecorationImage(image: NetworkImage(pod.artworkUrl60), fit: BoxFit.cover)
                                      ) : BoxDecoration(
                                        color: Colors.deepPurple,
                                      ),
                                      child: pod == null || pod.artworkUrl60 == null ? Text('${pod.collectionName.substring(0, 1)}') : Container(),
                                    ),
                                    title: Text(pod.collectionName, style: TextStyle(fontSize: 16)),
                                    onTap: () async {
                                      showDialog(
                                          context: context,
                                          builder: (context) {
                                            return Center(child: CircularProgressIndicator());
                                          }
                                      );
                                      Podcast goToPodcast = await Podcast.loadFeed(url: pod.feedUrl);
                                      Navigator.of(context).pop();
                                      Navigator.push(context, MaterialPageRoute(
                                        builder: (context) => PodcastPage(goToPodcast),
                                      ));
                                    },
                                  )
                                ),
                              );
                            }).toList(),
                          );
                        },
                      )
                  ),
                )
              ]
          );
        },
      ),
    );
  }
}

class DiscoverPodcastsProvider extends ChangeNotifier {
  Search podcastSearch = new Search();
  int selectedGenre;
  List<Item> podcasts;


  changeGenre(int newGenre) async {
    selectedGenre = newGenre;
    podcasts = null;
    notifyListeners();
    await getPodcasts();
  }

  Future<void> getPodcasts() async {
    SearchResult searchResult =  await Search().charts(country: Country.UNITED_STATES, limit: 30, explicit: true, genre: selectedGenre);
    print(searchResult.items);
    podcasts = searchResult.items.toList();
    notifyListeners();
    return;
  }
}

class Genre {
  int arts = 1301;
  int business = 1321;
  int comedy = 1303;
  int education = 1304;
  int fiction = 1483;
  int government = 1511;
  int health_fitness = 1512;
  int history = 1487;
  int kids_family = 1305;
  int leisure = 1502;
  int music = 1301;
  int news = 1489;
  int religion_spirituality = 1314;
  int science = 1533;
  int society_culture = 1324;
  int sports = 1545;
  int tv_film = 1309;
  int technology = 1318;
  int true_crime = 1488;
}

