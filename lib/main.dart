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
  // var file = File(xfile.path);

  String url = 'https://192.168.0.88:5443/run';
  // print(bytes);

  img.Image? image = img.decodeImage(await xfile.readAsBytes());

  // Resize the image to a 120x? thumbnail (maintaining the aspect ratio).
  img.Image thumbnail = img.copyResize(image!, width: 299, height: 299);

  print(thumbnail.length);
  print(img.encodeJpg(thumbnail).length);
  print(thumbnail.getPixel(0, 0));

  var postUri = Uri.parse(url);
  var request = http.MultipartRequest("POST", postUri);
  Map<String, String> headers = {"Content-type": "multipart/form-data"};
  request.fields['test'] = '123';
  request.files.add(http.MultipartFile.fromBytes('file', img.encodeJpg(thumbnail), filename: 'attachFile', contentType: MediaType('image', 'jpeg')),);
  //request.files.add(http.MultipartFile('file',file.readAsBytes().asStream(), file.lengthSync(),filename: 'attachFile',),);
  // request.files.add(http.MultipartFile.fromBytes('file', await file.readAsBytes(), contentType: MediaType('image', 'jpeg')));
  request.headers.addAll(headers);

  var res = await request.send();

  res.stream.transform(utf8.decoder).listen((value) {
    print(value);
  });

  return res;
}

