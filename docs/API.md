# API 说明

## 兼容旧 meme-plugin API，推荐给 Yunzai 用户

Base URL:

```text
http://SERVER_IP:2234
```

接口：

```text
GET  /health
GET  /memes/keys
GET  /memes/{key}/info
GET  /memes/{key}/preview
POST /memes/{key}/preview
POST /memes/{key}/
```

`/memes/{key}/info` 会保证返回旧插件需要的 `params_type` 字段。

## 原生 meme-generator-rs API

Base URL:

```text
http://SERVER_IP:2233
```

接口以当前 `meme-generator-rs` 版本为准，常用：

```text
GET  /meme/version
GET  /meme/keys
GET  /meme/search?query=关键词
GET  /memes/{key}/info
POST /memes/{key}/preview
POST /memes/{key}
GET  /image/{image_id}
```
