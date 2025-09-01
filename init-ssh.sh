#!/bin/bash
# ==========================================
# 通用跨系统 SSH 初始化脚本（交互版，输入可重试）
# 支持 Debian/Ubuntu、RockyLinux/CentOS/RHEL、Alpine 3.16~3.19
# 功能：
# - 自定义端口
# - 自定义 root 公钥
# - 禁止密码登录
# - 保证 UsePAM、Subsystem 配置安全
# ==========================================

set -e

echo "🔹 SSH 初始化脚本启动 🔹"

# --- 交互式输入 SSH 端口 ---
while true; do
    read -p "请输入 SSH 端口 (1-65535): " NEW_PORT
    if [[ "$NEW_PORT" =~ ^[0-9]+$ ]] && [ "$NEW_PORT" -ge 1 ] && [ "$NEW_PORT" -le 65535 ]; then
        break
    else
        echo "❌ 端口号不合法，请输入 1-65535 之间的数字"
    fi
done

# --- 交互式输入 SSH 公钥 ---
while true; do
    read -p "请输入 root 公钥 (ssh-ed25519/ssh-rsa 开头): " PUB_KEY
    if [[ "$PUB_KEY" =~ ^ssh-(ed25519|rsa) ]]; then
        break
    else
        echo "❌ 公钥格式不合法，请重新输入"
    fi
done

# --- 写入公钥 ---
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "$PUB_KEY" > ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo "✅ 公钥已写入 ~/.ssh/authorized_keys"

# --- 判断系统类型 & SSH 服务名 & SFTP 路径 & UsePAM ---
if [ -f /etc/debian_version ]; then
    SSH_SERVICE="ssh"
    USE_PAM="yes"
    if [ -f /usr/lib/openssh/sftp-server ]; then
        SFTP_PATH="/usr/lib/openssh/sftp-server"
    else
        SFTP_PATH="/usr/lib/ssh/sftp-server"
    fi
elif [ -f /etc/redhat-release ]; then
    SSH_SERVICE="sshd"
    USE_PAM="yes"
    SFTP_PATH="/usr/libexec/openssh/sftp-server"
elif [ -f /etc/alpine-release ]; then
    SSH_SERVICE="sshd"
    USE_PAM="no"
    SFTP_PATH="/usr/libexec/sftp-server"
else
    echo "⚠️ 当前系统未测试，可能无法正常工作"
    exit 1
fi

# --- 查找 sshd_config ---
if [ -f /etc/ssh/sshd_config ]; then
    SSHD_CONFIG="/etc/ssh/sshd_config"
elif [ -f /etc/ssh/sshd_config.d/sshd_config ]; then
    SSHD_CONFIG="/etc/ssh/sshd_config.d/sshd_config"
else
    echo "❌ 找不到 sshd_config 文件"
    exit 1
fi

# --- 修改必要字段 ---
modify_or_append() {
    local key="$1"
    local value="$2"
    grep -q "^$key" "$SSHD_CONFIG" && sed -i "s|^$key.*|$key $value|" "$SSHD_CONFIG" || echo "$key $value" >> "$SSHD_CONFIG"
}

modify_or_append "Port" "$NEW_PORT"
modify_or_append "PermitRootLogin" "prohibit-password"
modify_or_append "PasswordAuthentication" "no"
modify_or_append "PubkeyAuthentication" "yes"
modify_or_append "PermitEmptyPasswords" "no"
modify_or_append "UsePAM" "$USE_PAM"
modify_or_append "Subsystem" "sftp $SFTP_PATH"
modify_or_append "ChallengeResponseAuthentication" "no"
modify_or_append "X11Forwarding" "no"
modify_or_append "Protocol" "2"

# --- 重启 SSH 服务 ---
if command -v systemctl >/dev/null 2>&1; then
    systemctl restart $SSH_SERVICE
else
    service $SSH_SERVICE restart
fi

echo "✅ SSH 初始化完成！请使用：ssh -p $NEW_PORT root@IP 登录"
