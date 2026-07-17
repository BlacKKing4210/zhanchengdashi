# 丛林法则私有数据后台

这是一个仅使用 Node.js 标准库的私有管理网站。它读取专用服务器生成的脱敏统计快照，提供排行榜、头部玩家卡组、动物胜率和 Owner 授权管理；它不是游戏账号登录页。

## 首次初始化 Owner

必须在服务器本机的交互式终端执行。命令会以隐藏输入方式要求 Owner 密码，且只在尚未存在任何后台账号时成功；没有默认账号，也没有网页注册入口。

```powershell
.\tools\start_admin_dashboard.ps1 -InitializeOwner `
  -StateDir "$env:LOCALAPPDATA\JungleLaw\AdminDashboard" `
  -OwnerUsername owner
```

之后由 Owner 在“授权管理”页面创建或停用 Analyst / Owner 账号。

## 启动

传入服务端写出的 `dashboard_snapshot.json` 路径即可启动本机后台：

```powershell
.\tools\start_admin_dashboard.ps1 `
  -SnapshotPath "D:\server-data\dashboard_snapshot.json"
```

默认地址为 [http://127.0.0.1:24568](http://127.0.0.1:24568)。管理员状态（密码哈希、会话哈希和审计日志）默认保存在：

```text
%LOCALAPPDATA%\JungleLaw\AdminDashboard
```

可通过 `-StateDir` 或 `ZHANCHENG_DASHBOARD_STATE_DIR` 改到受保护的服务器私有目录。

## 远程访问

默认仅允许回环地址。若绑定到任何非回环地址，必须同时提供 TLS 证书和私钥；程序会拒绝裸 HTTP 公网监听：

```powershell
.\tools\start_admin_dashboard.ps1 `
  -SnapshotPath "D:\server-data\dashboard_snapshot.json" `
  -Host "0.0.0.0" `
  -TlsKeyPath "D:\secrets\dashboard-key.pem" `
  -TlsCertPath "D:\secrets\dashboard-cert.pem"
```

建议再通过 VPN 或受控 HTTPS 入口限制到 Owner 和明确授权人员的设备。

## 数据边界

只设置 `ZHANCHENG_DASHBOARD_SNAPSHOT_PATH`（或使用上述 `-SnapshotPath`）指向名字严格为 `dashboard_snapshot.json` 的服务端统计投影。后台会再次对字段做白名单清洗。

**绝不能**把 `player_accounts.json`、游戏账号数据库、安装 ID、刷新令牌或任何凭据文件设为数据源；该网站从不读取这些文件。

## 验证

```powershell
npm --prefix tools/admin_dashboard test
```
