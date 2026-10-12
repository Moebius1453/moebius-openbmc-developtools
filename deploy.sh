#!/bin/bash
# deploy.sh —— 一条命令：构建产物 → QEMU BMC → 重启服务
# 用法: ./deploy.sh <配方名>        例: ./deploy.sh meminfo

set -e    # 任何一步失败就停，不带着错误往下跑

RECIPE="${1:?用法: $0 <配方名>}"

BUILD=~/openbmc-workspace/openbmc/build/romulus
BMC=root@127.0.0.1
PORT=2222

# ① 找产物
BIN=$(ls -t $BUILD/tmp/work/*/"$RECIPE"/*/packages-split/"$RECIPE"/usr/bin/"$RECIPE" 2>/dev/null | head -1)

if [ -z "$BIN" ]; then
    echo "[错误] 没找到 $RECIPE 的产物——bitbake 跑过了吗？配方名对吗？"
    exit 1

fi

echo "[产物] $BIN"

# 从二进制所在的安装目录，找到同包的 systemd 单元
PKG_ROOT="${BIN%/usr/bin/$RECIPE}"
UNIT="$PKG_ROOT/usr/lib/systemd/system/$RECIPE.service"

if [ ! -f "$UNIT" ]; then
    echo "[错误] 没找到服务单元：$UNIT"
    exit 1
fi

echo "[单元] $UNIT"


# ② 先传 .new，再 mv 覆盖
scp -P "$PORT" "$BIN" "$BMC":/usr/bin/"$RECIPE".new
scp -P "$PORT" "$UNIT" "$BMC":/usr/lib/systemd/system/"$RECIPE".service.new

# ③ 替换二进制和单元，重新加载配置，再重启
ssh -p "$PORT" "$BMC" "
    mv /usr/bin/$RECIPE.new /usr/bin/$RECIPE &&
    mv /usr/lib/systemd/system/$RECIPE.service.new /usr/lib/systemd/system/$RECIPE.service &&
    systemctl daemon-reload &&
    systemctl restart $RECIPE.service
"


echo "[完成] $RECIPE 已更新并重启"

