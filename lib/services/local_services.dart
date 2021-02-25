import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'dart:io';

class LocalService {
  bool _isInitialized = false;
  Map data;
  String filepath;
  String filename = 'local_data.json';
  File file;

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
      data = jsonDecode(await file.readAsString());
    } catch (e) {
      print('Error Updating file: $e');
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
      await file.writeAsString(jsonEncode(data));
      await update();
    } catch (e) {
      print('Error writing update to file: $e\n$key/$value');
    }
  }
}
