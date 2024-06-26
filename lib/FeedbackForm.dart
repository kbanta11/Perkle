import 'package:Perkl/services/UserManagement.dart';
import 'package:Perkl/services/db_services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:Perkl/services/models.dart';

class FeedbackForm extends StatelessWidget {
  @override
  build(BuildContext context) {
    User? firebaseUser = Provider.of<User?>(context);
    return MultiProvider(
      providers: [
        StreamProvider<PerklUser?>(create: (_) => UserManagement().streamCurrentUser(firebaseUser), initialData: null),
        ChangeNotifierProvider<FeedbackProvider>(create: (_) => FeedbackProvider(),),
      ],
      child: Consumer<FeedbackProvider>(
        builder: (context, fbp, _) {
          PerklUser? currentUser = Provider.of<PerklUser?>(context);
          return SimpleDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
            title: Center(child: Text('Feedback')),
            contentPadding: EdgeInsets.fromLTRB(10, 10, 10, 20),
            children: <Widget>[
              Text('Rating:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<int>.generate(5, (i) => i + 1).map((i) => IconButton(
                    icon: Icon(fbp.rating != null && i <= (fbp.rating ?? 5) ? Icons.star : Icons.star_border, color: Colors.deepPurple,),
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
  int? rating;
  String? positive;
  String? negative;

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

  Future<void> sendFeedback(PerklUser? user) async {
    await DBService().sendFeedback(rating, positive, negative, user);
    return;
  }
}