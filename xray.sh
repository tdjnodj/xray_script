#!/bin/bash

red() {
	echo -e "\033[31m\033[01m$1\033[0m"
}

green() {
	echo -e "\033[32m\033[01m$1\033[0m"
}

yellow() {
	echo -e "\033[33m\033[01m$1\033[0m"
}

[[ $EUID -ne 0 ]] && red "请在root用户下运行脚本" && exit 1

CMD=(
	"$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)"
	"$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)"
	"$(lsb_release -sd 2>/dev/null)"
	"$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)"
	"$(grep . /etc/redhat-release 2>/dev/null)"
	"$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')"
)

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN="\033[0m"

REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove")

for i in "${CMD[@]}"; do
	SYS="$i" && [[ -n $SYS ]] && break
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
	[[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
done

[[ -z $SYSTEM ]] && red "不支持当前VPS系统，请使用主流的操作系统" && exit 1
[[ -z $(type -P curl) ]] && ${PACKAGE_UPDATE[int]} && ${PACKAGE_INSTALL[int]} curl

set_VMess_withoutTLS() {
    echo ""
    read -p "请输入 VMess 监听端口(默认随机): " port
    [[ -z "${port}" ]] && port=$(shuf -i200-65000 -n1)
    if [[ "${port:0:1}" == "0" ]]; then
        red "端口不能以0开头"
        port=$(shuf -i200-65000 -n1)
    fi
    yellow "当前端口: $port"
    echo ""
    uuid=$(xray uuid)
    [[ -z "$uuid" ]] && red "请先安装 Xray !" && exit 1
    yellow "当前uuid: $uuid"
    echo ""
    yellow "底层传输协议: "
    yellow "1. TCP(默认)"
    yellow "2. websocket(ws) (推荐)"
    yellow "3. mKCP"
    yellow "4. HTTP/2"
    green "5. gRPC"
    echo ""
    read -p "请选择: " answer
    case $answer in
        1) transport="tcp" ;;
        2) transport="ws" ;;
        3) transport="mKCP" ;;
        4) transport="http" ;;
        5) transport="grpc" ;;
        *) transport="tcp" ;;
    esac

    if [[ "$tansport" == "tcp" ]]; then
        yellow "伪装方式: "
        yellow "1. none(默认，无伪装)"
        yellow "2. http(可免流)"
        read -p "请选择: " answer
        if [[ "$answer" == "2" ]]; then
            read -p "请输入伪装域名(不一定是自己的，默认: a.189.cn): " host
            [[ -z "$host" ]] && host="a.189.cn"
            read -p "请输入路径(以"/"开头，默认随机): " path
            while true; do
                if [[ -z "${path}" ]]; then
                    tmp=$(openssl rand -hex 6)
                    path="/$tmp"
                    break
                elif [[ "${path:0:1}" != "/" ]]; then
                    red "伪装路径必须以/开头！"
                    path=""
                else
                    break
                fi
            done
            cat >/usr/local/etc/xray/config.json <<-EOF
{
  "inbounds": [
    {
      "port": $port,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$uuid",
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "tcpSettings": {
            "header": {
                "type": "http",
                "request": {
                    "path": ["$path"],
                    "headers": {
                        "Host": ["$host"]
                    }
                },
                "response": {
                    "version": "1.1",
                    "status": "200",
                    "reason": "OK"
                }
            }
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
        echo ""
        ip=$(curl ip.sb)
        yellow "协议: VMess"
        yellow "ip: $ip"
        yellow "端口: $port"
        yellow "uuid: $uuid"
        yellow "传输模式: TCP"
        yellow "伪装类型: http"
        yellow "伪装域名: $host"
        yellow "路径: $path"
        echo ""
raw="{
  \"v\":\"2\",
  \"ps\":\"\",
  \"add\":\"${ip}\",
  \"port\":\"${port}\",
  \"id\":\"${uuid}\",
  \"aid\":\"0\",
  \"net\":\"tcp\",
  \"type\":\"http\",
  \"host\":\"${host}\",
  \"path\":\"${path}\",
  \"tls\":\"\"
}"
        link=$(echo -n ${raw} | base64 -w 0)
        shareLink="vmess://${link}"
        yellow "分享链接: "
        green "$shareLink"

        else
            cat >/usr/local/etc/xray/config.json <<-EOF
{
  "inbounds": [
    {
      "port": $port,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$uuid",
            "alterId": 0
          }
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
            echo ""
            ip=$(curl ip.sb)
            yellow "协议: VMess"
            yellow "ip: $ip"
            yellow "端口: $port"
            yellow "uuid: $uuid"
            yellow "传输模式: TCP"
            yellow "伪装类型: http"
            yellow "伪装域名: $host"
            yellow "路径: $path"
            echo ""
raw="{
  \"v\":\"2\",
  \"ps\":\"\",
  \"add\":\"${ip}\",
  \"port\":\"${port}\",
  \"id\":\"${uuid}\",
  \"aid\":\"0\",
  \"net\":\"tcp\",
  \"type\":\"none\",
  \"host\":\"\",
  \"path\":\"\",
  \"tls\":\"\"
}"
            link=$(echo -n ${raw} | base64 -w 0)
            shareLink="vmess://${link}"
            yellow "分享链接: "
            green "$shareLink"
        fi


    elif [[ "$transport" == "ws" ]]; then
        echo ""
        read -p "请输入路径(以"/"开头，默认随机): " path
        while true; do
            if [[ -z "${path}" ]]; then
                tmp=$(openssl rand -hex 6)
                path="/$tmp"
                break
            elif [[ "${path:0:1}" != "/" ]]; then
                red "伪装路径必须以/开头！"
                path=""
            else
                break
            fi
        done
        yellow "当前路径: $path"
        echo ""
        yellow "请输入ws域名: 可用于免流(默认 a.189.cn): " host
        [[ -z "$host" ]] && host="a.189.cn"
        cat >/usr/local/etc/xray/config.json <<-EOF
{
  "inbounds": [
    {
      "port": $port,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$uuid",
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network":"ws",
        "wsSettings": {
            "path": "$path",
            "headers": {
                "Host": "$host"
            }
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
        ip=$(curl ip.sb)
        echo ""
        yellow "协议: VMess"
        yellow "ip: $ip"
        yellow "端口: $port"
        yellow "uuid: $uuid"
        yellow "额外ID: 0"
        yellow "传输方式: ws(websocket)"
        yellow "路径: $path 或 ${path}?ed=2048 (后面这个延迟更低，但可能增加特征)"
        yellow "ws host(伪装域名): $host"
raw="{
  \"v\":\"2\",
  \"ps\":\"\",
  \"add\":\"${ip}\",
  \"port\":\"${port}\",
  \"id\":\"${uuid}\",
  \"aid\":\"0\",
  \"net\":\"ws\",
  \"host\":\"${host}\",
  \"path\":\"${path}\",
  \"tls\":\"\"
}"
        link=$(echo -n ${raw} | base64 -w 0)
        shareLink="vmess://${link}"
        echo ""
        yellow "分享链接: "
        green "$shareLink"


    elif [[ "$transport" == "mKCP" ]]; then
        echo ""
        yellow "下行带宽:"
        yellow "单位: MB/s，注意是 Byte 而非 bit"
        yellow "默认: 100"
        yellow "建议设置为一个较大值"
        read -p "请设置: " uplinkCapacity
        [[ -z "$uplinkCapacity" ]] && uplinkCapacity=100
        yellow "当前上行带宽: $uplinkCapacity"
        echo ""
        yellow "上行带宽: "
        yellow "单位: MB/s，注意是 Byte 而非 bit"
        yellow "默认: 100"
        yellow "建议设为你的真实上行带宽到它的两倍"
        read -p "请设置: " downlinkCapacity
        [[ -z "$downlinkCapacity" ]] && downlinkCapacity=100
        yellow "当前下行带宽: $downlinkCapacity"
        echo ""
        yellow "伪装类型: "
        yellow "1. 不伪装:none(默认)"
        yellow "2. SRTP: 伪装成 SRTP 数据包，会被识别为视频通话数据（如 FaceTime）"
        yellow "3. uTP: 伪装成 uTP 数据包，会被识别为 BT 下载数据"
        yellow "4. wechat-video: 伪装成微信视频通话的数据包"
        yellow "5. DTLS: 伪装成 DTLS 1.2 数据包"
        yellow "6. wireguard: 伪装成 WireGuard 数据包。（并不是真正的 WireGuard 协议）"
        read -p "请选择: " answer
        case $answer in
            1) camouflageType="none" ;;
            2) camouflageType="srtp" ;;
            3) camouflageType="utp" ;;
            4) camouflageType="wechat-video" ;;
            5) camouflageType="dtls" ;;
            6) camouflageType="wireguard" ;;
            *) camouflageType="none" ;;
        esac
        yellow "当前伪装: $camouflageType"
        cat >/usr/local/etc/xray/config.json <<-EOF
{
    "inbounds": [
        {
            "port": $PORT,
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid",
                        "level": 1,
                        "alterId": 0
                    }
                ]
            },
            "streamSettings": {
                "network": "mkcp",
                "kcpSettings": {
                    "uplinkCapacity": ${uplinkCapacity},
                    "downlinkCapacity": ${downlinkCapacity},
                    "congestion": true,
                    "header": {
                        "type": "${camouflageType}"
                    }
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        },
        {
            "protocol": "blackhole",
            "settings": {},
            "tag": "blocked"
        }
    ]
}
EOF
        echo ""
        ip=$(curl ip.sb)
        yellow "协议: VMess"
        yellow "传输协议: mKCP"
        yellow "ip: $ip"
        yellow "端口: $port"
        yellow "uuid: $uuid"
        yellow "额外ID: 0"
        yellow "伪装类型: $camouflageType"
        yellow "上行带宽: $uplinkCapacity"
        yellow "下行带宽: $downlinkCapacity"
        yellow "mKCP seed(混淆密码): 无"
        echo ""
