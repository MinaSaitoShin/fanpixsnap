import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:fan_pix_snap/screens/send_pic_screen.dart';
import 'package:fan_pix_snap/services/local_server_manager.dart';
import 'package:fan_pix_snap/services/local_client_manager.dart';
//import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
//import 'package:firebase_core/firebase_core.dart';
//import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/signup_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/log_screen.dart';
import 'screens/err_send_screen.dart';
import 'screens/delete_image_screen.dart';
import 'services/app_state.dart';

void main() async {
  // Flutterのバインディングを初期化
  WidgetsFlutterBinding.ensureInitialized();

  // .envファイルのロード
  await dotenv.load(fileName: ".env");
  // SUPABASEのキーを設定
  String supabaseKey = dotenv.env['SUPABASE_KEY'] ?? 'default_key_here';
  String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? 'default_url_here';

  // Firebaseを初期化する処理
  // await Firebase.initializeApp();
  // Supabaseを初期化する処理
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
    authOptions: FlutterAuthClientOptions(
      autoRefreshToken: true,
      authFlowType: AuthFlowType.pkce, // 必要に応じて設定
    ),
  );

//  final supabase = Supabase.instance.client;
//  await supabase.auth.signInAnonymously;
//  final response = await Supabase.instance.client.auth.signInAnonymously();

// 既にログイン済みか確認（未ログインなら匿名ログイン）
//   if (supabase.auth.currentSession == null) {
//     // Anonymousログインができない場合は、サインアップで新規作成
//     final response = await supabase.auth.signUp(
//         email: 'user@example.com',
//         password: 'password123',
//     );
//
//     // サインアップ成功時の処理
//     if (response.error == null) {
//       print("サインアップ成功");
//     } else {
//       print("サインアップ失敗: ${response.error?.message}");
//     }
//   } else {
//     print("既にログイン済み");
//   }
  
  // Firebase App Checkの初期化
  // try {
  //   await FirebaseAppCheck.instance.activate(
  //     // Android：開発中は debug、公開時は playIntegrityを選択する
  //     androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
  //     // IOS
  //     appleProvider: AppleProvider.deviceCheck,
  //   );
  // } catch (e) {
  //     print('App Checkの初期化に失敗しました: $e');
  // }

  // // Firebase Authentication のセットアップ（匿名ログイン）
  // await signInAnonymously();

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

extension on AuthResponse {
  get error => null;
}


// // Firebase Authentication（匿名ログイン）
// Future<void> signInAnonymously() async {
//   try {
//     UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();
//     print("ログイン成功: ${userCredential.user?.uid}");
//   } catch (e) {
//     print("匿名ログイン失敗: $e");
//   }
// }

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
      home: AuthCheck(), // ユーザーの状態を確認
      routes: {
        '/home': (context) => MainScreen(), // メイン画面
      },
    );
  }
}
// ユーザーがログイン済みかチェックする画面
class AuthCheck extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    if (user != null) {
      return MainScreen(); // ログイン済みならメイン画面へ
    } else {
      return SignUpScreen(); // 未ログインなら認証画面へ
    }
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

// メイン画面クラス
class _MainScreenState extends State<MainScreen> {
  String? _token;
  String? _e;
  bool _isDialogOpen = false;
  // bool cameraGranted = false;
  // bool storageGranted = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    // アプリが起動したときにトークンを取得
    // _getAppCheckToken();
  }

  // ユーザー設定をロード（保存先設定）
  Future<void> _loadPreferences() async {
    final storageProvider = Provider.of<AppState>(context, listen: false);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // **保存先の取得**（デフォルトは "firebase"）
    String storedValue = prefs.getString('selectedStorage') ?? "firebase";
    storageProvider.setSelectedStorage(storedValue);
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    Navigator.pushReplacementNamed(context, '/'); // ログアウト後、認証画面へ
  }

  // トークンを取得する関数
  // Future<void> _getAppCheckToken() async {
  //   try {
  //     String? token = await FirebaseAppCheck.instance.getToken();
  //     setState(() {
  //       _token = token;
  //     });
  //   } catch (e) {
  //     print("Error getting App Check token: $e");
  //     setState(() {
  //       _e = e.toString();
  //       _token = "Failed to get token";
  //     });
  //   }
  // }

