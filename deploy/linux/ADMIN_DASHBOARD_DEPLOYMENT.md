# 数据后台阿里云部署手册

状态：`AUTHORIZED STAGING EXECUTION IN PROGRESS / 已完成 prepare 与正式证书签发，激活和外部验收待完成`

本目录只提供可审查的 Linux 部署模板，没有授权或执行任何 SSH、上传、安装、端口变更、服务启动、账号初始化或生产写入。只有 `production/deployment/aliyun-profile.yaml` 完整记录目标环境与授权，且制片人明确批准对应环境的远程写入后，才可以按本手册从 staging 开始部署。

## 1. 发布门禁

部署前必须在正式 profile 中填写并复核：

- 环境名称、SSH alias、主机角色、地域、操作系统与责任人；
- 管理域名、绑定地址、外部端口、阿里云安全组与主机防火墙规则；
- Node.js 版本与绝对路径、发布目录、持久化目录、服务名；
- TLS 证书来源、证书与私钥路径、续期责任人和到期告警；
- 健康检查地址、日志和监控位置；
- 备份范围、备份位置、保留期、恢复步骤与回滚责任人；
- staging 或 production 的远程写入授权，且 staging 验收完成后再单独批准 production。

缺少任一项时保持 `NOT READY`，不得猜测 IP、域名、端口、SSH 用户、目录或凭据。项目本机只用于编辑和静态测试，不作为部署服务器。

## 2. 网络与身份安全

- 用户已明确批准**仅 OpenClaw-ejrr、仅 staging** 将 TCP `443` 以 `0.0.0.0/0` 公网入站开放。该决定不扩展到 SSH、游戏端口、同机其他项目或 production；`production_remote_writes` 仍为 `false`。
- Node.js 在 `0.0.0.0:443` 直接终止 TLS，仅通过 systemd 239 drop-in 授予 `CAP_NET_BIND_SERVICE`。公网入口必须同时通过有效 IP 证书、登录鉴权、错误密码限速、会话/CSRF/Origin 防护与审计门禁；任一门禁失败都要关闭 `443` 或停止后台，不能降级为 HTTP。
- 证书目标为 Let's Encrypt 2026 短期 IP 证书，覆盖 `106.15.61.103`。本次固定 Python 3.11 venv 与 Certbot `5.7.0`（满足 IP 证书所需的 `>=5.4`），使用 `shortlived` profile 和已存在的 nginx TCP 80 webroot 完成 HTTP-01；本 overlay 不编辑、不 reload、也不 restart nginx。
- 本次 profile 已明确批准进程直接监听 `443`；只通过 systemd drop-in 添加 `AmbientCapabilities=CAP_NET_BIND_SERVICE` 和 `CapabilityBoundingSet=CAP_NET_BIND_SERVICE`，除此之外仍保持 capability 空集。`dashboard.env` 的运行端口必须与证书健康端口逐字一致，不能依赖会被 `EnvironmentFile` 覆盖的同名 drop-in 变量。
- 使用独立的非 root 用户 `junglelaw-admin`。它只能读取服务端生成的脱敏快照，只能向 `pending` 写入资源发放命令，并只能读取 `processed` / `failed` 回执。
- Owner 仅能在目标服务器的交互式终端初始化。命令会隐藏密码输入；不得通过环境变量、命令行参数、脚本、日志或仓库传递密码。密码必须满足程序当前的强度校验。
- TLS 私钥和 full chain 都固定为 `root:junglelaw-admin`、`0640`；环境文件同样为 `root:junglelaw-admin`、`0640`。禁止提交私钥、密码、token、cookie 或完整账号数据库。

Owner 初始化示例（仅在 staging 的服务首次启动前、获得远程写入授权后执行）：

```bash
sudo -u junglelaw-admin /usr/bin/node \
  /opt/junglelaw-admin/current/tools/admin_dashboard/server.mjs \
  init-owner \
  --state-dir /var/lib/junglelaw-admin-dashboard \
  --username '<approved-owner-name>'
```

不要把密码追加到该命令。程序应在当前 TTY 中隐藏读取并要求确认。

若 Owner 密码遗失或需要轮换，必须先停止后台，随后在同一台 staging 主机的真实 TTY 中运行下列命令。该命令只接受隐藏交互输入，不接受密码参数或环境变量；成功后原子写入 `admin_updated` 审计事件并撤销该 Owner 的旧会话。完成后再启动后台并验证新密码，禁止直接编辑状态 JSON：

```bash
systemctl stop junglelaw-admin-dashboard.service
sudo -u junglelaw-admin /usr/bin/node \
  /opt/junglelaw-admin/current/tools/admin_dashboard/server.mjs \
  reset-owner-password \
  --state-dir /var/lib/junglelaw-admin-dashboard \
  --username 'tian'
systemctl start junglelaw-admin-dashboard.service
```

证书续期配置只记录非秘密路径和公网 IP，安装在 `root:root`、`0600` 的 `/etc/junglelaw-admin-dashboard/cert-renew.env`：

```text
JUNGLELAW_CERT_IP=106.15.61.103
JUNGLELAW_CERT_WEBROOT=<由远端只读 nginx 基线确认的现有绝对 webroot>
JUNGLELAW_CERT_NAME=junglelaw-admin-ip
JUNGLELAW_CERTBOT_BIN=/opt/junglelaw-admin-certbot/venv/bin/certbot
JUNGLELAW_CERTBOT_PYTHON_BIN=/opt/junglelaw-admin-certbot/venv/bin/python
JUNGLELAW_CERT_HEALTH_PORT=8443
JUNGLELAW_AUTHORITY_PATH=<只读基线解析出的 canonical user://server/player_accounts.json>
```

