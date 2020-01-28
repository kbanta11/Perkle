import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'LoginPage.dart';
import 'SignUpPage.dart';
import 'HomePage.dart';
import 'SearchPage.dart';
import 'Dashboard.dart';

void main() async {
  runApp(new MainApp());
}

class MainApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return new MaterialApp(
      title: 'Perkl',
      theme: new ThemeData (
        primarySwatch: Colors.deepPurple
      ),
      home: Scaffold(body:LoginPage()),
      routes: <String, WidgetBuilder> {
        '/landingpage': (BuildContext context) => new MainApp(),
        '/signup': (BuildContext context) => new SignUpPage(),
        '/homepage': (BuildContext context) => new HomePage(),
        '/searchpage': (BuildContext context) => new SearchPage(),
        // '/dashboard': (BuildContext context) => new DashboardPage(),
      },
    );
  }
}