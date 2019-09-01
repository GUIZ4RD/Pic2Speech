import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image/image.dart' as imglib;
import 'package:flutter_tts/flutter_tts.dart';
import 'constants.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

/*
final int STATUS_INIT = 1;
final int STATUS_READY = 2;
final int STATUS_WAITING = 3;
final int STATUS_BUSY = 4;
* */
enum Status { Init, Ready, Waiting, Busy }

List<CameraDescription> cameras;

Future<void> main() async {
  cameras = await availableCameras();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(CameraApp());
}

class CameraApp extends StatefulWidget {
  @override
  _CameraAppState createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  final String MODEL_URL =
      "http://aed8d685-aa75-4e21-9b7d-1f213b0eb796.eastus2.azurecontainer.io/score";

  CameraController controller;
  FlutterTts flutterTts;
  int status;

  @override
  void initState() {
    super.initState();

    flutterTts = new FlutterTts();
    flutterTts.setLanguage("en-US");

    controller = CameraController(cameras[0], ResolutionPreset.medium);
    controller.initialize().then((_) {
      if (!mounted) {
        _speak("Sorry ! Something went wrong .");
        return;
      }

      setState(() {
        status = STATUS_READY;
      });

      _speak("Tap your screen to take a picture");

      controller.startImageStream((CameraImage image) {
        if (status == STATUS_WAITING) {
          caption(image);
          status = STATUS_BUSY;
        }
      });
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _tapped() {
    setState(() {
      status = STATUS_WAITING;
    });
  }

  imglib.Image convertYUV420toImageColor(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel;

      var img = imglib.Image(width, height);

      for (int x = 0; x < width; x++) {
        for (int y = 0; y < height; y++) {
          final int uvIndex =
              uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
          final int index = y * width + x;

          final yp = image.planes[0].bytes[index];
          final up = image.planes[1].bytes[uvIndex];
          final vp = image.planes[2].bytes[uvIndex];

          int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
          int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
              .round()
              .clamp(0, 255);
          int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

          img.data[index] = (0xFF << 24) | (b << 16) | (g << 8) | r;
        }
      }

      return img;
    } catch (e) {
      print("ERROR:" + e.toString());
    }
    return null;
  }

  Future _speak(text) async {
    await flutterTts.speak(text);
  }

  void caption(CameraImage image) async {
    imglib.Image myimage = convertYUV420toImageColor(image);
    myimage = imglib.copyResizeCropSquare(myimage, 299);
    myimage = imglib.copyRotate(myimage, 90);
    Uint8List data = myimage.getBytes(format: imglib.Format.rgb);

    var body = json.encode({
      "data": [data]
    });

    http.Response response = await http.post(MODEL_URL,
        body: body, headers: {'content-type': 'application/json'});

    debugPrint("Response status: ${response.statusCode}");
    debugPrint("Response body: ${response.body}");

    var resp = json.decode(response.body);

    if (resp.containsKey("error")) {
      _speak("Sorry ! Something went wrong .");

      Fluttertoast.showToast(
          msg: response.body,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
          timeInSecForIos: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 24.0);
    } else {
      _speak(resp["caption"]);
      Fluttertoast.showToast(
          msg: resp["caption"],
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIos: 1,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 24.0);
    }

    setState(() {
      status = STATUS_READY;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container();
    }

    return MaterialApp(
        home: new Stack(children: [
      new Container(
          alignment: Alignment.center,
          child: new GestureDetector(
              onTap: _tapped,
              child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: CameraPreview(controller)))),
      status != STATUS_READY
          ? new Container(color: const Color(0x000000).withOpacity(0.75))
          : new Container(),
      status != STATUS_READY
          ? SpinKitWave(color: Colors.white, size: 75.0)
          : new Container()
    ]));
  }
}
