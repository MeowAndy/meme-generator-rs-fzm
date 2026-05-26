# meme-generator-rs-fzm 🐺🎭

一套面向 **Yunzai / TRSS-Yunzai / 清语表情 meme-plugin** 的可部署表情包 API 方案。

它不是简单 clone 某个项目，而是把今天实战部署的一整套服务整理成可复用工程：

- ✅ `meme-generator-rs` 原生 API 服务
- ✅ 兼容旧版 `meme-plugin` 的 `/memes/*` API 代理
- ✅ 支持本机 Rust 表情库 + 旧 pippi 服务 fallback
- ✅ 支持扩展 `.so` 表情库，例如 `meme-emoji`
- ✅ 支持后续实时/定时更新扩展表情库
- ✅ systemd 一键部署
- ✅ Docker / Compose 示例
- ✅ 面向小白的部署与接入教程

---

## 1. 服务架构

```text
外部 meme-plugin / 清语表情
        │
        │ 旧接口：/memes/keys /memes/{key}/info /memes/{key}/
        ▼
兼容代理 meme-compat-proxy  :2234
        │
        ├─ 优先调用本机 Rust API :2233
        │
        └─ 本机没有的 key fallback 到 https://meme.pippi.top/pippi

Rust 原生 meme-generator-rs API :2233
        │
        ├─ 内置 meme-generator-rs 表情
        └─ 动态加载 data/libraries/*.so 扩展库，例如 meme-emoji
```

---

## 2. 对外应该给哪个地址？

### 给 Yunzai / 清语表情 meme-plugin 用户

给这个：

```text
http://你的服务器IP:2234
```

配置：

```yaml
url: 'http://你的服务器IP:2234'
```

然后让对方在机器人里执行：

```text
#清语表情更新资源
```

### 给开发者 / 新版 meme-generator-rs 原生 API 用户

给这个：

```text
http://你的服务器IP:2233
```

常用接口：

```text
GET  /meme/version
GET  /meme/keys
GET  /meme/search?query=关键词
GET  /memes/{key}/info
POST /memes/{key}/preview
POST /memes/{key}
GET  /image/{image_id}
```

---


## Windows 原生部署

Windows 用户请看：

```text
docs/WINDOWS.md
```

快速安装：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-windows.ps1
```

启动：

```powershell
powershell -ExecutionPolicy Bypass -File C:\meme-api\start-windows.ps1
```

检查：

```powershell
powershell -ExecutionPolicy Bypass -File C:\meme-api\check-windows.ps1
```

Windows 扩展库使用 `.dll`，例如 `meme-emoji-windows-x86_64.dll`；Linux 的 `.so` 不能直接在 Windows 使用。

---

## 3. 一键部署 systemd 版

### 系统要求

- Ubuntu 22.04 / 24.04 或 Debian 12+
- root 权限
- systemd
- curl / unzip / python3

### 部署

```bash
git clone https://github.com/MeowAndy/meme-generator-rs-fzm.git
cd meme-generator-rs-fzm
sudo bash scripts/install-systemd.sh
```

默认会部署到：

```text
/opt/meme-api
```

默认监听：

```text
原生 API: 0.0.0.0:2233
兼容代理: 0.0.0.0:2234
```

> 注意：如果只想本机 Yunzai 使用，可把兼容代理改成 `127.0.0.1:2234`。如果要给别人用，需要监听 `0.0.0.0:2234` 并放行防火墙端口。

### 查看状态

```bash
systemctl status meme-api.service
systemctl status meme-compat-proxy.service
```

### 测试

```bash
curl http://127.0.0.1:2233/meme/version
curl http://127.0.0.1:2234/memes/keys | python3 -m json.tool | head
curl http://127.0.0.1:2234/memes/petpet/info | python3 -m json.tool
```

---

## 4. 接入清语表情 meme-plugin

编辑：

```text
/root/Yunzai/plugins/meme-plugin/config/config/server.yaml
```

改成：

```yaml
# 自定义表情包服务地址
url: 'http://你的服务器IP:2234'

# 请求最大重试次数
retry: 3

