import 'package:Perkl/main.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ListTileBubble extends StatelessWidget {
  double width;
  Widget leading;
  Widget title;
  Widget subTitle;
  Widget trailing;
  Function onTap;
  MainAxisAlignment alignment;
  Color color;
  EdgeInsets padding;

  ListTileBubble({this.width, this.leading, this.title, this.subTitle, this.trailing, this.onTap, this.alignment, this.color, this.padding});

  @override

  build(BuildContext context) {
    print('Width: $width');
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    return InkWell(
      child: Row(
        mainAxisAlignment: alignment ?? MainAxisAlignment.start,
        children: <Widget>[
          Card(
            elevation: 5,
            color: color ?? Colors.white,
            margin: EdgeInsets.all(5),
            child: Container(
              padding: padding ?? EdgeInsets.all(5),
              child: Row(
                mainAxisAlignment: alignment ?? MainAxisAlignment.start,
                children: <Widget>[
                  leading ?? Container(),
                  leading != null ? SizedBox(width: 5) : Container(),
                  Column(
                    crossAxisAlignment: alignment == MainAxisAlignment.end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: <Widget>[
                      title != null ? ConstrainedBox(child: title, constraints: BoxConstraints(maxWidth: 200),) : Container(),
                      subTitle != null ? ConstrainedBox(child: subTitle, constraints: BoxConstraints(maxWidth: 200),) : Container(),
                    ],
                  ),
                  trailing != null ? SizedBox(width: 5) : Container(),
                  trailing ?? Container(),
                ],
              )
            ),
          )
        ],
      ),
      onTap: () {
        if(onTap != null) {
          onTap();
        }
      },
    );
  }
}