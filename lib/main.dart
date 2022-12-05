import 'dart:convert';
import 'dart:io' as io;
import 'dart:core';

import 'package:freshcls/provider/common_info_provider.dart';
import 'package:freshcls/provider/infer_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'login.dart';

// 카메라 기능 참고
// https://github.com/flutter/flutter/issues/45297 -> Hexer10
// https://github.com/Hexer10/plugins/blob/camera-web/packages/camera/camera_web/lib/camera_web.dart

// Tabbar 참고
// https://eunoia3jy.tistory.com/110

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  clear_prefs();

  // 테스트용 https에서만 사용할 인증 절차 무시하는 코드
  // TODO 실서비스 배포시 삭제하거나 개발용에서만 동작하도록 수정
  io.HttpOverrides.global = NoCheckCertificateHttpOverrides();

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      // home: MultiProvider(
      //   providers: [
      //     ChangeNotifierProvider(create: (_) => InferProvider()),
      //     ChangeNotifierProvider(create: (_) => CommonInfoProvider()),
      //   ],
      //   child: LoginPage(requestLogin: requestLogin),
      // ),
      home: LoginPage(requestLogin: requestLogin),
    ),
  );
}

void clear_prefs() async {
  final prefs = await SharedPreferences.getInstance();
  prefs.clear();
}

// TODO SSL Self-certification으로 인해 추가된 코드, 이후 공식 SSL 적용 시 삭제하거나 개발용에서만 사용하도록 수정
class NoCheckCertificateHttpOverrides extends io.HttpOverrides {
  @override
  io.HttpClient createHttpClient(io.SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (io.X509Certificate cert, String host, int port) => true;
  }
}


requestLogin(id, password) async {
  var header = {"Content-type": "application/json", 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST, GET'};
  var data = {'id': id, 'password': password};
  // var url = "https://192.168.0.88:5443/login";
  var url = "https://10.28.78.30:8091/login";
  var postUri = Uri.parse(url);

  // TODO 웹 개발을 위해 잠시 request는 비활성화
  var res = await http.post(postUri, body: jsonEncode(data), headers: header);
  String resBody = utf8.decode(res.bodyBytes);
  Map<String, dynamic> resultMap = Map.castFrom(jsonDecode(resBody));
  // Map<String, dynamic> resultMap = {};
  // List<dynamic> resultLabelList = [];
  // List<dynamic> tmp_label = [-1, 'Undefined', 'Undefined','None'];
  // resultLabelList.add(tmp_label);
  // tmp_label = [-1, 'apple', '사과','8801'];
  // resultLabelList.add(tmp_label);
  // resultMap['str_no'] = '0';
  // resultMap['login_no'] = '1';
  // resultMap['act_yn'] = 'Y';
  // resultMap['log_in_st'] = 0;
  // resultMap['label_init'] = resultLabelList;


  return resultMap;
}