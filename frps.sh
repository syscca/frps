#!/bin/bash
set -euo pipefail

function prompt() {
    while true; do
        read -p "$1 [y/N] " yn
        case $yn in
            [Yy] ) return 0;;
            [Nn]|"" ) return 1;;
        esac
    done
}

if [[ $(id -u) != 0 ]]; then
    echo 请以root用户身份运行此脚本
    exit 1
fi

if [[ $(uname -m 2> /dev/null) != x86_64 ]]; then
    echo 请在x86_64机器上运行此脚本
    exit 1
fi

FRP_NAME=frp
FRP_NAME_BIN=frps
FRP_INSTALLPREFIX=/usr/local
SYSTEMDPREFIX=/etc/systemd/system
TMPDIR="$(mktemp -d)"
FRP_VERSION=$(curl -fsSL https://api.github.com/repos/fatedier/frp/releases | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | head -n 1)
VERSION=${FRP_VERSION##*v}
NAME="${FRP_NAME}_${VERSION}_linux_amd64"
FRP_TARBALL="${FRP_NAME}_${VERSION}_linux_amd64.tar.gz"
FRP_DOWNLOADURL="https://github.com/fatedier/${FRP_NAME}/releases/download/${FRP_VERSION}/${FRP_TARBALL}"
#https://github.com/fatedier/frp/releases/download/v0.45.0/frp_0.45.0_linux_amd64.tar.gz
FRP_BINARYPATH="${FRP_INSTALLPREFIX}/bin/${FRP_NAME_BIN}"
FRP_CONFIGPATH="${FRP_INSTALLPREFIX}/etc/${FRP_NAME_BIN}.ini"
FRP_SYSTEMDPATH="${SYSTEMDPREFIX}/${FRP_NAME_BIN}.service"

echo "进入临时文件夹 $TMPDIR..."
cd "$TMPDIR"

echo "下载 ${FRP_DOWNLOADURL}..."
curl -LO --progress-bar "${FRP_DOWNLOADURL}" || wget -q --show-progress "${FRP_DOWNLOADURL}"

echo "解压 ${FRP_TARBALL}..."
tar -zxf "${FRP_TARBALL}"
cd "$NAME"

echo 安装 $FRP_BINARYPATH...
install -Dm755 "$FRP_NAME_BIN" "$FRP_BINARYPATH"

if [[ -f "${FRP_CONFIGPATH}" ]];then
  echo "${FRP_CONFIGPATH}文件存在"
  else
echo "写入 ${FRP_CONFIGPATH}..."
cat > "${FRP_CONFIGPATH}" << EOF
[common]
bind_addr = 0.0.0.0
bind_port = 7000
bind_udp_port = 7900
kcp_bind_port = 7000
vhost_http_port = 8000
vhost_https_port = 7443
dashboard_addr = 0.0.0.0
dashboard_port = 7700
dashboard_user = 管理用户
dashboard_pwd = 管理密码
token = 密码
allow_ports = 7000-8000
max_pool_count = 20
max_ports_per_client = 0
subdomain_host = frps.syscca.com
tcp_mux = true
EOF
fi

if [[ -f "${FRP_SYSTEMDPATH}" ]];then
  echo "${FRP_SYSTEMDPATH}文件存在"
  else
echo "正在创建 ${FRP_SYSTEMDPATH}..."
        cat > "$FRP_SYSTEMDPATH" << EOF
[Unit]
Description=frps server
Documentation=https://github.com/fatedier/frp
After=network-online.target
Wants=network-online.target

[Service]
ExecStart="${FRP_BINARYPATH}" -c "${FRP_CONFIGPATH}"
Type=simple
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF
fi

echo "Reloading systemd daemon..."
systemctl daemon-reload

if systemctl is-active --quiet frps; then
echo "强制停止和禁止 nginx..."
killall -9 frps
systemctl disable frps
else
echo "frps没有运行"
fi

echo "restart frps..."
systemctl restart frps

echo "enable frps..."
systemctl enable frps

echo Deleting temp directory $TMPDIR...
rm -rf "$TMPDIR"

echo Done!
