#!/bin/bash
# ==========================================
# 通用 SSH 初始化脚本
# 支持 Debian/Ubuntu、CentOS/RHEL、Alpine
# 自定义端口 + 上传公钥 + 禁止密码登录
# ==========================================

# --- 参数检查 ---
NEW_PORT=$1
if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_PORT" -lt 1 ] || [ "$NEW_PORT" -gt 65535 ]; then
    echo "用法: $0 SSH_PORT"
    echo "示例: $0 24171"
    exit 1
fi

# --- 公钥 ---
PUB_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICebokf+GXMr/V8n4ukMV4e9ePFwHV2XOXk+AVUSe1AU"

# --- 写入公钥 ---
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "$PUB_KEY" > ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# --- 判断系统 & SSH 服务名 ---
if [ -f /etc/debian_version ]; then
    SSH_SERVICE="ssh"
elif [ -f /etc/redhat-release ]; then
    SSH_SERVICE="sshd"
elif [ -f /etc/alpine-release ]; then
    SSH_SERVICE="sshd"
else
    echo "当前系统未测试，可能无法正常工作"
    exit 1
fi

# --- 修改 sshd_config ---
if [ -f /etc/ssh/sshd_config ]; then
    SSHD_CONFIG="/etc/ssh/sshd_config"
elif [ -f /etc/ssh/sshd_config.d/sshd_config ]; then
    SSHD_CONFIG="/etc/ssh/sshd_config.d/sshd_config"
else
    echo "找不到 sshd_config 文件"
    exit 1
fi

# 端口
sed -i "s/^#\?Port .*/Port $NEW_PORT/" $SSHD_CONFIG || echo "Port $NEW_PORT" >> $SSHD_CONFIG
# root 登录
sed -i "s/^#\?PermitRootLogin .*/PermitRootLogin prohibit-password/" $SSHD_CONFIG || echo "PermitRootLogin prohibit-password" >> $SSHD_CONFIG
# 禁止密码登录
sed -i "s/^#\?PasswordAuthentication .*/PasswordAuthentication no/" $SSHD_CONFIG || echo "PasswordAuthentication no" >> $SSHD_CONFIG
# 确保公钥登录和空密码
grep -q "^PubkeyAuthentication" $SSHD_CONFIG || echo "PubkeyAuthentication yes" >> $SSHD_CONFIG
grep -q "^PermitEmptyPasswords" $SSHD_CONFIG || echo "PermitEmptyPasswords no" >> $SSHD_CONFIG

# --- 重启 SSH 服务 ---
if command -v systemctl >/dev/null 2>&1; then
    systemctl restart $SSH_SERVICE
else
    service $SSH_SERVICE restart
fi

echo "✅ SSH 初始化完成！请使用：ssh -p $NEW_PORT root@IP 登录"
