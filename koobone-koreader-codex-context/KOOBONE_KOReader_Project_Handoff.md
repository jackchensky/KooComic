# KOOBONE × KOReader 插件项目交接文档

> **用途**：这是给 Codex / 后续独立开发项目使用的上下文交接文档。它记录了此前从需求提出、网页行为观察、Chrome DevTools 抓包、JavaScript 调用链分析、API 确认，到第一版 KOReader 插件原型的完整过程。  
> **目标**：让接手项目的 Codex 不需要重新猜测 KOOBONE 的工作方式，能够直接从已确认的事实继续开发、测试和迭代。
>
> **安全提醒**：此前调试过程中曾在对话截图/文本中暴露过真实邮箱、密码、`KBSKEY`、`sess_key` 等会话凭证。本交接文档不保存这些真实值。后续代码、日志、Git commit、Issue、截图中也绝不能写入真实凭证。建议使用新的会话重新登录，并尽快修改曾暴露过的密码。

---

## 1. 项目最终目标

主要运行环境：

- Kindle Oasis 3（KO3）
- 已越狱
- KOReader
- Simple UI
- 还装有 Readest、Customisable Sleep Screen 等第三方插件

希望开发一个 KOReader 插件，使 Kindle 可以：

```text
KOReader
  ↓
KOOBONE
  ↓
登录用户自己的 KOOBONE 账号
  ↓
读取“我的书库”
  ↓
显示漫画封面、书名、作者、大小、阅读进度
  ↓
点击某一卷
  ↓
直接下载服务器返回的 EPUB
  ↓
保存到 Kindle 本地
  ↓
KOReader 直接打开阅读
```

理想的后续版本还希望支持：

- 封面网格书架
- 搜索
- 标签 / 收藏
- 本地已下载标记
- 下载进度
- 大文件下载
- 断点续传
- 下载目录设置
- 阅读进度显示
- 后续研究是否可把阅读进度同步回 KOOBONE
- Simple UI 快捷入口
- 尽量符合 Kindle 墨水屏交互

---

# 2. 为什么研究 KOOBONE，而不是直接从 Kxx.moe 下载

最初目标是让 KOReader 直接看 Kxx.moe / Kmoe 的漫画。

Kxx.moe 漫画详情页提供：

- 推送 Kindle / KOOBONE
- 下载 Kindle `.mobi`
- 下载 `.epub`
- 单行本 / 连载卷选择

示例页面：

```text
https://kxx.moe/c/52915.htm
```

![Kxx.moe 漫画详情页](images/03-kxx-manga-page.png)

但点击 EPUB 下载页后发现：

> **等级 Lv3 以上才可下载**

![Kxx EPUB Lv3 限制](images/04-kxx-epub-lv3-limit.png)

因此不能依赖 Kxx.moe 的用户侧 EPUB 下载入口。

不过用户可以把漫画卷推送到 KOOBONE。因此项目思路改为：

```text
Kxx.moe
  ↓
推到 KOOBONE
  ↓
KOOBONE 已保存完整漫画
  ↓
研究 KOOBONE 自己的下载接口
  ↓
让 KOReader 直接访问用户自己的 KOOBONE 书库
```

---

# 3. KOOBONE 网页端的初步观察

KOOBONE 页面：

```text
https://bookof.hk/web.htm
```

书库页面可以看到用户已经推送进去的漫画。

![KOOBONE 书库](images/01-koobone-library.png)

每本书的“设置”窗口主要是元数据管理：

- 作者
- 文件大小
- 制作发布
- 来源
- 标签
- 锁定
- 删除

![KOOBONE 设置窗口](images/02-koobone-book-settings.png)

这说明“设置”本身不是下载入口。

---

# 4. 关键发现：点击漫画后，KOOBONE 会先下载整本 EPUB

点击 KOOBONE 书库中的漫画封面后，页面顶部出现：

```text
正在将文档从服务器下载至本地缓存中...
请不要刷新页面
```

书封面底部会出现下载进度条。

![KOOBONE 本地缓存下载进度](images/05-koobone-cache-download-progress.png)

下载完成后，KOOBONE 网页阅读器自动打开漫画。

这说明：

> KOOBONE 不是单纯逐页请求图片，而是会先取得一个完整的电子书文件，缓存到浏览器本地后再阅读。