raw="{
  \"v\":\"2\",
  \"ps\":\"\",
  \"add\":\"${ip}\",
  \"port\":\"${port}\",
  \"id\":\"${uuid}\",
  \"aid\":\"0\",
  \"net\":\"kcp\",
  \"type\":\"$camouflageType\",
  \"tls\":\"\"
}"
        link=$(echo -n ${raw} | base64 -w 0)
        shareLink="vmess://${link}"
        yellow "分享链接: "
        green "$shareLink"


    elif [[ "$transport" == "http" ]]; then
        red "由于本选项中不带TLS，所以不能使用 HTTP/2 作为传输方式！"
        exit 1


    elif [[ "$transport" == "gRPC" ]]; then
        echo ""
        yellow "server name: "
        yellow "作用类似于ws中的"path""
        read -p "请输入: " serverName
        while true; do
            if [[ -z "${serverName}" ]]; then
                serverName=$(openssl rand -hex 6)
                break
            else
                break
            fi
        done
        yellow "当前server name: $serverName"
        cat >/usr/local/etc/xray/config.json <<-EOF
{
    "inbounds": [
        {
            "port": "$port",
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid",
                        "alterId": 0
                    }
                ]
            },
            "streamSettings": {
                "network": "grpc",
                "grpcSettings": {
                    "serviceName": "$serviceName"
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        }
    ]
}
EOF
        ip=$(curl ip.sb)
        echo ""
        yellow "协议: VMess"
        yellow "ip: $ip"
        yellow "端口: $port"
        yellow "uuid: $uuid"
        yellow "额外ID: 0"
        yellow "传输方式: gRPC"
        yellow "server name: $serverName"
