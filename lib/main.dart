import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:fan_pix_snap/screens/send_pic_screen.dart';
import 'package:fan_pix_snap/services/local_server_manager.dart';
import 'package:fan_pix_snap/services/local_client_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
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

  // Supabaseを初期化する処理
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
    authOptions: FlutterAuthClientOptions(
      autoRefreshToken: true,
      authFlowType: AuthFlowType.pkce, // 必要に応じて設定
    ),
  );

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
  bool _isDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // ユーザー設定をロード（保存先設定）
  Future<void> _loadPreferences() async {
    final storageProvider = Provider.of<AppState>(context, listen: false);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // **保存先の取得**（デフォルトは "cloud"）
    String storedValue = prefs.getString('selectedStorage') ?? "cloud";
    storageProvider.setSelectedStorage(storedValue);
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    Navigator.pushReplacementNamed(context, '/'); // ログアウト後、認証画面へ
  }

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
        PermissionStatus manageStoragePermission =
            await Permission.manageExternalStorage.request();
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 画像撮影関連
              SectionHeader(title: '画像関連'),
              ElevatedButton.icon(
                onPressed: () {
                  _requestPermissionsAndProceed(() {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CameraScreen()),
                    );
                  });
                },
                icon: Icon(Icons.camera_alt),
                label: Text('画像を撮影'),
              ),
              SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  _requestPermissionsAndProceed(() {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SendPicScreen()),
                    );
                  });
                },
                icon: Icon(Icons.send),
                label: Text('画像を送る'),
              ),
              SizedBox(height: 20),
              Divider(),

              // 画像削除関連
              SectionHeader(title: '削除関連'),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            DeleteImageScreen(folderName: "fanpixsnap")),
                  );
                },
                icon: Icon(Icons.delete),
                label: Text("端末の画像を削除"),
              ),
              SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            DeleteImageScreen(folderName: "fanpixsnaperr")),
                  );
                },
                icon: Icon(Icons.error),
                label: Text("端末のエラー画像を削除"),
              ),
              SizedBox(height: 20),
              Divider(),

              // ログ関連
              SectionHeader(title: 'ログ関連'),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LogScreen()),
                  );
                },
                icon: Icon(Icons.list),
                label: Text('ログを表示'),
              ),
              SizedBox(height: 20),
              Divider(),

              // ログアウト
              SizedBox(height: 30),
              Align(
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Text('ログアウト'),
                    IconButton(
                      icon: Icon(Icons.logout),
                      onPressed: _signOut,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 40), // ボタン間のスペース
            ],
          ),
        ),
      ),
    );
  }

// セクションタイトル
  Widget SectionHeader({required String title}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