这一步决定了后续路线：

**如果这个文件是标准 EPUB，那么 KOReader 完全没有必要复刻网页阅读器，只需要取得并保存这个 EPUB。**

---

# 5. Chrome DevTools 抓包：确认实际下载的是 EPUB

操作：

```text
Chrome DevTools
→ Network
→ 点击一册尚未缓存的漫画
```

出现一条非常大的请求：

```text
<file_md5>.epub?sign=...
```

请求示例结构：

```text
https://xdl.koobone.com/<path>/<file_md5>.epub?sign=<temporary-signature>
```

Network 中可以看到：

- `Type = fetch`
- `Status = 200`
- 文件几十 MB 到一百多 MB

![Network 中的 EPUB fetch](images/06-network-epub-fetch.png)

因此确认：

> KOOBONE 实际下载的是标准 `.epub` 文件。

---

# 6. EPUB 下载请求的 Headers 分析

响应头中确认：

```text
Content-Type: application/epub+zip
Content-Length: ...
Accept-Ranges: bytes
```

![EPUB Response Headers](images/07-epub-response-headers.png)

意义：

1. 文件确实是 EPUB。
2. 可以直接保存给 KOReader。
3. `Accept-Ranges: bytes` 表明服务器支持 Range 请求，后续具备实现断点续传的条件。

请求头：

![EPUB Request Headers](images/08-epub-request-headers.png)

观察到：

```text
Origin: https://bookof.hk
Referer: https://bookof.hk/
X-KB-FROM: KOOBONE/5.0.0 WEB(7) WEB(7) FETCH /web.htm
```

关键点：

- EPUB 下载请求没有看到 `Authorization`
- 没有依赖 KOOBONE 登录 Cookie
- 权限主要依赖 URL 上的临时 `sign=...`

因此合理推断：

```text
登录权限
   ↓
发生在取得 file_url 之前

真正下载 EPUB
   ↓
依赖带签名的 file_url
```

不要硬编码或长期保存 `sign`，因为它是临时签名。

---

# 7. 一条最初的误判：vol_act.php 不是下载地址接口

Network 中同时出现过：

```text
vol_act.php?act=readpage&uin=...
```

其 Response 类似：

```json
{
  "uin": 11891513,
  "act": "readpage",
  "fmd": "<file_md5>",
  "ret": 0
}
```

![readpage response](images/09-readpage-response.png)

最初怀疑这个接口返回 EPUB 下载地址，后来确认不是。

它更像：

- 标记阅读行为
- 记录正在读取哪本书
- 更新阅读事件

因此**不要把 `vol_act.php?act=readpage` 当作下载 URL 获取接口**。

---

# 8. 通过 Initiator 找到真正的 JavaScript 调用链

EPUB fetch 的 Initiator：

![EPUB Initiator Stack](images/10-epub-initiator-stack.png)

调用链：

```text
onclick
  ↓
vol_open
  ↓
kb_http_down
  ↓
kb_fetch_down
  ↓
fetch(file_url)
```

对应：

```text
web.htm
zxcomm.js
```

---

# 9. zxcomm.js：下载函数确认

抓到的核心代码：

```javascript
function kb_http_get( s_url, f_callback ) {
    let xhr = new XMLHttpRequest();
    xhr.open( 'GET', s_url );

    xhr.setRequestHeader(
        'X-KB-FROM',
        KB_API_VERSION+' GET '+window.location.pathname
    );

    xhr.onload = function() {
        let rsp_json = JSON.parse( xhr.responseText );
        f_callback( rsp_json );
    };

    xhr.onerror = function() {};
    xhr.send();
}
```

下载函数：

```javascript
function kb_http_down(
    s_url,
    s_id,
    f_onload,
    f_onprog,
    f_onerr,
    f_onabort
) {
    if (
        window.chrome !== null &&
        window.chrome !== undefined
    ) {
        kb_fetch_down(
            s_url,
            s_id,
            f_onload,
            f_onprog,
            f_onerr,
            f_onabort
        );
        return;
    }

    if (s_url === undefined || s_url.length <= 0) return;

    let xhr = new XMLHttpRequest();
    xhr.open('GET', s_url);
    xhr.responseType = 'blob';

    xhr.setRequestHeader(
        'X-KB-FROM',
        KB_API_VERSION+' DOWN '+window.location.pathname
    );

    ...
}
```

