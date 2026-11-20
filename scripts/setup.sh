#!/bin/sh
# Apple Watch 健康功能解锁 — 工具链准备（幂等，可重复运行）
# 用法: setup.sh [--force]   (--force 重新下载源码并重建依赖)
# 缓存目录: ~/Library/Caches/accessory-location/（源码、uv、APK、MFi 身份文件）
# 网络: github.com 直连被墙时自动走 api.github.com；PyPI 走清华镜像；APK 内置 8 段并行+断点续传
set -u
[ "$(uname)" = "Darwin" ] || { echo "错误: 本技能仅支持 macOS" >&2; exit 1; }
# 防止 HOME 缺失时 CACHE 退化成 /Library/...，让后面的 rm -rf 指向系统目录
[ -n "${HOME:-}" ] && [ -d "$HOME" ] || { echo "错误: 未找到有效的 HOME 目录，拒绝继续" >&2; exit 1; }

CACHE="$HOME/Library/Caches/accessory-location"
TOOL_COMMIT="8a13296a3d81dae18ad4481e7a9eca913c2c644f"   # 2026-10-15，已实测可用版本
REPO="aur3l14no/accessory-location"
APK_ASSET_API="https://api.github.com/repos/shihabal3amri/DiPlay/releases/assets/598772337"
APK_SHA256="27b434462da7e78b1ff0987d129ed0a4b0a0e56beceaf8ec221d47150d4675bd"
APK_SIZE=32817385
APK_NAME="DiPlay-0.2.7.apk"
PYPI_INDEX="${PYPI_INDEX:-https://pypi.tuna.tsinghua.edu.cn/simple}"
N_SEG=8
mkdir -p "$CACHE"

step() { printf '\n==> %s\n' "$1"; }
die()  { printf '错误: %s\n' "$1" >&2; exit 1; }

# ---------- 1. Python ----------
step "检查 Python（需 3.11+）"
PY3="$(command -v python3 || true)"
[ -n "$PY3" ] || die "未找到 python3，请先安装 Python 3.11+（python.org 或 brew install python）"
PYV="$("$PY3" -c 'import sys; print("%d%d" % sys.version_info[:2])')"
[ "$PYV" -ge 311 ] || die "python3 版本过低，需 3.11+，当前: $("$PY3" --version 2>&1)"
echo "Python: $("$PY3" --version 2>&1)"

# ---------- 2. uv ----------
step "准备 uv（隔离安装到缓存目录，不动全局环境）"
if [ ! -x "$CACHE/uv/bin/uv" ]; then
  "$PY3" -m pip install --quiet --index-url "$PYPI_INDEX" --target "$CACHE/uv" uv \
    || die "安装 uv 失败，检查网络或换 PyPI 镜像（PYPI_INDEX 环境变量）"
fi
echo "uv: $("$CACHE/uv/bin/uv" --version 2>&1)"

# ---------- 3. 源码（固定 commit） ----------
step "准备 accessory-location 源码（commit ${TOOL_COMMIT}）"
if [ "${1:-}" = "--force" ] || [ ! -f "$CACHE/tool/.pinned-commit" ] \
   || [ "$(cat "$CACHE/tool/.pinned-commit" 2>/dev/null)" != "$TOOL_COMMIT" ]; then
  rm -rf "$CACHE/tool"; mkdir -p "$CACHE/tool"
  curl -fsSL --max-time 90 "https://api.github.com/repos/$REPO/tarball/$TOOL_COMMIT" -o "$CACHE/tool.tar.gz" \
    || die "下载源码失败（github 与 api.github.com 均不可达时检查代理）"
  tar -xzf "$CACHE/tool.tar.gz" -C "$CACHE/tool" --strip-components=1 || die "解压源码失败"
  printf '%s' "$TOOL_COMMIT" > "$CACHE/tool/.pinned-commit"
  rm -f "$CACHE/tool.tar.gz"
else
  echo "源码已缓存，跳过"
fi
[ -f "$CACHE/tool/pyproject.toml" ] || die "源码不完整，运行 setup.sh --force 重下"

# ---------- 4. 依赖 ----------
step "安装 Python 依赖（清华镜像，装到工具自己的 venv）"
if [ ! -x "$CACHE/tool/.venv/bin/accessory-location" ]; then
  ( cd "$CACHE/tool" && UV_DEFAULT_INDEX="$PYPI_INDEX" "$CACHE/uv/bin/uv" sync --python "$PY3" ) \
    || die "依赖安装失败（可重跑续传）"
else
  echo "依赖已缓存，跳过"
fi

# ---------- 5. APK（分段并行 + 断点续传 + 哈希校验） ----------
step "准备 DiPlay v0.2.7 APK（MFi 身份来源，仅提取证书用，从不安装运行）"
APK="$CACHE/$APK_NAME"
if [ -f "$APK" ] && [ "$(stat -f%z "$APK")" = "$APK_SIZE" ] \
   && [ "$(shasum -a 256 "$APK" | awk '{print $1}')" = "$APK_SHA256" ]; then
  echo "APK 已缓存且校验通过，跳过下载"
