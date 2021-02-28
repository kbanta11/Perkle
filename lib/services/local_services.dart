import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'dart:io';

class LocalService {
  bool _isInitialized = false;
  Map data;
  String filepath;
  String filename = 'local_data.json';
  File file;

  LocalService({this.filename});

  initialize() async {
    filepath = await getApplicationDocumentsDirectory().then((directory) => directory.path);
    file = await File('$filepath/$filename').exists() ? File('$filepath/$filename') : null;
    if(file != null) {
      print('Local Data File Exists, start decoding... \n${await file.readAsString()}');
      try {
        data = jsonDecode(await file.readAsString());
      } on Exception catch (e) {
        file = new File('$filepath/$filename');
        data = new Map<String, dynamic>();
      }
      //print('Decoding complete!');
    } else {
      file = new File('$filepath/$filename');
      data = new Map<String, dynamic>();
    }
    _isInitialized = true;
  }

  update() async {
    if(!_isInitialized) {
      await this.initialize();
    }
    try {
      print('Data json ###: ${jsonEncode(data)}');
      print('Data String ###: ${await file.readAsString()}');
      data = jsonDecode(await file.readAsString());
    } catch (e) {
      await file.writeAsString(jsonEncode(data), flush: true, mode: FileMode.write,);
      try {
        print('Data json ***: ${jsonEncode(data)}');
        print('Data String ***: ${await file.readAsString()}');
        data = jsonDecode(await file.readAsString());
      } on Exception catch (e) {
        print('Still an error after rewrite: $e');
      }
      print('Rewrote data: $e');
    }
  }

  Future<dynamic> getData(String key) async {
    if(!_isInitialized) {
      await this.initialize();
    }
    try {
      return data[key];
    } catch (e) {
      print('Error getting local data: $key/$e');
    }
    return;
  }

  Future<void> setData(String key, dynamic value) async {
    if(!_isInitialized) {
      await this.initialize();
    }
    try {
      data[key] = value;
      print('writing updated data file: ${jsonEncode(data)}');
      await file.writeAsString(jsonEncode(data), flush: true, mode: FileMode.write,);
      await update();
    } catch (e) {
      print('Error writing update to file: $e\n$key/$value');
    }
  }
}