Chrome 分支：

```javascript
async function kb_fetch_down(
    sUrl,
    sId,
    fSucc,
    fProg,
    fError,
    fAbort
) {
    if (sUrl == undefined || sUrl.length <= 0) return;

    let oHeaders = new Headers();

    oHeaders.append(
        'X-KB-FROM',
        KB_API_VERSION+' FETCH '+window.location.pathname
    );

    let oRes = fetch(
        sUrl,
        {
            mode: 'cors',
            headers: oHeaders
        }
    )
    .then(funcGetProgress)
    .catch(fError);

    ...
}
```

对应截图：

![zxcomm.js 下载函数](images/11-zxcomm-download-functions.png)

结论：

> `kb_fetch_down()` 和 `kb_http_down()` **不生成签名 URL**。  
> 它们收到的 `sUrl` 已经是完整、可下载的 `file_url`。

---

# 10. vol_open() 分析

关键代码：

```javascript
async function vol_open(file_url, file_md5) {
    objFile = await db_get(file_md5);

    if (objFile.num == 0) {

        if (file_url.length <= 0) {
            return(0);
        }

        await kb_http_down(
            file_url,
            file_md5,
            down_load,
            disp_progress,
            disp_downerr,
            disp_downerr
        );

    } else if (objFile.num == 1) {

        objEpub = await epub_info(objFile.data);
        ...
    }

    return(0);
}
```

![vol_open()](images/12-vol-open-function.png)

这说明 KOOBONE 网页阅读器的逻辑是：

```text
先根据 file_md5 检查浏览器本地数据库
  ↓
没缓存
  ↓
用 file_url 下载完整 EPUB
  ↓
存浏览器数据库
  ↓
解析 EPUB
  ↓
阅读

已经缓存
  ↓
直接从本地数据库读 EPUB
```

非常适合在 KOReader 中简化为：

```text
file_url
  ↓
直接下载到 Kindle 文件系统
  ↓
KOReader 阅读
```

---

# 11. file_url 在哪里传入 vol_open()

继续搜索 `vol_open(`，发现页面生成书架卡片时直接写了：

```javascript
onclick="javascript:vol_open('"
    + objVInfo.file_url
    + "','"
    + objVInfo.file_md5
    + "');"
```

截图：

![vol_open 卡片调用](images/14-vol-open-card-call.png)

列表模式同样使用：

```javascript
vol_open(objVInfo.file_url, objVInfo.file_md5)
```

![vol_open 列表调用](images/15-vol-open-list-call.png)

另一个本地缓存路径：

```javascript
vol_open('', sFmd5);
```

![vol_open 本地缓存路径](images/13-vol-open-cached-path.png)

因此确认：

> `objVInfo.file_url` 在书库 JSON 加载时就已经存在。

---

# 12. 最关键的书库 API：vol_list.php

在 Network → Fetch/XHR 刷新 KOOBONE 书库时，发现：

```text
vol_list.php?u=<uin>&by=time&limit=28
```

![Network 中的 vol_list.php](images/16-network-vol-list.png)

实际形式：

```text
GET https://bookof.hk/vol_list.php?u=<uin>&by=time&limit=28
```

它返回完整书库 JSON。

已观察字段包括：

```json
{
  "uin": 12345678,
  "orderby": "time",
  "total": 4,
  "totalpage": 1,
  "nowpage": 1,
  "nowcount": 4,
  "data": [
    {
      "seq": 1234567,
      "uin": 12345678,
      "status": 1,
      "file_md5": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
      "file_type": "epub",
      "file_size": 158843686,
      "file_from": "KMOE",
      "store_area": "GZ",
      "vol_name": "漫画名 - 卷01",
      "vol_author": "作者",
      "vol_series": "漫画名",
      "vol_seriesid": "KMOE:xxxxx",
      "vol_snumber": "卷01",
      "vol_publisher": "Kmoe",
      "vol_language": "zh-HK",
      "vol_identifier": "KSBN:...",
      "user_like": 0,
      "user_lock": 0,
      "cover_md5": "...",
      "count_page": 241,
      "count_read": 1,
      "last_readpage": 0,
      "time_add": "...",
      "time_update": "...",
      "file_url": "https://xdl.koobone.com/...epub?sign=<temporary>",
      "cover_url": "https://img.koobone.com/cover/...jpg?...",
      "cover_small": "https://img.koobone.com/cover/...jpg?..."
    }
  ],
  "url_timeout": 1787001177
}
```

