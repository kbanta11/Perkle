import 'package:flutter/material.dart';

import 'LoginPage.dart';
import 'SignUpPage.dart';
import 'HomePage.dart';
import 'SearchPage.dart';
import 'Dashboard.dart';

void main() {
  runApp(new BlogApp());
}

class BlogApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Firebase App',
      theme: new ThemeData (
        primarySwatch: Colors.deepPurple
      ),
      home: LoginPage(),
      routes: <String, WidgetBuilder> {
        '/landingpage': (BuildContext context) => new BlogApp(),
        '/signup': (BuildContext context) => new SignUpPage(),
        '/homepage': (BuildContext context) => new HomePage(),
        '/searchpage': (BuildContext context) => new SearchPage(),
        // '/dashboard': (BuildContext context) => new DashboardPage(),
      },
    );
  }
}