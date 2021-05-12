import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:podcast_search/podcast_search.dart';
import 'PodcastPage.dart';

class DiscoverPodcasts extends StatelessWidget {

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
                      DropdownMenuItem(child: Text('All'), value: Genre.ALL),
                      DropdownMenuItem(child: Text(Genre.ARTS.name), value: Genre.ARTS),
                      DropdownMenuItem(child: Text(Genre.BUSINESS.name), value: Genre.BUSINESS),
                      DropdownMenuItem(child: Text(Genre.COMEDY.name), value: Genre.COMEDY),
                      DropdownMenuItem(child: Text(Genre.EDUCATION.name), value: Genre.EDUCATION),
                      DropdownMenuItem(child: Text(Genre.FICTION.name), value: Genre.FICTION),
                      DropdownMenuItem(child: Text(Genre.GOVERNMENT.name), value: Genre.GOVERNMENT),
                      DropdownMenuItem(child: Text(Genre.HEALTH_FITNESS.name), value: Genre.HEALTH_FITNESS),
                      DropdownMenuItem(child: Text(Genre.HISTORY.name), value: Genre.HISTORY),
                      DropdownMenuItem(child: Text(Genre.KIDS_FAMILY.name), value: Genre.KIDS_FAMILY),
                      DropdownMenuItem(child: Text(Genre.LEISURE.name), value: Genre.LEISURE),
                      DropdownMenuItem(child: Text(Genre.MUSIC.name), value: Genre.MUSIC),
                      DropdownMenuItem(child: Text(Genre.NEWS.name), value: Genre.NEWS),
                      DropdownMenuItem(child: Text(Genre.RELIGION_SPIRITUALITY.name), value: Genre.RELIGION_SPIRITUALITY),
                      DropdownMenuItem(child: Text(Genre.SCIENCE.name), value: Genre.SCIENCE),
                      DropdownMenuItem(child: Text(Genre.SOCIETY_CULTURE.name), value: Genre.SOCIETY_CULTURE),
                      DropdownMenuItem(child: Text(Genre.SPORTS.name), value: Genre.SPORTS),
                      DropdownMenuItem(child: Text(Genre.TV_FILM.name), value: Genre.TV_FILM),
                      DropdownMenuItem(child: Text(Genre.TECHNOLOGY.name), value: Genre.TECHNOLOGY),
                      DropdownMenuItem(child: Text(Genre.TRUE_CRIME.name), value: Genre.TRUE_CRIME)
                    ],
                  value: dpp.selectedGenre,
                  onChanged: (Genre? value) {
                      print('Selected Genre ID: $value');
                      dpp.changeGenre(value ?? Genre.ALL);
                  },
                ),
                Expanded(
                  child: FutureProvider<void>(
                    initialData: null,
                      create: (_) => dpp.getPodcasts(),
                      child: Consumer<void>(
                        builder: (context, none, _) {
                          print('Podcasts Num: ${dpp.podcasts == null ? '' : dpp.podcasts?.length}');
                          return dpp.podcasts == null ? Center(child: CircularProgressIndicator()) : ListView(
                            children: dpp.podcasts?.map((pod) {
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
                                          image: DecorationImage(image: NetworkImage(pod.artworkUrl60 ?? ''), fit: BoxFit.cover)
                                      ) : BoxDecoration(
                                        color: Colors.deepPurple,
                                      ),
                                      child: pod == null || pod.artworkUrl60 == null ? Text('${pod.collectionName?.substring(0, 1)}') : Container(),
                                    ),
                                    title: Text(pod.collectionName ?? '', style: TextStyle(fontSize: 16)),
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
                            }).toList() ?? [Container()],
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
  Genre selectedGenre = Genre.ALL;
  List<Item>? podcasts;


  changeGenre(Genre newGenre) async {
    selectedGenre = newGenre;
    podcasts = null;
    notifyListeners();
    await getPodcasts();
  }

  Future<void> getPodcasts() async {
    SearchResult searchResult =  await Search().charts(country: Country.UNITED_STATES, limit: 30, explicit: true, genre: selectedGenre);
    print(searchResult.items);
    podcasts = searchResult.items?.toList();
    notifyListeners();
    return;
  }
}

/*
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
*/