else
  mkdir -p "$CACHE/apk_parts"
  SEG_SZ=$(( (APK_SIZE + N_SEG - 1) / N_SEG ))
  pass=0
  while [ "$pass" -lt 12 ]; do
    pass=$((pass + 1))
    complete=1; i=0
    while [ "$i" -lt "$N_SEG" ]; do
      START=$(( i * SEG_SZ )); END=$(( START + SEG_SZ - 1 ))
      [ "$END" -ge "$APK_SIZE" ] && END=$((APK_SIZE - 1))
      WANT=$(( END - START + 1 )); HAVE=0
      if [ -f "$CACHE/apk_parts/part_$i" ]; then
        HAVE=$(stat -f%z "$CACHE/apk_parts/part_$i" 2>/dev/null || echo 0)
        # 上游忽略 Range 时会把整包写进单个分片；不丢弃会永久停在「已完成」假象
        if [ "$HAVE" -gt "$WANT" ]; then
          echo "  分片 $i 异常（$HAVE > ${WANT}），丢弃重下"
          rm -f "$CACHE/apk_parts/part_$i"
          HAVE=0
        fi
      fi
      [ "$HAVE" -lt "$WANT" ] && complete=0
      i=$((i + 1))
    done
    [ "$complete" = "1" ] && break
    echo "第 $pass 轮补传（国内限速约 30KB/s，整体约 15~20 分钟，可中断重跑续传）"
    SIGNED=$(curl -s --max-time 30 -H "Accept: application/octet-stream" "$APK_ASSET_API" -o /dev/null -w "%{redirect_url}")
    if [ -z "$SIGNED" ]; then
      echo "  获取签名 URL 失败（GitHub API 频控），60 秒后重试"
      sleep 60; continue
    fi
    i=0
    while [ "$i" -lt "$N_SEG" ]; do
      START=$(( i * SEG_SZ )); END=$(( START + SEG_SZ - 1 ))
      [ "$END" -ge "$APK_SIZE" ] && END=$((APK_SIZE - 1))
      WANT=$(( END - START + 1 )); HAVE=0
      [ -f "$CACHE/apk_parts/part_$i" ] && HAVE=$(stat -f%z "$CACHE/apk_parts/part_$i")
      if [ "$HAVE" -lt "$WANT" ]; then
        CODE=$(curl -fs --max-time 250 -r "$((START + HAVE))-$END" "$SIGNED" \
                 -o "$CACHE/apk_parts/rest_$i" -w "%{http_code}" 2>/dev/null) || CODE="000"
        # 只接受 206；200 表示上游忽略 Range，拼接只会产出坏分片
        if [ "$CODE" = "206" ] && [ -s "$CACHE/apk_parts/rest_$i" ]; then
          if [ "$HAVE" -gt 0 ]; then
            cat "$CACHE/apk_parts/part_$i" "$CACHE/apk_parts/rest_$i" > "$CACHE/apk_parts/new_$i" \
              && mv "$CACHE/apk_parts/new_$i" "$CACHE/apk_parts/part_$i"
          else
            mv "$CACHE/apk_parts/rest_$i" "$CACHE/apk_parts/part_$i"
          fi
        else
          echo "  分片 $i: Range 响应异常（HTTP ${CODE}），本轮跳过，下轮重试"
        fi
        rm -f "$CACHE/apk_parts/rest_$i" "$CACHE/apk_parts/new_$i"
        echo "  分片 $i: $(stat -f%z "$CACHE/apk_parts/part_$i" 2>/dev/null || echo 0) / $WANT"
      fi
      i=$((i + 1))
    done
  done
  : > "$APK"
  i=0
  while [ "$i" -lt "$N_SEG" ]; do
    [ -f "$CACHE/apk_parts/part_$i" ] || die "缺少分片 ${i}（下载未完成，直接重跑本脚本续传）"
    cat "$CACHE/apk_parts/part_$i" >> "$APK" || die "合并分片 $i 失败"
    i=$((i + 1))
  done
  if [ "$(stat -f%z "$APK")" = "$APK_SIZE" ] \
     && [ "$(shasum -a 256 "$APK" | awk '{print $1}')" = "$APK_SHA256" ]; then
    rm -rf "$CACHE/apk_parts"
    echo "APK 下载完成，SHA-256 校验通过"
  else
    die "APK 校验未通过（分片已保留；若持续失败，检查上游是否支持 Range/206，或同步更新 APK_SHA256/APK_SIZE）"
  fi
fi

# ---------- 6. 提取 MFi 身份 ----------
step "提取 MFi 身份文件"
if [ -f "$CACHE/identity/certificate.p7b" ] && [ -f "$CACHE/identity/identity.pk8" ]; then
  echo "身份文件已缓存，跳过"
else
  rm -rf "$CACHE/identity"
  ( cd "$CACHE/tool" && "$CACHE/uv/bin/uv" run --no-sync \
      python tools/import_diplay_identity.py --apk "$APK" --output-dir "$CACHE/identity" ) \
    || die "身份提取失败（APK 哈希或格式异常）"
fi

printf '\n================ 工具链就绪 ================\n'
echo "缓存目录: $CACHE"
echo "下一步: iPhone 用 USB 数据线连接 Mac（解锁屏幕、弹窗点信任），"
echo "        再运行 probe.sh 验证握手；通过后后台运行 send.sh。"
