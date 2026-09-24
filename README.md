# Z Ai

AI 图像**生成**与**编辑**的 Web 应用。浏览器访问页面，由 Node 服务端代理上游图像 API；长任务在服务端执行，关掉页面也能继续出图。

> 项目已由 Flutter 客户端整体重写为 Web 版，原 Flutter 工程不再维护（源码见 git 历史 `e888978` 之前的提交）。

## 功能

| 模块 | 说明 |
|------|------|
| 文生图 | 提示词 → 生成 1–N 张图 |
| 图编辑 / 图生图 | 多张源图 + 编辑描述 → 改图 |
| 大图预览 | 全屏、缩放、多图切换、下载 |
| 任务 | 提交后轮询状态，支持取消；关页/刷新可继续查 |
| 图库 | 历史生成结果浏览与下载 |
| 模型管理 | 每个模型自带上游地址、协议与 Key，可拉取上游模型列表 |
| 日志 | 服务端实时日志（WebSocket） |
| 深色模式 | 明暗主题，localStorage 记忆 |
| 登录门禁 | 单密码访问，密钥只存服务端 |

**不做**（浏览器能力边界）：系统托盘、前台服务保活、原生通知栏、写入相册（改为浏览器下载）。

## 技术栈

| 层 | 选型 |
|----|------|
| 服务端 | Node.js 22+ / Express 4 / `node:sqlite`（内置）/ 原生 `fetch` |
| 前端 | Vite 6 / Vue 3 / TypeScript |
| 存储 | SQLite（任务、模型）+ 本地磁盘（`server/data/images`） |
| 实时 | WebSocket（日志推送） |

## 目录结构

```
z_ai_img/
├── server/                 # Express 服务端
│   ├── src/
│   │   ├── index.js        # 入口、路由挂载、静态托管
│   │   ├── auth.js         # 单密码登录 + 会话 Cookie
│   │   ├── config.js       # .env + config.json
│   │   ├── db.js           # node:sqlite 初始化与迁移
│   │   ├── taskRunner.js   # 任务状态机、并发控制、重启恢复
│   │   ├── imageApi.js     # 上游适配（OpenAI Images / 兼容扩展）
│   │   ├── dashscopeAsync.js / uuapiAsync.js  # 异步协议适配
│   │   ├── modelRegistry.js / modelList.js    # 模型注册与列表
│   │   ├── logBus.js / logSocket.js           # 日志缓冲与 WS 推送
│   │   └── routes/         # tasks / models / gallery / uploads / files / profiles
│   ├── config.json         # 多 Profile 结构（无密钥，可入库）
│   ├── .env.example        # 环境变量占位
│   └── data/               # sqlite + 图片（gitignore）
├── web/                    # Vite + Vue 3 前端
│   └── src/
│       ├── App.vue         # 登录门禁 + Tab 导航
│       ├── pages/          # Generate / Edit / Tasks / Gallery / Models / Logs
│       ├── components/     # Lightbox / ModelSelect
│       └── api/client.ts   # /api 封装
├── 功能清单.md             # 功能基线
└── 技术选型.md             # 选型与接口约定
```

## 快速开始

### 1. 环境要求

- **Node.js 22+**（服务端使用内置 `node:sqlite`）

### 2. 配置

```bash
cd server
cp .env.example .env
```

编辑 `server/.env`：

```bash
PORT=3003
DATA_DIR=./data

# 访问密码（公网务必用强口令）
AUTH_PASSWORD=你的密码

# 上游密钥，config.json 用 apiKeyEnv 引用
API_KEY_JENIYA=sk-xxxx
API_KEY_QWEN=sk-yyyy
```

`.env` 不入库；`config.json` 只存非敏感结构。也可以启动后在「模型管理」页里逐个添加模型（自带上游地址、协议、Key）。

### 3. 安装与构建

```bash
# 服务端
cd server && npm install

# 前端
cd ../web && npm install && npm run build
```

### 4. 启动

```bash
cd server && npm start
```

访问 `http://localhost:3003`。

### 开发模式

两个终端分别运行：

```bash
cd server && npm run dev     # Node --watch，端口 3003
cd web && npm run dev        # Vite，端口 5173，自动代理 /api 与 /ws 到 3003
```

开发时访问 `http://localhost:5173`。生产由 Express 托管 `web/dist`，同源无 CORS。

## 上游协议

| 项 | OpenAI Images | OpenAI 兼容扩展 |
|----|---------------|-----------------|
| 文生图 | `/v1/images/generations`（含 quality/format） | 同端点，无 quality/format |
| 图编辑 | `/v1/images/edits` multipart | `/v1/images/generations` + JSON `image` |
| 遮罩 mask | 支持 | 不支持 |
| n 上限 | 10 | 6 |
| 4K 尺寸 | 有 | 无 |

响应解析：`data[].url` 或 `data[].b64_json`，兜底 `choices[].message.content`。

## 服务端接口

**浏览器 → Node**（除 `/api/health`、`/api/me`、`/api/login` 外均需登录）

| 端点 | 方法 | 用途 |
|------|------|------|
| `/api/login` / `/api/logout` / `/api/me` | POST/POST/GET | 登录门禁 |
| `/api/tasks` | POST | 提交生成/编辑任务 |
| `/api/tasks/:id` | GET | 查询状态与结果 |
| `/api/tasks/:id/cancel` | POST | 取消 |
| `/api/tasks` | GET | 最近任务列表 |
| `/api/gallery` | GET | 历史结果 |
| `/api/models` | CRUD | 模型管理 |
| `/api/uploads` | POST | 上传源图 |
| `/files/:name` | GET | 预览/下载图片 |
| `/ws/logs` | WS | 实时日志 |

任务状态机：`queued → running → succeeded | failed | canceled`。服务端进程内有限并发（默认 2），重启后自动恢复未完成任务。

## 文档

- 《功能清单.md》——功能基线
- 《技术选型.md》——选型、接口约定、部署演进
