import 'package:flutter/material.dart';
import 'package:Perkl/services/models.dart';
import 'package:Perkl/services/db_services.dart';

class CreateGroupDialog extends StatefulWidget {
  PerklUser? user;

  CreateGroupDialog({Key? key, @required this.user}) : super(key: key);

  @override
  _CreateGroupDialogState createState() => new _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  String? _groupName;
  Map<String, dynamic> _groupUsers = new Map<String, dynamic>();

  @override
  build(BuildContext context) {
    if(widget.user != null) {
      List<String> selectableFollowers = widget.user?.followers?.where((followerID) => widget.user?.following?.contains(followerID) ?? false).toList() ?? [];
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15.0))),
        title: Center(child: Text('Create New Group')),
        content: Container(
          height: MediaQuery.of(context).size.height - 20,
          width: MediaQuery.of(context).size.width - 20,
          child: Column(
              children: [
                Container(
                    child: TextField(
                        style: TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: _groupName == null ? 'Group Name (Optional)' : _groupName,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _groupName = value;
                          });
                        }
                    )
                ),
                SizedBox(height: 10),
                ListTile(
                    title: Text('Select users to add...')
                ),
                Divider(height: 5),
                Expanded(
                    child: ListView(
                        children: selectableFollowers != null && selectableFollowers.length > 0 ? selectableFollowers.map((id) {
                          if(!_groupUsers.containsKey(id)) {
                            _groupUsers.addAll({id: false});
                          }
                          bool _val = _groupUsers[id];
                          return CheckboxListTile(
                              title: FutureBuilder(
                                  future: DBService().getPerklUser(id),
                                  builder: (context, AsyncSnapshot<PerklUser> thisUserSnap) {
                                    if(!thisUserSnap.hasData) {
                                      return Container();
                                    }
                                    return Text(thisUserSnap.data?.username ?? '', style: TextStyle(fontSize: 14),);
                                  }
                              ),
                              value: _val,
                              onChanged: (value) {
                                print(_groupUsers);
                                setState(() {
                                  _groupUsers[id] = value;
                                });
                              }
                          );
                        }).toList() : [Center(child: Text('You '))]
                    )
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      child: Text('Cancel', style: TextStyle(color: Colors.deepPurple)),
                      onPressed: () {
                        Navigator.pop(context, null);
                      },
                    ),
                    _groupUsers.containsValue(true) ? FlatButton(
                      child: Text('Create Group!', style: TextStyle(color: Colors.white)),
                      color: Colors.deepPurple,
                      onPressed: () async {
                        _groupUsers.removeWhere((String id, dynamic val) => !val);
                        print('Users in new group: ${_groupUsers.keys.toList()}');
                        List<String> groupUserIds = _groupUsers.keys.toList();
                        groupUserIds.add(widget.user?.uid ?? '');
                        Conversation newConvo = await DBService().createNewGroup(_groupName, groupUserIds);
                        Navigator.pop(context, newConvo);
                      },
                    ) : Container()
                  ]
                )
              ]
          ),
        ),
      );
    }
    return Center(child: CircularProgressIndicator());
  }
}