注意：

- 上面所有 ID 和 URL 都应该视作示例。
- 项目中不要提交真实 `uin`、真实签名 URL。
- `file_url` 是我们最重要的字段。
- `cover_url` / `cover_small` 可用于以后做封面书架。
- `last_readpage` / `count_page` 可用于展示阅读进度。
- `url_timeout` 很可能与签名过期时间有关，值得后续测试。

这一步基本完成了“书库 → 下载地址”的所有分析。

---

# 13. vol_list.php 需要登录 Cookie

`vol_list.php` Request Headers：

![vol_list Request Headers](images/17-vol-list-request-headers.png)

确认浏览器请求会带 Cookie：

```text
VLIBSID=<session>
KBSKEY=<session>
```

同时带：

```text
X-KB-FROM: KOOBONE/5.0.0 WEB(7) GET /web.htm
```

因此不能仅靠：

```text
u=<uin>
```

读取书库。

正确模型：

```text
登录
  ↓
获得会话 Cookie
  ↓
携带 Cookie 请求 vol_list.php
```

---

# 14. uinfo.php：用户信息接口

书库页面还会请求：

```text
GET /uinfo.php?v=web&ver=7
```

返回结构观察到：

```json
{
  "uin": 12345678,
  "nick": "nickname",
  "sess_key": "<sensitive-session-value>",
  "icon_url": "...",
  "device": "Mac",
  "htmlversion": 6,
  "uid": "user@example.com",
  "vip": 0,
  "quota_used": 123,
  "count_vol": 4,
  "quota_max": 21474836480
}
```

这里的：

```text
sess_key
```

属于敏感信息。

不要记录真实值。

插件登录成功后可以利用此接口确认：

- 是否真的登录成功
- `uin`
- 昵称
- 账号信息

---

# 15. 登录流程抓包

## 15.1 login.htm 只是登录页面

请求：

```text
GET https://bookof.hk/login.htm
```

![login.htm GET](images/18-login-page-get.png)

它不是实际认证接口。

---

## 15.2 真正的登录接口：login_do.php

登录动作产生：

```text
POST https://bookof.hk/login_do.php
```

![login_do.php POST](images/19-login-do-post.png)

表单字段：

```text
email
passwd
keepalive
```

![login Form Data](images/20-login-form-data.png)

注意：原始抓包截图中曾暴露过真实密码，项目使用时必须换成占位符。

请求 Content-Type：

```text
multipart/form-data
```

请求中也观察到：

```text
X-KB-FROM: KOOBONE/5.0.0 POST /login.php
```

---

# 16. 登录成功是通过 Set-Cookie 建立会话

`login_do.php`：

```text
Status: 200 OK
```

不是 302。

Response Headers 中有：

```text
Set-Cookie: KBSKEY=<value>; ...
```

![login Set-Cookie](images/21-login-set-cookie.png)

同时登录前浏览器已经存在：

```text
VLIBSID=<value>
```

所以目前推断的完整登录模型：

```text
访问登录页 / 初始化站点
  ↓
得到 VLIBSID
  ↓
POST /login_do.php
  ↓
email
passwd
keepalive=1
  ↓
服务端 Set-Cookie: KBSKEY=...
  ↓
此后请求携带：
VLIBSID
KBSKEY
  ↓
GET /uinfo.php
  ↓
获取 uin / nick / 当前账号信息
  ↓
GET /vol_list.php?u=<uin>...
  ↓
获取书库
```

---

# 17. 已确认的整体网络流程

目前已确认：

```text
1. 初始化/登录
   GET /login.htm
       ↓
   获得或已有 VLIBSID

2. 提交登录
   POST /login_do.php
   multipart/form-data:
       email
       passwd
       keepalive=1
       ↓
   Response:
       Set-Cookie: KBSKEY=...

3. 获取当前用户
   GET /uinfo.php?v=web&ver=7
   Cookie:
       VLIBSID
       KBSKEY
       ↓
   返回：
       uin
       nick
       ...

4. 获取我的书库
   GET /vol_list.php?u=<uin>&by=time&limit=28
   Cookie:
       VLIBSID
       KBSKEY
       ↓
   返回每本书：
       vol_name
       vol_author
       file_md5
       file_size
       cover_url
       cover_small
       last_readpage
       count_page
       file_url

5. 下载 EPUB
   GET file_url
       ↓
   application/epub+zip
       ↓
   保存到 Kindle 本地

6. KOReader 打开 EPUB
```

