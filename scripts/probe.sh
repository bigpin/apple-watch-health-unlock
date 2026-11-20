#!/bin/sh
# 握手测试：验证 iPhone 能接受模拟的 MFi 配件身份
# 用法: probe.sh [时长秒数，默认20，范围1~3600]   需先运行 setup.sh
# 通过标准: 输出中出现 identification_accepted 和 authentication_succeeded
set -u
DURATION="${1:-20}"
case "$DURATION" in
  ''|*[!0-9]*) echo "错误: 时长必须是 1~3600 的整数" >&2; exit 1 ;;
esac
[ "$DURATION" -ge 1 ] && [ "$DURATION" -le 3600 ] \
  || { echo "错误: 时长必须是 1~3600 的整数" >&2; exit 1; }
CACHE="$HOME/Library/Caches/accessory-location"
for f in "$CACHE/identity/certificate.p7b" "$CACHE/identity/identity.pk8" \
         "$CACHE/uv/bin/uv" "$CACHE/tool/.venv/bin/python"; do
  [ -e "$f" ] || { echo "错误: 缺少 ${f}，请先运行 setup.sh" >&2; exit 1; }
done
export ACCESSORY_MFI_CERT_FILE="$CACHE/identity/certificate.p7b"
export ACCESSORY_MFI_KEY_FILE="$CACHE/identity/identity.pk8"
cd "$CACHE/tool" || exit 1
exec "$CACHE/uv/bin/uv" run --no-sync accessory-location probe \
  --transport usb --auth-helper tools/local_mfi_v3_helper.py --duration "$DURATION"