raw="{
  \"v\":\"2\",
  \"ps\":\"\",
  \"add\":\"${ip}\",
  \"port\":\"${port}\",
  \"id\":\"${uuid}\",
  \"aid\":\"0\",
  \"net\":\"grpc\",
  \"path\":\"${serverName}\",
  \"tls\":\"\"
}"
        link=$(echo -n ${raw} | base64 -w 0)
        shareLink="vmess://${link}"
        echo ""
        yellow "分享链接: "
        green "$shareLink"

        
    fi 
    systemctl stop xray
    systemctl start xray
    ufw allow $port
    ufw reload
}

set_withoutTLS() {
    echo ""
    red "警告: 可能会删除原有配置!"
    yellow "请选择协议: "
    yellow "1. VMess"
    yellow "2. shadowsocks"
    yellow "3. VLESS(由于VLESS没有加密，请勿使用VLESS直接过墙!)"
    echo ""
    read -p "请选择: " protocol
    case $protocol in
        1) set_VMess_withoutTLS ;;
        2) set_shadowsocks_withoutTLS ;;
        3) set_VLESS_withoutTLS ;;
        *) red "请输入正确的选项！" ;;
    esac
}

install_build() {
    echo ""
    yellow "请确保: "
    yellow "1. 安装了最新版本的 golang(可使用本脚本102选项) 和 git"
    yellow "2. 自愿承担使用最新版本的风险(包括各种各样的bug、协议不适配等问题)"
    echo ""
    read -p "输入任意内容继续，按 ctrl + c 退出" rubbish
    echo ""
    red "3秒冷静期"
    sleep 3
    git clone https://github.com/XTLS/Xray-core.git
    yellow "即将开始编译，可能耗时较久，请耐心等待"
    cd Xray-core && go mod download
    CGO_ENABLED=0 go build -o xray -trimpath -ldflags "-s -w -buildid=" ./main
	chmod +x xray || {
		red "Xray安装失败"
        cd ..
        rm -rf Xray-core
        rm -rf /root/go
		exit 1
	}
    systemctl stop xray
    cp xray /usr/local/bin/
    cd ..
    rm -rf Xray-core/
    mkdir /usr/local/etc/xray 
    mkdir /usr/local/share/xray
    cd /usr/local/share/xray
    curl -L -k -O https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat
    mv dlc.dat geosite.dat
    curl -L -k -O https://github.com/v2fly/geoip/releases/latest/download/geoip.dat
	cat >/etc/systemd/system/xray.service <<-EOF
		[Unit]
		Description=Xray Service
		Documentation=https://github.com/XTLS/Xray-core
		After=network.target nss-lookup.target
		
		[Service]
		User=root
		#User=nobody
		#CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
		#AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
		NoNewPrivileges=true
		ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
		Restart=on-failure
		RestartPreventExitStatus=23
		
		[Install]
		WantedBy=multi-user.target
	EOF
    systemctl daemon-reload
    systemctl enable xray.service

    echo ""
    yellow "装完了(确信)"
}

