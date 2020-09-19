import 'package:flutter/material.dart';

class TutorialDialog extends StatefulWidget {
  //TutorialDialog({Key key, }) : super(key: key);

  @override
  _TutorialDialogState createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<TutorialDialog> {

  @override
  build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black12,
      body: Stack(
        children: <Widget>[
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  FlatButton(
                    child: Text('Skip', style: TextStyle(color: Colors.white)),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  FlatButton(
                      child: Text('Next', style: TextStyle(color: Colors.white)),
                      onPressed: () {

                      }
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}