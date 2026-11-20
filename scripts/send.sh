#!/bin/sh
# 启动坐标推送会话（前台运行，建议由代理放入后台任务并轮询日志）
# 用法: send.sh <纬度> <经度> [时长秒，默认1800，范围1~3600]
# 常用目标: 中国香港尖沙咀 22.2969 114.1722 / 中国澳门 22.1987 113.5439
# 运行在项目自带沙箱内（禁止对外 IP 联网），USB 本地通信不受影响
set -u
[ "$(uname)" = "Darwin" ] || { echo "错误: 仅支持 macOS" >&2; exit 1; }
LAT="${1:?用法: send.sh <纬度> <经度> [时长秒]}"
LON="${2:?用法: send.sh <纬度> <经度> [时长秒]}"
DURATION="${3:-1800}"
# 兑现文档宣称的 1~3600 秒上限，避免发送器无期限运行（见 security-notes.md 红线 3）
awk -v lat="$LAT" -v lon="$LON" -v dur="$DURATION" 'BEGIN {
  if (lat !~ /^-?[0-9]+([.][0-9]+)?$/ || lon !~ /^-?[0-9]+([.][0-9]+)?$/) exit 1
  if (dur !~ /^[0-9]+$/) exit 1
  if (lat < -90 || lat > 90) exit 1
  if (lon < -180 || lon > 180) exit 1
  if (dur < 1 || dur > 3600) exit 1
}' || { echo "参数错误: 纬度 -90~90、经度 -180~180、时长 1~3600 秒" >&2; exit 1; }
CACHE="$HOME/Library/Caches/accessory-location"
for f in "$CACHE/identity/certificate.p7b" "$CACHE/identity/identity.pk8" \
         "$CACHE/uv/bin/uv" "$CACHE/tool/.venv/bin/python" "$CACHE/tool/tools/local-only.sb"; do
  [ -e "$f" ] || { echo "错误: 缺少 ${f}，请先运行 setup.sh" >&2; exit 1; }
done
export ACCESSORY_MFI_CERT_FILE="$CACHE/identity/certificate.p7b"
export ACCESSORY_MFI_KEY_FILE="$CACHE/identity/identity.pk8"
cd "$CACHE/tool" || exit 1
exec /usr/bin/sandbox-exec -f tools/local-only.sb \
  "$CACHE/uv/bin/uv" run --no-sync accessory-location send \
  --transport usb --auth-helper tools/local_mfi_v3_helper.py \
  --latitude "$LAT" --longitude "$LON" --duration "$DURATION"
