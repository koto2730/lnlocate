# LNLocate

LocalNode サーバーを mDNS で LAN 内から検索し、見つかった URL をブラウザで開くランチャーアプリ。

関連: koto2730/localnode#308 (サーバー側の mDNS 告知)

## 対象プラットフォーム
- モバイル: Android / iOS
- デスクトップ: Windows / macOS / Linux

## 動作イメージ
1. LAN 内の `_localnode._tcp` (予定) を mDNS で検索
2. 見つかったサーバーを一覧表示 (名前 / ホスト / ポート)
3. TXT レコード (`scheme`, `path`) から `scheme://host:port/path` を組み立て
4. タップでブラウザ起動 (`url_launcher`)

## セットアップ
プラットフォームのファイルは生成済み。依存を取得して起動する:

```sh
flutter pub get
flutter run -d macos     # android / ios / windows / linux も同様
```

### 使用ライブラリ
- `bonsoir`: mDNS / DNS-SD の検索 (Android / iOS / macOS / Windows / Linux 対応)
- `url_launcher`: 見つけた URL をブラウザで開く

### ビルド環境
| 対象 | 必要なもの |
|---|---|
| macOS / iOS | Xcode、CocoaPods |
| Android | Android SDK (Platform 36)、JDK 21 |
| Windows | Windows 上でビルド (Visual Studio の「C++ によるデスクトップ開発」) |
| Linux | Linux 上でビルド (`clang cmake ninja-build pkg-config libgtk-3-dev`)。実行時は `avahi-daemon` が必要 |

### プラットフォーム設定 (設定済み)
- Android: `INTERNET` / `ACCESS_WIFI_STATE` / `CHANGE_WIFI_MULTICAST_STATE` 権限、http(s) 起動用 `<queries>`
- iOS / macOS: `NSLocalNetworkUsageDescription`、`NSBonjourServices` に `_localnode._tcp`
- macOS: `com.apple.security.network.client` entitlement

## 動作
1. 起動すると `_localnode._tcp` の検索を自動で開始する
2. 見つかったサーバーを一覧表示する (1台でも自動では開かない)
3. タップすると、既定のブラウザで `scheme://host:port/path` を開く
   - ホストは TXT の `host` → IPv4 アドレス → mDNS ホスト名の順に採用
4. 右上の更新ボタンで再検索

## テスト
```sh
flutter test                         # ユニット / ウィジェットテスト
# 実機の mDNS 検出 (LocalNode を --mdns で起動しておく)
flutter test integration_test -d macos --dart-define=EXPECT_SERVER="Office LocalNode"
```
macOS 15 以降は初回起動時に「ローカルネットワーク」の許可ダイアログが出る。許可しないと何も検出されない。

## 検討事項
- サービス種別・TXT レコード仕様は localnode#308 と揃える (`txtvers`, `scheme`, `path`, `name`, `auth`, `ver`, `host`)
- URL は `scheme://host:port/path` で組み立てる。TXT に `host` があればそれを優先
- Windows / Linux のファイアウォール (UDP 5353)、Linux は Avahi との共存

## アイコン
`assets/icon/icon.png` (1080x1080) から生成する。LocalNode のアイコン (黒地・白線の L—N) に、検索を表す虫眼鏡を組み合わせている。

```sh
dart run flutter_launcher_icons
```
Linux はウィンドウアイコンを別途設定していない。

## CI / CD (GitHub Actions)
iOS は Xcode Cloud で別途ビルドするため、ここには含まない。ストア (Google Play / App Store) へのアップロードは今は行わない。

| ワークフロー | トリガー | 内容 |
|---|---|---|
| `ci.yml` | PR / main への push | `flutter analyze` + `flutter test`、Android / Linux / Windows / macOS のビルド確認 |
| `release.yml` | main への push / 手動実行 | Android (APK) / Windows / Linux (x64・arm64) / macOS (署名なし) をビルドし、GitHub Releases にドラフト作成 |

### 必要な Secrets
| 名前 | 内容 |
|---|---|
| `ANDROID_KEYSTORE_CONTENT` | リリース用キーストア (base64) |
| `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_ALIAS` / `ANDROID_KEY_PASSWORD` | 署名情報 |

ストアへのアップロードを始める場合は、`release.yml` にアップロード用のジョブを追加する (Google Play は Play Console でのアプリ登録が先に必要)。
