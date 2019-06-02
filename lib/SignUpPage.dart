import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'services/UserManagement.dart';

GoogleSignIn _googleSignUp = new GoogleSignIn();

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  String _email;
  String _password;
  String _username;
  bool _usernameTaken;
  String _validateUsernameError;

  @override
  Widget build(BuildContext context){
    return new Scaffold (
        appBar: AppBar(),
        body: Center(
          child: Container(
              padding: EdgeInsets.all(25.0),
              child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Image.asset('assets/images/logo.png'),
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
                          decoration: InputDecoration(hintText: 'Email'),
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
                        child: Text('Sign Up'),
                        color: Colors.deepPurple,
                        textColor: Colors.white,
                        elevation: 7.0,
                        onPressed: () async {
                          _usernameTaken = await UserManagement().usernameExists(_username);
                          if(_username == null){
                            missingUsername(context);
                          } else if (_usernameTaken) {
                            usernameInUse(context);
                          } else if (_validateUsernameError != null) {
                            usernameError(context);
                          } else {
                            FirebaseAuth.instance.createUserWithEmailAndPassword(
                                email: _email,
                                password: _password
                            ).then((signedInUser) {
                              UserManagement().storeNewUser(signedInUser, context, username: _username);
                            }).catchError((e) {
                              print(e);
                            });
                          }
                        },
                      ),
                      SizedBox(height: 10.0),
                      _GoogleSignUpSection()
                    ],
                  )
              )
          ),
        )
    );
  }
}


class _GoogleSignUpSection extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _GoogleSignUpSectionState();
}

class _GoogleSignUpSectionState extends State<_GoogleSignUpSection> {
  String _username;
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
          child: RaisedButton(
            color: Colors.deepPurple,
            textColor: Colors.white,
            onPressed: () {
              _signUpWithGoogle();
            },
            child: const Text('Sign Up with Google'),
          ),
        ),
      ],
    );
  }

  void _signUpWithGoogle() async {
    bool userDocCreated;

    final GoogleSignInAccount googleUser = await _googleSignUp.signIn();
    final GoogleSignInAuthentication googleAuth = await googleUser
        .authentication;
    final AuthCredential credential = GoogleAuthProvider.getCredential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final FirebaseUser user = await FirebaseAuth.instance.signInWithCredential(
        credential);
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
        if (!userDocCreated) {
          print('creating user document');
          UserManagement().storeNewUser(currentUser, context);
        } else {
          Navigator.of(context).pushReplacementNamed('/homepage');
        }
      }
    });
  }
}