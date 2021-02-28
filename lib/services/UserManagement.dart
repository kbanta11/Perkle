import 'dart:async';
import 'dart:io';
import 'package:Perkl/services/models.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
//import 'models.dart';

class UserManagement {
  FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> storeNewUser(User user, {String username}) async {
    //print('Storing new user data');
    WriteBatch batch = _db.batch();
    DocumentReference timelineRef = _db.collection('/timelines').doc();
    batch.set(timelineRef, {'type': 'UserMainFeed', 'userUID': user.uid});

    String timelineId = timelineRef.id;
    DocumentReference userRef = _db.collection('/users').doc(user.uid);
    batch.set(userRef, {
      'email': user.email,
      'uid': user.uid,
      'username': username != null ? username : null,
      'usernameCaseInsensitive': username != null ? username.toLowerCase() : null,
      'mainFeedTimelineId': timelineId,
      'tos_accepted': true,
    });
    await batch.commit();
  }

  bool isLoggedIn() {
    if (FirebaseAuth.instance.currentUser != null) {
      return true;
    } else {
      return false;
    }
  }

  Stream<PerklUser> streamCurrentUser(User user) {
    if(user == null)
      return null;
    return _db.collection('users').doc(user.uid).snapshots().map((snap) => PerklUser.fromFirestore(snap));
    //await currentUser.loadFollowedPodcasts();
  }
  
  Stream<PerklUser> streamUserDoc(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((snap) => PerklUser.fromFirestore(snap));
  }

  Future<void> updateUser(BuildContext context, Map<String, dynamic> userData) async {
    if (isLoggedIn()) {
//      Firestore.instance.collection('/users').add(userData).catchError((e) {
//        print(e);
//      });

      _db.runTransaction((Transaction userTransaction) async {
        await getUserData().then((DocumentReference doc) async {
          await userTransaction.update(doc, userData);
        });
      });
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil('/landingpage', (Route<dynamic> route) => false);
    }
  }

  Future<void> addPost(String docId) async {
    Map<dynamic, dynamic> postMap = new Map();

    _db.runTransaction((Transaction transaction) async {
      await getUserData().then((DocumentReference doc) async {
        await doc.get().then((DocumentSnapshot snapshot) async {
          print('set currposts');
          print(snapshot.data()['posts'].runtimeType);
          Map<dynamic, dynamic> currPosts = snapshot.data()['posts'];
          print('check currposts');
          if(currPosts != null) {
            print('setting postMap to currPosts');
            postMap = currPosts.map((k, v) => MapEntry(k, v));
          }
          print('Post List: $postMap');
          print('curr posts: $currPosts');
          print('$docId/${postMap.runtimeType}');
          postMap.addAll({docId: true});
          print('Post List After add: $postMap');
          print('nothing will print');
          transaction.update(doc, {'posts': postMap});
        });
      });
    });
  }

