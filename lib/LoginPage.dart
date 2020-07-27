import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flushbar/flushbar.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';

import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';
import 'HomePage.dart';
import 'ConversationPage.dart';

final GoogleSignIn _googleSignIn = new GoogleSignIn();

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String _email;
  String _password;
  String _errorMessage;
  final Firestore _db = Firestore.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();
  bool _redirectOnNotification = true;

  StreamSubscription iosSubscription;

  _checkLoggedIn() async {
    FirebaseUser currentUser = await FirebaseAuth.instance.currentUser();
    if(currentUser != null)
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => HomePageMobile(redirectOnNotification: true,),
      ));
  }

  @override
  void initState() {
    super.initState();
    if (Platform.isIOS) {
      iosSubscription = _firebaseMessaging.onIosSettingsRegistered.listen((data) {
        // save the token  OR subscribe to a topic here
      });

      _firebaseMessaging.requestNotificationPermissions(IosNotificationSettings());
    }

    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> message) async {
        print("onMessage: $message");
        Flushbar(
          backgroundColor: Colors.deepPurple,
          title:  message['notification']['title'],
          message:  message['notification']['body'],
          duration:  Duration(seconds: 3),
          margin: EdgeInsets.all(8),
          borderRadius: 8,
          flushbarPosition: FlushbarPosition.TOP,
          onTap: (flushbar) {
            String conversationId = message['data']['conversationId'];
            if(conversationId != null){
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => ConversationPageMobile(conversationId: conversationId),
              ));
            }
          },
        )..show(context);
      },
      onLaunch: (Map<String, dynamic> message) async {
        print("onLaunch: $message");
        // TODO optional
        String conversationId = message['data']['conversationId'];
        print('Conversation id: ' + conversationId);
        if(conversationId != null && _redirectOnNotification){
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => ConversationPageMobile(conversationId: conversationId),
          )).then((_) {
            _redirectOnNotification = false;
          });
        }
      },
      onResume: (Map<String, dynamic> message) async {
        print("onResume: $message");
        // TODO optional
        String conversationId = message['data']['conversationId'];
        print('Conversation id: ' + conversationId);
        if(conversationId != null && _redirectOnNotification){
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => ConversationPageMobile(conversationId: conversationId),
          )).then((_) {
            _redirectOnNotification = false;
          });
        }
      },
    );
    _checkLoggedIn();
  }

  @override
  Widget build(BuildContext context){

    return Scaffold (
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/drawable-xxxhdpi/login-bg.png"),
            fit: BoxFit.cover,
          ),
        ),
        child:       Center(
          child: Container(
              padding: EdgeInsets.all(25.0),
              child: SingleChildScrollView(
                  child:Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                              image: AssetImage('assets/images/logo.png'),
                              fit: BoxFit.fill
                          ),
                        ),
                      ),
                      SizedBox(height: 50.0),
                      TextField(
                          decoration: InputDecoration(hintText: 'Email Address'),
                          onChanged: (value) {
                            setState((){
                              _email = value;
                            });
                          }
                      ),
                      SizedBox(height: 15.0),
                      TextField(
                        decoration: InputDecoration(hintText: 'Password'),
                        onChanged: (value) {
                          setState((){
                            _password = value;
                          });
                        },
                        obscureText: true,
                      ),
                      SizedBox(height: 20.0),
                      RaisedButton(
                        child: Text('Login'),
                        color: Colors.deepPurple,
                        textColor: Colors.white,
                        elevation: 7.0,
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                          );
                          FirebaseAuth.instance.signInWithEmailAndPassword(
                              email: _email,
                              password: _password
                          ).then((AuthResult authResult) {
                            Navigator.of(context).pop();
                            print('Auth Result: $authResult');
                            Navigator.of(context).pushReplacementNamed('/homepage');
                          })
                              .catchError((e) {
                            print('Error Logging In: ${e.code}/${e.message}');
                            Navigator.of(context).pop();
                            switch(e.code) {
                              case "ERROR_INVALID_EMAIL":
                                _errorMessage = "Your email address is invalid.";
                                break;
                              case "ERROR_WRONG_PASSWORD":
                                _errorMessage = "Your password is incorrect.";
                                break;
                              case "ERROR_USER_NOT_FOUND":
                                _errorMessage = "A user does not exist for this email address.";
                                break;
                              case "ERROR_USER_DISABLED":
                                _errorMessage = "This user has been disabled.";
                                break;
                              case "ERROR_TOO_MANY_REQUESTS":
                                _errorMessage = "Too many failed attempts. Try again later.";
                                break;
                              case "ERROR_OPERATION_NOT_ALLOWED":
                                _errorMessage = "Email and Password login is not enabled.";
                                break;
                              default:
                                _errorMessage = "An undefined Error happened.";
                            }
                            showDialog(
                              context: context,
                              builder: (context) {
                                return SimpleDialog(
                                  title: Center(child: Text('Error Logging In')),
                                  children: [
                                    Center(child: Text(_errorMessage, textAlign: TextAlign.center,)),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: <Widget>[
                                        FlatButton(
                                          child: Text('OK', style: TextStyle(color: Colors.deepPurple)),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        )
                                      ],
                                    )
                                  ],
                                );
                              }
                            );
                          });
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: new BorderRadius.circular(25.0),
                        ),
                      ),
                      _GoogleSignInSection(),
                      SizedBox(height: 100.0),
                      Text('Don\'t have an account?'),
                      SizedBox(height: 10.0),
                      RaisedButton(
                        child: Text('Sign Up'),
                        color: Colors.deepPurple,
                        textColor: Colors.white,
                        elevation: 7.0,
                        onPressed: (){
                          Navigator.of(context).pushNamed('/signup');
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: new BorderRadius.circular(25.0),
                        ),
                      ),
                    ],
                  )
              )
          ),
        )
    ),
    );
  }
}