不得猜测 webroot，也不得为适配本后台修改 nginx。installer 会把 service 模板中的占位路径替换为该 canonical webroot，并以唯一 `ReadWritePaths=<webroot>` 在 `ProtectSystem=full` 下只开放 ACME challenge 写入；占位符残留或替换次数不为 1 都会失败。

### 2.1 Certbot 5.7.0 自包含签发流程

先由远端只读基线确认 `python3.11` 和 nginx 已服务的 canonical webroot。获得 staging 软件安装授权后，创建独立 venv；不得污染系统 Python：

```bash
install -d -o root -g root -m 0755 /opt/junglelaw-admin-certbot
python3.11 -m venv /opt/junglelaw-admin-certbot/venv
/opt/junglelaw-admin-certbot/venv/bin/python -m pip \
  install --disable-pip-version-check 'certbot==5.7.0'
/opt/junglelaw-admin-certbot/venv/bin/python -c \
  'import sys; assert sys.version_info >= (3, 10)'
/opt/junglelaw-admin-certbot/venv/bin/certbot --version
```

先用 Let's Encrypt staging 端到端验证 HTTP-01。以下 `ACME_WEBROOT` 必须来自 nginx 只读基线，不能用占位符直接执行：

```bash
CERTBOT='/opt/junglelaw-admin-certbot/venv/bin/certbot'
ACME_WEBROOT='<confirmed-existing-nginx-webroot>'
ADMIN_PUBLIC_IP='106.15.61.103'

"${CERTBOT}" register --staging --non-interactive \
  --agree-tos --register-unsafely-without-email
"${CERTBOT}" certonly --staging --non-interactive \
  --agree-tos --register-unsafely-without-email \
  --preferred-profile shortlived \
  --webroot --webroot-path "${ACME_WEBROOT}" \
  --ip-address "${ADMIN_PUBLIC_IP}" \
  --cert-name junglelaw-admin-ip-staging
```

staging 成功只证明 challenge 路径，不得把不受信任的 staging 证书复制给后台。`prepare` 必须先安装 `/etc/letsencrypt/renewal-hooks/deploy/junglelaw-admin-dashboard-cert-deploy` 目录级 hook：该 wrapper 对其他 lineage 安全返回，只对正式 `junglelaw-admin-ip` 调用只做部署的 `deploy` 模式。随后注册正式 ACME 账号并签发正式 lineage；签发命令不再重复声明单个 lineage hook：

```bash
"${CERTBOT}" register --non-interactive \
  --agree-tos --register-unsafely-without-email
"${CERTBOT}" certonly --non-interactive \
  --agree-tos --register-unsafely-without-email \
  --preferred-profile shortlived \
  --webroot --webroot-path "${ACME_WEBROOT}" \
  --ip-address "${ADMIN_PUBLIC_IP}" \
  --cert-name junglelaw-admin-ip
test "$(stat -c '%U:%G:%a' \
  /etc/letsencrypt/renewal-hooks/deploy/junglelaw-admin-dashboard-cert-deploy)" \
  = 'root:root:755'
grep -F 'exec /usr/local/libexec/junglelaw-admin-dashboard-cert-renew deploy' \
  /etc/letsencrypt/renewal-hooks/deploy/junglelaw-admin-dashboard-cert-deploy
/usr/local/libexec/junglelaw-admin-dashboard-cert-renew initial
```

`renew` 模式只执行限定正式 lineage 的 `certbot renew --quiet --cert-name junglelaw-admin-ip`。Certbot 仅在真正续期时设置 `RENEWED_LINEAGE` / `RENEWED_DOMAINS` 并调用目录级 deploy hook；wrapper 过滤其他 lineage 后，`deploy` 模式严格核对 lineage 与 IP，只做校验、原子复制、服务重启和证书验证的健康检查，绝不调用 Certbot，因此不会递归。首次服务尚未启动时 `deploy` / `initial` 只暂存已验证证书，随后 `activate` 完成首次重启与健康验收。失败时 helper 恢复旧证书；签发或验证在替换前失败时旧证书完全不动。

## 3. 目录和最小权限

建议在部署准备阶段由管理员预先创建以下边界；具体 UID、GID 和路径必须与正式 profile 一致：

| 路径 | 所有者/权限意图 | 数据边界 |
|---|---|---|
| `/opt/junglelaw-admin/releases/<version>` | 根目录 `root:root 0755`，内部文件只读发布物 | 版本化源码与静态资源；服务账号只能遍历和读取，不能写入 |
| `/opt/junglelaw-admin/current` | 原子切换的只读符号链接 | 当前版本入口 |
| `/var/lib/junglelaw-admin-dashboard` | `junglelaw-admin:junglelaw-admin`, `0700` | 后台账号哈希、会话状态、审计日志 |
| `/var/lib/junglelaw/admin_exports` | `junglelaw:junglelaw-admin-read`, `2770` | `dashboard_snapshot.json`、`admin_accounts_snapshot.json` 脱敏投影 |
| `/var/lib/junglelaw/admin_commands/pending` | `junglelaw-admin:junglelaw-admin-command`, `2770` | 待执行、幂等的资源发放命令 |
| `/var/lib/junglelaw/admin_commands/processed` | `junglelaw:junglelaw-admin-command`, `2770` | 脱敏成功回执 |
| `/var/lib/junglelaw/admin_commands/failed` | `junglelaw:junglelaw-admin-command`, `2770` | 脱敏失败回执 |
| `/etc/junglelaw-admin-dashboard` | `root:junglelaw-admin`, `0750` | 环境文件与 TLS 文件，不属于发布物 |
| `/etc/junglelaw-admin-dashboard/tls` | `root:junglelaw-admin`, `0750` | 原子部署的 `privkey.pem` / `fullchain.pem`，文件均 `0640` |
| `/var/backups/junglelaw-admin-dashboard` | `root:root`, `0700` | staging 部署前备份、manifest 与 SHA-256；不得位于 `/opt/junglelaw-admin` 或 `/var/lib/junglelaw` 内 |

