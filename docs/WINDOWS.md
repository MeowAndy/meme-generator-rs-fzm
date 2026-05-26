# Windows 部署教程

本教程适合 Windows Server / Windows 10 / Windows 11。

> 如果你只是给 Yunzai / 清语表情 `meme-plugin` 用，最终要填的是兼容代理地址：
>
> ```text
> http://你的服务器IP:2234
> ```

---

## 1. 准备环境

需要：

- PowerShell 5.1+
- Python 3
- 可以访问 GitHub release

安装 Python：

```text
https://www.python.org/downloads/windows/
```

安装时建议勾选：

```text
Add python.exe to PATH
```

---

## 2. 下载仓库

方式 A：Git

```powershell
git clone https://github.com/MeowAndy/meme-generator-rs-fzm.git
cd meme-generator-rs-fzm
```

方式 B：下载 ZIP

在 GitHub 页面点 `Code -> Download ZIP`，解压后进入目录。

---

## 3. 一键安装

用管理员 PowerShell 执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-windows.ps1
```

默认安装到：

```text
C:\meme-api
```

默认端口：

```text
原生 API: 2233
兼容 API: 2234
```

安装脚本会做这些事：

1. 下载 `meme-generator-rs` Windows 版 `meme.exe`；
2. 复制兼容代理；
3. 安装 Python requests；
4. 下载 Windows 扩展库，例如 `meme-emoji-windows-x86_64.dll`；
5. 尝试放行防火墙端口 2233/2234。

---

## 4. 启动服务

前台启动：

```powershell
powershell -ExecutionPolicy Bypass -File C:\meme-api\start-windows.ps1
```

看到类似输出即可：

```text
Native API: http://127.0.0.1:2233
Compat API: http://127.0.0.1:2234
```

如果要长期后台运行，推荐用 NSSM / Windows 服务管理器把下面两个命令注册为服务：

### 服务 1：原生 API

```powershell
C:\meme-api\bin\meme.exe server --host 0.0.0.0 --port 2233
```

工作目录：

```text
C:\meme-api
```

环境变量：

```text
MEME_HOME=C:\meme-api\data
```

### 服务 2：兼容代理

```powershell
py C:\meme-api\proxy\meme_compat_proxy.py --host 0.0.0.0 --port 2234
```

工作目录：

```text
C:\meme-api
```

环境变量：

```text
MEME_BACKEND=http://127.0.0.1:2233
MEME_FALLBACK=https://meme.pippi.top/pippi
MEME_ENABLE_FALLBACK=1
```

---

## 5. 检查服务

```powershell
powershell -ExecutionPolicy Bypass -File C:\meme-api\check-windows.ps1
```

或手动测试：

```powershell
Invoke-RestMethod http://127.0.0.1:2233/meme/version
Invoke-RestMethod http://127.0.0.1:2234/memes/keys
Invoke-RestMethod http://127.0.0.1:2234/memes/petpet/info
```

---

## 6. 给清语表情 meme-plugin 使用

编辑：

```text
/root/Yunzai/plugins/meme-plugin/config/config/server.yaml
```

如果 Yunzai 在另一台 Linux 机器，填 Windows 服务器公网 IP：

```yaml
url: 'http://你的Windows服务器IP:2234'
retry: 3
timeout: 15
```

然后在 QQ 群执行：

```text
#清语表情更新资源
```

验证：

```text
#清语表情列表
#清语表情搜索 撅
撅 @某人
```

---

## 7. 更新扩展表情库

Windows 扩展库通常是 `.dll`，例如：

```text
meme-emoji-windows-x86_64.dll
```

一键更新：

```powershell
powershell -ExecutionPolicy Bypass -File C:\meme-api\update-libraries-windows.ps1
```

更新后需要重启原生 API，才能加载新的 `.dll`。

如果你新增其他扩展库 release URL，可以改：

```text
C:\meme-api\libraries.env
```

格式：

```bash
MEME_LIBRARY_URLS="https://example.com/xxx-windows-x86_64.dll"
```

---

## 8. 常见问题

### Q1：别人访问不了 2234

检查：

1. Windows 防火墙是否放行 2234；
2. 云服务器安全组是否放行 2234；
3. 兼容代理启动参数是否是：

```text
--host 0.0.0.0
```

### Q2：扩展库 `.so` 能不能在 Windows 用？

不能。Linux 用 `.so`，Windows 用 `.dll`。

本项目 Windows 脚本会把已知的 `meme-emoji-linux-x86_64.so` 自动映射为：

```text
meme-emoji-windows-x86_64.dll
```

### Q3：为什么要开两个端口？

- `2233`：新版 Rust 原生 API；
- `2234`：兼容旧 Yunzai 清语表情 `meme-plugin` 的 API。

给普通用户直接填：

```text
http://你的服务器IP:2234
```
