import 'package:Perkl/MainPageTemplate.dart';
//import 'package:Perkl/main.dart';
//import 'package:Perkl/services/db_services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:podcast_search/podcast_search.dart';

import 'ProfilePage.dart';
import 'PodcastPage.dart';
import 'MainPageTemplate.dart';

import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';
import 'services/models.dart';


//New Version
class SearchPageMobile extends StatelessWidget {
  DocumentReference searchRequestDoc = FirebaseFirestore.instance.collection('requests').doc();
  @override
  build(BuildContext context) {
    User? firebaseUser = Provider.of<User?>(context);
    return MultiProvider(
      providers: [
        StreamProvider<PerklUser?>(create: (_) => UserManagement().streamCurrentUser(firebaseUser), initialData: null),
        ChangeNotifierProvider<SearchPageProvider>(create: (_) => SearchPageProvider()),
      ],
      child: Consumer<PerklUser?>(
        builder: (context, currentUser, _) {
          SearchPageProvider spp = Provider.of<SearchPageProvider>(context);
          return MainPageTemplate(
            bottomNavIndex: 1,
            noBottomNavSelected: true,
            showSearchBar: true,
            searchRequestId: searchRequestDoc.id,
            body: Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    TextButton(
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(25)), side: BorderSide(color: Colors.deepPurple, width: 2)),
                        backgroundColor: spp.type == SearchType.PEOPLE ? Colors.deepPurple : Colors.transparent,
                      ),
                      child: Text('People', style: TextStyle(color: spp.type == SearchType.PEOPLE ? Colors.white : Colors.deepPurple)),
                      onPressed: () {
                        spp.changeSearchType(SearchType.PEOPLE);
                      },
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(25)), side: BorderSide(color: Colors.deepPurple, width: 2)),
                        backgroundColor: spp.type == SearchType.PODCASTS ? Colors.deepPurple : Colors.transparent,
                      ),
                      child: Text('Podcasts', style: TextStyle(color: spp.type == SearchType.PODCASTS ? Colors.white : Colors.deepPurple)),
                      onPressed: () {
                        spp.changeSearchType(SearchType.PODCASTS);
                      }
                    )
                  ]
                ),
                Expanded(
                  child: StreamBuilder(
                      stream: searchRequestDoc.snapshots(),
                      builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> asyncSearchDocSnap) {
                        print('Search Request Doc Snap: $asyncSearchDocSnap');
                        if(spp.type == SearchType.PODCASTS && asyncSearchDocSnap.hasData) {
                          if(asyncSearchDocSnap.data == null || asyncSearchDocSnap.data?.data() == null)
                            return Center(child: CircularProgressIndicator());
                          return FutureBuilder<SearchResult?>(
                            future: Search().search(asyncSearchDocSnap.data?.data()?['searchTerm'], limit: 50),
                            builder: (context, AsyncSnapshot<SearchResult?> searchResultSnap) {
                              print('Search Term: ${asyncSearchDocSnap.data?.data()?['searchTerm']}\nSnap: $searchResultSnap');
                              if(!searchResultSnap.hasData)
                                return Center(child: Text('Sorry...No results for this search'));
                              return ListView(
                                children: searchResultSnap.data?.items?.map((Item item) {
                                  return Card(
                                    margin: EdgeInsets.all(5),
                                    child: Padding(
                                      padding: EdgeInsets.all(5),
                                      child: ListTile(
                                        leading: Container(
                                          height: 50,
                                          width: 50,
                                          decoration: BoxDecoration(
                                              color: Colors.deepPurple,
                                              image: item.artworkUrl60 == null ? null : DecorationImage(
                                                  image: NetworkImage(item.artworkUrl60 ?? '')
                                              )
                                          ),
                                        ),
                                        title: Text(item.trackName ?? ''),
                                        onTap: () async {
                                          showDialog(
                                              context: context,
                                              builder: (context) {
                                                return Center(child: CircularProgressIndicator());
                                              }
                                          );
                                          Podcast podcast = await Podcast.loadFeed(url: item.feedUrl);
                                          Navigator.of(context).pop();
                                          Navigator.push(context, MaterialPageRoute(
                                            builder: (context) => PodcastPage(podcast),
                                          ));
                                        },
                                      )
                                    )
                                  );
                                }).toList() ?? [Container()],
                              );
                            },
                          );
                        }

                        List<String>? results;
                        if(asyncSearchDocSnap.data == null || asyncSearchDocSnap.data?.data() == null)
                          return Center(child: Text('There are no results for this search...'));
                        //print('Snapshot: $asyncSearchDocSnap/Snapshot term: ${asyncSearchDocSnap.data.data()['searchTerm']}/Results: ${asyncSearchDocSnap.data.data()["results"]}');
                        results = asyncSearchDocSnap.data?.data()?['results'] == null ? null : asyncSearchDocSnap.data?.data()?['results'].map<String>((value) => value.toString()).toList();
                        print('Query Results: $results');


                        if(results == null)
                          return Center(child: CircularProgressIndicator());

                        if(results.length == 0)
                          return Center(child: Text('There are no results for this search...'));

                        if (asyncSearchDocSnap.hasError) {
                          return Center(child: Text('Oops! We Messed Something Up... We\'re Sorry!'));
                          //return Text('Error: ${snapshot.error}');
                        }

                        if(asyncSearchDocSnap == null || asyncSearchDocSnap.data == null)
                          return Container();
                        switch (asyncSearchDocSnap.connectionState) {
                          case ConnectionState.waiting:
                            return Center(child: CircularProgressIndicator());
                          default:
                            return ListView(
                              children: asyncSearchDocSnap.data?.data()?['results'].map<Widget>((userId) {
                                print(userId);
                                return StreamBuilder<PerklUser>(
                                    stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots().map((snap) => PerklUser.fromFirestore(snap)),
                                    builder: (BuildContext context, AsyncSnapshot<PerklUser> userSnap) {
                                      if(!asyncSearchDocSnap.hasData)
                                        return Container();
                                      PerklUser? user = userSnap.data;
                                      Widget followButton = IconButton(
                                          icon: Icon(Icons.person_add),
                                          color: Colors.deepPurple,
                                          onPressed: () {
                                            ActivityManager().followUser(userId);
                                            print('now following ${user?.username}');
                                          }
                                      );

                                      return user == null ? Container() : Card(
                                        margin: EdgeInsets.all(5),
                                        child: Padding(
                                          padding: EdgeInsets.all(5),
                                          child: ListTile(
                                              leading: user == null || user.profilePicUrl == null  ? Container(
                                                  height: 50.0,
                                                  width: 50.0,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.deepPurple,
                                                  )
                                              ) : Container(
                                                  height: 50.0,
                                                  width: 50.0,
                                                  decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.deepPurple,
                                                      image: DecorationImage(
                                                          fit: BoxFit.cover,
                                                          image: NetworkImage(user.profilePicUrl ?? '')
                                                      )
                                                  )
                                              ),
                                              title: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: <Widget>[
                                                    Expanded(
                                                        child: Text(user.username ?? '')
                                                    ),
                                                    Container(
                                                        height: 40.0,
                                                        width: 40.0,
                                                        child: currentUser == null || user == null || currentUser.uid == user.uid || (currentUser.following?.contains(user.uid) ?? false) ? Container() : followButton
                                                    )
                                                  ]
                                              ),
                                              onTap: () {
                                                print(
                                                    'go to user profile: ${user.username}');
                                                Navigator.push(context, MaterialPageRoute(
                                                  builder: (context) =>
                                                      ProfilePageMobile(
                                                        userId: user.uid,),
                                                ));
                                              }
                                          ),
                                        )
                                      );
                                    }
                                );
                              }).toList(),
                            );
                        }
                      }
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}

enum SearchType {
  PEOPLE,
  PODCASTS
}

class SearchPageProvider extends ChangeNotifier {
  SearchType type = SearchType.PEOPLE;

  changeSearchType(SearchType newType) {
    type = newType;
    notifyListeners();
  }
}