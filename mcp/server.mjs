#!/usr/bin/env node
// DevManager MCP 桥：把 DevManager 的本地控制接口(127.0.0.1:39125)包成 MCP 工具。
// AI 工具通过 stdio 连上，就能列/启/停/重启项目、看日志、跑启动组合。
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const BASE = process.env.DEVMANAGER_URL || "http://127.0.0.1:39125";

async function api(path, { method = "GET", body } = {}) {
  try {
    const res = await fetch(BASE + path, {
      method,
      headers: body ? { "Content-Type": "application/json" } : undefined,
      body: body ? JSON.stringify(body) : undefined,
    });
    return await res.json();
  } catch (e) {
    return { error: `DevManager 未运行或接口不可达 (${BASE})：${e.message}` };
  }
}

const text = (obj) => ({ content: [{ type: "text", text: JSON.stringify(obj, null, 2) }] });

const server = new McpServer({ name: "devmanager", version: "0.2.0" });

server.tool(
  "list_projects",
  "列出 DevManager 里所有 dev 项目及其运行状态(state / port / tags)。",
  {},
  async () => text(await api("/projects"))
);

server.tool(
  "start_project",
  "按项目名或 id 启动一个 dev 项目。",
  { name: z.string().optional().describe("项目名，如 ark-us-vue/dev"), id: z.string().optional() },
  async (args) => text(await api("/start", { method: "POST", body: args }))
);

server.tool(
  "stop_project",
  "按项目名或 id 停止一个 dev 项目。",
  { name: z.string().optional(), id: z.string().optional() },
  async (args) => text(await api("/stop", { method: "POST", body: args }))
);

server.tool(
  "restart_project",
  "按项目名或 id 重启一个 dev 项目。",
  { name: z.string().optional(), id: z.string().optional() },
  async (args) => text(await api("/restart", { method: "POST", body: args }))
);

server.tool(
  "create_project",
  "创建一个新 dev 项目并加入 DevManager(可选自动启动)。name 不填会用 文件夹名/命令 自动生成。",
  {
    path: z.string().describe("项目目录，如 ~/my-app"),
    command: z.string().describe("启动命令，如 npm run dev"),
    name: z.string().optional().describe("项目名，不填自动生成"),
    port: z.number().optional().describe("端口，用于就绪探测/开浏览器"),
    tags: z.array(z.string()).optional().describe("标签(分类)"),
    start: z.boolean().optional().describe("创建后是否立即启动"),
  },
  async (args) => text(await api("/create", { method: "POST", body: args }))
);

server.tool(
  "delete_project",
  "按项目名或 id 删除一个项目。",
  { name: z.string().optional(), id: z.string().optional() },
  async (args) => text(await api("/delete", { method: "POST", body: args }))
);

server.tool(
  "get_logs",
  "取某个项目的日志(纯文本，已去 ANSI)。传 since=上次返回的 cursor 只取其后新增行(流式 tail 用),否则取最后 lines 行。返回里带 cursor 供下次续读。",
  {
    id: z.string().describe("项目 id"),
    lines: z.number().optional().describe("行数，默认 200(不传 since 时生效)"),
    since: z.number().optional().describe("上次返回的 cursor，只取其之后的新增行"),
  },
  async ({ id, lines, since }) => {
    const q = new URLSearchParams({ id });
    if (since != null) q.set("since", String(since));
    else if (lines) q.set("lines", String(lines));
    return text(await api(`/logs?${q}`));
  }
);

server.tool(
  "list_ports",
  "列出本机所有正在监听的 TCP 端口及占用进程(port / command / pid / addr)。managed=true 表示该端口是 DevManager 启动的项目占的。",
  {},
  async () => text(await api("/ports"))
);

server.tool(
  "health",
  "DevManager 总体健康状态:运行中数量 / 总项目数 / 版本。(各项目的 cpu / mem_mb / uptime_sec / ready 见 list_projects)",
  {},
  async () => text(await api("/health"))
);

server.tool(
  "list_profiles",
  "列出所有启动组合(profiles)。",
  {},
  async () => text(await api("/profiles"))
);

server.tool(
  "start_profile",
  "按 id 启动一个启动组合(按其顺序启动组内所有项目)。",
  { id: z.string() },
  async ({ id }) => text(await api("/start_profile", { method: "POST", body: { id } }))
);

const transport = new StdioServerTransport();
await server.connect(transport);
