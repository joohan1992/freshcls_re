import 'dart:convert';
import 'dart:io' as io;
import 'dart:core';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

import 'package:camera/camera.dart' as camlib;

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'package:flutter/foundation.dart';

import 'package:image_picker/image_picker.dart';

// 카메라 기능 참고
// https://github.com/flutter/flutter/issues/45297 -> Hexer10
// https://github.com/Hexer10/plugins/blob/camera-web/packages/camera/camera_web/lib/camera_web.dart

// Tabbar 참고
// https://eunoia3jy.tistory.com/110

Map<int, String> labelMap = Map();
List<int> labelList = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 테스트용 https에서만 사용할 인증 절차 무시하는 코드
  // TODO 실서비스 배포시 삭제하거나 개발용에서만 동작하도록 수정
  io.HttpOverrides.global = NoCheckCertificateHttpOverrides();

  Map<String, dynamic> resultMap = await getLabelList();
  if (resultMap['result'] == 'ok') {
    List<dynamic> resultLabelList = resultMap['str_label_list'];
    resultLabelList.forEach((element) {
      List<dynamic> eleMap = element;
      labelMap[eleMap[0]] = eleMap[2];
      labelList.add(eleMap[0]);
    });
  }

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: LoginPage(),
    ),
  );
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
  var data = {'id': id, 'password': password};
  var url = "https://192.168.0.88:5443/login";
  var postUri = Uri.parse(url);
  var res = await http.post(postUri, body: data);
  String resBody = utf8.decode(res.bodyBytes);
  Map<String, dynamic> resultmap = jsonDecode(resBody);
  Map<String, String> resultMap = {};
  resultMap['log_in_st'] = resultmap['log_in_st'].toString();
  resultMap['str_no'] = resultmap['str_no'].toString();
  resultMap['login_no'] = resultmap['login_no'].toString();
  resultMap['act_yn'] = resultmap['act_yn'].toString();
  resultMap['log_in_text'] = resultmap['log_in_text'].toString();
  return resultMap;
}

