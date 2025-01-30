import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:fan_pix_snap/screens/qr_code_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../services/app_state.dart';
import '../services/firebase_service.dart';

// カメラ画面を管理するウィジェット
class ErrSendScreenState extends ChangeNotifier {
  // ログを保持するリスト
  final List<String> _logs = [];
  // ログリストを取得するゲッター
  List<String> get logs => _logs;

  // ログを追加するメソッド
  void addLog(String message) {
    final logMessage = "[${DateTime.now()}] $message";
    _logs.add(logMessage);
  }
}

class ErrSendScreen extends StatefulWidget {
  @override
  _ErrSendScreenState createState() => _ErrSendScreenState();
}

class _ErrSendScreenState extends State<ErrSendScreen> {
  List<File> _imageFiles = [];
  // 選択された画像リスト
  List<File> _selectedImages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 画面起動時に画像をロード
    _loadImages();
  }

  // 画像ファイルをロードするメソッド
  Future<void> _loadImages() async {
    try {
      List<File> images = [];
      if (Platform.isAndroid) {
        final dirPath = Directory('/storage/emulated/0/Pictures/fanpixsnaperr');
        if (await dirPath.exists()) {
          images = dirPath
              .listSync()
              .whereType<File>()
              .where((item) => item.path.endsWith(".jpg"))
              .toList()
            ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        }
      } else if (Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        final dirPath = Directory('${directory.path}/fanpixsnaperr');
        if (await dirPath.exists()) {
          images = dirPath
              .listSync()
              .whereType<File>()
              .where((item) => item.path.endsWith(".jpg"))
              .toList()
            ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        }
      }
      setState(() {
        _imageFiles = images;
      });
    } catch (e) {
      Future.microtask(() {
        Provider.of<ErrSendScreenState>(context, listen: false)
            .addLog('エラー送信画像の読み込みでエラー: $e');
        });
    }
  }

  Future<void> _sendErrImage(List<File> selectedImages) async {
    if (_selectedImages.isEmpty) {
      // 画像が選択されていない場合
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('画像を選択してください')),
      );
      return;
    }
    // FirebaseStorageの場合、選択画像が1枚のみか確認
    if (Provider.of<AppState>(context, listen: false).useFirebaseStorage &&
        _selectedImages.length != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('外部ストレージへの保存する場合は、1枚ずつ選択してください。')),
      );
      return;
    }

    try {
      final storageProvider = Provider.of<AppState>(context, listen: false);
      for (var imageFile in _selectedImages) {
        Uint8List imageData = await imageFile.readAsBytes();
        String result;
        if (storageProvider.useFirebaseStorage) {
          result = await FirebaseService.uploadImage(imageFile);
          if (result.isNotEmpty) {
            // アップロードが成功した場合、QRコード表示画面へ遷移
            Future.microtask(() {
              Provider.of<ErrSendScreenState>(context, listen: false)
                  .addLog('ストレージへ保存: $result');
            });
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QRCodeScreen(imageUrl: result),
              ),
            );
          }
        } else {
          result = await _sendImageToLocalServer(imageData);
        }
        if (result.isNotEmpty) {
          Future.microtask(() {
            Provider.of<ErrSendScreenState>(context, listen: false)
                .addLog('エラー画像の保存成功: $result');
          });
        } else {
          Future.microtask(() {
            Provider.of<ErrSendScreenState>(context, listen: false)
                .addLog('エラー画像の保存失敗');
          });
        }
      }
      setState(() {
        _isLoading = false;
        _selectedImages.clear(); // 送信後、選択リストをクリア
      });
    } catch (e) {
      Future.microtask(() {
        Provider.of<ErrSendScreenState>(context, listen: false)
            .addLog('エラー画像保存中のエラー: $e');
      });
    }
  }

  Future<String> _sendImageToLocalServer(Uint8List editedImageData) async {
    try {
      final ipAddress = Provider.of<AppState>(context, listen: false).ipAddress;
      final port = Provider.of<AppState>(context, listen: false).port;
      final Uri uri = Uri.parse('http://$ipAddress:$port/upload');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/octet-stream'},
        body: editedImageData,
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              content: Text('ローカルサーバへ送信しました。'),
              actions: [
                TextButton(
                  onPressed: () {
                    // OKボタンが押されたときにダイアログを閉じる
                    Navigator.of(context).pop();
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
        return response.body;
      } else {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              content: Text('ローカルサーバへの保存に失敗しました。'),
              actions: [
                TextButton(
                  onPressed: () {
                    // OKボタンが押されたときにダイアログを閉じる
                    Navigator.of(context).pop();
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
        Future.microtask(() {
          Provider.of<ErrSendScreenState>(context, listen: false)
              .addLog('ローカルサーバへの保存失敗');
        });
        return '';
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: Text('ローカルサーバへの保存に失敗しました。'),
            actions: [
              TextButton(
                onPressed: () {
                  // OKボタンが押されたときにダイアログを閉じる
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
      Future.microtask(() {
        Provider.of<ErrSendScreenState>(context, listen: false)
            .addLog('ローカルサーバへの保存失敗');
      });
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('画像を選択して送信')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: _imageFiles.isEmpty
                ? Center(child: Text('画像が見つかりません'))
                : ListView.builder(
                  itemCount: _imageFiles.length,
                  itemBuilder: (context, index) {
                    final file = _imageFiles[index];
                    final fileName = file.uri.pathSegments.last;
                    return ListTile(
                      leading: Image.file(file, width: 50, height: 50),
                      title: Text(fileName),
                      trailing: Checkbox(
                        value: _selectedImages.contains(file),
                        onChanged: (bool? selected) {
                          setState(() {
                            if (selected == true) {
                              if (Provider.of<AppState>(context, listen: false).useFirebaseStorage &&
                                  _selectedImages.length >= 1) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('FirebaseStorageには1枚のみ選択できます')),
                                );
                              } else {
                                _selectedImages.add(file);
                              }
                            } else {
                              _selectedImages.remove(file);
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
          ),
          ElevatedButton(
            onPressed: _isLoading || (_selectedImages.length != 1)
                ? null
                : () async {
              await _sendErrImage(_selectedImages);  // この部分を修正
            },
            child: _isLoading ? CircularProgressIndicator() : Text('送信'),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }
}