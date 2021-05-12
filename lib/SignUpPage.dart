import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'LoginPage.dart';
import 'main.dart';
import 'services/UserManagement.dart';

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

  // Create an `OAuthCredential` from the credential returned by Apple.
  final oauthCredential = OAuthProvider("apple.com").credential(
    idToken: appleCredential.identityToken,
    rawNonce: rawNonce,
  );

  // Sign in the user with Firebase. If the nonce we generated earlier does
  // not match the nonce in `appleCredential.identityToken`, sign in will fail.
  return await FirebaseAuth.instance.signInWithCredential(oauthCredential);
}

GoogleSignIn _googleSignUp = new GoogleSignIn();

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  String? _email;
  String? _password;
  String? _username;
  bool? _usernameTaken;
  String? _validateUsernameError;
  String? _emailError;
  String? _passwordError;
  bool _termsAccepted = false;

  @override
  Widget build(BuildContext context){
    return new Scaffold (
        appBar: AppBar(
          backgroundColor: Colors.deepPurple,
          leading: IconButton(icon: Icon(Icons.arrow_back), onPressed: () {
            Navigator.pushReplacement(context, MaterialPageRoute(
              builder: (context) => LoginPage(),
            ));
          }),
        ),
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/images/drawable-xxxhdpi/login-bg.png"),
              fit: BoxFit.cover,
            ),
          ),
          child: Center(
            child: Container(
                padding: EdgeInsets.all(25.0),
                child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Image.asset('assets/images/logo.png', height: 150, width: 150,),
                        SizedBox(height: 50.0),
                        TextField(
                            decoration: InputDecoration(
                              hintText: 'Username',
                              errorText: _validateUsernameError,
                              errorMaxLines: 3,
                            ),
                            onChanged: (value) {
                              setState((){
                                _username = value;
                                _validateUsernameError = validateUsername(_username);
                              });
                            }
                        ),
                        SizedBox(height: 10.0),
                        TextField(
                            decoration: InputDecoration(hintText: 'Email',
                              errorText: _emailError,
                            ),
                            onChanged: (value) {
                              setState((){
                                _email = value;
                              });
                            }
                        ),
                        SizedBox(height: 15.0),
                        TextField(
                          decoration: InputDecoration(hintText: 'Password', errorText: _passwordError, errorMaxLines: 2),
                          onChanged: (value) {
                            setState((){
                              _password = value;
                            });
                          },
                          obscureText: true,
                        ),
                        SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            Checkbox(
                              value: _termsAccepted,
                              onChanged: (value) {
                                setState(() {
                                  _termsAccepted = !_termsAccepted;
                                });
                              },
                            ),
                            Container(
                              width: 200,
                              child: RichText(
                                text: TextSpan(
                                    children: [
                                      TextSpan(
                                          text: 'By signing in or signing, you are agreeing to our ',
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
                          ],
                        ),
                        SizedBox(height: 20.0),
                        RaisedButton(
                          child: Text('Sign Up'),
                          color: Colors.deepPurple,
                          textColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: new BorderRadius.circular(25.0),
                          ),
                          elevation: 7.0,
                          onPressed: () async {
                            if(!_termsAccepted) {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: Text('Accept our Terms of Use'),
                                    actions: <Widget>[
                                      FlatButton(
                                        child: Text('OK'),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      )
                                    ],
                                  );
                                }
                              );
                              return;
                            }
                            if(_username == null){
                              print('username is null');
                              missingUsername(context);
                              return;
                            }
                            _usernameTaken = await UserManagement().usernameExists(_username);
                            if (_usernameTaken ?? false) {
                              usernameInUse(context);
                            } else if (_validateUsernameError != null) {
                              usernameError(context);
                            } else {
                              if(_email == null || _email?.length == 0) {
                                setState(() {
                                  _emailError = "Don't forget to enter your email!";
                                  _passwordError = null;
                                });
                                return;
                              }
                              if(_password == null || _password?.length == 0) {
                                setState(() {
                                  _passwordError = "Don't forget to enter your password!";
                                  _emailError = null;
                                });
                                return;
                              }
                              FirebaseAuth.instance.createUserWithEmailAndPassword(
                                  email: _email ?? '',
                                  password: _password ?? ''
                              ).then((signedInUser) {
                                User? newUser = signedInUser.user;
                                UserManagement().storeNewUser(newUser, username: _username);
                              }).catchError((e) {
                                print('Error: ${e.code}');
                                switch(e.code) {
                                  case "weak-password":
                                    setState(() {
                                      _emailError = null;
                                      _passwordError = 'Your password is too weak. Passwords must be at least 6 characters long';
                                    });
                                    break;
                                  case 'email-already-in-use':
                                    setState(() {
                                      _passwordError = null;
                                      _emailError = 'Email already in use!';
                                    });
                                    break;
                                  case 'invalid-email':
                                    setState(() {
                                      _passwordError = null;
                                      _emailError = 'Please enter a valid email address!';
                                    });
                                    break;
                                  default:
                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        return SimpleDialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
                                          contentPadding: EdgeInsets.all(10),
                                          title: Text('Error Signing Up!'),
                                          children: [
                                            Text("We're sorry! It looks like there was an unexpected error while signing up: ${e.code}")
                                          ],
                                        );
                                      }
                                    );
                                    setState(() {
                                      _passwordError = null;
                                      _emailError = null;
                                    });
                                }
                              });
                            }
                          },
                        ),
                        _GoogleSignUpSection(termsAccepted: _termsAccepted,),
                        Platform.isIOS ? SignInWithAppleButton(
                            onPressed: () async {
                              await signInWithApple();
                        }) : Container()
                      ],
                    )
                )
            ),
          ),
        ),
    );
  }
}


