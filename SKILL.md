---
name: apple-watch-health-unlock
description: 在中国大陆为 Apple Watch 开通地区锁定的健康功能（高血压通知、睡眠呼吸暂停通知等）。通过 Mac 模拟 MFi 定位配件、经 USB 向 iPhone 推送中国香港坐标完成激活。当用户提到：Apple Watch 高血压通知/睡眠呼吸暂停通知"不可用"或"所在地区不可用"、想开通这些健康功能、问如何改定位解锁手表健康功能、或该功能在系统更新后被重置需要重新激活时使用。需要 macOS 电脑、USB 数据线、iPhone 11+/iOS 26+、Apple Watch Series 9/Ultra 2 及以后。
name_cn: AppleWatch高血压通知开通
description_cn: 在大陆为 Apple Watch 开通高血压通知、睡眠呼吸暂停通知等地区锁定健康功能（需 Series 9/Ultra 2 及以后机型、iOS 26+，仅支持 macOS）
create_source: super-agent-skill-creator
version: 1.0.0
---
# Apple Watch 健康功能解锁（高血压通知等）

利用开源工具 accessory-location 在 Mac 上模拟 MFi 定位配件，经 USB 向 iPhone 推送指定坐标，使「健康」App 的健康核对清单出现"不可用"功能的开通入口。**开通一次长期有效**，回到大陆正常使用。

## 工作流

> **执行前须授权**：以下步骤涉及下载约 31MB 的第三方 APK、安装 Python 依赖、通过 USB 操作用户 iPhone。执行任何脚本前，先向用户说明该步会做什么、大致耗时与风险，取得明确同意后再运行；不要静默执行。

### 第 1 步：前置核对

先读 [references/prerequisites.md](references/prerequisites.md)。硬性条件：**手表 Series 9/Ultra 2 及以后**（SE 不支持）、**iPhone 11+/iOS 26+**、watchOS 26+、macOS、USB 数据线。高血压通知另限 22 岁以上、未怀孕、未确诊高血压。

1. 向用户确认手表型号与 iPhone 系统版本，不满足的到此为止并说明原因
2. 让用户用**数据线**把 iPhone 连到 Mac，保持屏幕解锁，弹"信任此电脑"时点信任
3. 运行 `sh scripts/device_info.sh` 自动读设备名和 iOS 版本

### 第 2 步：准备工具链（幂等，首次约 15~20 分钟，为国内限速下的估算值）

先向用户说明：将下载固定 commit 的源码、Python 依赖和约 31MB 的 DiPlay APK（仅提取 MFi 证书，不安装不运行），全部写入 `~/Library/Caches/accessory-location/`，不动全局环境；取得同意后执行：

```bash
sh scripts/setup.sh        # 已准备过则秒级跳过；中断后重跑自动续传
```

自动完成：源码下载（固定 commit）、依赖安装（清华镜像）、APK 下载（内置 8 段并行+断点续传+SHA-256 校验）、MFi 身份提取。全部隔离在 `~/Library/Caches/accessory-location/`，不动用户全局环境。

### 第 3 步：握手测试

```bash
sh scripts/probe.sh 20
```

输出必须同时出现 `identification_accepted` 和 `authentication_succeeded` 才算通过；失败按 [references/troubleshooting.md](references/troubleshooting.md) 排查。

### 第 4 步：后台启动坐标推送

用平台的后台任务机制运行（长时会话，需轮询日志），例如：

```bash
sh scripts/send.sh 22.2969 114.1722 1800
```

参数：纬度、经度、时长秒（默认 1800，脚本强制 1~3600）。常用坐标：中国香港尖沙咀 `22.2969 114.1722`、中国澳门 `22.1987 113.5439`。**只有 `send.sh`** 在 `tools/local-only.sb` 沙箱内运行、禁止对外 IP 联网；`probe.sh` 不使用沙箱（只做本地 USB 握手）。日志出现 `authentication_succeeded` 后再让用户操作手机。

### 第 5 步：指导用户手机端操作（逐条发送，等确认再下一条）

1. 打开控制中心**开飞行模式**（防 IP 定位穿帮，不影响 USB 推送）
2. 打开「地图」验证定位已跳到目标位置；若没变：设置→隐私与安全性→定位服务**关 10 秒再开**（推送保持运行）
3. 打开「健康」→ 右上角头像 → 「健康核对清单」→ 把所有"不可用"功能（高血压通知、睡眠呼吸暂停通知）逐个点「设置」完成开通

### 第 6 步：收尾

1. 用户确认开通后，停止后台推送任务：先核对后台任务 ID 与启动命令（`send.sh` + 本次坐标）一致，再用平台机制停止；不要按进程名批量 kill。会话最长 3600 秒会自动结束
2. 让用户关飞行模式、打开地图确认**真实定位已恢复**
3. 交付提醒：前 30 天为基线采集期无通知；**勿手动关闭功能开关**（再开需重跑本流程）；系统大版本更新后若被重置，重新执行第 3~5 步即可
4. 按前置条件文档末尾向用户做**健康免责说明**

## 排障与披露

- 网络绕行、握手失败、定位不被采用、版本兼容：读 [references/troubleshooting.md](references/troubleshooting.md)
- 证书来源、审计结论、使用红线：读 [references/security-notes.md](references/security-notes.md)，其中"必须向用户披露"与"红线"为强制要求
