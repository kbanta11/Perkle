import 'package:Perkl/MainPageTemplate.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/models.dart';
import 'services/db_services.dart';
import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';
import 'PageComponents.dart';
import 'ProfilePage.dart';

class UserList extends StatelessWidget {
  List<String> userIdList;
  UserListType type;

  UserList(this.userIdList, this.type);

  @override
  build(BuildContext context) {
    return MainPageTemplate(
      bottomNavIndex: 1,
      noBottomNavSelected: true,
      body: ListView(
        children: userIdList.length > 0 ? userIdList.map((id) => StreamBuilder<User>(
          stream: UserManagement().streamUserDoc(id),
          builder: (context, AsyncSnapshot<User> userSnap) {
            User user = userSnap.data;
            print('User Id: $id/User obj: $user');
            return Card(
              margin: EdgeInsets.all(5),
              elevation: 5,
              child: ListTile(
                contentPadding: EdgeInsets.all(5),
                leading: ProfilePic(user),
                title: Text(user == null ? '' : user.username, style: TextStyle(fontSize: 16)),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) =>
                        ProfilePageMobile(userId: user.uid),
                  ));
                },
              ),
            );
          },
        )).toList() : [Center(child: Text(type == UserListType.FOLLOWERS ? 'User has no followers 🙁' : 'User is not following anyone yet!'))],
      ),
    );
  }
}