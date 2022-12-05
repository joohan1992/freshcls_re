import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:freshcls/provider/common_info_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freshcls/provider/infer_provider.dart';
import 'package:provider/provider.dart';

import 'camera_app.dart';

// 로그인 화면 UI
class LoginPage extends StatefulWidget {
  final Function(dynamic, dynamic) requestLogin;

  const LoginPage({Key? key, required this.requestLogin, }) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with WidgetsBindingObserver {

  // late InferProvider _inferProvider;
  // late CommonInfoProvider _commonInfoProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final prefs = await SharedPreferences.getInstance();

    switch (state) {
      case AppLifecycleState.detached:
        await prefs.clear();
        break;

      case AppLifecycleState.paused:
      // await prefs.clear();
        break;

      case AppLifecycleState.resumed:
      // TODO: Handle this case.
        break;

      case AppLifecycleState.inactive:
      // TODO: Handle this case.
        break;
    }
  }

  final formKey = new GlobalKey<FormState>();

  late String id;
  late String password;

  Map<String, String> resultMap = {};

  Text title_text = Text('');
  Text act_text = Text('');

  bool validateAndSave() {
    final form = formKey.currentState;
    if (form!.validate()) {
      form.save();
      print('Form is valid Email: $id, password: $password');
      return true;
    } else {
      print('Form is invalid Email: $id, password: $password');
      return false;
    }
  }

  loginFailure(BuildContext context, resultMap) async {
    final prefs = await SharedPreferences.getInstance();

    if (resultMap['log_in_st'] == 0) {
      prefs.setString('ID', id);
      prefs.setString('PW', password);
      prefs.setString('str_no', resultMap['str_no'].toString());
      prefs.setString('login_no', resultMap['login_no'].toString());
      prefs.setString('act_yn', resultMap['act_yn'].toString());

      // _inferProvider.pushLabels(resultMap['label_init']);
      List<dynamic> listLabel = resultMap['label_init'];
      listLabel.forEach((element) {
        List<dynamic> eleMap = element;
        labelMap[eleMap[0]] = eleMap[2];
        labelList.add(eleMap[0]);
      });

      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            // builder: (BuildContext context) => MultiProvider(
            //   providers: [
            //     ChangeNotifierProvider(create: (_) => InferProvider()),
            //     ChangeNotifierProvider(create: (_) => CommonInfoProvider()),
            //   ],
            //   child: CameraApp(),
            // ),
            builder: (BuildContext context) => CameraApp(labelMap: labelMap, labelList: labelList,),
          ));
    } else {
      if (resultMap['log_in_st'] == 1) {
        title_text = Text(
          '인증 실패',
          textAlign: TextAlign.left,
        );
        act_text = Text(
          resultMap['log_in_text'],
          textAlign: TextAlign.center,
        );
      } else if (resultMap['log_in_st'] == 2) {
        title_text = Text(
          '로그인 실패',
          textAlign: TextAlign.left,
        );
        act_text = Text(
          resultMap['log_in_text'],
          textAlign: TextAlign.center,
        );
      } else if (resultMap['log_in_st'] == 3) {
        title_text = Text(
          '로그인 실패',
          textAlign: TextAlign.left,
        );
        act_text = Text(
          resultMap['log_in_text'],
          textAlign: TextAlign.center,
        );
      }
      return showDialog<void>(
        context: context,
        barrierDismissible: false, // user must tap button!
        builder: (BuildContext context) {
          return AlertDialog(
            title: title_text,
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  act_text,
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('확인'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // _inferProvider = Provider.of<InferProvider>(context, listen: false);

    return Scaffold(
      appBar: new AppBar(
        title: new Text('R-pha Vision V1.0'),
      ),
      body: Container(
          padding: EdgeInsets.all(16),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                new TextFormField(
                  decoration: new InputDecoration(labelText: 'Id'),
                  validator: (value) =>
                  value!.isEmpty ? 'Id can\'t be empty' : null,
                  onSaved: (value) => id = value!,
                  onChanged: (value) => id = value,
                ),
                new TextFormField(
                  obscureText: true,
                  decoration: new InputDecoration(labelText: 'Password'),
                  validator: (value) =>
                  value!.isEmpty ? 'Password can\'t be empty' : null,
                  onSaved: (value) => password = value!,
                  onChanged: (value) => password = value,
                ),
                ElevatedButton(
                  child: new Text(
                    'Login',
                    style: new TextStyle(fontSize: 20.0),
                  ),

                  onPressed: () async {
                    if(validateAndSave()) {

                      Map<String, dynamic> resultMap = await widget.requestLogin(id, password);
                      loginFailure(context, resultMap);
                    }
                  },
                ),
              ]
            ),
          )
        ),
    );
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}