需要两个补充组：`junglelaw-admin-read` 用于共享脱敏快照，`junglelaw-admin-command` 用于生产者/消费者共享命令和回执。**禁止**把 `junglelaw-admin` 加入权威 `junglelaw` 组。目标机 `/var/lib/junglelaw` 只给该账号增加一条可回滚 POSIX ACL `user:junglelaw-admin:--x`，仅用于穿越到两个直接共享子目录；不得增加读权限、named-group ACL 或任何 default ACL。setgid 目录配合游戏服 drop-in 的 `UMask=0007`，确保新文件继承预期组并保持组读写；后台 unit 再通过 `ReadOnlyPaths` 把快照、`processed` 和 `failed` 挂为进程只读，只保留 `pending` 可写。只读预检必须同时证明后台可读两个投影、可写 `pending`，且不能列出 canonical `server` 目录、不能读取 `player_accounts.json`。目标缺少 `getfacl` / `setfacl` 时部署 fail closed。OpenClaw-ejrr 实测为 `getfacl 2.2.53`，数字 UID/GID 输出必须使用该版本支持的短参数 `-n`；禁止使用其不支持的 `--numeric-names`。两种写法语义等价，但发布门禁固定检查兼容写法，避免备份事务在停服窗口内因参数解析失败。

### 3.1 游戏服共享路径契约

现有 `junglelaw-server.service` 使用 Godot 默认 `user://` 路径且设置 `UMask=0077`，不能直接满足后台跨用户读取快照和消费命令的要求。不要编辑基础 unit；把 `junglelaw-server-admin-dashboard.conf.example` 作为 drop-in 安装。它固定设置：

```text
ZHANCHENG_DASHBOARD_SNAPSHOT_PATH=/var/lib/junglelaw/admin_exports/dashboard_snapshot.json
ZHANCHENG_DASHBOARD_ACCOUNT_SNAPSHOT_PATH=/var/lib/junglelaw/admin_exports/admin_accounts_snapshot.json
ZHANCHENG_DASHBOARD_COMMAND_ROOT=/var/lib/junglelaw/admin_commands
SupplementaryGroups=junglelaw-admin-read junglelaw-admin-command
UMask=0007
```

在获得 staging 主机写入授权后，管理员按正式 profile 核对用户和绝对路径，再准备 setgid 目录。下列命令的目标必须逐项解析为本节列出的路径，不得替换成宽泛目录：

```bash
getent group junglelaw-admin-read >/dev/null || groupadd --system junglelaw-admin-read
getent group junglelaw-admin-command >/dev/null || groupadd --system junglelaw-admin-command
usermod --append --groups junglelaw-admin-read,junglelaw-admin-command junglelaw
usermod --append --groups junglelaw-admin-read,junglelaw-admin-command junglelaw-admin

install -d -o junglelaw -g junglelaw-admin-read -m 2770 \
  /var/lib/junglelaw/admin_exports
install -d -o junglelaw -g junglelaw-admin-command -m 2770 \
  /var/lib/junglelaw/admin_commands
install -d -o junglelaw-admin -g junglelaw-admin-command -m 2770 \
  /var/lib/junglelaw/admin_commands/pending
install -d -o junglelaw -g junglelaw-admin-command -m 2770 \
  /var/lib/junglelaw/admin_commands/processed \
  /var/lib/junglelaw/admin_commands/failed
```

安装 drop-in 后必须先做静态验证，再 reload 并仅在 staging 重启游戏服：

```bash
install -d -o root -g root -m 0755 \
  /etc/systemd/system/junglelaw-server.service.d
install -o root -g root -m 0644 \
  /opt/junglelaw-admin/current/deploy/linux/junglelaw-server-admin-dashboard.conf.example \
  /etc/systemd/system/junglelaw-server.service.d/admin-dashboard.conf
systemd-analyze verify \
  /etc/systemd/system/junglelaw-server.service \
  /etc/systemd/system/junglelaw-admin-dashboard.service
systemctl daemon-reload
systemctl restart junglelaw-server.service
systemctl show junglelaw-server.service --property=UMask,Environment,SupplementaryGroups
systemctl cat junglelaw-server.service
```

重启后先确认游戏服已生成两个脱敏快照，且文件组分别为 `junglelaw-admin-read`、组位可读写；再运行第 6 节预检并启动后台。禁止为了绕过预检而把权威账号库复制到共享目录。

## 4. 版本化发布与 current 链接

每次发布生成不可变版本号，例如 Git commit 加 UTC 构建时间。产物先在本地通过测试，打包后生成 SHA-256；远端先校验 SHA-256，再解压到全新的：

```text
/opt/junglelaw-admin/releases/<version>
```

禁止覆盖旧 release，也禁止直接在 `current` 目录编辑。staging 步骤为：

