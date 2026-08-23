# F-ZC-ADMIN-001 v1.3.1 只读诊断与执行回执

- Request ID: `REQ-20260823-ADMIN-DASHBOARD-V1.3.1-GRANT-CTA-PLAYER-NAME`
- Feature ID: `F-ZC-ADMIN-001`
- Version: `v1.3.1-aliyun-staging`
- Date: `2026-08-23`
- Producer: `user-producer`
- Accountable owner: `codex-primary`
- Target: Alibaba Cloud staging `OpenClaw-ejrr`, JungleLaw admin Node overlay only
- RAG: `READY`, receipt `temp/rag/receipts/tasks/REQ-20260823-ADMIN-DASHBOARD-V1.3.1-GRANT-CTA-PLAYER-NAME.json`
- Control plane: `READY / L3`, fingerprint `64B5AC2EF46099BDCCE4660DDDABD5BA2BFF73C7B4F2A87D6AB7EC7D00CAF02D`

## 制作人请求

制作人要求检查资源发放按钮为何在当前页面不可见，并要求玩家页面显示可识别的玩家名称，便于在资源页选择目标。输入截图 SHA-256 为 `350426A726A65DD568CB34B71DBE0C09DCA16C8F98150F7FA56FA09B1348D026`。

## 只读诊断

1. `renderGrants()` 先渲染完整玩家选择面板，资源表单与主按钮在其后；玩家表内部又设置 `max-height: 440px`。在截图分辨率下，主按钮落在首屏下方，且页面滚动与表格内部滚动叠加，因此用户合理地认为“没有发放按钮”。
2. 线上账号快照有 30 行，但只包含 `user_id`、`masked_account`、段位、阵容与资源等字段；30 行均无 `username` / `display_name`。脱敏账号统一显示为 `device-account`，无法帮助区分玩家。
3. 本地更新后的游戏服投影合同已经允许白名单字段 `username`，但当前 Node 清洗器会丢弃该字段，前端搜索和身份展示也不读取它，构成第二个显示断点。
4. 线上权威账号文件版本 3、30 条记录，当前没有用户名字段；其 SHA-256 为 `c1fc9cbe4813d2aeb0d264f9e07c2cede959bf66beec4fe13870f75c8af63594`。本次只读检查没有输出账号、密码哈希、安装 ID 或任何玩家值。

## 已批准的最小修复合同

1. 资源发放主操作卡与玩家表在桌面并列，操作卡保持可见；窄屏把操作卡放在玩家表之前。主按钮始终显示，并在未选择玩家时明确禁用，而不是藏到表格之后。
2. 资源选择表只保留决策所需列：选择、玩家名称、完整玩家 ID、段位/Elo、抽卡券、阵容卡数。完整 ID 继续显示，低优先级数据仍保留在角色页或账号投影中。
3. Node 只白名单清洗 `username`，绝不暴露登录 `account`。前端优先显示用户名；快照未提供用户名时，基于 user_id 生成稳定的 `新玩家XXXX` 展示回退，并明确标记为系统临时名称。
4. 角色、阵容和资源页搜索均支持玩家名称、完整 user_id 与脱敏账号；角色页列名改为“玩家名称 / ID”。
5. 本任务只部署 Node 后台叠层，不部署账号身份游戏服、不迁移或写回线上权威账号，也不执行真实资源发放。真实用户名会在未来获得独立授权的游戏服投影升级后自动替换临时名称。

## 验收边界

- 自动测试覆盖用户名白名单/凭据不泄露、名称搜索标记、首屏操作区结构、主按钮禁用状态、多选合同与响应式布局。
- 浏览器证据必须同时看见玩家表、玩家名称、资源输入和发放按钮；不得通过真实提交来证明按钮存在。
- 阿里云 staging 部署前备份当前 Node release、状态与共享宿主机指纹；部署后验证 TLS、登录保护、静态标记、服务重启、日志与三类命令队列仍为零。
- Production、账号权威迁移、游戏服二进制、人物头像与真实资源到账均不在本任务授权范围内。

结论：`READY FOR LOCKED IMPLEMENTATION AND NODE-ONLY STAGING DEPLOYMENT`。
