#!/bin/bash
# 从第一个参数读取端口
NEW_PORT=$1
if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_PORT" -lt 1 ] || [ "$NEW_PORT" -gt 65535 ]; then
    echo "端口号不合法！请输入 1-65535 之间的数字。"
    exit 1
fi

# 公钥
PUB_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICebokf+GXMr/V8n4ukMV4e9ePFwHV2XOXk+AVUSe1AU"

# 写入公钥
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "$PUB_KEY" > ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# 修改 sshd_config
SSHD_CONFIG="/etc/ssh/sshd_config"
sed -i "s/^#\?Port .*/Port $NEW_PORT/" $SSHD_CONFIG
sed -i "s/^#\?PermitRootLogin .*/PermitRootLogin prohibit-password/" $SSHD_CONFIG
sed -i "s/^#\?PasswordAuthentication .*/PasswordAuthentication no/" $SSHD_CONFIG

grep -q "^PubkeyAuthentication" $SSHD_CONFIG || echo "PubkeyAuthentication yes" >> $SSHD_CONFIG
grep -q "^PermitEmptyPasswords" $SSHD_CONFIG || echo "PermitEmptyPasswords no" >> $SSHD_CONFIG

# 重启 ssh
systemctl restart ssh

echo "✅ 配置完成！请用 ssh -p $NEW_PORT root@IP 登录"