1. 只读远端预检，记录当前 `current` 指向、服务状态、版本、磁盘、证书、端口、健康和最近错误日志。
2. 记录上一版本为 `<previous-version>`，完成第 5 节备份。
3. runtime-only ZIP 不包含 `tests/`。打包前必须在本地对同一份候选源码完成当前全部后台自动测试并全部通过，保存测试用例总数/通过数、完整输出、源码 HEAD、dirty overlay 清单；打包后把运行时 ZIP 的 SHA-256 与该测试证据绑定到同一发布回执。
4. 上传版本化 runtime-only ZIP、manifest 与 SHA-256 文件；校验后解压为 root 所有、运行用户只读的新 release。即使上传/解压暂存根为 `0700`，复制后的版本根也必须显式恢复为 `root:root 0755`，不能继承暂存根权限导致服务账号无法遍历。
5. 远端新 release 必须分别以 root 和实际 `junglelaw-admin` 服务账号运行 `node --check`、`node server.mjs --help`，并完成 manifest/文件哈希核对和隔离健康检查；服务账号至少要能遍历版本根并读取入口。`server.mjs` 的 CLI 入口身份必须比较 canonical realpath，使通过 `/opt/junglelaw-admin/current` 符号链接运行时仍真正进入 `serve` / `init-owner`，不能静默以 0 退出。不得从 runtime-only release 运行项目测试。只有另外提供、明确批准且与同一源码/制品哈希关联的 QA 测试包时，才允许在远端执行测试；QA 包不得混入 runtime release。
6. 使用同目录临时链接指向新 release，再以单文件原子重命名创建或替换 `/opt/junglelaw-admin/current`；首次部署允许 `current` 不存在，升级时必须是符号链接；保留旧 release。预检读取 owner/mode 时必须显式跟随 `current` 到真实版本根，不能把符号链接自身的 `0777` 当成 release 权限。
7. `systemctl daemon-reload`，启动或重启服务，立即执行第 7 节全部验收。
8. staging 全部通过并由制片人接受后，另行申请 production 推广授权；不得自动推广。

获得该环境写入授权后，原子切换必须先校验明确目标；不得把变量留空，也不得让 `current` 指向 release 根目录：

```bash
ADMIN_RELEASE_VERSION='<approved-version>'
case "${ADMIN_RELEASE_VERSION}" in
  ''|*[!A-Za-z0-9._-]*) printf '%s\n' 'invalid release version' >&2; exit 1 ;;
esac
ADMIN_RELEASE_TARGET="/opt/junglelaw-admin/releases/${ADMIN_RELEASE_VERSION}"
ADMIN_CURRENT_LINK='/opt/junglelaw-admin/current'
ADMIN_NEXT_LINK="/opt/junglelaw-admin/.current-${ADMIN_RELEASE_VERSION}.new"
test -d "${ADMIN_RELEASE_TARGET}"
if test -e "${ADMIN_CURRENT_LINK}" && ! test -L "${ADMIN_CURRENT_LINK}"; then
  printf '%s\n' 'current exists but is not a symlink' >&2
  exit 1
fi
test ! -e "${ADMIN_NEXT_LINK}"
ln -s "${ADMIN_RELEASE_TARGET}" "${ADMIN_NEXT_LINK}"
mv -T "${ADMIN_NEXT_LINK}" "${ADMIN_CURRENT_LINK}"
test "$(readlink -f "${ADMIN_CURRENT_LINK}")" = "${ADMIN_RELEASE_TARGET}"
```

`junglelaw-admin-dashboard.service.example` 与正式 profile 都固定使用 `/usr/bin/node`，installer 必须同时核对该绝对路径可执行且版本逐字为 `v24.14.0`，并执行 `server.mjs --check`、`server.mjs --help` 与 `systemd-analyze verify`；不得临时改用 PATH 中另一份 Node。先将环境模板安装为 `/etc/junglelaw-admin-dashboard/dashboard.env`，确认其中没有占位符和秘密，再安装 unit。

正式 staging 操作优先使用有检查收据的 helper，不能手工拆开后省略备份：

```bash
bash '<absolute-verified-extracted-release>/deploy/linux/install_junglelaw_admin_dashboard.sh' prepare \
  --release-version '<approved-version>' \
  --release-source '<absolute-verified-extracted-release>' \
  --node-archive '<absolute-approved-v1.3.0-runtime.zip>' \
  --node-manifest '<absolute-approved-v1.3.0-runtime.manifest.json>' \
  --expected-node-sha256 '<approved-v1.3.0-node-zip-sha256>' \
  --game-release-source '<absolute-verified-v1.3.0-game-bundle-directory>' \
  --game-archive '<absolute-JungleLawServer-v1.3.0-local-linux-rc1.tar.gz>' \
  --expected-game-archive-sha256 '<approved-v1.3.0-game-archive-sha256>' \
  --expected-game-sha256 5318144037F2F81A962C22510AB2764557ECA289534BC043B023789495E376F1 \
  --backup-root /var/backups/junglelaw-admin-dashboard \
  --authority-path '<read-only-baseline-resolved-player_accounts.json>' \
  --acme-webroot '<read-only-baseline-resolved-existing-nginx-webroot>' \
  --public-ip 106.15.61.103 \
  --dashboard-port 443 \
  --fisher-unit '<exact-read-only-observed-Fisher.service>' \
  --nginx-unit '<exact-read-only-observed-nginx.service>' \
  --authorize-state-directory-quarantine
```

helper 必须从已验签 Node release 自己的 `deploy/linux` 目录运行；执行中的 overlay 与 `--release-source/deploy/linux` canonical 路径不相同就拒绝。Node ZIP 的整体哈希、ZIP 内每个文件、外部 manifest 和解压目录必须四方一致。游戏 ELF、基础 unit、stop helper 和后台 drop-in 则全部来自已验签的 v1.3.0 游戏服 bundle；drop-in 必须命中 `12D08A7B47816517BEEE46EF1C0D939D49F796D692425A1F9E23709D5E3B0BF1`，不得从 Node overlay 混装。

`prepare` 记录 game/dashboard/cert timer 的 active 与 enabled 基线以及 cert-renew active 基线；按 cert timer → cert-renew → 后台的顺序停止后第一次检查 `pending`，再停止游戏服并第二次检查 `pending`，随后创建一致性备份。它再原子安装 v1.3.0 游戏 ELF/unit/stop helper/drop-in、Node release、续期 helper/timer、端口 drop-in 和无秘密环境文件；新游戏服只启动一次。`--authorize-state-directory-quarantine` 是失败自动恢复的强制门禁：只有已校验的 exact receipt 可把当前完整状态目录移动到 root-only quarantine，绝不删除。它不会初始化 Owner、不会签发证书、不会开放云防火墙、不会改 nginx，也不会启动后台。

