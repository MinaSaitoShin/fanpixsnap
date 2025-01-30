import 'package:fan_pix_snap/services/local_server_manager.dart';
import 'package:fan_pix_snap/services/local_client_manager.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/camera_screen.dart';
import 'screens/local_qr_code_screen.dart';
import 'screens/log_screen.dart';
import 'screens/err_send_screen.dart';
import 'services/app_state.dart';

void main() async {
  // Flutterのバインディングを初期化
  WidgetsFlutterBinding.ensureInitialized();

  //Firebaseを初期化する処理
  await Firebase.initializeApp();

  // アプリを起動。複数のProviderを設定して状態管理を提供
  runApp(
    MultiProvider(
      providers: [
        // ローカルサーバー管理のインスタンスをアプリ全体に提供
        ChangeNotifierProvider(create: (context) => localServerManager),
        // ローカルクライアント管理のインスタンスをアプリ全体に提供
        ChangeNotifierProvider(create: (context) => localClientManager),
        // 画像撮影・保存のインスタンスをアプリ全体に提供
        ChangeNotifierProvider(create: (context) => CameraScreenState()),

        ChangeNotifierProvider(create: (context) => ErrSendScreenState()),
        // アプリ全体の状態管理インスタンスを提供
        ChangeNotifierProvider(create: (context) => AppState()),
      ],
      // アプリのメインウィジェット
      child: MyApp(),
    ),
  );
}

// StatelessWidgetを継承。アプリのテーマやホームを設定
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // ウィジェットを返す。タイトルとテーマを指定。ホーム画面にアプリを指定。
    return MaterialApp(
      title: 'FanPixSnap',
      // アプリのテーマカラー
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // ボタンのデフォルトの色をWhiteに設定
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            // ボタンの背景色を白に設定
            backgroundColor: Colors.white,
          ),
        ),
      ),
      // 最初に表示される画面をMainScreenに設定
      home: MainScreen(),
    );
  }
}

// メイン画面クラス
class MainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title:Text('FanPixSnap')),
      body: Center(
        child:Column(
          // 縦方向の中心に配置
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              // カメラ画面に遷移するボタン
              onPressed: () {
                Navigator.push(
                  context,
                  // CameraScreenに遷移
                  MaterialPageRoute(builder: (context) => CameraScreen()),
                );
              },
              child: Text(' 画像を撮影 '),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              // QRコード画面に遷移するボタン
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    // LocalQrCodeScreenに遷移
                      builder: (context) => LocalQrCodeScreen()
                  ),
                );
              },
              child: Text(' 画像を送る '),
            ),
            // ボタン間のスペース
            SizedBox(height: 20),
            ElevatedButton(
              // QRコード画面に遷移するボタン
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    // LocalQrCodeScreenに遷移
                      builder: (context) => ErrSendScreen()
                  ),
                );
              },
              child: Text(' エラー画像を送る '),
            ),
            // ボタン間のスペース
            SizedBox(height: 100),
            ElevatedButton(
              // ログ画面に遷移するボタン
              onPressed: () {
                Navigator.push(
                  context,
                  // LogScreen に遷移
                  MaterialPageRoute(builder: (context) => LogScreen()
                  ),
                );
              },
              child: Text(' ログを表示 '),
            ),
          ],
        ),
      ),
    );
  }
}