# 请求超时时间
timeout: 15
```

然后在 QQ 群里执行：

```text
#清语表情更新资源
```

验证：

```text
#清语表情列表
#清语表情搜索 撅
#清语表情详情 撅
撅 @某人
```

---

## 5. 更新扩展表情库

本项目支持把扩展库 `.so` 放到：

```text
/opt/meme-api/data/libraries/
```

例如：

```text
/opt/meme-api/data/libraries/meme-emoji-linux-x86_64.so
```

然后重启：

```bash
systemctl restart meme-api.service
```

### 一键更新扩展库

```bash
sudo bash scripts/update-libraries.sh
```

它会：

1. 从配置的 release URL 下载扩展库；
2. 校验文件存在；
3. 替换到 `data/libraries/`；
4. 重启 `meme-api.service`；
5. 验证 `/meme/keys` 数量。

### 定时更新

安装 systemd timer：

```bash
sudo bash scripts/install-library-updater-timer.sh
```

默认每天凌晨 04:20 自动检查/更新扩展库。

---

## 6. 字体问题：帮助图全是框框怎么办？

如果 `#清语表情帮助` 出来的图全是 □□□，说明服务器缺中文字体。

Ubuntu/Debian 安装：

```bash
sudo apt-get update
sudo apt-get install -y fonts-noto-cjk fonts-wqy-zenhei fonts-wqy-microhei
sudo fc-cache -fv
```

然后重启 Yunzai：

```bash
tmux kill-session -t yz
cd /root/Yunzai && tmux new-session -d -s yz 'node .'
```

验证字体：

```bash
fc-match 'Noto Sans CJK SC'
fc-match sans-serif:lang=zh-cn
```

---

## 7. 常见问题

### Q1：`#清语表情更新资源` 报 notNull Violation

典型报错：

```text
notNull Violation: meme.min_texts cannot be null
notNull Violation: meme.max_texts cannot be null
notNull Violation: meme.min_images cannot be null
notNull Violation: meme.max_images cannot be null
```

原因：旧 `meme-plugin` 需要 `params_type` 字段，而新版 Rust API 返回 `params`。  
解决：使用本项目的 `2234` 兼容代理，不要直接把 `2233` 填进旧插件。

### Q2：`撅` 没反应？

`撅` 通常需要目标图片或目标用户，例如：

```text
撅 @某人
```

或者回复一张图再发：

```text
撅
```

### Q3：为什么有些表情本机没有？

兼容代理会优先走本机 Rust API；如果本机没有这个 key，会 fallback 到旧 pippi API。这样可以兼容更多旧表情。

### Q4：怎么确认更新真的完成？

```bash
sqlite3 /root/Yunzai/plugins/meme-plugin/data/data.db 'select count(*) from meme;'
sqlite3 /root/Yunzai/plugins/meme-plugin/data/data.db 'select count(*) from meme where min_texts is null or max_texts is null or min_images is null or max_images is null;'
curl -s http://127.0.0.1:2234/memes/keys | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))'
```

正常情况：

```text
本地 DB 数量 == API keys 数量
null 参数行数 == 0
```

---

## 8. 项目结构

```text
meme-generator-rs-fzm/
├── proxy/
│   └── meme_compat_proxy.py
├── scripts/
│   ├── install-systemd.sh
│   ├── update-libraries.sh
│   ├── install-library-updater-timer.sh
│   └── check.sh
├── systemd/
│   ├── meme-api.service
│   ├── meme-compat-proxy.service
│   ├── meme-library-updater.service
│   └── meme-library-updater.timer
├── docker/
│   ├── Dockerfile.proxy
│   └── docker-compose.yml
├── config/
│   ├── config.toml
│   └── libraries.env
├── examples/
│   └── meme-plugin-server.yaml
└── docs/
    ├── TODAY_SUMMARY.md
    └── API.md
```

---

## 9. 鸣谢

- [MemeCrafters/meme-generator-rs](https://github.com/MemeCrafters/meme-generator-rs)
- [meme-generator-contrib-rs](https://github.com/MemeCrafters/meme-generator-contrib-rs)
- [meme-emoji](https://github.com/anyliew/meme-emoji)
- 清语表情 / meme-plugin 生态

本仓库主要提供面向 Yunzai 生态的部署、兼容、运维与扩展整理。