`prepare` 成功后，先用已固定为 Certbot `5.7.0` 的虚拟环境签发正式短期 IPv4 证书。测试 lineage `junglelaw-admin-ip-staging` 只能证明 HTTP-01 通路，证书标记为 `TEST_CERT`，不得复制到后台或计入 HTTPS 验收。正式签发必须使用生产 ACME endpoint、`shortlived` 必需 profile、现有 nginx webroot 和独立 lineage `junglelaw-admin-ip`；不得使用 `--staging`、`--test-cert`、`--dry-run`、`--no-verify-ssl` 或任何 TLS 绕过参数：

```bash
/opt/junglelaw-admin-certbot/venv/bin/certbot certonly \
  --non-interactive \
  --agree-tos \
  --register-unsafely-without-email \
  --webroot \
  --webroot-path /usr/share/nginx/html \
  --ip-address 106.15.61.103 \
  --cert-name junglelaw-admin-ip \
  --required-profile shortlived \
  --preferred-challenges http \
  --key-type ecdsa \
  --elliptic-curve secp256r1
```

Certbot 成功后，必须用 `certbot certificates` 与 `openssl x509 -noout -issuer -dates -fingerprint -sha256 -ext subjectAltName` 确认 lineage 不是 `TEST_CERT`、SAN 精确包含 `106.15.61.103` 且剩余有效期大于 24 小时。`prepare` 已安装的目录级 deploy hook 会调用续期 helper 的 `deploy` 模式；仍应显式运行一次 `initial`，确认 root-owned TLS 副本与正式 lineage 一致。随后必须在真实 TTY 中初始化 Owner，运行：

```bash
/usr/local/libexec/junglelaw-admin-dashboard-cert-renew initial
bash deploy/linux/install_junglelaw_admin_dashboard.sh activate
```

`activate` 先运行只读预检，再启动后台并把本机连接重定向到 loopback、同时仍按 `106.15.61.103` 验证证书的 `/api/health`；只有成功后才启用每天 UTC 00:00/12:00 两次检查、随机延迟不超过 1 小时的续期 timer。先完成这一步，最后才新增 SWAS/主机防火墙的公网 8443 规则并做真实外部访问。若外部登录、限速或安全验收失败，立即撤销新规则或停止后台。任何阶段都保存 `prepare` 输出的绝对 backup receipt 路径。

### 4.1 条件批准的标准 443 回退路径

systemd 239 支持 `AmbientCapabilities` 和 `CapabilityBoundingSet`。profile 已把 TCP 443 限定批准为“8443 真实外网探测失败后”的回退；只有该条件被证据满足时，才能重跑同一 transaction helper 并显式传 `--dashboard-port 443`。helper 会把已经哈希核对的 `junglelaw-admin-dashboard-public-443.conf.example` 安装为**单独 drop-in**，其中只允许：

```ini
[Service]
Environment=ZHANCHENG_DASHBOARD_PORT=443
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
```

不得把服务用户改为 root，不得增加其他 capability。443 方案的进程可绑定任何空闲的低位端口，因此验收必须额外确认 `ss -lntp` 只有批准的 443；未获批准前基础 unit 继续保留空 `CapabilityBoundingSet=` / `AmbientCapabilities=`，正式默认仍是可由环境文件配置的 8443。

helper 在 443 transaction 中同时写入 `JUNGLELAW_CERT_HEALTH_PORT=443`、备份/恢复 drop-in，并重跑 Unknown-lvalue 门禁；8443 transaction 必须确认该 capability drop-in 不存在。禁止手工只改其中一项。`activate` 和续期 helper 都从该配置读取验收端口，不在脚本里固定 8443。基础 `dashboard.env` 仍可保留 8443，因为 drop-in 的 systemd `Environment=` 会显式覆盖它。

## 5. 备份与恢复

每次切换前创建带 UTC 时间与版本号的只读备份清单，并计算 SHA-256。最小备份范围：

- `/var/lib/junglelaw-admin-dashboard` 的认证状态和审计日志；
- `pending`、`processed`、`failed` 三个命令目录及其权限/所有者元数据；
- 当前环境文件以及受保护的完整 `/etc/junglelaw-admin-dashboard/tls`；该副本包含 TLS 私钥，必须与 receipt 一样保持 `root:root`、`0700/0600` 边界，禁止输出正文或移出批准备份域；
- 当前 release 版本、`current` 链接目标、systemd unit、Node 版本和证书指纹；
- 游戏服 `/opt/junglelaw/JungleLawServer.x86_64`、基础 unit、同步 stop helper 和后台 drop-in；
- 由只读远端基线解析出的整个 canonical `user://server` 状态目录，包括 `player_accounts.json`、`match_analytics.json`、`dashboard_snapshot.json` 与迁移 sidecar；逐文件哈希、owner/mode、递归 ACL 和 tar ACL/xattr 都进入 root-only receipt，不输出内容。只传单个账号文件的备份不合格。
- `/var/lib/junglelaw` 修改前的 numeric POSIX ACL，以及 game/dashboard/cert timer 的 active/enabled 基线；首次部署不存在的 unit 和 wants symlink 也必须恢复为 absent。

备份包含权威账号、密码哈希、会话状态、TLS 私钥和审计记录，必须使用 `root:root`、`0700` 的 profile 批准目录和最小保留期；若后续复制到对象存储必须先采用批准的服务端加密。备份禁止放进 release 或 `/var/lib/junglelaw`。`prepare` 先停 cert timer、cert-renew、后台，检查 `pending`，再停游戏服并再次检查 `pending`，使权威数据通过同步停服契约落盘；四个 unit 都确认 inactive 后才创建 `tar --acls --xattrs --numeric-owner`、逐文件/owner/mode/xattr 哈希、递归 ACL receipt 和隔离 archive 回放校验。任何停服、tar、清单、哈希、ACL、回放或安装失败都由 ERR transaction trap 用 exact receipt 恢复受管组件及部署前 enabled/active 状态；状态目录只通过显式授权的 root-only quarantine 移动后恢复，绝不删除。

