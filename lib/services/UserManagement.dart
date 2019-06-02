import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserManagement {
  storeNewUser(user, context, {username}){
    //print('Storing new user data');
    Firestore.instance.collection('/timelines').add({'type': 'UserMainFeed', 'userUID': user.uid}).then((doc) {
      String timelineId = doc.documentID;
      Firestore.instance.collection('/users').document(user.uid).setData({
        'email': user.email,
        'uid': user.uid,
        'username': username != null ? username : null,
        'usernameCaseInsensitive': username != null ? username.toLowerCase() : null,
        'mainFeedTimelineId': timelineId,
      }).then((value) {
        Navigator.of(context).pop();
        print('Pushing to homepage');
        Navigator.of(context).pushReplacementNamed('/homepage');
      }).catchError((e) {
        print(e);
      });
    });
  }

  bool isLoggedIn() {
    if (FirebaseAuth.instance.currentUser() != null) {
      return true;
    } else {
      return false;
    }
  }

  Future<void> updateUser(BuildContext context, Map<String, dynamic> userData) async {
    if (isLoggedIn()) {
//      Firestore.instance.collection('/users').add(userData).catchError((e) {
//        print(e);
//      });

      Firestore.instance.runTransaction((Transaction userTransaction) async {
        await getUserData().then((DocumentReference doc) async {
          await userTransaction.update(doc, userData).catchError((e) {
            print(e);
          });
        });
      });
    } else {
      Navigator.of(context).pushReplacementNamed('/landingpage');
    }
  }

  Future<void> addPost(String docId) async {
    Map<dynamic, dynamic> postMap = new Map();

    Firestore.instance.runTransaction((Transaction transaction) async {
      await getUserData().then((DocumentReference doc) async {
        await doc.get().then((DocumentSnapshot snapshot) async {
          print('set currposts');
          print(snapshot.data['posts'].runtimeType);
          Map<dynamic, dynamic> currPosts = snapshot.data['posts'];
          print('check currposts');
          if(currPosts != null) {
            print('setting postMap to currPosts');
            postMap = currPosts;
          }
          print('Post List: $postMap');
          print('curr posts: $currPosts');
          print(docId);
          postMap.addAll({docId.toString(): true});
          print('Post List After add: $postMap');
          print('nothing will print');
          await transaction.update(doc, {'posts': postMap});
        });
      });
    });
  }

  Future<DocumentReference> getUserData() async {
    FirebaseUser user = await FirebaseAuth.instance.currentUser().then((FirebaseUser user) {
      return user;
    });
    if (user == null) {
      return null;
    }
    print('getting user data document------------------');
    return Firestore.instance.collection('users').document(user.uid);
  }

  Future<bool> userAlreadyCreated () async {
    FirebaseUser user = await FirebaseAuth.instance.currentUser().then((user) {
      return user;
    });
    print('User UID: $user.uid--------------');
    return await Firestore.instance.collection('users').document(user.uid).get().then((snapshot) {
      return snapshot.exists;
    });
  }

  Future<bool> usernameExists(username) async {
    QuerySnapshot result = await Firestore.instance.collection('users')
        .where("usernameCaseInsensitive", isEqualTo: username.toLowerCase()).limit(1)
        .getDocuments();
    return result.documents.length > 0;
  }
}


