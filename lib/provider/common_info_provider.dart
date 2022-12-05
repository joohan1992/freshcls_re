import 'package:flutter/material.dart';

enum LoginStatus { initial, success, fail }

class CommonInfoProvider extends ChangeNotifier {
  String _str_no = "";
  String _device = "";

  String get str_no => _str_no;
  String get device => _device;

  void setUserInfo(dynamic data) {
    _str_no = data['str_no'].toString();
    notifyListeners();
  }

  void setDeviceInfo(dynamic data) {
    _device = data;
    notifyListeners();
  }
}