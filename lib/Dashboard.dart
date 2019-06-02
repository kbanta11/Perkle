/*import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/UserManagement.dart';

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String bio;
  String username;

  QuerySnapshot userInfo;

  UserManagement manageUser = new UserManagement();

  Future<bool> addDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Complete Profile', style: TextStyle(fontSize: 15.0)),
          content: Column(
            children: <Widget>[
              TextField(
                decoration: InputDecoration(hintText: 'Enter a short bio...'),
                onChanged: (value) {
                  this.bio = value;
                }),
              SizedBox(height: 5.0),
              TextField(
                decoration: InputDecoration(hintText: 'Enter a username'),
                onChanged: (value) {
                  this.username = value;
                }),
            ],
          ),
          actions: <Widget>[
            FlatButton(
              child: Text('Update'),
              textColor: Colors.purple,
              onPressed: () {
                Navigator.of(context).pop();
                manageUser.updateUser({
                  'bio': this.bio,
                  'username': this.username
                }).then((result) {
                  dialogTrigger(context);
                }).catchError((e) {
                  print(e);
                });
              },
            ),
          ],
        );
      });//showDialog//builder
  }

  Future<bool> dialogTrigger(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Successfully Updated', style: TextStyle(fontSize: 15.0)),
          content: Text('Username/Bio updated!'),
          actions: <Widget>[
            FlatButton(
              child: Text('Done'),
              color: Colors.purple,
              textColor: Colors.white,
              onPressed: () {
                Navigator.of(context).pop();
              },
            )
          ],
        );
      });
  }

  @override
  void initState() {
    manageUser.getUserData().then((QuerySnapshot results) {
      setState(() {
        userInfo = results.get().then((QuerySnapshot snapshot) {
          return snapshot;
        });
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold (
      appBar: AppBar(
        title: Text('Dashboard'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              addDialog(context);
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              manageUser.getUserData().then((results) {
                setState(() {
                  userInfo = results;
                });
              });
            },
          ),
        ]
      ),
      body: _userProfile(),
    );
  }

  Widget _userProfile() {
    if(userInfo != null) {
      return ListView.builder(
        itemCount: userInfo.documents.length,
        padding: EdgeInsets.all(5.0),
        itemBuilder: (context, i) {
          String username;
          String bio;

          if (userInfo.documents[i].data['username'] != null) {
            username = userInfo.documents[i].data['username'];
          } else {
            username = 'Please enter a username!';
          }

          if (userInfo.documents[i].data['bio'] != null) {
            bio = userInfo.documents[i].data['bio'];
          } else {
            bio = 'Please enter a bio!';
          }

          return new ListTile(
            title: Text(username),
            subtitle: Text(bio),
          );
        },
      );
    } else {
      return Text('Loading...');
    }
  }
}*/