每个受管路径都在 manifest 中记录 `present` / `absent`。因此第一次部署前不存在的 `current`、后台 unit/helper/timer 和 drop-in 能作为精确无状态文件恢复为 absent；`ADMIN_STATE`、`COMMAND_ROOT`、`EXPORT_ROOT`、后台 TLS/config、Certbot lineage 以及 canonical server 等含账号、审计、命令或私钥的数据路径一律移动到 exact backup 下的 root-only 唯一 quarantine，绝不递归删除。新 release 与 quarantine 都保留作取证；首次创建的服务用户/组可以保留，不能为了表面清理而删除可能已被其他文件引用的 UID/GID。

`prepare` 返回 backup receipt 绝对路径后，至少保存以下只读复核证据；不要输出 tar 内容中的文件正文：

```bash
ADMIN_BACKUP_RECEIPT='<absolute-receipt-from-prepare>'
test -f "${ADMIN_BACKUP_RECEIPT}/manifest.tsv"
test -f "${ADMIN_BACKUP_RECEIPT}/payload.tar"
test -f "${ADMIN_BACKUP_RECEIPT}/payload.tar.sha256"
(cd "${ADMIN_BACKUP_RECEIPT}" && sha256sum --check payload.tar.sha256)
tar --list --file "${ADMIN_BACKUP_RECEIPT}/payload.tar" >/dev/null
test -f "${ADMIN_BACKUP_RECEIPT}/server-tree.tsv"
test -f "${ADMIN_BACKUP_RECEIPT}/server-tree.acl"
test -f "${ADMIN_BACKUP_RECEIPT}/junglelaw-root.acl"
test -f "${ADMIN_BACKUP_RECEIPT}/shared-host.fingerprint"
test -f "${ADMIN_BACKUP_RECEIPT}/receipt.sha256"
(cd "${ADMIN_BACKUP_RECEIPT}" && sha256sum --check receipt.sha256)
grep -E '^(backup_id|release_version|game_was_active|dashboard_was_active|game_was_enabled|dashboard_was_enabled|cert_timer_was_active|cert_timer_was_enabled|authority_sha256|game_elf_sha256)\t' \
  "${ADMIN_BACKUP_RECEIPT}/manifest.tsv"
```

receipt 是敏感元数据，不能发到公开日志。恢复演练先复制 receipt 到 profile 指定的隔离目录并核对清单、所有者、权限、账号状态和幂等记录；正式 `rollback` 只能在明确传入 receipt 路径并逐字确认 manifest 的 `backup_id` 后运行。

## 6. 只读预检

安装目录与权限准备完成后，在启动服务前执行：

```bash
sudo bash /opt/junglelaw-admin/current/deploy/linux/admin_dashboard_preflight.sh
```

脚本只检查用户/专用补充组、明确禁止的 `junglelaw` 成员关系、最小 traverse ACL、无 default ACL、权威目录不可读、游戏服 drop-in 的三个绝对路径、`SupplementaryGroups`、`UMask=0007`、setgid/文件组读写、后台只读挂载、端口/capability 一致性、短期 TLS SAN 与剩余寿命、Node 入口语法和四个 systemd unit/timer，不创建文件、不修改权限、不启动服务。必须保存完整输出；任何 `FAIL` 均阻止 staging 启动。

OpenClaw-ejrr 当前为 systemd 239。基础后台 unit 已移除该版本不支持的 `ProtectClock`、`ProtectHostname`、`ProtectKernelLogs`、`ProtectProc`、`ProcSubset`、`RestrictSUIDSGID`，并保留 239 可用的 `NoNewPrivileges`、`PrivateDevices`、`ProtectSystem=strict`、内核/控制组保护、namespace/address-family 限制和空 capability 集。installer 与 preflight 都捕获 `systemd-analyze verify` 的完整输出；即使命令退出码为 0，只要出现 `Unknown lvalue`、`Unknown key name` 或 `Unknown assignment` 也会失败。不得静默忽略 warning 后启动。

Let's Encrypt IP 证书约 6 天有效，不能再使用“剩余 7 天”门禁；本 overlay 要求剩余至少 24 小时，并由每天两次、每次随机延迟最多 1 小时的 timer 检查。timer 未启用、上次失败、下一次触发晚于证书到期或续期日志不可达都阻止验收。

## 7. staging 验收

以下证据缺一不可：

