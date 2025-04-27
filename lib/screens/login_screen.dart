import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signup_screen.dart';
import 'password_reset_request_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  final supabase = Supabase.instance.client;

  // ログイン（メール & パスワード）
  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = "メールアドレスとパスワードを入力してください");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.error != null) {
        String errorMessage = _getFriendlyErrorMessage(response.error!.message);
        setState(() => _errorMessage = errorMessage);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      } else if (response.user != null) {
        setState(() => _errorMessage = '');
        print("ログイン成功: ${response.user!.id}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("ログイン成功")),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      setState(() => _errorMessage = "ログインに失敗しました。もう一度お試しください。");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getFriendlyErrorMessage(String errorCode) {
    // エラーコードを小文字に統一
    errorCode = errorCode.toLowerCase();

    if (errorCode.contains("invalid_credentials")) {
      return "メールアドレスまたはパスワードが間違っています。";
    } else if (errorCode.contains("email_not_confirmed")) {
      return "メールアドレスが確認されていません。確認メールをチェックしてください。";
    } else if (errorCode.contains("user_not_found")) {
      return "このメールアドレスのアカウントは存在しません。";
    } else if (errorCode.contains("password_too_short") ||
        errorCode.contains("weak_password")) {
      return "パスワードは8文字以上で入力してください。";
    } else if (errorCode.contains("network_error") ||
        errorCode.contains("timeout")) {
      return "ネットワークエラーが発生しました。接続を確認してください。";
    } else if (errorCode.contains("email_already_in_use") ||
        errorCode.contains("user_already_exists")) {
      return "このメールアドレスはすでに使用されています。";
    } else if (errorCode.contains("invalid_email")) {
      return "無効なメールアドレスです。正しい形式で入力してください。";
    } else if (errorCode.contains("token_expired")) {
      return "確認コードの有効期限が切れています。再度メールを送信してください。";
    } else if (errorCode.contains("invalid_token")) {
      return "無効な確認コードです。正しいコードを入力してください。";
    } else if (errorCode.contains("session_expired")) {
      return "セッションが期限切れです。再度ログインしてください。";
    } else if (errorCode.contains("operation_not_allowed")) {
      return "この操作は許可されていません。";
    } else {
      return "エラーが発生しました。もう一度お試しください。";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("ログイン")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: "メールアドレス"),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: "パスワード"),
              obscureText: true,
            ),
            SizedBox(height: 20),
            if (_errorMessage.isNotEmpty)
              Text(_errorMessage, style: TextStyle(color: Colors.red)),
            if (_isLoading)
              CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _signIn,
                child: Text("ログイン"),
              ),
            SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => SignUpScreen()),
                );
              },
              child: Text(
                "アカウントをお持ちでない方はこちら",
                style: TextStyle(
                    color: Colors.blue, decoration: TextDecoration.underline),
              ),
            ),
            SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => PasswordResetRequestScreen()),
                );
              },
              child: Text(
                "パスワードをお忘れですか？",
                style: TextStyle(
                    color: Colors.blue, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on AuthResponse {
  get error => null;
}
