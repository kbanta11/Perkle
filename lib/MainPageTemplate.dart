import 'package:Perkl/DiscoverPage.dart';
import 'package:Perkl/ListPage.dart';
import 'package:Perkl/ProfilePage.dart';
import 'package:Perkl/main.dart';
import 'package:Perkl/services/ActivityManagement.dart';
import 'package:Perkl/services/UserManagement.dart';
import 'package:Perkl/services/models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'HomePage.dart';
import 'PageComponents.dart';


class MainPageTemplate extends StatelessWidget {
  Widget body;
  //ActivityManager _activityManager = new ActivityManager();
  int bottomNavIndex;
  bool noBottomNavSelected;
  bool showSearchBar = false;
  String searchRequestId;
  String pageTitle;
  bool isConversation = false;
  String conversationId;

  MainPageTemplate({this.body, this.bottomNavIndex, this.noBottomNavSelected, this.showSearchBar, this.searchRequestId, this.pageTitle, this.isConversation, this.conversationId});

  @override
  build(BuildContext context) {
    User firebaseUser = Provider.of<User>(context);
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MainTemplateProvider>(create: (_) => MainTemplateProvider()),
        StreamProvider<PerklUser>(create: (_) => UserManagement().streamCurrentUser(firebaseUser)),
      ],
      child: Consumer<MainTemplateProvider>(
          builder: (context, tempProvider, _) {
            PerklUser currentUser = Provider.of<PerklUser>(context);
            //print('Padding: ${MediaQuery.of(context).viewPadding}');
            return Scaffold(
              backgroundColor: Colors.white,
              body: SlidingUpPanel(
                borderRadius: BorderRadius.all(Radius.circular(25)),
                panel: TopPanel(showPostButtons: true, pageTitle: pageTitle, searchRequestId: searchRequestId, showSearchBar: showSearchBar,),
                collapsed: TopPanel(showPostButtons: false, pageTitle: pageTitle, searchRequestId: searchRequestId, showSearchBar: showSearchBar,),
                maxHeight: 265 + MediaQuery.of(context).viewPadding.top,
                minHeight: 185 + MediaQuery.of(context).viewPadding.top,
                defaultPanelState: mp.panelOpen ? PanelState.OPEN : PanelState.CLOSED,
                slideDirection: SlideDirection.DOWN,
                panelSnapping: true,
                renderPanelSheet: false,
                onPanelOpened: () {
                  tempProvider.changeOffsetHeight(1);
                  mp.updatePanelState();
                  //print('Panel opened: ${mp.panelOpen}');
                },
                onPanelClosed: () {
                  tempProvider.changeOffsetHeight(0);
                  mp.updatePanelState();
                  //print('Panel closed: ${mp.panelOpen}');
                },
                onPanelSlide: (slidePct) {
                  tempProvider.changeOffsetHeight(slidePct);
                },
                body: Container(
                  color: Colors.transparent,
                  child: Column(
                    children: <Widget>[
                      Container(height: (tempProvider.offsetHeight != null ? tempProvider.offsetHeight : mp.panelOpen ? 265 : 185) + MediaQuery.of(context).viewPadding.top),
                      Expanded(
                          child: body
                      ),
                      bottomNavBarMobile((int i) {
                        if(i == 0) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => HomePageMobile(),
                          ));
                        }
                        if(i == 1) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => DiscoverPageMobile(),
                          ));
                        }
                        if(i == 2) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => ConversationListPageMobile(),
                          ));
                        }
                        if(i == 3) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => ProfilePageMobile(userId: currentUser.uid),
                          ));
                        }
                      }, bottomNavIndex, noSelection: noBottomNavSelected)
                    ],
                  )
                ),
              ),
            );
          }
      ),
    );
  }
}

class MainTemplateProvider extends ChangeNotifier {
  double offsetHeight;
  String searchTerm;

  void changeOffsetHeight(double slidePct) {
    double base = 185;
    double max = 265;
    double diff = max - base;
    offsetHeight = base + (diff * slidePct);
    notifyListeners();
  }

  void setSearchTerm(String value) {
    searchTerm = value;
    notifyListeners();
  }
}