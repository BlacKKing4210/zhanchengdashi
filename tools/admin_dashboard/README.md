# 丛林法则私有数据后台

## v1.4 全动物测试指令

在“资源发放”页搜索玩家名称或完整 ID，勾选一名玩家，点击操作区顶部的“一键发放全部动物（各1份）”。自动填写测试审计原因，无需第二次确认。全部动物来自当前阿里云服务器的动物目录，不包含金矿和防御塔；每种增加 1 份，不自动升级、改变阵容或发放抽卡券。未选或多选时快捷按钮禁用；普通多玩家资源发放保持不变。

接口 `POST /api/resource-grants/preview` 接受 `target: {kind: "user", user_id: "..."}`、`grant: {type: "all_animals", amount: 1}`、`reason` 和 UUID `idempotency_key`；目录由服务端读取，扩展后通过既有签名预览提交端点。Node 和游戏执行器必须同时支持 256 项指令上限。单次点击只产生一条原子指令，完整列表参与幂等校验；界面只收到终态后显示成功。测试使用隔离账号夹具，不向真实玩家发送资源。

v1.4 同时修正 HTTPS 续期部署：允许替换已过期旧证书、每次续期任务补偿未部署的签发结果，并在重启后重试受信 HTTPS 健康检查。

这是一个仅使用 Node.js 标准库的私有运营后台。它读取阿里云服务端生成的两份脱敏只读投影，提供按战斗类型统计的总览与动物平均排名、带玩家名称和完整 ID 的全部角色、按存储段位排序且使用中文卡牌名的保存阵容，以及受签名预览、幂等和审计保护的 Owner 资源指令；它不是游戏账号登录页，也不直接修改玩家权威存档。

## 首次初始化 Owner

必须在服务器本机的交互式终端执行。命令会以隐藏输入方式要求 Owner 密码，且只在尚未存在任何后台账号时成功；没有默认账号，也没有网页注册入口。

```powershell
.\tools\start_admin_dashboard.ps1 -InitializeOwner `
  -StateDir "$env:LOCALAPPDATA\JungleLaw\AdminDashboard" `
  -OwnerUsername owner
```

之后由 Owner 在“Owner 权限”页面创建、停用或调整 Analyst / Owner 账号。仓库、文档和启动脚本均不得保存管理员明文密码。

## 启动

在阿里云目标机上提供统计投影、账号阵容投影和受保护的资源指令目录：

```powershell
.\tools\start_admin_dashboard.ps1 `
  -SnapshotPath "D:\server-data\dashboard_snapshot.json" `
  -AccountSnapshotPath "D:\server-data\admin_accounts_snapshot.json" `
  -CommandRoot "D:\server-private\admin-commands"
```

默认地址为 [http://127.0.0.1:24568](http://127.0.0.1:24568)。该地址只用于目标服务器上的回环预检；正式外部访问必须走受控 HTTPS。管理员状态（密码哈希、会话哈希和审计日志）默认保存在：

```text
%LOCALAPPDATA%\JungleLaw\AdminDashboard
```

可通过 `-StateDir` 或 `ZHANCHENG_DASHBOARD_STATE_DIR` 改到受保护的服务器私有目录。

## 远程访问

默认仅允许回环地址。若绑定到任何非回环地址，必须同时提供 TLS 证书和私钥；程序会拒绝裸 HTTP 公网监听：

```powershell
.\tools\start_admin_dashboard.ps1 `
  -SnapshotPath "D:\server-data\dashboard_snapshot.json" `
  -AccountSnapshotPath "D:\server-data\admin_accounts_snapshot.json" `
  -CommandRoot "D:\server-private\admin-commands" `
  -Host "0.0.0.0" `
  -TlsKeyPath "D:\secrets\dashboard-key.pem" `
  -TlsCertPath "D:\secrets\dashboard-cert.pem"
```

建议通过 VPN、访问白名单或受控 HTTPS 入口限制到 Owner 和明确授权人员的设备。部署前必须使用项目正式阿里云部署档案核对域名、TLS、备份、回滚、监控和目录权限；本脚本不等于生产部署授权。

## 数据边界

后台使用以下三个互相分离的服务端边界：

- `-SnapshotPath` / `ZHANCHENG_DASHBOARD_SNAPSHOT_PATH`：文件名必须严格为 `dashboard_snapshot.json`，只含赛事与动物统计投影。
- `-AccountSnapshotPath` / `ZHANCHENG_DASHBOARD_ACCOUNT_SNAPSHOT_PATH`：文件名必须严格为 `admin_accounts_snapshot.json`，只含后台需要的脱敏账号、阵容、段位镜像和资源摘要。
- `-CommandRoot` / `ZHANCHENG_DASHBOARD_COMMAND_ROOT`：资源发放指令的服务器私有目录，只允许后台写入、授权执行器读取并回写状态；不得位于 Web 静态目录、投影目录或公开下载目录。

两份投影均由服务器按白名单生成，后台读取后还会再次做字段白名单清洗。玩家身份优先显示 `username`；旧快照没有该字段时只基于 `user_id` 生成稳定的“新玩家XXXX”临时名称，不读取或暴露登录 `account`。资源页桌面端把玩家表和资源操作卡并列，窄屏把操作卡放在玩家表之前，发放按钮始终可见且无选择时明确禁用。指定账号资源发放在一次“发放资源”动作内完成签名预览与提交，不再要求第二次密码或确认文本；全账号群发仍必须重新验证当前 Owner 密码，并准确输入 `SEND TO ALL`。提交成功只代表命令已登记，页面会短轮询同一 command_id；只有 `processed` 才表示到账，`failed` 表示失败，短暂 `pending` 只显示一条处理中状态。

**绝不能**把 `player_accounts.json`、游戏账号数据库、安装 ID、刷新令牌或任何凭据文件设为数据源；该网站从不读取这些文件。

## 页面与权限

页面顺序固定为：总览、动物平衡、角色、阵容库、Owner 资源发放、Owner 任务与审计、Owner 权限。Analyst 可以只读访问前四页；后三页在界面隐藏，服务端也必须再次执行 Owner 校验。角色页显示账号投影中的全部账号、玩家名称和完整 ID，并允许 Owner 直达指定账号发放；角色、阵容和资源页都可按玩家名称或 ID 搜索。阵容库仅列出非空保存阵容，按存储段位、星数、Elo 和 user_id 稳定排序。动物平衡页是决策辅助，不会直接改写 `config/tables/` 或运行时配置。

## 验证

```powershell
npm --prefix tools/admin_dashboard test
```