---

# 18. 第一版插件原型已经做过

此前已经生成过一个实验插件：

```text
koobone.koplugin
```

结构：

```text
koobone.koplugin/
├── _meta.lua
├── main.lua
└── README.md
```

对应 ZIP：

```text
koobone-koreader-plugin-v0.1.zip
```

第一版设计目标：

- 工具菜单增加 `KOOBONE`
- 登录
- 不保存密码
- 保存 `VLIBSID / KBSKEY`
- 调用 `uinfo.php`
- 调用 `vol_list.php`
- 简单列表显示：
  - 书名
  - 作者
  - 文件大小
  - last_readpage / count_page
- 点击书籍后下载 `file_url`
- 保存到 `KOOBONE/`
- 下载完成后调用 KOReader 打开 EPUB

---

# 19. v0.1 的重要说明：它是原型，不代表已经验证可运行

Codex 接手后不要假设 v0.1 已经稳定。

必须重点检查：

## 19.1 LuaSocket HTTPS 支持

原型用了类似：

```lua
local http = require("socket.http")
```

但是：

```text
https://bookof.hk
https://xdl.koobone.com
```

都是 HTTPS。

KOReader 插件中通常应确认：

- `ssl.https`
- KOReader 自带网络封装
- `socketutil`

是否需要正确组合。

**第一优先级就是验证 HTTPS 请求能否成功。**

---

## 19.2 Set-Cookie 多值解析

必须可靠解析：

```text
VLIBSID
KBSKEY
```

注意不同 Lua HTTP 库返回 Headers 时：

```text
set-cookie
Set-Cookie
table
string
```

形式可能不同。

---

## 19.3 登录前 VLIBSID 的来源

目前已知：

- 登录请求中浏览器带已有 `VLIBSID`
- 登录成功后服务器设置 `KBSKEY`

但还需要更严谨确认：

> `VLIBSID` 究竟是 GET `/login.htm` 下发，还是此前访问 `bookof.hk` 主页时下发。

Codex 应在干净 cookie jar 下测试：

```text
GET /
GET /login.htm
GET /login.php
```

分别观察 Set-Cookie。

---

## 19.4 Cookie 生命周期

需要确认：

- `VLIBSID` 是否长期稳定
- `KBSKEY` 是否长期保持
- `keepalive=1` 对有效期的影响
- 登录失效后 `uinfo.php` 返回什么
- 登录失效后 `vol_list.php` 返回什么

插件必须能识别登录过期并提示重新登录。

---

## 19.5 file_url 是临时签名

`file_url` 含：

```text
?sign=...
```

而 Response 还含：

```text
url_timeout
```

可能是：

- 书库 JSON 返回时动态签名
- 签名只在一定时间内有效

正确实现应该：

```text
用户点下载
  ↓
如书库数据较旧
  ↓
重新请求 vol_list.php
  ↓
取得最新 file_url
  ↓
立即下载
```

不要缓存 `file_url` 很久。

---

# 20. 下一版建议架构

建议 Codex 把代码拆开，不要所有逻辑都塞在 `main.lua`。

推荐：

```text
koobone.koplugin/
├── _meta.lua
├── main.lua
├── api.lua
├── auth.lua
├── library.lua
├── downloader.lua
├── storage.lua
├── ui/
│   ├── login.lua
│   ├── bookshelf.lua
│   ├── bookdetail.lua
│   └── download.lua
└── README.md
```

职责：

### `auth.lua`

负责：

```text
VLIBSID
KBSKEY
login_do.php
uinfo.php
logout
session validation
```

### `api.lua`

负责：

```text
统一 HTTP GET / POST
headers
X-KB-FROM
cookies
JSON decode
错误处理
```

### `library.lua`

负责：

```text
vol_list.php
分页
搜索
标签
书库数据模型
```

### `downloader.lua`

负责：

```text
file_url
大文件下载
进度
Range
断点续传
临时 .part 文件
完成后 rename
```

