# Apple Watch 健康功能解锁（apple-watch-health-unlock）

利用开源工具 [accessory-location](https://github.com/aur3l14no/accessory-location) 在 Mac 上**模拟 MFi 定位配件**，经 USB 向 iPhone 推送中国香港坐标，使「健康」App → **健康核对清单**里「高血压通知」「睡眠呼吸暂停通知」等大陆"不可用"功能出现开通入口。**开通一次长期有效**，回到大陆正常使用，无需保持伪装。

这是一个 [Agent Skill](#-作为-agent-skill-使用推荐)：既可以交给 AI agent 按工作流自动执行，也可以手动运行 `scripts/` 下的脚本。

---

## ⚠️ 免责声明（务必先读）

- 模拟 MFi 配件身份属**灰色变通**，苹果可能随时吊销所用证书（届时认证失败，需等上游更新）
- 高血压通知是**筛查提示，非医疗诊断**，不能替代血压计和医生；大陆未完成审批，属提前尝鲜
- 仅限**本人设备**使用，不得用于批量设备操作或商业代开
- 每一步执行前 agent 都会向用户说明将要做什么并取得同意；手动使用同理

## 🧭 原理

### 为什么不是"改地区"

watchOS 官方功能可用性表中，高血压通知等健康功能**不含中国大陆**（截至 2026-11 仍在审批流程中）。而 iPhone 侧判定这些功能可用性时，依据的是**当前 GPS 位置**，不是设备地区设置——所以改地区是绕远路，直接把"当前位置"变成香港才是对症下药。

### 工作链路

```
Mac（本技能）
 │  USB 数据线 · iAP2 配件协议
 │  （向 iPhone 自我标识为一台 MFi 认证"定位配件"）
 ▼
iPhone
 │  系统定位被替换为中国香港坐标（需 MFi 认证配件才有推送资格）
 ▼
「健康」App · 健康核对清单
    高血压通知 / 睡眠呼吸暂停通知：不可用 → 可开通
```

iPhone 只接受**经过 MFi 认证的配件**推送位置数据，因此整个方案的关键是身份：本技能在 `setup.sh` 阶段从固定 SHA-256 校验的 DiPlay v0.2.7 APK 中**现场提取** MFi 身份文件（certificate.p7b / identity.pk8）。该 APK 携带的是第三方从 Carlinkit 车载配件公开固件中恢复的生产 MFi 凭据。**本仓库不包含、也不会分发任何身份文件**，每次使用都现场提取、留在本机缓存。

### 特性

| 特性 | 说明 |
|---|---|
| 开通一次长期有效 | 回大陆正常使用，前 30 天为基线采集期（无通知属正常） |
| 不改设备地区 | Apple Pay / 天气 / 地图等日常体验不受影响 |
| 无残留 | 全部工具隔离在 `~/Library/Caches/accessory-location/`，不动全局环境；APK 仅提取证书，**从不安装运行** |
| 全程禁外网 | `send.sh` 在 `sandbox-exec` 沙箱内运行，禁止对外 IP 联网，仅本地 USB 通信 |
| 幂等可重跑 | setup 中断后重跑自动续传；系统大版本更新重置功能后，重跑 probe → send 即可 |

## ✅ 前置条件

| 项目 | 要求 | 不支持 |
|---|---|---|
| Apple Watch | Series 9 / 10 / 11 / 12、Ultra 2 / 3 / 4 | **SE 全系**、Series 8 及更早 |
| iPhone | iPhone 11 及以后，**iOS 26+** | iPhone X 及更早 |
| watchOS | 26+ | — |
| 电脑 | macOS + USB **数据线**（充电线无法通信） | Windows |
| 人群（高血压通知） | 年满 22 岁、未怀孕、未确诊高血压 | 已确诊服药者官方不推荐 |

## 🚀 使用方法

### 作为 Agent Skill（推荐）

把本仓库放入 agent 的 skills 目录：

```sh
# zcode
git clone https://github.com/bigpin/apple-watch-health-unlock.git ~/.zcode/skills/apple-watch-health-unlock

# Claude Code
git clone https://github.com/bigpin/apple-watch-health-unlock.git ~/.claude/skills/apple-watch-health-unlock
```

之后对 agent 说「**帮我开通 Apple Watch 高血压通知**」即可。agent 会按 [SKILL.md](SKILL.md) 的六步工作流执行，每一步先说明、经同意再动手；排障与安全披露分别见 [references/troubleshooting.md](references/troubleshooting.md) 与 [references/security-notes.md](references/security-notes.md)。

### 手动执行（无 agent）

```sh
# 1. 前置核对（读 references/prerequisites.md），USB 连接 iPhone 并保持解锁
sh scripts/device_info.sh            # 自动读设备名与 iOS 版本

# 2. 准备工具链（幂等；首装约 15~20 分钟，含 31MB APK 分段下载）
sh scripts/setup.sh                  # 中断后重跑自动续传

# 3. 握手测试：必须同时出现 identification_accepted 和 authentication_succeeded
sh scripts/probe.sh 20

# 4. 后台启动坐标推送（香港尖沙咀；备选澳门 22.1987 113.5439）
sh scripts/send.sh 22.2969 114.1722 1800   # 参数：纬度 经度 时长秒(1~3600)

# 5. 手机端：开飞行模式 → 地图确认定位已跳香港 → 健康→头像→健康核对清单 → 逐个开通
#    （定位没跳：设置→隐私与安全性→定位服务 关 10 秒再开）

# 6. 收尾：确认开通后停止推送 → 关飞行模式 → 地图确认真实定位恢复
```

**成功判定**：probe 出现 `identified: true, authenticated: true`；send 中持续出现 `location_requested` + `location_link_acknowledged`。日志关键事件速查见排障手册。

## 📁 目录结构

```
apple-watch-health-unlock/
├── SKILL.md                     # Agent 工作流主文件（六步流程 + 授权要求）
├── references/
│   ├── prerequisites.md         # 前置条件与功能机制详解
│   ├── troubleshooting.md       # 排障手册（网络/握手/开通/兼容性）
│   └── security-notes.md        # 安全审计结论、MFi 身份披露、使用红线
└── scripts/
    ├── device_info.sh           # 读取已连接 iPhone 的型号与 iOS 版本
    ├── setup.sh                 # 工具链准备（固定 commit + 清华镜像 + APK 校验 + 身份提取）
    ├── probe.sh                 # MFi 握手测试
    └── send.sh                  # 坐标推送（沙箱内运行，时长强制 1~3600 秒）
```

## 🔧 排障速览

| 现象 | 处理 |
|---|---|
| probe 认证失败 / 无 `authentication_succeeded` | MFi 证书可能被吊销，到上游仓库确认新版并同步更新 setup.sh 中的 `APK_SHA256` |
| 已 ack 但地图不跳点 | 保持 send 运行，定位服务关 10 秒再开（ack 只代表送达，不代表采纳） |
| `ConnectionTerminatedError` | 最大嫌疑：自动锁屏挂起了会话。设置→显示与亮度→自动锁定→**永不**，全程亮屏 |
| `NoDeviceConnectedError` | 多为会话恢复瞬间的通道竞争，iPhone 实际未掉线，直接重跑 send |
| 凌晨失败率高 | 原件技能评分显示差评集中在凌晨，白天成功率明显更高，建议白天操作 |

完整排障：[references/troubleshooting.md](references/troubleshooting.md)

## 🔒 安全与合规

- accessory-location（GPL-3.0）经审计：纯本地 USB 通信，无遥测无上传；依赖仅 pymobiledevice3 与 cryptography
- 全程不变更 Apple 账号数据、不安装 APK、不上传任何信息
- **红线**：不打包/不分发/不上传身份文件；仅限本人设备；推送会话结束及时停止；向用户如实披露风险

详见 [references/security-notes.md](references/security-notes.md)。

## 📜 实测记录

- 2026-11-20 实测开通成功：iPhone 15 Pro Max / 国行 / iOS 27.2.x，首装全流程约 20 分钟
- 首装耗时 15~20 分钟为**国内限速下的估算值**（30KB/s 限速、31MB APK）；工具链已缓存时秒级跳过

## 🙏 致谢与来源

- [aur3l14no/accessory-location](https://github.com/aur3l14no/accessory-location)（GPL-3.0）— 核心工具，经 `setup.sh` 现场下载固定 commit，不随本仓库分发
- [shihabal3amri/DiPlay](https://github.com/shihabal3amri/DiPlay) — MFi 身份来源 APK（见其 THIRD_PARTY_NOTICES）
- 工作流移植自「星辰超级智能体」技能广场同名技能原件（2026-11-20），并结合本机实测补充了排障与安全披露

## 📄 许可

本仓库的 README / SKILL.md / references / scripts 为原创文档与胶水脚本，未附开源许可证（保留所有权利，如需复用请开 issue 联系）；运行时下载的上游工具各自遵循其原始许可证（accessory-location：GPL-3.0）。
