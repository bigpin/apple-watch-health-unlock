#!/bin/sh
# 检测当前 USB 连接、已信任的 iPhone，输出设备名/型号/iOS 版本
# 需先运行 setup.sh。退出码: 0=检测到, 1=未检测到/未信任
set -u
CACHE="$HOME/Library/Caches/accessory-location"
[ -x "$CACHE/uv/bin/uv" ] || { echo "错误: 请先运行 setup.sh" >&2; exit 1; }
[ -x "$CACHE/tool/.venv/bin/python" ] || { echo "错误: 请先运行 setup.sh" >&2; exit 1; }
cd "$CACHE/tool" || exit 1
exec "$CACHE/uv/bin/uv" run --no-sync python - <<'PYEOF'
try:
    from pymobiledevice3.lockdown import create_using_usbmux
except ImportError:
    print("错误: 依赖未安装，请先运行 setup.sh"); raise SystemExit(1)

def not_found(reason):
    print(f"未检测到 iPhone（{reason}）")
    print("请用 USB 数据线连接、保持屏幕解锁，弹窗时点【信任】后重试")
    raise SystemExit(1)

client = None
try:
    client = create_using_usbmux(connection_type="USB", autopair=False)
    vals = client.all_values or {}
except Exception as e:
    not_found(type(e).__name__)

if not vals.get("ProductVersion"):
    not_found("未取到设备信息，可能已拔线")

print("设备:", vals.get("DeviceName", "未知"))
print("硬件型号:", vals.get("ProductType", "未知"))
print("iOS 版本:", vals.get("ProductVersion", "未知"))
try:
    client.close()
except Exception:
    pass
PYEOF