### `storage.lua`

负责：

```text
KOOBONE 下载目录
已下载判断
MD5 / 文件名
设置
```

---

# 21. UI 设计建议

v0.1 可以先用简单列表。

稳定后做墨水屏友好的书架。

理想界面：

```text
KOOBONE
--------------------------------
[封面]  镖人 - 卷11
        许先哲
        65.2 MB
        已读 7 / 229

[封面]  浪客行 - 卷01
        井上雄彦
        153 MB
        已读 19 / 114
--------------------------------
刷新   下载管理   设置
```

最终可考虑封面网格，但 Kindle E Ink 上优先保证：

- 刷新少
- 不要复杂动画
- 图片缓存
- 页面响应快

---

# 22. 下载器设计建议

漫画 EPUB 经常：

```text
60 MB
100 MB
150 MB+
```

不能只做“一次性内存下载”。

建议：

```text
GET
  ↓
流式写入：
book.epub.part
  ↓
实时更新：
downloaded bytes / total bytes
  ↓
成功
  ↓
rename:
book.epub.part → book.epub
```

由于服务器：

```text
Accept-Ranges: bytes
```

后续可以：

```text
已有 70 MB .part
  ↓
Range: bytes=73400320-
  ↓
继续下载
```

---

# 23. 文件名策略

可用：

```text
<vol_series> - <vol_snumber>.epub
```

或者直接：

```text
<vol_name>.epub
```

必须 sanitize：

```text
/
\
:
*
?
"
<
>
|
```

避免 Kindle 文件系统问题。

建议保留：

```text
file_md5
```

作为内部唯一 ID。

---

# 24. 封面

书库返回：

```text
cover_url
cover_small
```

建议：

- 列表用 `cover_small`
- 详情页用 `cover_url`
- 保存到插件 cache
- 用 `cover_md5` 当缓存 key

例如：

```text
koreader/cache/koobone/covers/<cover_md5>.jpg
```

---

# 25. 阅读进度

已有：

```text
last_readpage
count_page
count_read
```

可以先只显示：

```text
已读 7 / 229
```

但不要马上假设：

```text
KOReader EPUB 页码 == KOOBONE last_readpage
```

漫画 EPUB 可能每张图片是一页，可能接近，但需要验证。

---

# 26. 后续可研究的 KOOBONE 阅读同步

已经发现：

```text
vol_act.php?act=readpage...
```

它可能参与阅读行为上报。

现阶段不要写进 v0.1。

等基础插件稳定后，再抓：

- 翻页时 Network
- 退出一本书时 Network
- 添加书签时 Network
- 收藏时 Network
- 阅读进度更新时 Network

目标再判断：

```text
KOReader 本地页码
  ↓
KOOBONE readpage API
  ↓
同步 last_readpage
```

---

# 27. X-KB-FROM Header

观察到网站会发送类似：

```text
X-KB-FROM: KOOBONE/5.0.0 WEB(7) GET /web.htm
```

登录：

```text
X-KB-FROM: KOOBONE/5.0.0 POST /login.php
```

EPUB fetch：

```text
X-KB-FROM: KOOBONE/5.0.0 WEB(7) WEB(7) FETCH /web.htm
```

服务器是否强制检查这个 Header 尚未确认。

为了兼容性，插件初期可以模仿网站发送。

后续可测试是否可简化。

---

# 28. Cloudflare / 网络问题

`bookof.hk` 响应经过 Cloudflare。

此前 KOReader 的 Storefront 在 Kindle 上曾出现：

```text
Connection reset by peer
```

说明 Kindle 国际网络/TLS 可能不稳定。

因此 KOOBONE 插件必须有：

- 合理 timeout
- retry
- 错误提示
- 不要卡死 UI
- 下载失败保留 `.part`
- 网络恢复后继续

---

# 29. 安全原则

Codex 开发时必须遵守：

1. 不把真实 email / password 写进源码。
2. 不把真实 `KBSKEY` 写进源码。
3. 不把真实 `VLIBSID` 写进源码。
4. 不把 `sess_key` 写进源码。
5. 不把临时 `file_url?sign=...` 提交 Git。
6. 密码只存在登录对话框内存中。
7. 登录完成后立即释放密码变量。
8. 本地仅保存 session cookie。
9. 提供“退出登录 / 清除会话”。
10. 日志默认不能打印 Cookie、password、sign。
11. 如开启 debug，敏感字段必须自动 redact。

