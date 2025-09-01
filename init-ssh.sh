#!/bin/bash
# 统一设置 SSH 公钥 & 配置（可自定义端口）

# 1. 交互式输入端口
read -p "请输入 SSH 端口号（1-65535）： " NEW_PORT
if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_PORT" -lt 1 ] || [ "$NEW_PORT" -gt 65535 ]; then
    echo "端口号不合法！请输入 1-65535 之间的数字。"
    exit 1
fi

# 2. 设置公钥
PUB_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICebokf+GXMr/V8n4ukMV4e9ePFwHV2XOXk+AVUSe1AU"

# 3. 写入公钥
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "$PUB_KEY" > ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# 4. 修改 sshd_config
SSHD_CONFIG="/etc/ssh/sshd_config"
sed -i "s/^#\?Port .*/Port $NEW_PORT/" $SSHD_CONFIG
sed -i "s/^#\?PermitRootLogin .*/PermitRootLogin prohibit-password/" $SSHD_CONFIG
sed -i "s/^#\?PasswordAuthentication .*/PasswordAuthentication no/" $SSHD_CONFIG

# 确保必要选项存在
grep -q "^PubkeyAuthentication" $SSHD_CONFIG || echo "PubkeyAuthentication yes" >> $SSHD_CONFIG
grep -q "^PermitEmptyPasswords" $SSHD_CONFIG || echo "PermitEmptyPasswords no" >> $SSHD_CONFIG

# 5. 重启 ssh
systemctl restart ssh

echo "✅ 配置完成！请用 ssh -p $NEW_PORT root@IP 登录"