//Setup Login section for Google Authentication
class _GoogleSignInSection extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _GoogleSignInSectionState();
}

class _GoogleSignInSectionState extends State<_GoogleSignInSection> {
  bool _success;
  String _userID;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          alignment: Alignment.center,
          child: RaisedButton(
            color: Colors.white,
            textColor: Colors.deepPurple,
            onPressed: () async {
              showDialog(
                context: context,
                builder: (context) {
                  return Center(
                    child: Container(
                      height: 50.0,
                      width: 50.0,
                      child: CircularProgressIndicator(),
                    )
                  );
                }
              );
              _signInWithGoogle(context).then((_) {
                Navigator.of(context).pop();
              });
            },
            child: Container(
              width: 200.0,
              child: Center(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Image.asset("assets/images/drawable-xxxhdpi/google-logo.png", height: 45.0, width: 45.0),
                      Text('Sign in with Google'),
                    ]
                ),
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: new BorderRadius.circular(25.0),
            ),
          ),
        ),
      ],
    );
  }

  // Example code of how to sign in with google.
  Future<void> _signInWithGoogle(BuildContext context) async {
    bool userDocCreated;

    print('Starting Google sign in');
    final GoogleSignInAccount googleUser = await _googleSignIn.signIn().catchError((e) {
      print('Error ${e.toString()}');
    });
    print('Google User: $googleUser');
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.getCredential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final AuthResult authResult = await FirebaseAuth.instance.signInWithCredential(credential);
    final FirebaseUser user = authResult.user;
    assert(user.email != null);
    assert(user.displayName != null);
    assert(!user.isAnonymous);
    assert(await user.getIdToken() != null);

    final FirebaseUser currentUser = await FirebaseAuth.instance.currentUser();
    assert(user.uid == currentUser.uid);

    userDocCreated = await UserManagement().userAlreadyCreated();
    print('User exists: $userDocCreated------------------');

    setState(() {
      if (user != null) {
        _success = true;
        _userID = user.uid;
        print('userid: $_userID-------------');
        if (!userDocCreated) {
          print('creating user document');
          UserManagement().storeNewUser(currentUser, context).then((value) {
            print('closing loading dialog');
            Navigator.of(context).pop();
            print('Pushing to homepage');
            Navigator.of(context).pushReplacementNamed('/homepage');
          });
        } else {
          print('closing loading dialog');
          Navigator.of(context).pop();
          Navigator.of(context).pushReplacementNamed('/homepage');
        }
      } else {
        _success = false;
        Navigator.of(context).pop();
      }
    });
  }
}