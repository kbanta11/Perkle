import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'services/UserManagement.dart';

final GoogleSignIn _googleSignIn = new GoogleSignIn();

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String _email;
  String _password;

  @override
  Widget build(BuildContext context){
    return new Scaffold (
      body: Center(
        child: Container(
          padding: EdgeInsets.all(25.0),
          child: SingleChildScrollView(
              child:Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Image.asset('assets/images/logo.png'),
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
                    child: Text('Login'),
                    color: Colors.deepPurple,
                    textColor: Colors.white,
                    elevation: 7.0,
                    onPressed: () {
                      FirebaseAuth.instance.signInWithEmailAndPassword(
                          email: _email,
                          password: _password
                      ).then((FirebaseUser user) {
                        Navigator.of(context).pushReplacementNamed('/homepage');
                      })
                          .catchError((e) {
                        print(e);
                      });
                    },
                  ),
                  SizedBox(height: 10.0),
                  _GoogleSignInSection(),
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
                  ),
                ],
              )
          )
        ),
      )
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
            color: Colors.deepPurple,
            textColor: Colors.white,
            onPressed: () async {
              _signInWithGoogle();
            },
            child: const Text('Sign in with Google'),
          ),
        ),
      ],
    );
  }

  // Example code of how to sign in with google.
  void _signInWithGoogle() async {
    bool userDocCreated;

    print('Starting Google sign in');
    final GoogleSignInAccount googleUser = await _googleSignIn.signIn();
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.getCredential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final FirebaseUser user = await FirebaseAuth.instance.signInWithCredential(credential);
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
          UserManagement().storeNewUser(currentUser, context);
        } else {
          Navigator.of(context).pushReplacementNamed('/homepage');
        }
      } else {
        _success = false;
      }
    });
  }
}