1. **版本与服务**：`readlink -f /opt/junglelaw-admin/current` 指向本次版本；`systemctl is-active junglelaw-admin-dashboard.service` 为 active；journal 中记录正确版本且没有重复崩溃。
2. **TLS 与端口**：从服务器本机和一台真实公网外部客户端分别检查 `106.15.61.103` 的 IP SAN、完整证书链、到期日和 HTTPS 响应；`ss -lntp` 只出现 profile 批准的 `0.0.0.0:8443`（或后续单独批准的 443），不存在后台裸 HTTP。
3. **健康**：`GET https://106.15.61.103/api/health` 返回预期状态。不得用 `-k` / `--insecure` 绕过证书校验。
4. **公网访问**：独立公网网络可打开登录页并完成登录；阿里云安全组/SWAS 防火墙与主机防火墙只新增本项目批准的 TCP 443 `0.0.0.0/0`，不得放宽 SSH、UDP 游戏端口或同机其他服务。保存变更前后规则证据。
5. **登录与权限**：Owner 可登录；错误密码被拒绝并触发限速；Analyst 无法执行 Owner 操作；cookie、CSRF 和 Origin 防护与自动测试一致。
6. **数据读取**：动物平均名次、平衡提示、全部脱敏阵容可见；后台进程没有读取 `player_accounts.json` 的权限。
7. **资源发放**：仅在存在明确标识的 staging 测试账号时执行一次指定账号发放；记录命令 ID，验证 `pending -> processed`、数量、目标范围、审计日志和重复提交幂等。全账号发放只做非变更合同检查（Owner 密码复验与精确 `SEND TO ALL`），不得向真实玩家批量发放。
8. **持久化**：记录 Owner 登录、审计条目和测试命令 ID；重启后台服务后再次登录并核对数据不丢失；重启游戏服务后确认命令不会重复消费。
9. **服务级持久化**：只重启 JungleLaw 游戏服和后台服务，确认二者恢复、TLS/健康正常、账号状态和幂等记录保持一致。OpenClaw-ejrr 是共享主机，本次授权禁止主机 reboot，不能影响 Fisher/OpenClaw。
10. **日志与监控**：journal、健康告警、证书到期/续期失败告警、磁盘告警、失败命令告警可到达 profile 记录的责任人，日志中没有密码、token、cookie、私钥或完整账号数据；`systemctl list-timers` 显示续期 timer 的最近/下次触发。
11. **共享主机不变证据**：在 transaction 前后分别保存 Fisher 与 nginx 的实际 unit 名、MainPID/启动时间、`systemctl cat` 哈希、配置文件清单哈希和监听端口。Fisher 的 UDP 24568、nginx 的 TCP 80/PID/config 必须逐项一致；overlay 不编辑、不 reload、不 restart 这两个服务。目标 unit 名只能来自只读基线，不得猜测。

游戏服验收还必须保存 `systemctl show junglelaw-server.service --property=UMask,Environment,SupplementaryGroups` 和 `systemctl cat junglelaw-server.service` 的输出，证明 daemon-reload 后实际生效的是三个共享路径、两个补充组和 `UMask=0007`，而不是只把 drop-in 文件放到了磁盘。

外部客户端验收必须真实经过阿里云入口；localhost、进程 PID、静态截图或单次退出码不能替代该证据。

服务端的只读检查命令如下；IP 和端口必须逐字匹配正式 profile，也禁止给 curl 添加 `-k`：

```bash
ADMIN_CHECK_IP='106.15.61.103'
ADMIN_CHECK_PORT='443'
systemctl show junglelaw-admin-dashboard.service \
  --property=ActiveState,SubState,ExecMainStatus,NRestarts
systemctl show junglelaw-admin-dashboard-cert-renew.timer \
  --property=ActiveState,SubState,LastTriggerUSec,NextElapseUSecRealtime
readlink -f /opt/junglelaw-admin/current
journalctl --unit junglelaw-admin-dashboard.service --since '-15 minutes' --no-pager
systemctl list-timers junglelaw-admin-dashboard-cert-renew.timer --no-pager
ss -lntp
openssl s_client \
  -connect "${ADMIN_CHECK_IP}:${ADMIN_CHECK_PORT}" \
  -verify_return_error </dev/null
curl --fail --silent --show-error \
  "https://${ADMIN_CHECK_IP}:${ADMIN_CHECK_PORT}/api/health"
```

同一条不带 `-k` 的 curl 命令必须在一台不属于服务器局域网的真实外部客户端上成功。另用内置浏览器打开公网链接并完成登录；两次测试都记录 UTC 时间、源出口 IP、阿里云地址、证书指纹和返回结果。公网可连接是本次明确验收目标，不再把 allowlist 外连接失败作为 staging 条件。

持久化/重启检查使用一个专门 staging Owner 和测试玩家：

1. 登录后记录一个既有审计条目 ID；仅当存在明确 staging 测试玩家时，提交一个指定账号的唯一资源命令 ID并等待其进入 `processed`。
2. 记录三个命令目录清单及 `dashboard_admin_state.json` 的 SHA-256，不输出文件内容。
3. 在批准维护窗口执行 `systemctl restart junglelaw-admin-dashboard.service`，重跑服务、TLS、健康和外部登录检查；确认同一 Owner、审计 ID、命令 ID 仍可见。
4. 重启游戏服务，确认该命令 ID 不会再次增加资源，且不会重新出现在 `pending`。
5. 不执行共享主机 reboot；保存 game/admin 两个 service restart 后的外部登录、状态哈希和幂等证据，主机级 reboot 验收明确列为本次范围外。

## 8. 回滚

触发条件包括健康失败、TLS/端口错误、登录失败、数据投影异常、权限越界、命令重复或持久化失败。回滚顺序：

1. 停止新的管理操作并记录最后一个命令 ID；若存在 `pending`，先冻结队列并人工核对，不能删除或重复提交。
2. 将临时链接指向 `<previous-version>`，用原子重命名恢复 `current`，再重启后台服务。
3. 检查旧版本是否兼容当前认证状态和命令格式。若不兼容，停止服务，按第 5 节已演练步骤恢复对应备份；禁止猜测性降级数据库或手工改 JSON。
4. 重跑 TLS、健康、登录、数据读取、幂等、服务重启和外部客户端检查。
5. 保留失败 release、journal、命令 ID 和脱敏差异用于复盘；只有健康恢复且未产生重复资源后才宣布回滚完成。

回滚证据必须记录恢复的版本、`current` 目标、服务状态、健康结果、外部客户端结果、持久化结果和命令队列状态。

正式回滚优先使用 `prepare` 生成的 receipt。命令需要逐字确认 manifest 中的 backup ID，防止选错备份：

