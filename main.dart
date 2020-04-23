//  dependencies :
//  camera: ^0.5.7+4
//  flutter_socket_io:
//  image:
//  http:
//  path:
//  path_provider:
//  fluttertoast:


import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_socket_io/flutter_socket_io.dart';
import 'package:flutter_socket_io/socket_io_manager.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

void main() => runApp(
  MaterialApp(
    home: Ca(),
  )
);

class Ca extends StatefulWidget {
  @override
  _CaState createState() => _CaState();
}

class _CaState extends State<Ca> {
  CameraController controller;
  List cameras;
  int selectedCameraIdx;
  String imagePath;
  SocketIO socketIO;

  @override
  void initState() {
    SystemChrome.setEnabledSystemUIOverlays([SystemUiOverlay.bottom]);
    socketIO = new SocketIOManager().createSocketIO('http://127.0.0.1:8808', '/')
      ..init()
      ..connect();
    Future.microtask(() async{
      await availableCameras().then((availableCameras) {
        cameras = availableCameras;
        if (cameras.length > 0) {
          setState(() => selectedCameraIdx = 0);
          _onCameraSwitched(cameras[selectedCameraIdx]).then((void v) => controller.addListener(() => setState(() {})));
        }
      }).catchError((err) => throw err);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context)  => Scaffold(body: _cameraPreviewWidget());

  Widget _cameraPreviewWidget() => (controller == null || !controller.value.isInitialized)
    ? Center(child: CircularProgressIndicator())
    : Stack(
        children: <Widget>[
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            left: 0,
            child: CameraPreview(controller)
          ),
          Positioned(
              width: MediaQuery.of(context).size.width,
              bottom: MediaQuery.of(context).size.height*0.2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.red,
                    child: Icon(Icons.videocam),
                    onPressed: () => print("await"),
                  ),
                  FloatingActionButton(
                    mini: false,
                    backgroundColor: Colors.red,
                    child: Icon(Icons.play_arrow,size: 40,),
                    onPressed: _onCapturePressed,
                  ),
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.swap_horizontal_circle),
                    onPressed:_onSwitchCamera,
                  )
                ],
              )
          ),
          _thumbnailWidget()
        ],
      );

  Widget _thumbnailWidget() => Positioned(
    bottom: 10,
    width: MediaQuery.of(context).size.width,
    child: Container(
      alignment: Alignment.center,
      child: imagePath == null
        ? SizedBox()
        : SizedBox(
            child: Image.file(File(imagePath)),
            width: 100.0,
            height: 100.0,
          ),
    ),
  );

  Future _onCameraSwitched(CameraDescription cameraDescription) async {
    if (controller != null) await controller.dispose();
      controller = CameraController(cameraDescription, ResolutionPreset.high)..addListener((){
          if (mounted) setState(() {});
          if (controller.value.hasError) return _errView(errTxt: "ERR");
        });
    try {
      await controller.initialize();
    }
    catch (e) {
      _errView(errTxt: "ERR");
    }
  }

  void _onSwitchCamera() {
    selectedCameraIdx = (selectedCameraIdx < cameras.length - 1)
      ? selectedCameraIdx + 1
      : 0;
    CameraDescription selectedCamera = cameras[selectedCameraIdx];
    _onCameraSwitched(selectedCamera);
    selectedCameraIdx = selectedCameraIdx;
  }

  Future<String> _takePicture() async {
    if (!controller.value.isInitialized) {
      _errView(errTxt: "Plz.. await");
      return null;
    }
    if (controller.value.isTakingPicture) return null;

    final Directory appDirectory = await getApplicationDocumentsDirectory();
    final String pictureDirectory = '${appDirectory.path}/Pictures';

    final String currentTime = DateTime.now().millisecondsSinceEpoch.toString();
    final String filePath = '$pictureDirectory/$currentTime.jpg';
    try {
      await Directory(pictureDirectory).create(recursive: true);
      await controller.takePicture(filePath);
      return filePath;
    }
    catch (e) {
      _errView(errTxt: "ERR");
      return null;
    }
  }

  void _onCapturePressed() async{
    String _filePath = await _takePicture();
    if(_filePath.isEmpty) return _errView(errTxt:"ERR");
    imagePath = _filePath;
    File _image = File(_filePath);
    String result = 'data:image/jpg;base64,' + base64Encode(_image.readAsBytesSync());
    await http.post(
      "http://127.0.0.1:8808/ph",
      body: {
       "photo": result.toString()
      }
    );
    await socketIO.sendMessage(
      'send_message', json.encode(
      {
        "message": result,
        "name" :"James"
      }
    ));
  }

  void _errView({String errTxt}) => Fluttertoast.showToast(msg: errTxt);
}
