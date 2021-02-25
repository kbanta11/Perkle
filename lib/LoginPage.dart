import 'package:Perkl/SignUpPage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
//import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flushbar/flushbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
//import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';

import 'main.dart';
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
  //final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  bool _redirectOnNotification = true;

  StreamSubscription iosSubscription;

  _checkLoggedIn() async {
    User currentUser = FirebaseAuth.instance.currentUser;
    if(currentUser != null)
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (context) => HomePageMobile(redirectOnNotification: true,),
      ));
  }

  @override
  void initState() {
    super.initState();
    print('Building Login Page');
    if (Platform.isIOS) {
      _firebaseMessaging.requestPermission();
    }

    _firebaseMessaging.getInitialMessage().then((initialMessage) {
      if(initialMessage?.data != null && initialMessage?.data['conversationId'] != null) {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (context) => ConversationPageMobile(conversationId: initialMessage.data['conversationId']),
        )).then((_) {
          _redirectOnNotification = false;
        });
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Remote Message: $message');
      Flushbar(
        backgroundColor: Colors.deepPurple,
        title:  message.data['notification']['title'],
        message:  message.data['notification']['body'],
        duration:  Duration(seconds: 3),
        margin: EdgeInsets.all(8),
        borderRadius: 8,
        flushbarPosition: FlushbarPosition.TOP,
        onTap: (flushbar) {
          String conversationId = message?.data['conversationId'];
          if(conversationId != null){
            Navigator.pushReplacement(context, MaterialPageRoute(
              builder: (context) => ConversationPageMobile(conversationId: conversationId),
            ));
          }
        },
      ).show(context);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("onResume: $message");
      String conversationId = message?.data['conversationId'];
      if(conversationId != null && _redirectOnNotification){
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (context) => ConversationPageMobile(conversationId: conversationId),
        )).then((_) {
          _redirectOnNotification = false;
        });
      }
    });
/*
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
              Navigator.pushReplacement(context, MaterialPageRoute(
                builder: (context) => ConversationPageMobile(conversationId: conversationId),
              ));
            }
          },
        ).show(context);
      },
      onLaunch: (Map<String, dynamic> message) async {
        print("onLaunch: $message");
        // TODO optional
        String conversationId = message['data']['conversationId'];
        print('Conversation id: ' + conversationId);
        if(conversationId != null && _redirectOnNotification){
          Navigator.pushReplacement(context, MaterialPageRoute(
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
          Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (context) => ConversationPageMobile(conversationId: conversationId),
          )).then((_) {
            _redirectOnNotification = false;
          });
        }
      },
    );
 */
    //_checkLoggedIn();
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
                          ).then((UserCredential authResult) {
                            Navigator.of(context).pop();
                            print('Auth Result: $authResult');
                            Navigator.pushReplacement(context, MaterialPageRoute(
                              builder: (context) => MainApp(),
                            ));
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
                          Navigator.pushReplacement(context, MaterialPageRoute(
                            builder: (context) => SignUpPage(),
                          ));
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
  bool _isLoading = false;
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
              setState(() {
                _isLoading = true;
              });
              await _signInWithGoogle(context);
              setState(() {
                _isLoading = false;
              });
              Navigator.pushReplacement(context, MaterialPageRoute(
                builder: (context) => MainApp(),
              ));
            },
            child: Container(
              width: 200.0,
              child: _isLoading ? Center(child: Padding(
                padding: EdgeInsets.all(5),
                child: CircularProgressIndicator(),
              )) : Center(
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
  Future<bool> _signInWithGoogle(BuildContext context) async {
    bool userDocCreated;

    print('Starting Google sign in');
    final GoogleSignInAccount googleUser = await _googleSignIn.signIn().catchError((e) {
      print('Error ${e.toString()}');
    });
    print('Google User: $googleUser');
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final UserCredential userCred = await FirebaseAuth.instance.signInWithCredential(credential);
    final User user = userCred.user;
    assert(user.email != null);
    assert(user.displayName != null);
    assert(!user.isAnonymous);
    assert(await user.getIdToken() != null);

    final User currentUser = FirebaseAuth.instance.currentUser;
    assert(user.uid == currentUser.uid);

    userDocCreated = await UserManagement().userAlreadyCreated();
    print('User exists: $userDocCreated------------------');

    if (user != null) {
      _success = true;
      _userID = user.uid;
      if (!userDocCreated) {
        print('creating user document');
        await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Accept Our Terms!'),
              content: Container(
                width: 200,
                child: RichText(
                  text: TextSpan(
                      children: [
                        TextSpan(
                            text: 'By continuing, you are agreeing to our ',
                            style: TextStyle(color: Colors.black)
                        ),
                        TextSpan(
                            text: 'terms and conditions',
                            style: TextStyle(color: Colors.blue,),
                            recognizer: TapGestureRecognizer()..onTap = () {launch('https://www.perklapp.com/tos');}
                        ),
                        TextSpan(
                            text: ' and ',
                            style: TextStyle(color: Colors.black)
                        ),
                        TextSpan(
                            text: 'privacy policy.',
                            style: TextStyle(color: Colors.blue,),
                            recognizer: TapGestureRecognizer()..onTap = () {launch('https://firebasestorage.googleapis.com/v0/b/flutter-fire-test-be63e.appspot.com/o/AppFiles%2Fprivacy_policy.html?alt=media&token=85870176-cf2e-49d8-b9a1-100a44a4390a');}
                        )
                      ]
                  ),
                ),
              ),
              actions: [
                FlatButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  }
                ),
                FlatButton(
                  child: Text('OK'),
                  onPressed: () async {
                    await UserManagement().storeNewUser(currentUser);
                  }
                )
              ]
            );
          }
        );
      }
    } else {
      _success = false;
    }
    return _success;
  }
}