//Username validation and dialogs
Future<void> missingUsername(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Username Missing!'),
        content: const Text('You forgot to enter your username!'),
        actions: <Widget>[
          FlatButton(
            child: Text('Ok'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

Future<void> usernameInUse(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Username Taken!'),
        content: const Text('This username is already in use. Please choose a different usename.'),
        actions: <Widget>[
          FlatButton(
            child: Text('Ok'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

Future<void> usernameError(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Invalid Username!'),
        content: const Text('The chosen username is invalid.  Usernames must be between 3 and 30 characters and can only contain letters (a-z, A-Z), numbers (0-9), periods (.) and underscores (_).'),
        actions: <Widget>[
          FlatButton(
            child: Text('Ok'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

String validateUsername(String username, {allowEmpty = false}) {
  if(username == '' && allowEmpty) {
    return null;
  }
  if(username.length < 3) {
    return 'Usernames must be at least 3 characters in length';
  }
  if(username.length > 30) {
    return 'Usernames cannot be longer than 30 characters';
  }
  RegExp exp = new RegExp(
    r'^[a-zA-Z0-9_\.]+$',
  );
  print(exp.allMatches(username).length);
  if(exp.allMatches(username).length == 0){
    return 'Usernames can only contain letters, numbers, underscores (_) and periods (.)';
  }
  return null;
}

//Getting Username Dialog
class UsernameDialog extends StatefulWidget {
  @override
  _UsernameDialogState createState () => new _UsernameDialogState ();
}

class _UsernameDialogState extends State<UsernameDialog> {
  String _validateUsernameError;
  String _username;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Enter a Username'),
      content: Container(
        width: 150.0,
        child: TextField(
            decoration: InputDecoration(
              hintText: 'Username',
              errorText: _validateUsernameError,
              errorMaxLines: 3,
            ),
            onChanged: (value) {
              setState(() {
                _username = value;
                _validateUsernameError = validateUsername(_username);
              });
            }
        )
      ),
      actions: <Widget>[
        FlatButton(
          child: Text('Ok'),
          onPressed: () async {
            if(_username == null || _username == ''){
              missingUsername(context);
            } else if (await UserManagement().usernameExists(_username)) {
              usernameInUse(context);
            } else if (_validateUsernameError != null) {
              usernameError(context);
            } else {
              UserManagement().updateUser(context, {
                'username': _username,
                'usernameCaseInsensitive': _username.toLowerCase(),
              });
              Navigator.of(context).pop();
            }
          },
        ),
      ],
    );
  }
}

class UpdateProfileDialog extends StatefulWidget {
  @override
  _UpdateProfileDialogState createState() => new _UpdateProfileDialogState();
}

class _UpdateProfileDialogState extends State<UpdateProfileDialog> {
  String newUsername;
  String newUsernameError;
  String newBio;
  String currentBio;
  String newBioValidation;

  void getCurrentBio() async {
    await UserManagement().getUserData().then((doc) async {
      await doc.get().then((snapshot) async {
        currentBio = snapshot.data['bio'].toString();
      });
    });
  }

  @override
  void initState() {
    super.initState();
    getCurrentBio();
  }

  @override
  Widget build(BuildContext context) {
    String hintBio = 'Enter a short bio...';
    if(currentBio != null && currentBio.length > 0 && currentBio != 'null') {
      print('checked currentBio length');
      hintBio = currentBio;
    }

    return new SimpleDialog(
      contentPadding: EdgeInsets.all(10.0),
      title: Center(child: Text('Update Profile',
        style: TextStyle(
          color: Colors.deepPurple,
        ),
      )),
      children: <Widget>[
        Divider(
          color: Colors.deepPurple,
          height: 20.0,
        ),
        Text('Change Username',
          style: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          )
        ),
        Container(
          width: 200.0,
          child: TextField(
              decoration: InputDecoration(
                hintText: 'New Username',
                errorText: newUsernameError,
                errorMaxLines: 3,
              ),
              onChanged: (value) {
                setState(() {
                  newUsername = value;
                  newUsernameError = validateUsername(newUsername, allowEmpty: true);
                });
              }
          ),
        ),
        SizedBox(height: 20.0),
        Text('Update Bio',
          style: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          )
        ),
        SizedBox(height: 10.0),
        Container(
          width: 200.0,
          child: TextField(
            decoration: InputDecoration(
              hintText: hintBio,
              errorText: newBioValidation,
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.multiline,
            maxLines: 5,
            onChanged: (value) {
              setState(() {
                newBio = value;
                if (newBio != null) {
                  newBioValidation = newBio.length > 140
                      ? 'Your Bio must be 140 characters or less'
                      : null;
                }
              });
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            FlatButton(
              child: Text('Cancel'),
              textColor: Colors.deepPurple,
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            FlatButton(
              child: Text('Update'),
              textColor: Colors.deepPurple,
              onPressed: () async {
                Map<String, dynamic> updateData = new Map();

                if(newUsernameError != null || newBioValidation != null) {
                  return;
                }

                print('New Username: $newUsername');
                if (newUsername != null && newUsername != '' &&
                    newUsernameError == null) {
                  if (await UserManagement().usernameExists(newUsername)) {
                    usernameInUse(context);
                    return;
                  } else {
                    updateData['username'] = newUsername;
                    updateData['usernameCaseInsensitive'] =
                        newUsername.toLowerCase();
                  }
                }

                if (newBio != null && newBioValidation == null) {
                  updateData['bio'] = newBio;
                }

                print('Update Data: $updateData');
                if (updateData != null) {
                  await UserManagement().updateUser(context, updateData);
                  Navigator.of(context).pop();
                }
              }
            )
          ],
        ),
      ],
    );
  }
}