// 선택한 피드백을 서버에 제출
Future<Map<String, dynamic>> getLabelList() async {
  // 피드백 제출 URL
  // TODO 주소는 공통 전역 변수로 변경
  String url = 'https://192.168.0.88:5443/initialize';
  var postUri = Uri.parse(url);

  // TODO 인증코드 관련 수정은 위의 추론 요청과 동일
  String CRUDENTIAL_KEY = "testauthcode";

  var header = {"Content-type": "application/json", 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST, GET'};
  http.Response res = await http.post(postUri, headers:header, body: json.encode({
    "key": CRUDENTIAL_KEY,
    "auth": 'code',
    "ID": 'None',
    "PW": 'None',
    "store_no": 0,
  }));

  String resBody = utf8.decode(res.bodyBytes);
  Map<String, dynamic> resultMap = Map.castFrom(jsonDecode(resBody));

  return resultMap;
}

// img.Image 형식을 입력으로 받아 추론 요청
requestInference(img.Image? image) async {

  // API 요청 URL
  // TODO IP(주소) 부분을 공통 전역 변수로 설정해서 불러와서 사용하도록 변경
  String url = 'https://192.168.0.88:5443/run';
  var postUri = Uri.parse(url);

  // 간이 인증용 코드
  // TODO 1) 코드를 공통 전역 변수로 설정
  // TODO 2) 로그인 기능 도입 시 세션으로 인증할 수 있도록 변경 필요
  String CRUDENTIAL_KEY = "testauthcode";

  // 이미지의 중간 부분을 Crop해서 전달(화면 상에 보이는 부분만 보내도록)
  // => 촬영 화면에서는 이미지의 중간 부분만 보이도록 되어있지만 캡쳐 시 보이지 않는 위아래 부분도 포함되기 때문에 Crop 필요
  final face = img.copyCrop(
    image!,
    0,
    (image.height-image.width) ~/ 2,
    image.width,
    image.width,
  );
  // 추론에 필요한 크기 299X299로 리사이즈
  img.Image thumbnail = img.copyResize(face, width: 299, height: 299);
  // 바이트로 변환하여 base64로 인코딩하여 전달
  var byteImg = thumbnail.getBytes();
  Codec<String, String> stringToBase64 = utf8.fuse(base64);
  String encoded = stringToBase64.encode(byteImg.toString());

  // json형식으로 보내기 때문에 헤더 설정 필수
  // TODO 실제 운영 서비스에 올릴 경우 CORS 설정 세분화 필요(주소 지정, 메소드 지정 등)
  var header = {"Content-type": "application/json", 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST, GET'};
  http.Response res = await http.post(postUri, headers:header, body: json.encode({
    "image": encoded,
    "x_size": '299',
    "y_size": '299',
    "channel": '3',
    "key": CRUDENTIAL_KEY,
    "auth": 'code',
    "ID": 'None',
    "PW": 'None',
    'store_no': 0,
  }));

  // 결과 파일을 Map 형식으로 받아옴
  String resBody = utf8.decode(res.bodyBytes);
  Map<String, dynamic> resultMap = Map.castFrom(jsonDecode(resBody));

  // 피드백 화면에서 고정된 이미지를 보여주기 위해 원본 크기의 Crop된 이미지 face 전달
  resultMap['thumbnail'] = img.encodeJpg(face);

  return resultMap;
}

// 선택한 피드백을 서버에 제출
sendFeedback(infer_no, title) async {
  // 피드백 제출 URL
  // TODO 주소는 공통 전역 변수로 변경
  String url = 'https://192.168.0.88:5443/infer_feedback';
  var postUri = Uri.parse(url);

  // TODO 인증코드 관련 수정은 위의 추론 요청과 동일
  String CRUDENTIAL_KEY = "testauthcode";

  var header = {"Content-type": "application/json", 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST, GET'};
  http.Response res = await http.post(postUri, headers:header, body: json.encode({
    "key": CRUDENTIAL_KEY,
    "auth": 'code',
    "ID": 'None',
    "PW": 'None',
    "feedback": title,
    "infer_no": infer_no,
  }));

  String resBody = utf8.decode(res.bodyBytes);
  Map<String, dynamic> resultMap = jsonDecode(resBody);

  return resultMap;
}

// 로그인 화면 UI
class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with WidgetsBindingObserver {

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

  void validateAndSave() {
    final form = formKey.currentState;
    if (form!.validate()) {
      form.save();
      print('Form is valid Email: $id, password: $password');
    } else {
      print('Form is invalid Email: $id, password: $password');
    }
  }

  loginFailure(BuildContext context, resultMap) async {
    final prefs = await SharedPreferences.getInstance();

    if (resultMap['log_in_st'] == "0") {
      prefs.setString('ID', id);
      prefs.setString('PW', password);
      prefs.setString('str_no', resultMap['str_no']);
      prefs.setString('login_no', resultMap['login_no']);
      prefs.setString('act_yn', resultMap['act_yn']);

      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (BuildContext context) => CameraApp()));
    } else {
      if (resultMap['log_in_st'] == "1") {
        title_text = Text(
          '인증 실패',
          textAlign: TextAlign.left,
        );
        act_text = Text(
          resultMap['log_in_text'],
          textAlign: TextAlign.center,
        );
      } else if (resultMap['log_in_st'] == "2") {
        title_text = Text(
          '로그인 실패',
          textAlign: TextAlign.left,
        );
        act_text = Text(
          resultMap['log_in_text'],
          textAlign: TextAlign.center,
        );
      } else if (resultMap['log_in_st'] == "3") {
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
  void clear_prefs() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.clear();
  }

  @override
  Widget build(BuildContext context) {
    clear_prefs();

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
                      final prefs = await SharedPreferences.getInstance();
                      validateAndSave();
                      Map<String, String> resultMap = await requestLogin(id, password);
                      loginFailure(context, resultMap);
                    },
                  ),
                ]),
          )),
    );
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

// 추론 요청 화면 UI
class CameraApp extends StatefulWidget {
  @override
  _CameraAppState createState() => _CameraAppState();
}

// 상단 Bar를 가진 UI
// TODO 웹화면은 상단 바가 아니라 title에 해당 내용이 나오고 환영 문구가 있으니 여기도 분기 필요
class _CameraAppState extends State<CameraApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: Text('R-pha Vision V1.0')),
          body: AppBody(),
        ));
  }
}

