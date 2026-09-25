# Android 构建与签名

Android 客户端连接运行在其他设备上的 OAS 服务。首次启动后，在设置页填写可从手机访问的服务地址（例如 `http://192.168.1.10:22288`）；`127.0.0.1` 指的是手机自身。服务端和手机需要在同一可互通网络，服务端也需要监听对应网卡。

应用允许 HTTP 连接，以兼容局域网中的 OAS 服务。请只在可信网络使用 HTTP；有条件时优先通过 HTTPS 连接。

发布版 APK 必须使用独立的签名密钥。构建环境需要设置：

- `ANDROID_KEYSTORE_PATH`：keystore 文件的绝对路径
- `ANDROID_KEYSTORE_PASSWORD`：keystore 口令
- `ANDROID_KEY_ALIAS`：签名密钥别名
- `ANDROID_KEY_PASSWORD`：签名密钥口令

GitHub Actions 使用同名的后 3 项 Secrets，并从 `ANDROID_KEYSTORE_BASE64` 还原 keystore。不要把 keystore、口令或 `key.properties` 提交到仓库。每次更新必须使用同一签名密钥；应在安全位置保留密钥备份。

```powershell
flutter build apk --release
```
