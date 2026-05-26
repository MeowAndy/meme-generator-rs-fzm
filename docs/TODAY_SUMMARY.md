# 今日实战总结：meme-generator-rs-fzm

## 部署目标

在 4-4 服务器上部署一套可供 Yunzai 清语表情 `meme-plugin` 使用的表情包 API，并支持后续扩展表情库。

## 实际部署内容

- 服务器：4-4，`你的服务器IP`
- 原生 Rust API：`http://你的服务器IP:2233`
- 兼容旧 `meme-plugin` API：`http://你的服务器IP:2234`
- 服务目录：`/opt/meme-api`
- 原生服务：`meme-api.service`
- 兼容代理：`meme-compat-proxy.service`
- Yunzai tmux 会话：`yz`

## 关键问题与修复

### 1. 旧插件接口和新 Rust API 不兼容

旧插件调用：

```text
/memes/keys
/memes/{key}/info
/memes/{key}/preview
/memes/{key}/
```

新 Rust API 部分返回 `image_id`，且 info 字段为 `params`。  
解决：增加 `meme_compat_proxy.py`，转换路径、返回图片二进制，并把 `params` 规范化为 `params_type`。

### 2. `撅` 等旧表情缺失

`撅` 对应 key 是 `do`，本机 Rust API 不包含。  
解决：兼容代理优先本机，缺失时 fallback 到旧 `https://meme.pippi.top/pippi`。

### 3. 帮助图中文变方框

原因：服务器缺中文字体。  
解决：安装：

```bash
apt install fonts-noto-cjk fonts-wqy-zenhei fonts-wqy-microhei
fc-cache -fv
```

### 4. 更新资源报 notNull Violation

原因：旧插件入库需要：

```text
params_type.min_texts / max_texts / min_images / max_images
```

解决：兼容代理 normalize info，自动补 `params_type`。

## 最终验证

- `/memes/keys` 返回 872 个 key
- `meme-plugin` 本地数据库 872 条
- 空参数行数 0
- `#清语表情更新资源` 成功
- `#清语表情帮助` 可正常出图
- `撅 @某人` 可通过 fallback 使用旧表情
