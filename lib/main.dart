import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/camera_screen.dart';
import 'services/nearby_transfer_page.dart';
void main() async {
  // Flutterのバインディングを初期化
  WidgetsFlutterBinding.ensureInitialized();
  //Firebaseを初期化する処理
  await Firebase.initializeApp();
  // アプリ起動
  runApp(MyApp());
}

// StatelessWidgetを継承。アプリのテーマやホームを設定
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // ウィジェットを返す。タイトルとテーマを指定。ホーム画面にアプリを指定。
    return MaterialApp(
      title: 'FanPixSnap',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title:Text('FanPixSnap')),
      body: Center(
        child:Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CameraScreen()),
                );
              },
              child: Text(' 画像を撮影 '),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NearbyTransferPage(isHost: true)),
                );
              },
              child: Text('画像受け取り'),
            ),
          ],
        ),
      ),
    );
  }
}