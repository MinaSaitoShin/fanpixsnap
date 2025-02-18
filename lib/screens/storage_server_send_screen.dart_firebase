import 'package:fan_pix_snap/screens/storage_qr_code_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

class StorageServerSendScreen extends StatefulWidget {
  @override
  _StorageServerSendScreenState createState() => _StorageServerSendScreenState();
}

class _StorageServerSendScreenState extends State<StorageServerSendScreen> {
  // 画像URLリスト
  // List<String> _imageUrls = [];
  // 選択した画像URL
  String? _selectedImageUrl;
  // 初期値は当日
  DateTime _selectedDate = DateTime.now().toLocal();
  // ローディング状態
  bool _isLoading = false;
  // キャッシュ用のリスト
  List<Map<String, dynamic>> _cachedImageList = [];
  // フィルタリングしたリスト
  List<Map<String, dynamic>> _filteredImageList = [];

  @override
  void initState() {
    super.initState();
    _loadImages(fromCache: false);
  }

  // Firebase Storage から選択した日付の画像URLを取得
  Future<void> _loadImages({bool fromCache = true}) async {
    setState(() {
      _isLoading = true; // ローディング開始
    });

    try {
      if (!fromCache || _cachedImageList.isEmpty) {
        // 更新ボタン押下時、またはキャッシュが空なら Firebase から取得
        FirebaseStorage storage = FirebaseStorage.instance;
        List<Map<String, dynamic>> imageList = [];
        // List<String> urls = [];
        print('ストレージの情報を確認: $storage');

        // Firebase Storage のフォルダ（例: images/）を参照
        ListResult result = await storage.ref('images').listAll();
        print('ストレージ内の画像リスト: $result');

        for (var item in result.items) {
          String imageUrl = await item.getDownloadURL();
          print("取得した画像URL: $imageUrl");
          // メタデータ取得
          FullMetadata metadata = await item.getMetadata();

          // 作成日時をフォーマット
          DateTime? createdAt = metadata.timeCreated;
          String formattedDate = createdAt != null
              ? DateFormat('yyyy/MM/dd HH:mm:ss').format(createdAt)
              : "不明";

          // 画像情報をリストに追加
          var imageData = {
            'name': metadata.name,
            'url': imageUrl,
            'createdAt': formattedDate,
            'createdAtRaw': createdAt,
          };
          imageList.add(imageData);
          print("画像取得: ${metadata
              .name}, 作成日時: $formattedDate, URL: $imageUrl");
        }
        // // 作成日が選択された日と一致する場合のみリストに追加
        // if (_isDateMatched(imageData)) {
        //   imageList.add(imageData);
        // }
        imageList.sort((a, b) =>
            b['createdAtRaw'].compareTo(a['createdAtRaw']));
        // キャッシュ更新
        _cachedImageList = imageList;
      }
      _filteredImageList = _cachedImageList.where(_isDateMatched).toList();
    } catch (e) {
      print("エラー: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
      //
      //   // ファイル名にタイムスタンプが含まれていると仮定し、並び替えを実施
      //   String timestampStr = '';
      //
      //   try {
      //     // URLデコードしてから処理
      //     var filename = Uri.decodeFull(item.name);
      //     print("取得したファイル名：$filename");
      //
      //     // ファイル名に "T" が含まれているかチェック
      //     if (filename.contains('T')) {
      //       var timestampParts = filename.split('T');
      //       print("タイムスタンプパーツの確認：$timestampParts");
      //
      //       if (timestampParts.isNotEmpty) {
      //         timestampStr = timestampParts[0]; // タイムスタンプ部分を取得
      //         print("タイムスタンプの取得：$timestampStr");
      //       }
      //     } else {
      //       print("警告: ファイル名に 'T' が含まれていないため、タイムスタンプを取得できません → $filename");
      //     }
      //   } catch (e) {
      //     print("エラー: タイムスタンプの解析に失敗: ${item.name} ($e)");
      //   }
      //
      //   if (timestampStr.isNotEmpty) {
      //     DateTime timestamp = _parseTimestamp(timestampStr); // タイムスタンプ部分を DateTime に変換
      //     String formattedSelectedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      //     String formattedTimestamp = DateFormat('yyyy-MM-dd').format(timestamp);
      //
      //     // 選択した日付と一致する画像のみ追加
      //     if (formattedTimestamp == formattedSelectedDate) {
      //       urls.add(imageUrl);
      //       print('選択した日付の画像を追加: $imageUrl');
      //     }
      //   }
      // }

  //     if (mounted) {
  //       setState(() {
  //        // _imageUrls = urls;
  //         _imageList = imageList;
  //         _isLoading = false; // ローディング終了
  //       });
  //     }
  //   } catch (e) {
  //     print("エラー: $e");
  //     setState(() {
  //       _isLoading = false; // ローディング終了（エラー時）
  //     });
  //   }
  // }

  // タイムスタンプを DateTime に変換するメソッド
  DateTime _parseTimestamp(String timestampStr) {
    try {
      print("解析対象のタイムスタンプ: $timestampStr");
      DateTime timestamp = DateTime.parse(timestampStr); // UTC時間としてパース
      return timestamp.toLocal(); // ローカル時間に変換
    } catch (e) {
      print("タイムスタンプの解析エラー: $e");
      return DateTime.now(); // エラー時は現在時刻を返す
    }
  }

  // 選択した日付と一致する画像のみフィルタリング
  bool _isDateMatched(Map<String, dynamic> image) {
    // 作成日を DateTime に変換して、時間部分を無視して一致を比較
    DateTime imageDate = DateFormat('yyyy/MM/dd HH:mm:ss').parse(image['createdAt']!);
    print('イメージ日付（DateTime形式）：$imageDate');
    print('選択日付（_selectedDate）: $_selectedDate');

    // 年、月、日 のみ比較
    bool isMatch = imageDate.year == _selectedDate.year &&
        imageDate.month == _selectedDate.month &&
        imageDate.day == _selectedDate.day;

    print('一致結果: $isMatch');

    return isMatch;
  }

  // 日付変更時にキャッシュからフィルタリング
  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        // キャッシュから検索
        _filteredImageList = _cachedImageList.where(_isDateMatched).toList();
      });
      // // 日付変更後に画像を再取得
      // _loadImages();
    }
  }

  // 画像を選択して QR コードを生成
  void _generateQRCode(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StorageQRCodeScreen(imageFuture: Future.value(imageUrl)),
      ),
    );
    // if (mounted) {
    //   setState(() {
    //     _selectedImageUrl = imageUrl;
    //   });
    // }
  }

  // 選択をリセット（QRコードを非表示にする）
  void _resetSelection() {
    if (mounted) {
      setState(() {
        _selectedImageUrl = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('画像を選択して送信')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // 日付選択ボタン
            ElevatedButton(
              onPressed: () => _selectDate(context),
              child: Text("日付を選択: ${DateFormat('yyyy/MM/dd').format(_selectedDate)}"),
            ),
            SizedBox(height: 10),

            // ローディング中はインジケーターを表示
            _isLoading
                ? Expanded(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
                : Expanded(
                  child: _filteredImageList.isEmpty
                    ? Center(child: Text('画像が見つかりません'))
                    : ListView.builder(
                      itemCount: _filteredImageList.length,
                      itemBuilder: (context, index) {
                        //String imageUrl = _imageList[index];
                        //var image = _imageList[index];
                        var image = _filteredImageList[index];

                        return ListTile(
                          contentPadding: EdgeInsets.all(8.0),
                          leading: Image.network(
                            //imageUrl,
                            image['url'],
                            width: 50, // サムネイルサイズ
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                    // title: Text('image ${index + 1}'),
                          title: Text(image['name']),
                          subtitle: Text("作成日時: ${image['createdAt']}"),
                          onTap: () => _generateQRCode(image['url']),
                        );
                      },
                    ),
                ),
            SizedBox(height: 20),
            ElevatedButton(
              // 更新ボタンで Firebase から取得
              onPressed: () => _loadImages(fromCache: false),
              child: Text("更新"),
            ),
          ],
        ),
      ),
    );
  }
}
