# 多端发布打包流程

## 默认目标

每次正式打包默认同时产出以下三端客户端，不再只导出 Windows：

| 平台 | Godot 导出预设 | 固定名称产物 | 日期归档产物 |
| --- | --- | --- | --- |
| Windows | `Windows Desktop` | `build/windows/JungleLaw-windows-x64.zip` | `build/windows/JungleLaw-windows-x64-YYYY-MM-DD.zip` |
| Android | `Android` | `build/android/JungleLaw-android.apk` | `build/android/JungleLaw-android-YYYY-MM-DD.apk` |
| HTML5 | `Web` | `build/web/JungleLaw-web.zip` | `build/web/JungleLaw-web-YYYY-MM-DD.zip` |

HTML5 先导出网页入口及其资源文件，再归档为 ZIP；部署时解压 ZIP，并以 HTTP(S) 服务提供同一目录中的文件，不能直接双击本地 HTML 文件。

## 发布前提

- 先运行 `tools/validate_config.py` 与 `tools/export_config.py`，确保运行时 JSON 和 CSV 源表一致。
- 本机必须安装与项目 Godot 版本一致的 Windows、Android、Web 导出模板。
- Android 还要求 OpenJDK 17 和 Android SDK。SDK 至少需要 Platform-Tools、Build-Tools 35.0.1、Platform 35 与 Command-line Tools；只有启用 Gradle 自定义构建时才额外需要 CMake 与 NDK。
- 当前 Android 预设面向真机安装包，默认仅导出 `arm64-v8a`，以控制 APK 体积。未提供生产签名时，脚本会以 Godot 的本机调试签名导出发布模式 APK，便于内测安装。上架 Google Play 前须设置 `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`、`GODOT_ANDROID_KEYSTORE_RELEASE_USER`、`GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`，并改为输出 AAB。
- Android 发布会启用项目的 ETC2/ASTC 纹理导入；首次切换到该发布流程后，Godot 会为移动端重新导入受影响的纹理资源。

## 执行命令

```powershell
powershell -ExecutionPolicy Bypass -File tools/package_release.ps1 `
  -GodotExe 'D:\Work\godot\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
```

脚本顺序固定为：验证配置 → 导出运行时 JSON → 先预检并导出 Android/Web → 导出 Windows → 生成日期归档 → 刷新固定名称最新包 → 输出 SHA-256。任一导出失败即停止，不把旧包误报为最新包。