---

# 30. 已经证明“不需要做”的事情

不要重新浪费时间研究这些：

### 不需要解析 Kxx.moe 的 Lv3 EPUB 下载

因为用户自己的 KOOBONE 已经返回 EPUB。

### 不需要逐页抓漫画图片

KOOBONE 本身就是完整 EPUB。

### 不需要复刻 KOOBONE 网页阅读器

KOReader 能直接打开 EPUB。

### 不需要从 vol_act.php 获取下载地址

真正下载地址直接在 `vol_list.php` 返回的：

```text
file_url
```

### 不需要从 JavaScript 自己计算 sign

目前 sign 已经由书库接口返回。

---

# 31. 推荐 Codex 的第一阶段任务

建议第一阶段只实现：

```text
1. 插件能被 KOReader 正常加载
2. 登录 UI
3. 正确拿到 VLIBSID
4. POST login_do.php
5. 正确拿到 KBSKEY
6. GET uinfo.php
7. GET vol_list.php
8. 显示简单书籍列表
9. 下载一个较小 EPUB
10. KOReader 成功打开
```

不要一开始就做：

- 漂亮封面网格
- 阅读同步
- 断点续传
- 标签
- 搜索
- 自动更新

先打通最核心闭环。

---

# 32. 第二阶段

基础闭环稳定后：

- 下载进度
- `.part`
- 断点续传
- 封面缓存
- 已下载标记
- 下载目录设置
- 重新登录
- Cookie 失效处理
- 书库刷新
- 下拉 / 翻页
- Simple UI 快捷入口

---

# 33. 第三阶段

再考虑：

- KOOBONE 阅读进度同步
- 收藏
- 标签
- 搜索
- 删除本地漫画
- 下载管理器
- 后台下载
- Storefront 发布
- GitHub Release
- 自动更新

---

# 34. 当前结论

整个技术路线已经得到浏览器抓包和源码调用链的充分验证：

```text
KOOBONE 登录
  ↓
VLIBSID + KBSKEY
  ↓
uinfo.php
  ↓
取得 uin
  ↓
vol_list.php
  ↓
取得漫画书库 JSON
  ↓
取得 file_url
  ↓
GET xdl.koobone.com/...epub?sign=...
  ↓
标准 application/epub+zip
  ↓
保存
  ↓
KOReader 阅读
```

因此：

> **开发一个原生 KOReader KOOBONE 漫画插件在技术上是可行的。**

当前最大不确定点已经不在“有没有接口”，而在：

- KOReader Lua 环境中如何最稳地做 HTTPS
- Cookie 初始化和保持
- 大文件下载稳定性
- UI 线程与网络下载
- 临时签名 URL 过期策略
- Kindle 弱网络环境处理

这些应成为 Codex 下一阶段的重点。

---

# 35. 本文档截图说明

`images/` 目录包含此次分析中最重要的截图，并按分析顺序重新命名。

建议 Codex 在需要理解网页行为或接口关系时直接查看图片，而不是只依赖本文文字描述。

---

# 36. 给 Codex 的启动提示

可以把下面这段作为新项目第一次指令：

```text
请先完整阅读 KOOBONE_KOReader_Project_Handoff.md，并查看其中引用的 images/ 截图。

这是一个 KOReader 第三方插件项目。之前已经通过 Chrome DevTools 逆向确认 KOOBONE 的登录、书库和 EPUB 下载流程。

不要重新从头猜接口，也不要把任何真实登录凭证写进代码。

第一阶段目标：
1. 检查当前 koobone.koplugin v0.1 原型代码是否符合最新版 KOReader 插件 API。
2. 修正 HTTPS、Cookie jar、multipart/form-data 登录。
3. 确保插件可以在 Kindle Oasis 3 的 KOReader 中加载。
4. 完成：
   登录 → uinfo → vol_list → 显示书库 → 下载 EPUB → KOReader 打开
   的最小闭环。
5. 优先实现稳定性，不要先做复杂 UI。
6. 所有请求和日志必须自动隐藏 password、KBSKEY、VLIBSID、sess_key、file_url sign。
7. 每一次修改都说明为什么，并尽量保持模块化。
```

---

**End of handoff document**