class _GoogleSignUpSection extends StatefulWidget {
  bool? termsAccepted = false;

  _GoogleSignUpSection({this.termsAccepted});

  @override
  State<StatefulWidget> createState() => _GoogleSignUpSectionState();
}

class _GoogleSignUpSectionState extends State<_GoogleSignUpSection> {
  String? _username;
  final TextEditingController usernameController = TextEditingController();

  @override
  void dispose() {
    usernameController.dispose();
    super.dispose();
  }

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
              textStyle: TextStyle(color: Colors.deepPurple,),
              shape: RoundedRectangleBorder(
                borderRadius: new BorderRadius.circular(25.0),
              ),
            ),
            onPressed: () async {
              if(!(widget.termsAccepted ?? false)) {
                await showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text('Accept our Terms of Use'),
                        actions: <Widget>[
                          TextButton(
                            child: Text('OK'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          )
                        ],
                      );
                    }
                );
                return;
              } else {
                _signUpWithGoogle();
              }
            },
            child: Container(
              width: 200.0,
              child: Center(
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

  void _signUpWithGoogle() async {
    bool userDocCreated;

    final GoogleSignInAccount? googleUser = await _googleSignUp.signIn();
    if(googleUser == null) {
      return;
    }
    final GoogleSignInAuthentication googleAuth = await googleUser
        .authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final UserCredential userCred = await FirebaseAuth.instance.signInWithCredential(
        credential);
    final User? user = userCred.user;
    assert(user?.email != null);
    assert(user?.displayName != null);
    assert(!(user?.isAnonymous ?? false));
    assert(await user?.getIdToken() != null);

    final User? currentUser = FirebaseAuth.instance.currentUser;
    assert(user?.uid == currentUser?.uid);

    userDocCreated = await UserManagement().userAlreadyCreated();
    print('User exists: $userDocCreated------------------');

    setState(() {
      if (user != null) {
        if (!userDocCreated) {
          print('creating user document');
          UserManagement().storeNewUser(currentUser);
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (context) => MainApp(),
          ));
        }
      }
    });
  }
}