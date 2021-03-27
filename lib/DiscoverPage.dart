import 'package:Perkl/services/db_services.dart';
import 'package:Perkl/services/models.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:podcast_search/podcast_search.dart';

import 'ConversationPage.dart';
import 'MainPageTemplate.dart';
import 'PageComponents.dart';
import 'HomePage.dart';
import 'ProfilePage.dart';
import 'ListPage.dart';
import 'Timeline.dart';
import 'DiscoverPodcasts.dart';

import 'main.dart';
import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';


//--------------------------------------------------------------------------
//-----------------New Version----------------------------------------------
class DiscoverPageMobile extends StatelessWidget {

  @override
  build(BuildContext context) {
    User firebaseUser = Provider.of<User>(context);
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    return MultiProvider(
      providers: [
        StreamProvider<PerklUser>(create: (_) => UserManagement().streamCurrentUser(firebaseUser)),
        ChangeNotifierProvider<DiscoverPageMobileProvider>(create: (_) => DiscoverPageMobileProvider()),
        FutureProvider<List<DiscoverTag>>(create: (_) => DBService().getDiscoverTags()),
      ],
      child: Consumer<PerklUser>(
          builder: (context, user, _) {
            DiscoverPageMobileProvider pageProvider = Provider.of<DiscoverPageMobileProvider>(context);
            List<DiscoverTag> discoverTags = Provider.of<List<DiscoverTag>>(context);
            print('DiscoverTags: $discoverTags');
            String firstTag = discoverTags != null ? discoverTags.first.value : null;
            print('Current Tag: ${pageProvider.selectedTag ?? firstTag}');
            return user == null ? Center(child: CircularProgressIndicator()) : MainPageTemplate(
              bottomNavIndex: 1,
              body: Column(
                children: <Widget>[
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        TextButton(
                          child: Text('Pods',
                            style: TextStyle(color: pageProvider.selectedCat == 'Pods' ? Colors.white : Colors.deepPurple),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: pageProvider.selectedCat == 'Pods' ? Colors.deepPurple : Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15.0),
                              side: BorderSide(color: Colors.deepPurple),
                            ),
                          ),
                          onPressed: () {
                            pageProvider.selectCategory('Pods');
                          },
                        ),
                        TextButton(
                          child: Text('People',
                            style: TextStyle(color: pageProvider.selectedCat == 'People' ? Colors.white : Colors.deepPurple),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: pageProvider.selectedCat == 'People' ? Colors.deepPurple : Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15.0),
                              side: BorderSide(color: Colors.deepPurple),
                            ),
                          ),
                          onPressed: () {
                            pageProvider.selectCategory('People');
                          },
                        ),
                      ]
                  ),
                  /*
                  pageProvider.selectedCat == 'Tags' ? Expanded(
                    child: Column(
                      children: <Widget>[
                        Container(
                          height: 35,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: discoverTags == null ? [Container()]
                                : discoverTags.map((tag) {
                                  if(pageProvider.selectedTag == null && tag.rank == 1)
                                    firstTag = tag.value;
                                  return FlatButton(
                                    color: pageProvider.selectedTag == null && tag.rank == 1 ? Colors.deepPurple : pageProvider.selectedTag == tag.value ? Colors.deepPurple : Colors.white,
                                    child: Text('#${tag.value}', style: TextStyle(color: pageProvider.selectedTag == null && tag.rank == 1 ? Colors.white : pageProvider.selectedTag == tag.value ? Colors.white : Colors.deepPurple)),
                                    onPressed: () {
                                      pageProvider.selectTag(tag.value);
                                    },
                                  );
                            }).toList(),
                          ),
                        ),
                        Expanded(
                          child: (pageProvider == null || pageProvider.selectedTag == null) && firstTag == null ? Center(child: CircularProgressIndicator()) : Timeline(tagStream: DBService().streamTagPosts(pageProvider.selectedTag ?? firstTag), type: TimelineType.STREAMTAG,),
                        )
                      ],
                    ),
                  ) :
                  */ pageProvider.selectedCat == 'People' ? Expanded(
                    child: StreamProvider<List<String>>(
                      create: (context) => DBService().streamDiscoverPods(),
                      child: Consumer<List<String>>(
                        builder: (context, userList, _) {
                          if(userList == null)
                            return Center(child: CircularProgressIndicator());
                          return SingleChildScrollView(
                            child: Column(
                              children: userList.map((userId) => StreamProvider<PerklUser>(
                                  create: (context) => UserManagement().streamUserDoc(userId),
                                  child: Consumer<PerklUser>(
                                      builder: (context, user, _) {
                                        return user == null ? Container()
                                            : Card(
                                          elevation: 5,
                                          margin: EdgeInsets.all(5),
                                          child: ListTile(
                                            contentPadding: EdgeInsets.fromLTRB(5, 5, 5, 5),
                                            //Leading of list tile for pods
                                            leading: user.profilePicUrl != null ? Container(
                                                height: 50.0,
                                                width: 50.0,
                                                decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.deepPurple,
                                                    image: DecorationImage(
                                                        fit: BoxFit.cover,
                                                        image: NetworkImage(user.profilePicUrl)
                                                    )
                                                )
                                            ) : Container(
                                                height: 50.0,
                                                width: 50.0,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.deepPurple,
                                                )
                                            ),
                                            title: Text('${user.username}', style: TextStyle(fontSize: 18)),
                                            trailing: Container(
                                              width: 50,
                                              child: Row(
                                                children: <Widget>[
                                                  FaIcon(FontAwesomeIcons.users, color: Colors.black, size: 16,),
                                                  SizedBox(width: 5),
                                                  Text('${user.followers != null ? user.followers.length.toString() : '0'}', style: TextStyle(fontSize: 16))
                                                ],
                                              ),
                                            ),
                                            onTap: () {
                                              Navigator.push(context, MaterialPageRoute(
                                                builder: (context) =>
                                                    ProfilePageMobile(userId: user.uid,),
                                              ));
                                            },
                                          ),
                                        );
                                      }
                                  )
                              )).toList(),
                            )
                          );
                        }
                      )
                    )
                  ) : Expanded(
                    child: DiscoverPodcasts(),
                  ),
                ],
              ),
            );
          }
      ),
    );
  }
}

class DiscoverPageMobileProvider extends ChangeNotifier {
  String selectedCat = 'Pods';
  String selectedTag;

  void selectCategory(String value) {
    selectedCat = value;
    notifyListeners();
  }

  void selectTag(String value) {
    selectedTag = value;
    notifyListeners();
  }


}