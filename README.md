# ubidding_flutter_example

Demonstrates how to use the ubidding_flutter plugin.

公开导出的示例从 pub.dev 依赖 `ubidding_flutter`。Android 核心 AAR 放到
`android/sdk/`，iOS 用环境变量 `UBIDDING_POD_SOURCE` 指定 Pod 源。插件仓库内另有
`pubspec_overrides.yaml` 指向本地插件，导出时不包含该文件。

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## 示例宿主参数

| 平台 | 应用标识 | App ID | 开屏 Slot ID |
| --- | --- | --- | --- |
| Android | `com.ubidding.android` | `184795459909` | `5000005` |
| iOS | `com.ubidding.ios` | `162525628065` | `5000006` |

参数集中在 `lib/demo_config.dart`，当前页面按平台预填 App ID，不自动初始化。
以上广告位均为开屏类型，未填入插屏输入框；插屏/激励现按平台预填对应广告位。
开屏/插屏/激励原生桥接已接入，真机广告流程待验收。iOS 真机签名需为新 Bundle ID 配置对应开发团队/描述文件。

## 全屏示例操作

默认进入插屏页面，顶部“开屏”“激励”进入独立页面；各页都有手动初始化、加载、Ready、展示、信息和释放。
开屏按平台预填对应开屏位，插屏/激励按平台预填对应类型的测试位。
进入页面不自动初始化或请求广告；隐私可选访问默认关闭。加载后锁定 Slot ID，释放后可修改。
离开页面释放该页句柄。日志中的 rewardVerify 代表 SDK 回调，不等同业务服务端奖励结算。

公共句柄已区分 UBiddingFullScreenAd 与 UBiddingEmbeddedAd；Native/Banner 不再公开 show。
嵌入式 PlatformView 已接入：Banner 与信息流（模板/自渲染）经独立页面手动挂载/解绑/释放；真机渲染验收待完成。

## 2026-09-20 广告位更新

| 类型 | iOS | Android |
| --- | --- | --- |
| 开屏 | 5000006 | 5000005 |
| 插屏 | 5000007 | 5000004 |
| 激励 | 5000008 | 5000003 |
| Banner | 5000011 | 5000002 |
| 模板信息流 | 5000009 | 5000001 |
| 原生自渲染信息流 | 5000010 | 5000000 |

按用户截图更新，App ID 不变；配置广告位不代表对应广告实现或真机验收完成。

## 宿主展示职责（2026-10-23）

- 开屏提供“带底部加载”“带底部展示”“无底部展示”；Android 使用 example_splash_bottom XML，iOS 使用 UBExampleSplashBottomView 类。普通展示继承 load 配置。
- 自渲染页面先 getMaterial，布局完全由 example/lib/widgets/native_layout.dart 指定；其 @Preview 可独立检查槽位几何。
- iOS Adapter 版本由本示例 Podfile 显式引入。Android 核心 AAR 单独打包，三方广告 AAR 放在 android/libs，由 app/build.gradle 引入。
- 详见「宿主自定义展示」文档。

Android Release 的可选 Honor 标识类精确 R8 规则也归本示例维护，见 android/app/proguard-rules.pro。

## 控制台诊断

启动页和首页的 Plugin 日志下拉框可选 off/error/warn/info/debug/trace，默认 Info；SDK debugLogEnabled 独立。
详见「插件日志」与「开屏底部参数/宿主资源」文档。

## 多条 Native

模板、自渲染页面一次 SDK load 后遍历 nativeAdDatas，每条独立 Key/PlatformView/素材/事件。
提供逐条解绑、重挂载和释放；整批重新加载替换旧批次。布局仍定义在 lib/widgets/native_layout.dart。
接口与 SDK 作用域见「批次说明」文档。