// // カメラとストレージの権限をチェックFuture<bool> _checkPermissions() async {
// //   bool cameraGranted = false;
// //   bool storageGranted = false;
// //
// //   if (Platform.isAndroid) {
// //     final androidInfo = await DeviceInfoPlugin().androidInfo;
// //     final int androidOsVersion = androidInfo.version.sdkInt;
// //
// //     if (androidOsVersion >= 29) {
// //       // Android 10 (API 29) 以降では、Scoped Storageに対応
// //       PermissionStatus storagePermission = await Permission.manageExternalStorage.request();
// //       if (storagePermission.isGranted) {
// //         storageGranted = true;
// //         print("外部ストレージ管理パーミッションが許可されました");
// //       } else {
// //         print("外部ストレージ管理パーミッションが拒否されました");
// //       }
// //     } else {
// //       // Android 10 未満では通常のストレージパーミッション
// //       PermissionStatus storagePermission = await Permission.storage.request();
// //       if (storagePermission.isGranted) {
// //         storageGranted = true;
// //         print("ストレージパーミッションが許可されました");
// //       } else {
// //         print("ストレージパーミッションが拒否されました");
// //       }
// //     }
// //
// //     // カメラのパーミッションをリクエスト
// //     PermissionStatus cameraPermission = await Permission.camera.request();
// //     if (cameraPermission.isGranted) {
// //       cameraGranted = true;
// //       print("カメラパーミッションが許可されました");
// //     } else {
// //       print("カメラパーミッションが拒否されました");
// //     }
// //
// //   } else if (Platform.isIOS) {
// //     // iOSの場合、写真のパーミッションをリクエスト
// //     PermissionStatus photosPermission = await Permission.photos.request();
// //     if (photosPermission.isGranted) {
// //       cameraGranted = true;
// //       storageGranted = true;
// //       print("フォトパーミッションが許可されました");
// //     } else {
// //       print("フォトパーミッションが拒否されました");
// //     }
// //   }
// //
// //   // AppState にパーミッション情報を保存
// //   Provider.of<AppState>(context, listen: false)
// //       .updatePermissions(camera: cameraGranted, storage: storageGranted);
// //
// //   return cameraGranted && storageGranted;
//   Future<void> checkPermissions(BuildContext context) async {
//     if (Platform.isAndroid) {
//       // Android端末の場合、バージョンごとにパーミッションをリクエスト
//       final androidInfo = await DeviceInfoPlugin().androidInfo;
//       final int androidOsVersion = androidInfo.version.sdkInt;
//       // Android 10以降の場合、Scoped Storageの制約に対応
//       // if (androidOsVersion >= 29) {
//         if (androidOsVersion >= 33) {
//         // Scoped Storageの場合は、外部ストレージの管理パーミッションをリクエスト
//         // PermissionStatus storagePermission = await Permission.manageExternalStorage.request();
//         PermissionStatus storagePermission = await Permission.photos.request();
//         if (!storagePermission.isGranted) {
//           print("外部ストレージの管理パーミッションが拒否されました");
//           //_showPermissionDialog();
//         }
//       } else {
//         // Android 10未満の場合は、通常のストレージパーミッションをリクエスト
//         PermissionStatus storagePermission = await Permission.storage.request();
//         if (!storagePermission.isGranted) {
//           print("ストレージのアクセスが拒否されました");
//           //_showPermissionDialog();
//         }
//       }
//
//       // カメラパーミッションのリクエスト
//       PermissionStatus cameraPermission = await Permission.camera.request();
//       if (!cameraPermission.isGranted) {
//         print("カメラのアクセスが拒否されました");
//         //_showPermissionDialog();
//       }
//
//     } else if (Platform.isIOS) {
//       // iOSの場合は、写真のパーミッションをリクエスト
//       PermissionStatus photosPermission = await Permission.photos.request();
//       if (!photosPermission.isGranted) {
//         print("カメラのアクセスが拒否されました");
//         //_showPermissionDialog();
//       }
//     }
//
//     // AppStateにパーミッション情報を保存
//     Provider.of<AppState>(context, listen: false)
//         .updatePermissions(camera: cameraGranted, storage: storageGranted);
//   }
//   Future<bool> _checkPermissions() async {
//     bool cameraGranted = false;
//     bool storageGranted = false;
//
//     if (Platform.isAndroid) {
//       final androidInfo = await DeviceInfoPlugin().androidInfo;
//       final int androidOsVersion = androidInfo.version.sdkInt;
//
//       if (androidOsVersion >= 29) {
//         // Android 10 (API 29) 以降では、Scoped Storageに対応
//         PermissionStatus storagePermission = await Permission.manageExternalStorage.request();
//         if (storagePermission.isGranted) {
//           storageGranted = true;
//           print("外部ストレージ管理パーミッションが許可されました");
//         } else {
//           print("外部ストレージ管理パーミッションが拒否されました");
//         }
//       } else {
//         // Android 10 未満では通常のストレージパーミッション
//         PermissionStatus storagePermission = await Permission.storage.request();
//         if (storagePermission.isGranted) {
//           storageGranted = true;
//           print("ストレージパーミッションが許可されました");
//         } else {
//           print("ストレージパーミッションが拒否されました");
//         }
//       }
//
//       // カメラのパーミッションをリクエスト
//       PermissionStatus cameraPermission = await Permission.camera.request();
//       if (cameraPermission.isGranted) {
//         cameraGranted = true;
//         print("カメラパーミッションが許可されました");
//       } else {
//         print("カメラパーミッションが拒否されました");
//       }
//
//     } else if (Platform.isIOS) {
//       // iOSの場合、写真のパーミッションをリクエスト
//       PermissionStatus photosPermission = await Permission.photos.request();
//       if (photosPermission.isGranted) {
//         cameraGranted = true;
//         storageGranted = true;
//         print("フォトパーミッションが許可されました");
//       } else {
//         print("フォトパーミッションが拒否されました");
//       }
//     }
//
//     // AppState にパーミッション情報を保存
//     Provider.of<AppState>(context, listen: false)
//         .updatePermissions(camera: cameraGranted, storage: storageGranted);
//
//     return cameraGranted && storageGranted;
//   }
//
//
//   // カメラ及びストレージのアクセス許可をリクエストするダイアログ
//   Future<void> _showPermissionDialog() async {
//     if (!mounted || _isDialogOpen) return;
//     _isDialogOpen = true;
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('カメラとストレージへのアクセス権限が必要です'),
//           content: Text('このアプリを使用するためには、カメラとストレージへのアクセスが必要です。設定画面に移動して権限を有効にしてください。'),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 _isDialogOpen = false;
//               },
//               child: Text('閉じる'),
//             ),
//             TextButton(
//               onPressed: () {
//                 openAppSettings();
//                 checkPermissions(context);
//               },
//               child: Text('設定に移動'),
//             ),
//           ],
//         );
//       },
//     );
//     // 設定画面から戻った後、パーミッションを再確認
//     bool permissionGranted = await _checkPermissions();
//     if (permissionGranted) {
//       // 権限が許可されていれば、状態を更新
//       Provider.of<AppState>(context, listen: false)
//           .updatePermissions(camera: true, storage: true);
//     } else {
//       // 権限が許可されていなければ、再度ダイアログ表示など
//       _showPermissionDialog();
//     }
//   }
  Future<bool> _checkPermissions() async {
    bool cameraGranted = false;
    bool storageGranted = false;

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final int androidOsVersion = androidInfo.version.sdkInt;

      // ** カメラのパーミッションリクエスト**
      PermissionStatus cameraPermission = await Permission.camera.request();
      cameraGranted = cameraPermission.isGranted;

      // ** Android のストレージ権限リクエスト**
      if (androidOsVersion >= 33) {
        // **Android 13 (API 33) 以上は `photos` 権限をリクエスト**
        PermissionStatus storagePermission = await Permission.photos.request();
        storageGranted = storagePermission.isGranted;
      } else if (androidOsVersion >= 30) {
        // **Android 11 (API 30) 以上は `MANAGE_EXTERNAL_STORAGE` をリクエスト**
        PermissionStatus manageStoragePermission = await Permission.manageExternalStorage.request();
        storageGranted = manageStoragePermission.isGranted;
      } else {
        // **Android 10 (API 29) 以下は `storage` 権限をリクエスト**
        PermissionStatus storagePermission = await Permission.storage.request();
        storageGranted = storagePermission.isGranted;
      }
    } else if (Platform.isIOS) {
      final iosInfo = await DeviceInfoPlugin().iosInfo;
      final int iosVersion = int.parse(iosInfo.systemVersion.split('.')[0]);
      PermissionStatus photosPermission = await Permission.photos.request();

      if (photosPermission.isGranted) {
        // **iOS でフルアクセスが許可された場合**
        cameraGranted = true;
        storageGranted = true;
      } else if (photosPermission.isLimited && iosVersion >= 14) {
        // **iOS 14 以降で「制限付きアクセス」**
        storageGranted = true; // **一部の写真のみアクセス可能**
        cameraGranted = false; // **カメラの利用は未許可の可能性**
        // **ユーザーに設定変更を促す**
        Future.microtask(() => PhotoManager.openSetting());
      } else {
        // **許可されていない場合**
        cameraGranted = false;
        storageGranted = false;
      }
    }

    Provider.of<AppState>(context, listen: false)
        .updatePermissions(camera: cameraGranted, storage: storageGranted);

    return cameraGranted && storageGranted;
  }

  // パーミッションの確認と必要なら設定画面を開く
  Future<void> _requestPermissionsAndProceed(VoidCallback onSuccess) async {
    bool permissionGranted = await _checkPermissions();
    if (permissionGranted) {
      onSuccess();
    } else {
      _showPermissionDialog();
    }
  }

  // 権限リクエストのダイアログ
  void _showPermissionDialog() {
    if (!mounted || _isDialogOpen) return;
    _isDialogOpen = true;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('カメラとストレージへのアクセス権限が必要です'),
          content: Text('このアプリを使用するには、カメラとストレージのアクセスを許可してください。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _isDialogOpen = false;
              },
              child: Text('閉じる'),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
                _isDialogOpen = false;
              },
              child: Text('設定に移動'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('FanPixSnap')),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 20), // ボタン間のスペース
              ElevatedButton(
                onPressed: () {
                  _requestPermissionsAndProceed(() {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CameraScreen()),
                    );
                  });
                },
                child: Text(' 画像を撮影 '),
              ),
              SizedBox(height: 20), // ボタン間のスペース
              ElevatedButton(
                onPressed: () {
                  _requestPermissionsAndProceed(() {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SendPicScreen()),
                    );
                  });
                },
                child: Text('画像を送る'),
              ),
              SizedBox(height: 20), // ボタン間のスペース
              Divider(),
              SizedBox(height: 20), // ボタン間のスペース
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => DeleteImageScreen(folderName: "fanpixsnap")),
                  );
                },
                child: Text("端末の画像を削除"),
              ),
              SizedBox(height: 20), // ボタン間のスペース
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => DeleteImageScreen(folderName: "fanpixsnaperr")),
                  );
                },
                child: Text("端末のエラー画像を削除"),
              ),
              SizedBox(height: 20), // ボタン間のスペース
              Divider(),
              SizedBox(height: 60), // ボタン間のスペース
              ElevatedButton(
                // ログ画面に遷移するボタン
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LogScreen()),
                  );
                },
                child: Text(' ログを表示 '),
              ),
              SizedBox(height: 60), // ボタン間のスペース
              Divider(),
              SizedBox(height: 30), // ボタン間のスペース
              Text('ログアウト'),
              IconButton(
                icon: Icon(Icons.logout),
                onPressed: _signOut,
              ),
              // トークン表示部分
              // Padding(
              //   padding: EdgeInsets.all(16.0),
              //   child: Text(
              //     _token != null ? 'App Check Token: $_token:' : 'Loading token...',
              //     style: TextStyle(fontSize: 16, color: Colors.black),
              //   ),
              // ),
              // // エラー表示部分
              // if (_e != null)
              //   Padding(
              //     padding: EdgeInsets.all(16.0), // 余白を追加
              //     child: Text(
              //       'エラー: $_token:$_e',  // エラー内容を表示
              //       style: TextStyle(fontSize: 16, color: Colors.red),
              //     ),
              //   ),
            ],
          ),
        ),
      ),
    );
  }
}