// 메인 컨텐츠 부분 UI
class AppBody extends StatefulWidget {
  @override
  _AppBodyState createState() => _AppBodyState();
}

// UI 시작부분에서 사용가능한 카메라 가져오고 로딩이 끝나면 화면 로딩
class _AppBodyState extends State<AppBody> {
  bool cameraAccess = false;
  String? error;
  List<camlib.CameraDescription>? cameras;

  @override
  void initState() {
    getCameras();
    super.initState();
  }

  Future<void> getCameras() async {
    try {
      if (html.window.navigator.mediaDevices != null) {
        await html.window.navigator.mediaDevices!
            .getUserMedia({'video': true, 'audio': false});
      }
      setState(() {
        cameraAccess = true;
      });
      final cameras = await camlib.availableCameras();
      setState(() {
        this.cameras = cameras;
      });
    } on html.DomException catch (e) {
      setState(() {
        error = '${e.name}: ${e.message}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Center(child: Text('Error: $error'));
    }
    if (!cameraAccess) {
      return Center(child: Text('Camera access not granted yet.'));
    }
    if (cameras == null) {
      return Center(child: Text('Reading cameras'));
    }
    return CameraView(cameras: cameras!);
  }
}

// 카메라와 아래 조작부를 포함한 메인 컨텐츠 화면 UI
class CameraView extends StatefulWidget {
  final List<camlib.CameraDescription> cameras;

  const CameraView({Key? key, required this.cameras}) : super(key: key);

  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with TickerProviderStateMixin{
  String? error;
  camlib.CameraController? controller;
  late camlib.CameraDescription cameraDescription = widget.cameras[0];

  Uint8List? captured = null;
  bool suspending = false;
  bool suspending2 = false;
  int suspendingImage = -1;
  bool isLoading = false;
  camlib.CameraPreview? cameraPreview = null;
  Widget? previewFrame = null;
  List<Map<String, dynamic>> listLabel = [];

  final ImagePicker _picker = ImagePicker();
  List<Uint8List> imgFileList = [];

  List<Widget> list_results = [];
  List<Widget> list_results_2 = [];

  late TabController _tabController;

  Future<void> initCam(camlib.CameraDescription description) async {

    setState(() {
      controller = camlib.CameraController(description, camlib.ResolutionPreset.max);
      cameraPreview = camlib.CameraPreview(controller!);
    });

    try {
      await controller!.initialize();

      setState(() {
      });
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    }
  }

  @override
  void initState() {
    initCam(cameraDescription);
    _tabController = TabController(
      length: 2,
      vsync: this,  //vsync에 this 형태로 전달해야 애니메이션이 정상 처리됨
    );
    _tabController.addListener(() {
      if(_tabController.index == 0) {
        setState(() {
          initCam(cameraDescription);
        });
      }
    });
    super.initState();
  }

  void notifyReceive() {
    setState(() {
      suspending = false;
      list_results = [];
      initCam(cameraDescription);
    });
  }

  void notifyReceive2() {
    setState(() {
      suspending2 = false;
      suspendingImage = -1;
      list_results_2 = [];
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (error != null) {
      return Center(
        child: Text('Initializing error: $error\nCamera list:'),
      );
    }
    if (controller == null) {
      return Center(child: Text('Loading controller...'));
    }
    if (!controller!.value.isInitialized) {
      return Center(child: Text('Initializing camera...'));
    }

    List<Widget> list_tabs = [
      Container(
        height: 40,
        alignment: Alignment.center,
        child: Text(
          'Camera',
        ),
      ),
      Container(
        height: 40,
        alignment: Alignment.center,
        child: Text(
          'File',
        ),
      ),
    ];

    TabBar tabBar = TabBar(
      tabs: list_tabs,
      indicator: BoxDecoration(
        color: Colors.white,
      ),
      labelColor: Colors.black,
      unselectedLabelColor: Colors.black,
      controller: _tabController,
    );

    Widget? viewToShow = null;
    if (isLoading) {
      viewToShow = Image(image: AssetImage('assets/loading.jpg'));
    } else if (suspending) {
      viewToShow = Image.memory(captured!);
    } else {
      viewToShow = ClipRect(
        child: OverflowBox(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.fitWidth,
            child: Container(
              width: width,
              height:
              width * controller!.value.aspectRatio,
              child: cameraPreview, // this is my CameraPreview
            ),
          ),
        ),
      );
    }

    SingleChildScrollView cameraView = SingleChildScrollView(
      child: Column(
        children: [
        Container(
          width: width,
          height: (suspending && !isLoading) ? width*0.5 : width,
          child: viewToShow,
        ),
        Container(
          height: (suspending && !isLoading) ? 20 : 0,
          child: const Text("Results"),
        ),
        Container(
          height: (suspending && !isLoading) ? width*0.5 + 50 : 70,
          child:
          SingleChildScrollView(
            child: Column(
              children: list_results,
            ),
          ),
        ),
        Container(
          height: 30,
          child: ElevatedButton(
            onPressed: (controller == null || isLoading) ? null : () async {
              if (suspending) {
                setState(() {
                  suspending = false;
                  list_results = [];
                  initCam(cameraDescription);
                });
              } else {
                setState(() {
                  isLoading = true;
                  suspending = true;
                });
                controller!.lockCaptureOrientation();

                camlib.XFile xfile = await controller!.takePicture();

                img.Image? image = img.decodeImage(await xfile.readAsBytes());
                Map<String, dynamic> resultMap = await requestInference(image);
                captured = resultMap['thumbnail'];
                int infer_no = resultMap['infer_no'];
                List<Widget> tmp_list_results = [];
                List<int>? list_infer = (resultMap['cls_list'] as List)?.map((item) => item as int)?.toList();
                for (var element in list_infer!) {
                  tmp_list_results.add(
                      ElevatedButton(
                        onPressed: () async {
                          sendFeedback(infer_no, element);

                          setState(() {
                            suspending = false;
                            list_results = [];
                          });
                        },
                        style: ElevatedButton.styleFrom(
                            minimumSize: Size(width, 30) // put the width and height you want
                        ),
                        child: Text(labelMap[element]!),
                      )
                  );
                }
                tmp_list_results.add(
                    ElevatedButton(
                      onPressed: () async {
                        // title이 null인 경우(기타 클릭 시) 기타 라벨 선택 화면으로 이동
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                LabelSeletionScreen(infer_no: infer_no, predict_labels: list_infer, parentNotify: notifyReceive),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                          minimumSize: Size(width, 30) // put the width and height you want
                      ),
                      child: const Text('기타'),
                    )
                );
                setState(() {
                  list_results = tmp_list_results;
                  isLoading = false;
                });
              }
            },
            child: Text(isLoading ? 'Waiting' : (suspending ? 'Retry' : 'Take picture')),
          ),
        ),
      ],
      ),
    );

    List<Widget> imageViewList = [];
    int tmpIdx = 0;
    imgFileList.forEach((element) async {
      int innerIdx = tmpIdx;
      imageViewList.add(
        IconButton(
          onPressed: suspending2 ? null : () async {
            setState(() {
              suspending2 = true;
              suspendingImage = innerIdx;
            });
            Map<String, dynamic> resultMap = await requestInference(img.decodeImage(element));
            int infer_no = resultMap['infer_no'];
            List<Widget> tmp_list_results = [];
            List<int>? list_infer = (resultMap['cls_list'] as List)?.map((item) => item as int)?.toList();
            for (var element in list_infer!) {
              tmp_list_results.add(
                  ElevatedButton(
                    onPressed: () async {
                      sendFeedback(infer_no, element);

                      setState(() {
                        suspending2 = false;
                        suspendingImage = -1;
                        list_results_2 = [];
                      });
                    },
                    style: ElevatedButton.styleFrom(
                        minimumSize: Size(width, 30) // put the width and height you want
                    ),
                    child: Text(labelMap[element]!),
                  )
              );
            }
            tmp_list_results.add(
                ElevatedButton(
                  onPressed: () async {
                    // title이 null인 경우(기타 클릭 시) 기타 라벨 선택 화면으로 이동
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            LabelSeletionScreen(infer_no: infer_no, predict_labels: list_infer, parentNotify: notifyReceive2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                      minimumSize: Size(width, 30) // put the width and height you want
                  ),
                  child: const Text('기타'),
                )
            );

            setState(() {
              list_results_2 = tmp_list_results;
            });
          },
          iconSize: 160,
          icon: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(
                width: 1,
                color: Colors.black45,
              ),
            ),
            child: Stack(
              children: [
                Container(
                  child: suspendingImage == innerIdx ? new Icon(
                    Icons.done,
                    size: 150,
                  ) : null,
                  decoration: BoxDecoration(
                      image:DecorationImage(
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(Colors.black.withOpacity(suspendingImage == innerIdx ? 0.2 : 1.0), BlendMode.dstATop),
                        image: Image.memory(element).image,
                      )
                  )
                ),
              ]
            )
        ),
      ));
      tmpIdx += 1;
    });

    return Column(children: [
      tabBar,
      Expanded(
        child: TabBarView(
          controller: _tabController,
          children: [
            cameraView,
            Scaffold(
              appBar: null,
              body: Column(
                children: [
                  Container(
                    alignment: Alignment.center,
                    width: width,
                    height: width*0.5,
                    child: SingleChildScrollView(
                      child: Column(
                        children: imageViewList,
                      ),
                    ),
                  ),
                  Container(
                    height: 20,
                    child: const Text("Results"),
                  ),
                  Expanded(
                    child:
                    SingleChildScrollView(
                      child: Column(
                        children: list_results_2,
                      ),
                    ),
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: suspending2
                ? () {
                  setState(() {
                    suspending2 = false;
                    list_results_2 = [];
                    suspendingImage = -1;
                  });
                } : () async {
                  final List<camlib.XFile> _images = await _picker.pickMultiImage();
                  if (_images != null) {
                    final List<Uint8List> tmpList = [];
                    tmpList.addAll(imgFileList);
                    for (var element in _images) {
                      tmpList.add(await element.readAsBytes());
                    }
                    setState(() {
                      imgFileList = tmpList;
                    });
                  }
                  // FilePickerResult? result = await FilePicker.platform.pickFiles(
                  //   type: FileType.image,
                  // );
                  // if (result != null && result.files.isNotEmpty) {
                  //   String fileName = result.files.first.name;
                  //   Uint8List fileBytes = result.files.first.bytes!;
                  //   imgFileList.add(img.Image.fromBytes(fileBytes));
                  // }
                },
                child: suspending2 ? const Icon(Icons.replay) : const Icon(Icons.navigation),
              ),
            ),
          ],
        ),
      ),
    ],);
  }
}

// 기타 선택
class LabelSeletionScreen extends StatefulWidget {
  final int infer_no;
  final List<int> predict_labels;
  final Function() parentNotify;

  const LabelSeletionScreen({Key? key, required this.infer_no, required this.predict_labels, required this.parentNotify}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _LabelSeletionScreenState();
}


class _LabelSeletionScreenState extends State<LabelSeletionScreen>{
  late Table table;

  @override
  void initState() {
    List<TableRow> listTableRow = [];
    List<Widget> listCell = [];
    int idx = 0;
    labelList.forEach((element) {
      listCell.add(
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Container(
            height: 32,
            color: Colors.green,
            child: ElevatedButton(
              onPressed: widget.predict_labels.contains(element) ? null : () async {
                sendFeedback(widget.infer_no, element);
                widget.parentNotify();
                Navigator.pop(context);
              },
              child: Text(labelMap[element]!),
            ),
          )
        )
      );

      if(idx%3 == 2) {
        listTableRow.add(
          TableRow(
            children: listCell,
          )
        );
        listCell = [];
      }
      idx += 1;
    });
    if(idx%3 != 0) {
      while (idx%3 != 0) {
        listCell.add(
            TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: Container(
              height: 32,
            ),
          )
        );
        idx += 1;
      }
      listTableRow.add(
          TableRow(
            children: listCell,
          )
      );
    }
    setState(() {
      table = Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: listTableRow,
      );
    });
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a Label')),
      body: SingleChildScrollView(child: table,),
    );
  }
}