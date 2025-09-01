#!/bin/bash
# ==========================================
# 通用跨系统 SSH 初始化脚本
# 支持 Debian/Ubuntu、RockyLinux/CentOS/RHEL、Alpine 3.16~3.19
# 功能：
# - 自定义端口
# - 自定义 root 公钥
# - 禁止密码登录
# - 安全配置 UsePAM、Subsystem
# ==========================================

set -e

echo "🔹 SSH 初始化脚本启动 🔹"

# --- 检测系统类型 ---
OS=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
fi

# --- 获取交互输入或环境变量 ---
# SSH端口
while true; do
    if [ -n "$SSH_PORT" ]; then
        NEW_PORT=$SSH_PORT
    else
        read -p "请输入 SSH 端口 (1-65535): " NEW_PORT </dev/tty
    fi
    if [[ "$NEW_PORT" =~ ^[0-9]+$ ]] && [ "$NEW_PORT" -ge 1 ] && [ "$NEW_PORT" -le 65535 ]; then
        break
    else
        echo "❌ 端口号不合法，请输入 1-65535 之间的数字" </dev/tty
        unset SSH_PORT
    fi
done

# SSH公钥
while true; do
    if [ -n "$SSH_PUBKEY" ]; then
        PUB_KEY="$SSH_PUBKEY"
    else
        read -p "请输入 root 公钥 (ssh-ed25519/ssh-rsa 开头): " PUB_KEY </dev/tty
    fi
    if [[ "$PUB_KEY" =~ ^ssh-(ed25519|rsa) ]]; then
        break
    else
        echo "❌ 公钥格式不合法，请重新输入" </dev/tty
        unset SSH_PUBKEY
    fi
done

# --- 写入公钥 ---
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "$PUB_KEY" > ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo "✅ 公钥已写入 ~/.ssh/authorized_keys"

# --- 修改 sshd_config ---
SSHD_CONFIG="/etc/ssh/sshd_config"

# 备份原配置
cp -f "$SSHD_CONFIG" "${SSHD_CONFIG}.bak.$(date +%s)"

# 基础配置
cat > "$SSHD_CONFIG" << EOF
Port $NEW_PORT
Protocol 2
PermitRootLogin prohibit-password
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PermitEmptyPasswords no
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

# --- 重启 SSH 服务 ---
if command -v systemctl >/dev/null 2>&1; then
    systemctl restart ssh || systemctl restart sshd
elif command -v service >/dev/null 2>&1; then
    service ssh restart || service sshd restart
else
    echo "❌ 无法重启 SSH 服务，请手动重启"
fi

# --- 输出完成信息 ---
echo "✅ SSH 初始化完成！请使用：ssh -p $NEW_PORT root@IP 登录"
