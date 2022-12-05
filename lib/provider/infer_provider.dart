import 'package:flutter/material.dart';

class InferProvider extends ChangeNotifier {
  Map<int, String> _labelMap = Map();
  List<int> _labelList = [];

  Map<int, String> get labelMap => _labelMap;
  List<int> get labelList => _labelList;

  void pushLabels(List<dynamic> data) {
    data.forEach((element) {
      List<dynamic> eleMap = element;
      _labelMap[eleMap[0]] = eleMap[2];
      _labelList.add(eleMap[0]);
    });
    notifyListeners();
  }
}