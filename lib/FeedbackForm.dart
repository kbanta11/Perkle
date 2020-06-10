import 'package:Perkl/services/UserManagement.dart';
import 'package:Perkl/services/db_services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:Perkl/services/models.dart';

class FeedbackForm extends StatelessWidget {
  @override
  build(BuildContext context) {
    FirebaseUser firebaseUser = Provider.of<FirebaseUser>(context);
    return MultiProvider(
      providers: [
        StreamProvider<User>(create: (_) => UserManagement().streamCurrentUser(firebaseUser),),
        ChangeNotifierProvider<FeedbackProvider>(create: (_) => FeedbackProvider(),),
      ],
      child: Consumer<FeedbackProvider>(
        builder: (context, fbp, _) {
          User currentUser = Provider.of<User>(context);
          return SimpleDialog(
            title: Center(child: Text('Feedback')),
            contentPadding: EdgeInsets.fromLTRB(10, 10, 10, 20),
            children: <Widget>[
              Text('Rating:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<int>.generate(5, (i) => i + 1).map((i) => IconButton(
                    icon: Icon(fbp.rating != null && i <= fbp.rating ? Icons.star : Icons.star_border),
                  onPressed: () {
                      fbp.changeRating(i);
                  },
                )).toList(),
              ),
              Text('Tell us what rocks about Perkl:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextField(
                maxLines: 4,
                onChanged: (val) {
                  fbp.changePositive(val);
                },
              ),
              SizedBox(height: 10),
              Text('Tell us what sucks about Perkl:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextField(
                maxLines: 4,
                onChanged: (val) {
                  fbp.changeNegative(val);
                },
              ),
              SizedBox(height: 15),
              FlatButton(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                child: Text('Send Feedback', style: TextStyle(fontSize: 18, color: Colors.white)),
                color: Colors.deepPurple,
                onPressed: () async {
                  await fbp.sendFeedback(currentUser);
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        }
      ),
    );
  }
}

class FeedbackProvider extends ChangeNotifier {
  int rating;
  String positive;
  String negative;

  void changeRating(int val) {
    rating = val;
    notifyListeners();
  }

  void changePositive(String newVal) {
    positive = newVal;
    notifyListeners();
  }

  void changeNegative(String newVal) {
    negative = newVal;
    notifyListeners();
  }

  Future<void> sendFeedback(User user) async {
    await DBService().sendFeedback(rating, positive, negative, user);
    return;
  }
}