import 'package:Perkl/services/UserManagement.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:Perkl/services/models.dart';
import 'package:Perkl/services/db_services.dart';
import 'package:provider/provider.dart';

class AccountSettings extends StatelessWidget {
  @override
  build(BuildContext context) {
    FirebaseUser firebaseUser = Provider.of<FirebaseUser>(context);
    return MultiProvider(
      providers: [
        StreamProvider<User>(create: (_) => UserManagement().streamCurrentUser(firebaseUser),),
        ChangeNotifierProvider<AccountSettingsProvider>(create: (_) => AccountSettingsProvider(),)
      ],
      child: Consumer<AccountSettingsProvider>(
        builder: (context, asp, _) {
          User currentUser = Provider.of<User>(context);
          print('Firebase User Info: ${firebaseUser.providerId}/${firebaseUser.isEmailVerified}');
          return SimpleDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
            title: Center(child: Text('Account Settings'),),
            contentPadding: EdgeInsets.fromLTRB(10, 10, 10, 20),
            children: <Widget>[
              Text('Username:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${currentUser == null || currentUser.username == null ? '' : currentUser.username}'),
              SizedBox(height: 10),
              Text('Email:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${currentUser == null || currentUser.email == null ? '' : currentUser.email}'),
              SizedBox(height: 10),
              FlatButton(
                child: Text('Change Password'),
                onPressed: () {

                },
              ),
              FlatButton(
                child: Text('Deactivate Account'),
                onPressed: () {

                },
              )
            ],
          );
        },
      ),
    );
  }
}

class AccountSettingsProvider extends ChangeNotifier {

}