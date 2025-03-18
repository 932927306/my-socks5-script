#!/usr/bin/env bash

#====================================================
# 一键安装 Dante SOCKS5 服务 (TCP + UDP) - PAM 认证版
# 适用系统：Debian 11.11（含AWS环境）
# 默认监听端口：6080
# 默认系统用户：myproxy
# 默认密码：mypassword
#====================================================

# 1. 必须以 root 身份执行
if [ "$(id -u)" != "0" ]; then
  echo "请使用 root 用户执行此脚本！"
  exit 1
fi

# 2. 更新系统并安装 dante-server
apt update -y
apt install -y dante-server

# 3. 自动检测默认网卡名称 (如eth0, ens3等)
NET_INTERFACE=$(ip route show default | awk '/default/ {print $5}')
if [ -z "$NET_INTERFACE" ]; then
  # 如果无法检测到，则可手动指定
  NET_INTERFACE="eth0"
fi

# 4. 备份旧配置并生成新的 /etc/danted.conf (使用 PAM)
mv /etc/danted.conf /etc/danted.conf.bak 2>/dev/null

cat << EOF > /etc/danted.conf
# 日志输出到 syslog
logoutput: syslog

# 以 danted 默认用户 (proxy) 运行，降低权限后使用 nobody
user.privileged: proxy
user.notprivileged: nobody

# 监听端口：6080；监听所有 IPv4
internal: 0.0.0.0 port = 6080

# 出口网卡
external: $NET_INTERFACE

# 使用 PAM 做 SOCKS5 认证
socksmethod: pam

# 客户端连接时无需提供额外 method
clientmethod: none

# 允许哪些客户端可以连接
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect
}

# 允许访问哪些目标，以及哪些协议
pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    protocol: tcp udp
    log: error
}
EOF

# 5. 确保 /etc/pam.d/danted 存在并启用 pam_unix.so
#   Debian 通常自带此文件，也可能叫 /etc/pam.d/sockd
#   如果不存在，就自动创建一个最简配置
if [ ! -f /etc/pam.d/danted ]; then
  cat << PAM_EOF > /etc/pam.d/danted
auth    required   pam_unix.so
account required   pam_unix.so
PAM_EOF
fi

# 6. 创建一个测试用的系统用户和密码 (myproxy / mypassword)
#    你可自行修改为其他用户名、密码
SOCKS5_USER="2025"
SOCKS5_PASS="123456"

# 若用户不存在则创建
id -u "$SOCKS5_USER" &>/dev/null || useradd -m -s /bin/bash "$SOCKS5_USER"
echo "${SOCKS5_USER}:${SOCKS5_PASS}" | chpasswd

# 7. 启动并设置开机自启
systemctl enable danted
systemctl restart danted

# 8. 输出结果
echo "====================================================="
echo "Dante SOCKS5 (PAM版) 已安装并启动完毕!"
echo "监听端口 : 6080 (TCP + UDP)"
echo "系统用户 : $SOCKS5_USER"
echo "密码     : $SOCKS5_PASS"
echo "外网网卡 : $NET_INTERFACE"
echo "配置文件 : /etc/danted.conf"
echo "PAM配置 : /etc/pam.d/danted"
echo "如需更改端口/网卡/用户/密码，请相应修改后重启服务。"
echo "====================================================="
