import 'package:Perkl/SignUpPage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
//import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
//import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
//import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';

import 'main.dart';
import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';
import 'HomePage.dart';
import 'ConversationPage.dart';

String generateNonce([int length = 32]) {
  final charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(length, (_) => charset[random.nextInt(charset.length)])
      .join();
}

/// Returns the sha256 hash of [input] in hex notation.
String sha256ofString(String input) {
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

Future<UserCredential> signInWithApple() async {
  // To prevent replay attacks with the credential returned from Apple, we
  // include a nonce in the credential request. When signing in in with
  // Firebase, the nonce in the id token returned by Apple, is expected to
  // match the sha256 hash of `rawNonce`.
  final rawNonce = generateNonce();
  final nonce = sha256ofString(rawNonce);

  // Request credential for the currently signed in Apple account.
  final appleCredential = await SignInWithApple.getAppleIDCredential(
    scopes: [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ],
    nonce: nonce,
  );
  print('Apple Credential: $appleCredential');
  // Create an `OAuthCredential` from the credential returned by Apple.
  final oauthCredential = OAuthProvider("apple.com").credential(
    idToken: appleCredential.identityToken,
    rawNonce: rawNonce,
  );

  // Sign in the user with Firebase. If the nonce we generated earlier does
  // not match the nonce in `appleCredential.identityToken`, sign in will fail.
  return await FirebaseAuth.instance.signInWithCredential(oauthCredential).catchError((e) {
    print('Error signing in with apple: $e');
  });
}

final GoogleSignIn _googleSignIn = new GoogleSignIn();

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String? _email;
  String? _password;
  String? _errorMessage;
  //final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  bool _redirectOnNotification = true;

  StreamSubscription? iosSubscription;

  @override
  void initState() {
    super.initState();
    print('Building Login Page');
    if (Platform.isIOS) {
      _firebaseMessaging.requestPermission();
    }

    _firebaseMessaging.getInitialMessage().then((initialMessage) {
      print('Initial Message: $initialMessage');
      if(initialMessage?.data != null && initialMessage?.data['conversationId'] != null) {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (context) => ConversationPageMobile(conversationId: initialMessage?.data?['conversationId']),
        )).then((_) {
          _redirectOnNotification = false;
        });
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Remote Message: ${message.notification}');
      Flushbar(
        backgroundColor: Colors.deepPurple,
        title:  message.notification?.title,
        message:  message.notification?.body,
        duration:  Duration(seconds: 3),
        margin: EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(8),
        flushbarPosition: FlushbarPosition.TOP,
        onTap: (flushbar) {
          String conversationId = message.data['conversationId'];
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
      String conversationId = message.data['conversationId'];
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
                      ElevatedButton(
                        child: Text('Login'),
                        style: ElevatedButton.styleFrom(
                          primary: Colors.deepPurple,
                          textStyle: TextStyle(color: Colors.white),
                          elevation: 7.0,
                          shape: RoundedRectangleBorder(
                            borderRadius: new BorderRadius.circular(25.0),
                          )
                        ),
                        onPressed: () {
                          if(_email == null || _email?.length == 0 || _password == null || _password?.length == 0) {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return SimpleDialog(
                                  contentPadding: EdgeInsets.all(10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
                                  title: Text('Email or Password is Missing!', textAlign: TextAlign.center,),
                                  children: [
                                    Center(child: Text('It looks like you forgot to include your email or password when logging in!', textAlign: TextAlign.center)),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          child: Text('OK', style: TextStyle(color: Colors.white)),
                                          style: TextButton.styleFrom(
                                            backgroundColor: Colors.deepPurple
                                          ),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        )
                                      ],
                                    )
                                  ]
                                );
                              }
                            );
                            return;
                          }
                          showDialog(
                            context: context,
                            builder: (context) {
                              return Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                          );
                          FirebaseAuth.instance.signInWithEmailAndPassword(
                              email: _email ?? '',
                              password: _password ?? ''
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
                              case "invalid-email":
                                _errorMessage = "Your email address is invalid.";
                                break;
                              case "wrong-password":
                                _errorMessage = "Your password is incorrect.";
                                break;
                              case "user-not-found":
                                _errorMessage = "A user does not exist for this email address. Sign Up Now!";
                                break;
                              case "too-many-requests":
                                _errorMessage = "Too many failed login attempts. Please try again later.";
                                break;
                              default:
                                _errorMessage = "We're Sorry! It looks like there was an undefined Error logging in. Please try again, or sign up if you don't yet have an account!";
                            }
                            showDialog(
                              context: context,
                              builder: (context) {
                                return SimpleDialog(
                                  contentPadding: EdgeInsets.all(10),
                                  title: Center(child: Text('Sorry!')),
                                  children: [
                                    Center(child: Text(_errorMessage ?? '', textAlign: TextAlign.center,)),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: <Widget>[
                                        TextButton(
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
                      ),
                      _GoogleSignInSection(),
                      Platform.isIOS ? SignInWithAppleButton(
                          onPressed: () async {
                            await signInWithApple();
                          }) : Container(),
                      SizedBox(height: 100.0),
                      Text('Don\'t have an account?'),
                      SizedBox(height: 10.0),
                      ElevatedButton(
                        child: Text('Sign Up'),
                        style: ElevatedButton.styleFrom(
                          primary: Colors.deepPurple,
                          textStyle: TextStyle(color: Colors.white),
                          elevation: 7.0,
                          shape: RoundedRectangleBorder(
                            borderRadius: new BorderRadius.circular(25.0),
                          )
                        ),
                        onPressed: (){
                          Navigator.pushReplacement(context, MaterialPageRoute(
                            builder: (context) => SignUpPage(),
                          ));
                        },
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
  bool? _success;
  String? _userID;
  bool _isLoading = false;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          alignment: Alignment.center,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              primary: Colors.white,
              textStyle: TextStyle(color: Colors.deepPurple),
              shape: RoundedRectangleBorder(
                borderRadius: new BorderRadius.circular(25.0),
              ),
            ),
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
                      Text('Sign in with Google', style: TextStyle(color: Colors.deepPurple)),
                    ]
                ),
              ),
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
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn().catchError((e) {
      print('Error ${e.toString()}');
    });
    print('Google User: $googleUser');
    if(googleUser == null) {
      return false;
    }
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final UserCredential userCred = await FirebaseAuth.instance.signInWithCredential(credential);
    final User? user = userCred.user;
    assert(user?.email != null);
    assert(user?.displayName != null);
    assert(await user?.getIdToken() != null);

    final User? currentUser = FirebaseAuth.instance.currentUser;
    assert(user?.uid == currentUser?.uid);

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
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  }
                ),
                TextButton(
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
    return _success ?? false;
  }
}