install_official() {
    echo ""
    read -p "是否手动指定 Xray 版本?不指定将安装最新稳定版(y/N): " ownVersion
    if [[ "$ownVersion" == "y" ]]; then
        read -p "请输入安装版本(不要以"v"开头): " xrayVersion
        [[ -z "xrayVersion" ]] && red "请输入有效版本号！" && exit 1
        bash -c "$(curl -L -k https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --version ${xrayVersion}
    else
        bash -c "$(curl -L -k https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    fi
}

update_system() {
    ${PACKAGE_UPDATE[int]}
    ${PACKAGE_INSTALL[int]} curl wget tar openssl
}

get_cert() {
    bash <(curl -L -k https://github.com/tdjnodj/simple-acme/releases/latest/download/simple-acme.sh)
}

install_go() {
    ${PACKAGE_INSTALL[int]} git curl
    # CPU
    bit=`uname -m`
    if [[ $bit = x86_64 ]]; then
        cpu=amd64
    elif [[ $bit = amd64 ]]; then
        cpu=amd64
    elif [[ $bit = aarch64 ]]; then
        cpu=arm64
    elif [[ $bit = armv8 ]]; then
        cpu=arm64
    elif [[ $bit = armv7 ]]; then
        cpu=arm64
    else 
        cpu=$bit
        red "可能不支持该型号( $cpu )的CPU!"
    fi
    go_version=$(curl https://go.dev/VERSION?m=text)
    red "当前最新版本golang: $go_version"
    curl -O -k -L https://go.dev/dl/${go_version}.linux-${cpu}.tar.gz
    yellow "正在解压......"
    tar -xf go*.linux-${cpu}.tar.gz -C /usr/local/
    sleep 3
    export PATH=\$PATH:/usr/local/go/bin
    rm go*.tar.gz
    cat >>/root/.bash_profile <<-EOF
export PATH=\$PATH:/usr/local/go/bin
EOF
    source /root/.bash_profile
    yellow "检查当前golang版本: "
    go version
    yellow "为确保正常安装，请手动输入: "
    red "export PATH=\$PATH:/usr/local/go/bin"
    red "source /root/.bash_profile"
    echo ""
    echo "如果错误，常见错误原因: 未删除旧的go"
}

menu() {
    clear
    red "Xray一键安装/配置脚本"
    echo ""
    yellow "1. 通过官方脚本安装 Xray"
    yellow "2. 编译安装 Xray (易失败)"
    echo ""
    echo "------------------------------------"
    echo ""
    yellow "3. 配置 Xray: 无TLS的协议"
    echo ""
    echo "------------------------------------"
    echo ""
    yellow "100. 更新系统和安装依赖"
    yellow "101. 申请TLS证书(http申请/自签)"
    yellow "102. 安装最新版本的golang 及 编译 Xray 的其他组件"
    echo ""
    echo "------------------------------------"
    echo ""
    yellow "0. 退出脚本"
    read -p "清选择: " answer
    case $answer in
        0) exit 0 ;;
        1) install_official ;;
        2) install_build ;;
        3) set_withoutTLS ;;
        100) update_system ;;
        101) get_cert ;;
        102) install_go ;;
        *) red "不存在本选项！" && exit 1 ;;
    esac
}

action=$1
[[ -z $1 ]] && action=menu

case "$action" in
	menu | update | uninstall | start | restart | stop | showInfo | showLog) ${action} ;;
	*) echo " 参数错误" && echo " 用法: $(basename $0) [menu|update|uninstall|start|restart|stop|showInfo|showLog]" ;;
esac