  Future<DocumentReference> getUserData() async {
    User user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return null;
    }
    print('getting user data document------------------');
    return _db.collection('users').doc(user.uid);
  }

  Future<String> getUID() async {
    return FirebaseAuth.instance.currentUser.uid;
  }


  Future<bool> userAlreadyCreated () async {
    User user = FirebaseAuth.instance.currentUser;
    //print('User UID: $user.uid--------------');
    return await _db.collection('users').doc(user.uid).get().then((snapshot) {
      return snapshot.exists;
    });
  }

  Future<bool> usernameExists(username) async {
    QuerySnapshot result = await _db.collection('users')
        .where("usernameCaseInsensitive", isEqualTo: username.toLowerCase()).limit(1)
        .get();
    return result.docs.length > 0;
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
              showDialog(
                context: context,
                builder: (context) {
                  return Center(child: CircularProgressIndicator());
                }
              );
              await UserManagement().updateUser(context, {
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
        currentBio = snapshot.data()['bio'].toString();
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
      contentPadding: EdgeInsets.all(10.0),
      title: Center(child: Text('Update Profile',
        style: TextStyle(
          color: Colors.deepPurple,
        ),
      )),
      children: <Widget>[
        SizedBox(height: 15),
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

class UploadProfilePic extends StatefulWidget {
  final File picFile;
  final String userId;

  UploadProfilePic({Key key, this.picFile, this.userId}) : super(key: key);

  @override
  _UploadProfilePicState createState() => new _UploadProfilePicState();
}

class _UploadProfilePicState extends State<UploadProfilePic> {
  static DateTime date = DateTime.now();
  UploadTask _uploadTask;
  String fileUrl;
  String fileUrlString;

  _startUpload() async {

    final Reference storageRef = FirebaseStorage.instance.ref().child(widget.userId).child('profile-pics').child('${date.toString()}-pic.jpg');

    setState(() {
      _uploadTask = storageRef.putFile(widget.picFile);
    });
  }

  updateUserDoc(BuildContext context) async {
    await _uploadTask.whenComplete(() => null);
    fileUrl = await _uploadTask.snapshot.ref.getDownloadURL();
    fileUrlString = fileUrl.toString();

    await UserManagement().updateUser(context, {'profilePicUrl': fileUrlString}).then((_) {
      Navigator.pop(context);
    });

  }

  @override
  Widget build(BuildContext context) {
    if(_uploadTask != null) {
      return StreamBuilder<TaskSnapshot>(
        stream: _uploadTask.snapshotEvents,
        builder: (context, AsyncSnapshot<TaskSnapshot> snapshot) {
          if(!snapshot.hasData) {
            return SizedBox(
                width: double.infinity,
                child: Padding(
                  child: LinearProgressIndicator(value: 0),
                  padding: EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 0.0),
                )
            );
          }
          TaskState event = snapshot.data.state;
          if(event == TaskState.success){
            updateUserDoc(context);
          }
          double progressPercent = snapshot.data != null ? snapshot.data.bytesTransferred / snapshot.data.totalBytes : 0;
          return SizedBox(
            width: double.infinity,
            child: Padding(
              child: LinearProgressIndicator(value: progressPercent),
              padding: EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 0.0),
            )
          );
        }
      );
    }
    return SizedBox(
        width: double.infinity,
        child: Padding(
            child: FlatButton(
                child: Text('Upload Photo'),
                color: widget.picFile != null ? Colors.deepPurple : Colors.white10,
                textColor: Colors.white,
                shape: new RoundedRectangleBorder(borderRadius: new BorderRadius.circular(5.0)),
                onPressed: () async {
                  if(widget.picFile != null)
                    _startUpload();
                }
            ),
            padding: EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 10.0)
        )
    );
  }
}

class ProfilePicDialog extends StatefulWidget {
  final String userId;

  ProfilePicDialog({Key key, this.userId}) : super(key: key);

  @override
  _ProfilePicDialogState createState() => new _ProfilePicDialogState();
}

class _ProfilePicDialogState extends State<ProfilePicDialog> {
  File _profilePic;

  Future<void> getImage(ImageSource source) async {
    File image = await ImagePicker.pickImage(source: source);

    setState(() {
      _profilePic = image;
    });
  }

  Future<void> cropImage() async {
    File cropped = await ImageCropper.cropImage(
      sourcePath: _profilePic.path,
      cropStyle: CropStyle.circle,
      aspectRatioPresets: [
        CropAspectRatioPreset.square,
      ],
      androidUiSettings: AndroidUiSettings(
        toolbarWidgetColor: Colors.white,
        toolbarColor: Colors.deepPurple,
        statusBarColor: Colors.deepPurple,
        activeControlsWidgetColor: Colors.deepPurple,
        //activeWidgetColor: Colors.deepPurple,
      ),
    );

    setState(() {
      _profilePic = cropped ?? _profilePic;
    });
  }

  Widget image() {
    if (_profilePic != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              height: 160,
              width: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.deepPurpleAccent,
                image: DecorationImage(
                  fit: BoxFit.cover,
                  image: FileImage(_profilePic),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.crop),
              color: Colors.deepPurple,
              onPressed: () {
                cropImage();
              },
            ),
          ]
      );
    }
    return Container();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white30.withOpacity(0.75),
        body: Container(
          alignment: Alignment.bottomCenter,
          child: Column(
              children: <Widget>[
                SizedBox(
                    width: double.infinity,
                    child: Padding(
                        child: FlatButton(
                            child: Text('Camera'),
                            shape: new RoundedRectangleBorder(borderRadius: new BorderRadius.circular(5.0)),
                            color: Colors.deepPurple,
                            textColor: Colors.white,
                            onPressed:() {
                              getImage(ImageSource.camera);
                            }
                        ),
                        padding: EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0.0)
                    )
                ),
                SizedBox(height: 5.0),
                SizedBox(
                    width: double.infinity,
                    child: Padding(
                      child: OutlineButton(
                          child: Text('Gallery'),
                          shape: new RoundedRectangleBorder(borderRadius: new BorderRadius.circular(5.0)),
                          textColor: Colors.deepPurple,
                          borderSide: BorderSide(
                            color: Colors.deepPurple,
                          ),
                          onPressed:() {
                            getImage(ImageSource.gallery);
                          }
                      ),
                      padding: EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 0.0),
                    )
                ),
                Expanded(
                    child: Center(
                      child: image(),
                    ),
                ),
                UploadProfilePic(picFile: _profilePic, userId: widget.userId),
                SizedBox(
                  width: double.infinity,
                  child: Padding(
                    child: FlatButton(
                      child: Text('Cancel'),
                      color: Colors.red,
                      textColor: Colors.white,
                      shape: new RoundedRectangleBorder(borderRadius: new BorderRadius.circular(5.0)),
                      onPressed: () {
                        Navigator.pop(context);
                      }
                    ),
                    padding: EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 10.0)
                  )
                )
              ]
          ),
        )
    );
  }
}


class ConversationListObject {
  String targetUid;
  String targetUsername;
  String conversationId;
  int unreadPosts;

  ConversationListObject(String this.targetUid, String this.targetUsername, String this.conversationId, int this.unreadPosts);
}