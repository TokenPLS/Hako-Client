# Clash for Apple Platforms

[中文](#中文) · [English](#english)

## 中文

基于 Hako 内核的规则代理客户端，支持 iOS、iPadOS、tvOS 和 macOS。
当前为预发布源码，尚不代表正式发行版本。

### 官网与下载

- [官方网站](https://clash.md/)
- [在 App Store 下载官方客户端](https://apps.apple.com/app/id6794257189)

### 仓库结构

- `apple/HakoClient`：各平台应用与扩展
- `apple/HakoClientKit`：共享配置与档案模型
- `apple/HakoClientUI`：共享界面组件
- `apple/HakoMacClient`：macOS 组件

[内核](https://github.com/TokenPLS/Hako)与 [Adapter](https://github.com/TokenPLS/Hako-Adapter)
的公开源码版本固定在 `Dependencies.lock.json`。

### 构建

准备 macOS、Xcode 26.6、XcodeGen、Git、Go，以及安装了 PyYAML 的 Python 3。

```sh
python3 scripts/bootstrap.py
python3 scripts/configure.py
```

首次运行会拉取固定版本的公开依赖并构建 SDK。
打开 `apple/HakoClient/HakoClient.xcodeproj`，选择对应 Scheme：

| 平台 | Scheme |
| --- | --- |
| iOS / iPadOS | `HakoClient` |
| tvOS | `HakoTV` |
| macOS | `HakoMac` |

例如，不签名编译 iOS 模拟器版本：

```sh
xcodebuild -project apple/HakoClient/HakoClient.xcodeproj \
  -scheme HakoClient -configuration Release \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

### 真机签名

使用你自己的 Bundle ID 和 Apple Developer Team ID：

```sh
python3 scripts/configure.py --bundle-base org.yourname.clash --team YOURTEAMID
```

在 Xcode 中配置相应的签名与应用能力。仓库不包含证书或描述文件。

### 许可证

见 [LICENSE](LICENSE)。第三方资源的许可证随资源保留。

## English

A rule-based proxy client for iOS, iPadOS, tvOS and macOS, powered by Hako.
This is a pre-release source distribution, not a formal product release.

### Website and download

- [Official website](https://clash.md/)
- [Download the official client on the App Store](https://apps.apple.com/app/id6794257189)

### Source layout

- `apple/HakoClient`: platform applications and extensions
- `apple/HakoClientKit`: shared configuration and profile models
- `apple/HakoClientUI`: shared interface components
- `apple/HakoMacClient`: macOS components

Public [Kernel](https://github.com/TokenPLS/Hako) and
[Adapter](https://github.com/TokenPLS/Hako-Adapter) revisions are pinned in
`Dependencies.lock.json`.

### Build

Requirements: macOS, Xcode 26.6, XcodeGen, Git, Go, and Python 3 with PyYAML.

```sh
python3 scripts/bootstrap.py
python3 scripts/configure.py
```

The first run fetches pinned public dependencies and builds the SDK.
Open `apple/HakoClient/HakoClient.xcodeproj` and select a scheme:

| Platform | Scheme |
| --- | --- |
| iOS / iPadOS | `HakoClient` |
| tvOS | `HakoTV` |
| macOS | `HakoMac` |

For example, build for the iOS Simulator without signing:

```sh
xcodebuild -project apple/HakoClient/HakoClient.xcodeproj \
  -scheme HakoClient -configuration Release \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

### Device signing

Use your own bundle identifier and Apple Developer Team ID:

```sh
python3 scripts/configure.py --bundle-base org.yourname.clash --team YOURTEAMID
```

Configure signing and the required capabilities in Xcode. Certificates and
provisioning profiles are not included.

### License

See [LICENSE](LICENSE). Third-party resource licenses remain with their resources.
