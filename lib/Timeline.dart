import 'dart:io';
import 'package:Perkl/services/UserManagement.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'ProfilePage.dart';
import 'StreamTagPage.dart';
import 'services/models.dart';
import 'services/db_services.dart';
import 'main.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:http/http.dart' as http;

enum TimelineType {
  STREAMTAG,
  MAINFEED,
  USER,
}

class Timeline extends StatelessWidget {
  String timelineId;
  Stream tagStream;
  String userId;
  TimelineType type;

  Timeline({this.timelineId, this.tagStream, this.userId, this.type});

  @override
  build(BuildContext context) {
    FirebaseUser firebaseUser = Provider.of<FirebaseUser>(context);
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    //print('TimelineId: $timelineId/StreamTag: $tagStream/UserId: $userId');
    Stream postStream;
    if(tagStream != null) {
      postStream = tagStream;
      //print('Grabbed stream for tag: $tagStream');
    } else {
      postStream = DBService().streamTimelinePosts(firebaseUser, timelineId: timelineId, userId: userId);
    }

    /*
    convertFile(Post post) async {
      String fileLocation = post.audioFileLocation;
      http.Response downloadedFile = await http.get(fileLocation);
      var bytes = downloadedFile.bodyBytes;
      String directory = (await getApplicationDocumentsDirectory()).path;
      File tempFile = File('$directory/tempInputFile.aac');
      await tempFile.writeAsBytes(bytes).then((file) {
        print('File Size: ${file.lengthSync()}');
      });
      String inputFilePath = tempFile.path;
      String outputFilePath = '$directory/outputFile.aac';
      print('Temp Input FilePath: $inputFilePath');
      //await FlutterFFmpegConfig().resetStatistics();

      print('try deleting file if exists');
      try {
        print('getting output file');
        File currentOutputFile = File(outputFilePath);
        print('deleting file');
        await currentOutputFile.delete();
        print('file deleted');
      } catch (e) {
        print('error deleting file: $e');
        //return 0;
      }

      print('getting file info:');
      await FlutterFFprobe().getMediaInformation(inputFilePath).then((info) {
        print(info);
      }).catchError((error) {
        print('error: $error');
      });

      FlutterFFmpeg _ffmpeg = new FlutterFFmpeg();
      await _ffmpeg.execute('-i $inputFilePath $outputFilePath').then((rc) {
        print('Result from conversion: $rc');
      });

      print('output file: $outputFilePath/Size: ${File(outputFilePath).lengthSync()}');

      //Upload new file
      String dateString = DateFormat("yyyy-MM-dd_HH_mm_ss").format(post.datePosted).toString();
      File newFile = File(outputFilePath);
      String filename = dateString.toString().replaceAll(new RegExp(r' '), '_');
      final StorageReference storageRef = FirebaseStorage.instance.ref().child(post.userUID).child(filename);
      final StorageUploadTask uploadTask = storageRef.putFile(newFile);
      //Add new download url to post
      String _fileUrl = await (await uploadTask.onComplete).ref.getDownloadURL();
      DocumentReference postRef = Firestore.instance.collection('posts').document(post.id);
      await Firestore.instance.runTransaction((transaction) async {
        await transaction.update(postRef, {'audioFileLocation': _fileUrl});
      });
    }
    */

    return MultiProvider(
      providers: [
        StreamProvider<List<Post>>(create: (_) => postStream),
        StreamProvider<User>(create: (_) => UserManagement().streamCurrentUser(firebaseUser))
      ],
      child: StreamBuilder<List<Post>>(
        stream: postStream,
        builder: (context, AsyncSnapshot<List<Post>> postListSnap) {
          User currentUser = Provider.of<User>(context);
          List<Post> postList = postListSnap.data;
          if(postList != null) {
            //print('setting page posts');
            mp.setPagePosts(postList);
          }
          //print('Post List: ${postList != null ? postList.length : ''}');
          String emptyText = 'Looks like there are\'nt any posts to show here!';
          if(type == TimelineType.MAINFEED)
            emptyText = 'Your Timeline is Empty! Try following some users!';
          if(type == TimelineType.USER && currentUser != null && userId == currentUser.uid)
            emptyText = 'You have no posts! Try recording and say hello!';
          if(type == TimelineType.USER && currentUser != null && userId != currentUser.uid)
            emptyText = 'This user hasn\'t posted yet!';
          if(type == TimelineType.STREAMTAG)
            emptyText = 'There aren\'t any posts for this tag yet!';

          //Get Days in timeline and group daily posts together
          List<DayPosts> days = List<DayPosts>();
          if(postList != null) {
            postList.forEach((post) {
              if(days.where((d) => d.date.year == post.datePosted.year && d.date.month == post.datePosted.month && d.date.day == post.datePosted.day).length > 0) {
                days.where((d) => d.date.year == post.datePosted.year && d.date.month == post.datePosted.month && d.date.day == post.datePosted.day).first.list.add(post);
              } else {
                List list = List();
                list.add(post);
                days.add(DayPosts(date: DateTime(post.datePosted.year, post.datePosted.month, post.datePosted.day), list: list));
              }
            });
          }

          return ListView(
            children: postList == null ? [Center(child: CircularProgressIndicator())] : postList.length == 0 ? [Center(child: Text(emptyText))] : days.map((day) {
              return Container(
                margin: EdgeInsets.only(left: 10, bottom: 10),
                padding: EdgeInsets.only(left: 10),
                decoration: BoxDecoration(
                    border: Border(
                        left: BorderSide(color: Colors.deepPurple[500], width: 2)
                    )
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(day.date.year == DateTime.now().year && day.date.month == DateTime.now().month && day.date.day == DateTime.now().day ? 'Today' : DateFormat('MMMM dd, yyyy').format(day.date), style: TextStyle(fontSize: 16, color: Colors.deepPurple[500]),),
                    Column(
                      children: day.list.map((post) {
                        return StreamProvider<User>(
                          create: (context) => UserManagement().streamUserDoc(post.userUID),
                          child: Consumer<User>(
                            builder: (context, poster, _) {
                              return Card(
                                elevation: 5,
                                color: Colors.deepPurple[50],
                                margin: EdgeInsets.all(5),
                                child: Padding(
                                  padding: EdgeInsets.all(5),
                                  child: ExpansionTile(
                                    leading: poster == null || poster.profilePicUrl == null ? Container(
                                      height: 60.0,
                                      width: 60.0,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.deepPurple,
                                      ),
                                      child: InkWell(
                                        child: Container(),
                                        onTap: () {
                                          Navigator.push(context, MaterialPageRoute(
                                            builder: (context) =>
                                                ProfilePageMobile(userId: post.userUID,),
                                          ));
                                        },
                                      ),
                                    ) : Container(
                                        height: 60.0,
                                        width: 60.0,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.deepPurple,
                                          image: DecorationImage(
                                            fit: BoxFit.cover,
                                            image: NetworkImage(poster.profilePicUrl),
                                          ),
                                        ),
                                        child: InkWell(
                                          child: Container(),
                                          onTap: () {
                                            Navigator.push(context, MaterialPageRoute(
                                              builder: (context) =>
                                                  ProfilePageMobile(userId: post.userUID,),
                                            ));
                                          },
                                        )
                                    ),
                                    title: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text('@${post.username}'),
                                        Text('${post.postTitle != null ? post.postTitle : DateFormat('MMMM dd, yyyy hh:mm').format(post.datePosted)}'),
                                        post.postTitle != null ? Text(DateFormat('MMMM dd, yyyy hh:mm').format(post.datePosted))  : Container(),
                                      ],
                                    ),
                                    trailing: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: <Widget>[
                                        Container(
                                          width: 80,
                                          child: Row(
                                            children: <Widget>[
                                              InkWell(
                                                child: Container(
                                                  height: 35,
                                                  width: 35,
                                                  decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: mp.currentPostPodId == post.id ? Colors.red : Colors.deepPurple
                                                  ),
                                                  child: Center(child: FaIcon(mp.currentPostPodId == post.id && mp.isPlaying != null && mp.isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play, color: Colors.white, size: 16)),
                                                ),
                                                onTap: () {
                                                  mp.isPlaying != null && mp.isPlaying && mp.currentPostPodId == post.id ? mp.pausePost() : mp.playPost(PostPodItem.fromPost(post));
                                                },
                                              ),
                                              SizedBox(width: 5,),
                                              InkWell(
                                                child: Container(
                                                  height: 35,
                                                  width: 35,
                                                  decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: mp.queue.where((p) => p.id == post.id).length > 0 ? Colors.grey : Colors.deepPurple
                                                  ),
                                                  child: Center(child: FaIcon(FontAwesomeIcons.plus, color: Colors.white, size: 16)),
                                                ),
                                                onTap: () {
                                                  if(mp.queue.where((p) => p.id == post.id).length <= 0)
                                                    mp.addPostToQueue(PostPodItem.fromPost(post));
                                                },
                                              )
                                            ],
                                          ),
                                        ),
                                        Text(post.getLengthString())
                                      ],
                                    ),
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          SizedBox(width: 90),
                                          Expanded(
                                            child: post.streamList != null && post.streamList.length > 0 ? Wrap(
                                              spacing: 8,
                                              children: post.streamList.map<Widget>((String tag) {
                                                return InkWell(
                                                    child: Text('#$tag', style: TextStyle(color: Colors.lightBlue)),
                                                    onTap: () {
                                                      Navigator.push(context, MaterialPageRoute(
                                                          builder: (context) => StreamTagPageMobile(tag: tag,)
                                                      ));
                                                    }
                                                );
                                              }).toList(),
                                            ) : Container(),
                                          ),
                                          currentUser != null && post.userUID == currentUser.uid ? Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: <Widget>[
                                              IconButton(icon: Icon(Icons.delete_forever)),
                                              IconButton(icon: Icon(Icons.file_download))
                                            ],
                                          ) : IconButton(icon: Icon(Icons.file_download),),
                                          /*
                                IconButton(icon: Icon(Icons.music_note),
                                  onPressed: () async {
                                    convertFile(post);
                                  }
                                ),
                                 */
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }).toList(),
                    )
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}