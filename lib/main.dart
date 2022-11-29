import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

import 'package:camera/camera.dart' as camlib;

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;

import 'package:flutter/foundation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 테스트용 https에서만 사용할 인증 절차 무시하는 코드
  // TODO 실서비스 배포시 삭제
  io.HttpOverrides.global = NoCheckCertificateHttpOverrides();

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: CameraApp(),
    ),
  );
}

class NoCheckCertificateHttpOverrides extends io.HttpOverrides {
  @override
  io.HttpClient createHttpClient(io.SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (io.X509Certificate cert, String host, int port) => true;
  }
}

requestInference(camlib.XFile xfile) async {
  String url = 'https://192.168.0.88:5443/run';
  var postUri = Uri.parse(url);

  String CRUDENTIAL_KEY = "7{@:M8IR;DW\\/X71uhHOd[nxa@uB%+m(/<Owq5LZ.kO%K583{t-fDb'GkE\$YscX?N`X}M=WnMC<Ed}a4.\$.lvDPL=q;i237fvcDjPPXmY`r.FU`@D*nQ]mBTNb#t7_Qw*Tr?f6]aTWm},Z(8L&^xI\$^5Ccru'a.}'/uaN+{d\\Ox#FWv(ZT,>8vVC}kc2q2&'.qddiHnN}^*L]A*ZMT,{soMw@BrppFG[OIrv_bD/b67H:H0-;dxDID/Y[Yhz{y~VUVG|(aZ]]xj[jB*q)ARPA>)S._*JH]iE!zlnFzBatlkAfvy";

  img.Image? image = img.decodeImage(await xfile.readAsBytes());

  final face = img.copyCrop(
    image!,
    0,
    (image.height-image.width) ~/ 2,
    image.width,
    image.width,
  );
  img.Image thumbnail = img.copyResize(face, width: 299, height: 299);

  var byteImg = thumbnail.getBytes();
  Codec<String, String> stringToBase64 = utf8.fuse(base64);
  String encoded = stringToBase64.encode(byteImg.toString());
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
  }));

  String resBody = utf8.decode(res.bodyBytes);
  Map<String, dynamic> resultMap = jsonDecode(resBody);

  resultMap['thumbnail'] = img.encodeJpg(thumbnail);
  print(byteImg);
  print(byteImg.length);

  return resultMap;
}

class CameraApp extends StatefulWidget {
  @override
  _CameraAppState createState() => _CameraAppState();
}

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

class AppBody extends StatefulWidget {
  @override
  _AppBodyState createState() => _AppBodyState();
}

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

class CameraView extends StatefulWidget {
  final List<camlib.CameraDescription> cameras;

  const CameraView({Key? key, required this.cameras}) : super(key: key);

  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with TickerProviderStateMixin{
  String? error;
  camlib.CameraController? controller;
  double? zoomLevel;
  late camlib.CameraDescription cameraDescription = widget.cameras[0];

  double? minZoom;
  double? maxZoom;

  double? minExposure;
  double? maxExposure;
  double? exposure;

  bool recording = false;
  bool flashLight = false;
  bool orientationLocked = false;

  Uint8List? captured = null;
  bool suspending = false;
  bool isLoading = false;
  camlib.CameraPreview? cameraPreview = null;
  Widget? previewFrame = null;

  List<Widget> list_results = [];

  late TabController _tabController;

  Future<void> initCam(camlib.CameraDescription description) async {

    setState(() {
      controller = camlib.CameraController(description, camlib.ResolutionPreset.max);
      cameraPreview = camlib.CameraPreview(controller!);
    });

    try {
      await controller!.initialize();

      final minZoom = await controller!.getMinZoomLevel();
      final maxZoom = await controller!.getMaxZoomLevel();

      final minExposure = await controller!.getMinExposureOffset();
      final maxExposure = await controller!.getMaxExposureOffset();

      print(minZoom);
      print(maxZoom);
      print(maxExposure);
      print(minExposure);
      setState(() {
        this.minZoom = minZoom;
        this.maxZoom = maxZoom;
        this.zoomLevel = minZoom;

        this.minExposure = minExposure;
        this.maxExposure = maxExposure;
        this.exposure = 1;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    initCam(cameraDescription);
    _tabController = TabController(
      length: 2,
      vsync: this,  //vsync에 this 형태로 전달해야 애니메이션이 정상 처리됨
    );
    super.initState();
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

    print(controller!.value.aspectRatio);

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

    sendFeedback(context, infer_no, title, list_label) {
      print(title);

      if (title == null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                LabelSeletionScreen(infer_no: infer_no, predict_labels: list_label,),
          ),
        );
      }
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
                });
              } else {
                setState(() {
                  isLoading = true;
                  suspending = true;
                });
                controller!.lockCaptureOrientation();

                camlib.XFile xfile = await controller!.takePicture();
                Uint8List byteImg = await xfile.readAsBytes();

                Map<String, dynamic> resultMap = await requestInference(xfile);
                captured = resultMap['thumbnail'];
                int infer_no = resultMap['infer_no'];
                List<Widget> tmp_list_results = [];
                List<dynamic> list_infer = resultMap['cls_list'];
                for (var element in list_infer) {
                  tmp_list_results.add(
                      ElevatedButton(
                        onPressed: () async {sendFeedback(context, infer_no, element, list_infer); },
                        style: ElevatedButton.styleFrom(
                            minimumSize: Size(width, 30) // put the width and height you want
                        ),
                        child: Text(element),
                      )
                  );
                }
                tmp_list_results.add(
                    ElevatedButton(
                      onPressed: () async {sendFeedback(context, infer_no, null, list_infer); },
                      style: ElevatedButton.styleFrom(
                          minimumSize: Size(width, 30) // put the width and height you want
                      ),
                      child: const Text('기타'),
                    )
                );
                tmp_list_results.add(
                    ElevatedButton(
                      onPressed: () async {sendFeedback(context, infer_no, null, list_infer); },
                      style: ElevatedButton.styleFrom(
                          minimumSize: Size(width, 30) // put the width and height you want
                      ),
                      child: const Text('기타'),
                    )
                );
                tmp_list_results.add(
                    ElevatedButton(
                      onPressed: () async {sendFeedback(context, infer_no, null, list_infer); },
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

    return Column(children: [
      tabBar,
      Expanded(
        child: TabBarView(
          controller: _tabController,
          children: [
            cameraView,
            Container(
              color: Colors.green[200],
              alignment: Alignment.center,
              child: const Text(
                'Tab2 View',
                style: TextStyle(
                  fontSize: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    ],);
  }
}

// 기타 선택
class LabelSeletionScreen extends StatelessWidget {
  final int infer_no;
  final List<dynamic> predict_labels;

  const LabelSeletionScreen({Key? key, required this.infer_no, required this.predict_labels}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a Label')),
      // 이미지는 디바이스에 파일로 저장됩니다. 이미지를 보여주기 위해 주어진
      // 경로로 `Image.file`을 생성하세요.
      body: SingleChildScrollView(child: Column(children: [],)),
    );
  }
}