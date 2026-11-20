# 排障手册

## 网络（中国大陆环境实测，2026-11）

| 现象 | 处理 |
|------|------|
| github.com 直连超时 | 正常。脚本已全部走 `api.github.com`（源码 tarball、release asset 302 重定向至 objects.githubusercontent.com），无需处理 |
| 下载限速约 30KB/s | 已内置 8 段并行 + 断点续传 + 12 轮重试。APK 共 31MB，约 15~20 分钟；**中断后直接重跑 setup.sh 续传**，不重头开始 |
| "获取签名 URL 失败" | GitHub 未认证 API 频控（60 次/小时），脚本会等 60 秒自动重试，不要手动频繁刷 |
| uv/pip 安装依赖超时 | 已默认走清华镜像；镜像异常时可用 `PYPI_INDEX=https://pypi.tuna.tsinghua.edu.cn/simple sh scripts/setup.sh` 指定其他镜像 |
| `uv sync --locked` 报锁文件需更新 | 正常现象（锁文件按官方 PyPI 生成，与镜像不兼容），setup.sh 已用不带 `--locked` 的写法 |

## 设备与握手

| 现象 | 处理 |
|------|------|
| device_info.sh / probe 报未检测到设备 | ① 确认用的是**数据线**非充电线 ② iPhone 保持**屏幕解锁** ③ 首次连接弹"信任此电脑"时点信任并输密码 ④ 换个 USB 口/线 |
| probe 输出 `identification_accepted` 但没有 `authentication_succeeded`，或出现 0xAA04 认证失败 | MFi 证书可能已被苹果吊销或上游更换身份来源。到 github.com/aur3l14no/accessory-location 和 shihabal3amri/DiPlay 确认是否有新版（新版 APK 的 SHA-256 需同步更新 setup.sh 中的 `APK_SHA256`/`APK_ASSET_API`） |
| authentication_succeeded 但没有 location_requested | 手机端没触发定位订阅：让用户打开「地图」App 请求当前位置 |
| 已收到 location_link_acknowledged 但地图位置不变 | 保持 send 运行，让用户把 设置→隐私与安全性→定位服务 **关闭 10 秒再打开**，然后回地图重新定位。注意：确认收到 ack 只代表送达，不代表被采用 |

## 手机端开通

| 现象 | 处理 |
|------|------|
| 健康核对清单里仍显示"不可用" | ① 确认已开**飞行模式**（防 IP 定位穿帮）② 完全杀掉健康 App 重开 ③ 确认手表已配对且连接正常 ④ 换一组中国香港坐标重试 |
| 开通完成后定位回不去 | 拔掉 USB 线，开关一次定位服务，打开地图确认恢复真实位置 |

## 版本兼容

- iOS 26.1 测试版曾封堵过此类虚拟定位方案，稳定版已恢复；**大版本升级前**建议先搜社区反馈再决定是否升级
- 上游工具是实验性项目，watchOS/iOS 更新可能影响握手、订阅、坐标采用任一环节，此时到上游仓库确认更新
- send 会话到期自动结束；用户操作未完成时重新启动一个会话即可（无需重跑 setup.sh）

## 日志关键事件速查

```
device_connected          USB 已连接
identification_accepted   配件身份被接受
authentication_succeeded  MFi 认证通过（核心）
location_requested        手机请求定位数据
location_link_acknowledged 坐标报文送达（每10个显示一次）
location_stopped          手机停止请求（正常）
finished                  会话结束（输出统计）
```
