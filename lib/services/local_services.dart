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
      data = jsonDecode(await file.readAsString());
    } else {
      file = new File('$filepath/$filename');
      data = new Map<String, dynamic>();
    }
    _isInitialized = true;
  }

  update() async {
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