requestPost() async {
  String url = 'https://192.168.0.88/test';
  var postUri = Uri.parse(url);
  var res = await http.post(postUri, body: {
    'val1': 'test'
  });
  print(res.body);
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
          appBar: AppBar(title: Text('Camera test')),
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

  bool isLoading = false;

  late TabController _tabController;

  Future<void> initCam(camlib.CameraDescription description) async {

    setState(() {
      controller = camlib.CameraController(description, camlib.ResolutionPreset.max);
    });

    try {
      print("!?");
      print(description);
      print(controller);
      await controller!.initialize();
      print("?!");

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
    final size = MediaQuery.of(context).size;
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

    List<Widget> list_results = [];

    camlib.CameraPreview cameraPreview = camlib.CameraPreview(controller!);

    Widget viewToShow = cameraPreview;
    if (isLoading) {
      viewToShow = Image(image: AssetImage('assets/loading.jpg'));
    }

    SingleChildScrollView cameraView = SingleChildScrollView(
      child: Column(children: [
        AspectRatio(aspectRatio: 1.4/1,
          child: viewToShow,
        ),
        Container(
          child: Text("Results"),
        ),
        Container(
          height: 200,
          child:
            SingleChildScrollView(
              child: Column(
                children: list_results,
              ),
            ),
        ),
        // if (!recording)
        //   ElevatedButton(
        //     onPressed: controller == null
        //         ? null
        //         : () async {
        //       await controller!.startVideoRecording();
        //       setState(() {
        //         recording = true;
        //       });
        //     },
        //     child: Text('Record video'),
        //   ),
        // if (recording)
        //   ElevatedButton(
        //     onPressed: () async {
        //       final file = await controller!.stopVideoRecording();
        //       final bytes = await file.readAsBytes();
        //       final uri =
        //       Uri.dataFromBytes(bytes, mimeType: 'video/webm;codecs=vp8');
        //
        //       final link = html.AnchorElement(href: uri.toString());
        //       link.download = 'recording.webm';
        //       link.click();
        //       link.remove();
        //       setState(() {
        //         recording = false;
        //       });
        //     },
        //     child: Text('Stop recording'),
        //   ),
        // SizedBox(height: 10),
        ElevatedButton(
          onPressed: controller == null
              ? null
              : () async {

            setState(() {
              isLoading = true;
            });
            controller!.lockCaptureOrientation();

            camlib.XFile xfile = await controller!.takePicture();
            Uint8List byteImg = await xfile.readAsBytes();

            print(byteImg);
            var response = await requestInference(xfile);
            setState(() {
              isLoading = false;
            });
            print(response.stream.bytesToString());

            // 사진을 촬영하면, 새로운 화면으로 넘어갑니다.
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DisplayPictureScreen(image: byteImg),
              ),
            );
          },
          child: Text('Take picture'),
        ),
        // SizedBox(height: 10),
        // if (!orientationLocked)
        //   ElevatedButton(
        //       onPressed: () {
        //         controller!.lockCaptureOrientation();
        //         setState(() {
        //           orientationLocked = true;
        //         });
        //       },
        //       child: Text('Lock orientation')),
        // if (orientationLocked)
        //   ElevatedButton(
        //       onPressed: () {
        //         controller!.unlockCaptureOrientation();
        //         setState(() {
        //           orientationLocked = false;
        //         });
        //       },
        //       child: Text('Unlock orientation')),
        // SizedBox(height: 10),
        // if (!flashLight)
        //   ElevatedButton(
        //       onPressed: () {
        //         controller!.setFlashMode(camlib.FlashMode.always);
        //         setState(() {
        //           flashLight = true;
        //         });
        //       },
        //       child: Text('Turn flashlight on')),
        // if (flashLight)
        //   ElevatedButton(
        //       onPressed: () {
        //         controller!.setFlashMode(camlib.FlashMode.off);
        //         setState(() {
        //           flashLight = false;
        //         });
        //       },
        //       child: Text('Turn flashlight off')),
        // SizedBox(height: 10),
        // if (zoomLevel != null && maxZoom != null)
        //   Text('Zoom level: $zoomLevel/$maxZoom'),
        // if (zoomLevel != null && minZoom != null && maxZoom != null)
        //   Slider(
        //     value: zoomLevel!,
        //     onChanged: (newValue) {
        //       setState(() {
        //         zoomLevel = newValue;
        //       });
        //       controller!.setZoomLevel(newValue);
        //     },
        //     min: minZoom!,
        //     max: maxZoom!,
        //   ),
        // if (exposure != null && maxExposure != null)
        //   Text('Exposure offset: $exposure/$maxExposure'),
        // if (exposure != null && minExposure != null && maxExposure != null)
        //   Slider(
        //     value: exposure!,
        //     onChanged: (newValue) {
        //       setState(() {
        //         exposure = newValue;
        //       });
        //       controller!.setExposureOffset(newValue);
        //     },
        //     min: minExposure!,
        //     max: maxExposure!,
        //   ),
        // SizedBox(height: 10),
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
                child: Text(
                  'Tab2 View',
                  style: TextStyle(
                    fontSize: 30,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class _MediaSizeClipper extends CustomClipper<Rect> {
  final Size mediaSize;
  const _MediaSizeClipper(this.mediaSize);
  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, mediaSize.width, mediaSize.height);
  }
  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) {
    return true;
  }
}

// A screen that takes in a list of cameras and the Directory to store images.
class TakePictureScreen extends StatefulWidget {
  final camlib.CameraDescription camera;

  const TakePictureScreen({
    Key? key,
    required this.camera,
  }) : super(key: key);

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  // CameraController와 Future를 저장하기 위해 두 개의 변수를 state 클래스에
  // 정의합니다.
  late camlib.CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();

    // 카메라의 현재 출력물을 보여주기 위해
    // CameraController를 생성합니다.
    _controller = camlib.CameraController(
      // Get a specific camera from the list of available cameras.
      // 이용 가능한 카메라 목록에서 특정 카메라를 가져옵니다.
      widget.camera,
      // 적용할 해상도를 지정합니다.
      camlib.ResolutionPreset.medium,
    );

    // 다음으로 controller를 초기화합니다. 초기화 메서드는 Future를 반환합니다.
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // 위젯의 생명주기 종료시 컨트롤러 역시 해제시켜줍니다.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Take a picture')),
      // 카메라 프리뷰를 보여주기 전에 컨트롤러 초기화를 기다려야 합니다. 컨트롤러 초기화가
      // 완료될 때까지 FutureBuilder를 사용하여 로딩 스피너를 보여주세요.
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // Future가 완료되면, 프리뷰를 보여줍니다.
            return camlib.CameraPreview(_controller);
          } else {
            // 그렇지 않다면, 진행 표시기를 보여줍니다.
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.camera_alt),
        // onPressed 콜백을 제공합니다.
        onPressed: () async {
          // try / catch 블럭에서 사진을 촬영합니다. 만약 뭔가 잘못된다면 에러에
          // 대응할 수 있습니다.
          try {
            // 카메라 초기화가 완료됐는지 확인합니다.
            await _initializeControllerFuture;

            // 사진 촬영을 시도하고 저장되는 경로를 로그로 남깁니다.
            camlib.XFile xfile = await _controller.takePicture();
            Uint8List byteImg = await xfile.readAsBytes();

            //print(bytes);

            var response = await requestInference(xfile);
            print(response.stream.bytesToString());

            // 사진을 촬영하면, 새로운 화면으로 넘어갑니다.
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DisplayPictureScreen(image: byteImg),
              ),
            );
          } catch (e) {
            // 만약 에러가 발생하면, 콘솔에 에러 로그를 남깁니다.
            print(e);
          }
        },
      ),
    );
  }
}


// 사용자가 촬영한 사진을 보여주는 위젯
class DisplayPictureScreen extends StatelessWidget {
  final Uint8List image;

  const DisplayPictureScreen({Key? key, required this.image}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Display the Picture')),
      // 이미지는 디바이스에 파일로 저장됩니다. 이미지를 보여주기 위해 주어진
      // 경로로 `Image.file`을 생성하세요.
      body: Image.memory(image),
    );
  }
}