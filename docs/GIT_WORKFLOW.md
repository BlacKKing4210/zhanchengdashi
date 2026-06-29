# Git 工作流

## 远程仓库

SSH 地址：

```text
git@github.com:BlacKKing4210/zhanchengdashi.git
```

默认主分支：

```text
main
```

## 推荐分支

- `main`：稳定主线，保持可运行。
- `dev`：日常集成分支，可选。
- `feature/<topic>`：功能开发。
- `fix/<topic>`：缺陷修复。
- `content/<topic>`：配置、关卡、文本、数值内容。

## 提交建议

提交信息保持短句动词开头：

```text
chore: initialize project foundation
config: add base unit and skill tables
docs: add config workflow
fix: correct drop pool references
```

## 常用命令

```powershell
git status
git add .
git commit -m "chore: initialize project foundation"
git push -u origin main
```

## 推送前检查

```powershell
python tools/validate_config.py
python tools/export_config.py
# Windows py launcher alternative:
py -3 tools/validate_config.py
py -3 tools/export_config.py
git status
```

如果 `runtime/config/` 因配置表变化而更新，需要一起提交。