```bash
ADMIN_BACKUP_RECEIPT='<absolute-receipt-from-prepare>'
ADMIN_BACKUP_ID="$(awk -F '\t' '$1 == "backup_id" {print $2}' \
  "${ADMIN_BACKUP_RECEIPT}/manifest.tsv")"
bash deploy/linux/install_junglelaw_admin_dashboard.sh rollback \
  --backup-dir "${ADMIN_BACKUP_RECEIPT}" \
  --confirm-backup-id "${ADMIN_BACKUP_ID}" \
  --authorize-state-directory-quarantine
```

`rollback` 在任何服务变更前同时要求 exact receipt、逐字 backup ID 和显式 `--authorize-state-directory-quarantine`。它先完整校验 archive 并创建隔离 restore stage，再按 cert timer → cert-renew → 后台 → pending 复核 → 游戏服 → pending 二次复核的顺序冻结。当前 canonical `server`、后台状态/命令/导出/TLS 与 Certbot lineage 都移动到 exact backup 下唯一、`root:root 0700` 的 quarantine，**绝不删除**；只有无状态 unit/helper/drop-in/symlink 可按 manifest 精确替换或移除。随后恢复原 `/var/lib/junglelaw` ACL、unit enabled/active 状态并按部署前状态各启动一次。缺少 flag 或 backup ID 不一致时不得停止服务、移动目录或修改任何路径；任何哈希或启动失败都保持 `NOT READY`，保留 quarantine、restore stage 与失败现场，不得手工修改权威 JSON 绕过。

只有升级场景且确认认证/命令 schema 向后兼容时，才可不恢复数据而使用已记录的明确旧版本原子切换：

```bash
ADMIN_ROLLBACK_VERSION='<previous-approved-version>'
case "${ADMIN_ROLLBACK_VERSION}" in
  ''|*[!A-Za-z0-9._-]*) printf '%s\n' 'invalid rollback version' >&2; exit 1 ;;
esac
ADMIN_ROLLBACK_TARGET="/opt/junglelaw-admin/releases/${ADMIN_ROLLBACK_VERSION}"
ADMIN_CURRENT_LINK='/opt/junglelaw-admin/current'
ADMIN_ROLLBACK_LINK="/opt/junglelaw-admin/.rollback-${ADMIN_ROLLBACK_VERSION}.new"
test -d "${ADMIN_ROLLBACK_TARGET}"
test -L "${ADMIN_CURRENT_LINK}"
test ! -e "${ADMIN_ROLLBACK_LINK}"
ln -s "${ADMIN_ROLLBACK_TARGET}" "${ADMIN_ROLLBACK_LINK}"
mv -T "${ADMIN_ROLLBACK_LINK}" "${ADMIN_CURRENT_LINK}"
test "$(readlink -f "${ADMIN_CURRENT_LINK}")" = "${ADMIN_ROLLBACK_TARGET}"
systemctl restart junglelaw-admin-dashboard.service
systemctl is-active --quiet junglelaw-admin-dashboard.service
```

随后必须重新执行第 7 节的服务、TLS、健康、外部访问、登录、数据、幂等与持久化检查；不能只以 `systemctl is-active` 宣布回滚成功。

## 9. 专用服同步停服契约与信任边界

专用服的版本化服务端制品必须把下列文件与同一源码版本、manifest 和 SHA-256 回执绑定；不得只上传 Godot ELF：

- `junglelaw-server.service`；
- `junglelaw-server-stop.sh`；
- `install_junglelaw_server.sh`；
- 对应版本的 `JungleLawServer.x86_64`。

目标 Linux 必须提供绝对路径 `/usr/bin/python3`，版本不低于 3.6。installer、unit 的 `ExecStartPre` 和只读 preflight 会分别检查该依赖。正式 profile 仍须记录 Python、systemd 的实际版本；没有 profile、备份、回滚和 staging 写入授权时维持 `NOT READY`。

停服控制根固定为 `/run/junglelaw`，由 systemd 以专用服用户拥有并强制 `0700`。运行时通过原子创建 `junglelaw-server.shutdown` 目录取得唯一 session；`owner_token` 和 `ready.json` 只在该已独占目录中发布。stop helper 只在这个信任边界内读取严格 JSON，并用同文件系统 hardlink 以 no-replace 方式提交 `request.json`。该模型不把 root 或另一个已经取得专用服同一 UID 的恶意进程视为隔离对象；这类权限本身已经等同于专用服 authority 被攻破。纯 GDScript 的 `_write_json_new` 在此边界内属于 P2 防御纵深，不作为当前发布阻断；不得把该结论扩大到共享目录或不同 UID 可写的控制根。

同步 `ExecStop` 必须等待 `MAINPID` 退出，并验证固定结果 `junglelaw-server.shutdown-result.json` 的 `pid`、64 位十六进制 token、`ok=true`、`exit_code=0` 和 `reason=graceful_shutdown_complete`，同时确认同名 `.previous` 不存在。成功返回 0；I/O、等待或结果失败返回 74；配置/契约失败返回 78。unit 使用 `RuntimeDirectoryPreserve=yes` 和 `RestartPreventExitStatus=74 78` 保留失败现场并阻止自动重启循环。

stop helper 绝不发送信号，也绝不删除 authority lock、control session、request、ready、owner token 或结果文件。失败时必须保留现场、停止晋级并人工审计；不得为了让服务重新启动而直接删除残留锁。只有正式事故处置流程确认进程已不存在、PID/token/文件所有权一致、权威数据已备份且获批后，才能另行处理残留状态。

本地只读/临时验证入口为：

```bash
bash deploy/linux/test_junglelaw_server_deploy.sh
```

该脚本执行 Bash 语法、Python 版本、unit 契约、`systemd-analyze verify` 和故障矩阵；它不是阿里云 staging 的停服、持久化、重启或外部验收证据。
