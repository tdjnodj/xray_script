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

[[ $EUID -ne 0 ]] && red "Please run the script under the root user" && exit 1

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

[[ -z $SYSTEM ]] && red "Current VPS systems are not supported, please use a mainstream operating system" && exit 1
[[ -z $(type -P curl) ]] && ${PACKAGE_UPDATE[int]} && ${PACKAGE_INSTALL[int]} curl

SITES=(
	http://www.zhuizishu.com/
	http://xs.56dyc.com/
	http://www.ddxsku.com/
	http://www.biqu6.com/
	https://www.wenshulou.cc/
	http://www.55shuba.com/
	http://www.39shubao.com/
	https://www.23xsw.cc/
	https://www.jueshitangmen.info/
	https://www.zhetian.org/
	http://www.bequgexs.com/
	http://www.tjwl.com/
)

CONFIG_FILE="/usr/local/etc/xray/config.json"

IP6=$(curl -s6m8 ip.sb)

IP4=$(curl -s4m8 ip.sb)

BT="false"
NGINX_CONF_PATH="/etc/nginx/conf.d/"
res=$(which bt 2>/dev/null)
[[ "$res" != "" ]] && BT="true" && NGINX_CONF_PATH="/www/server/panel/vhost/nginx/"

VLESS="false"
TROJAN="false"
TLS="false"
WS="false"
XTLS="false"
KCP="false"

checkCentOS8() {
	if [[ -n $(cat /etc/os-release | grep "CentOS Linux 8") ]]; then
		yellow "The current VPS system is detected as CentOS 8, is it upgraded to CentOS Stream 8 to ensure the package is installed properly?"
		read -p "请输入选项 [y/n]：" comfirmCentOSStream
		if [[ $comfirmCentOSStream == "y" ]]; then
			yellow "It is being upgraded to CentOS Stream 8 for you and will take about 10-30 minutes"
			sleep 1
			sed -i -e "s|releasever|releasever-stream|g" /etc/yum.repos.d/CentOS-*
			yum clean all && yum makecache
			dnf swap centos-linux-repos centos-stream-repos distro-sync -y
		else
			red "The upgrade process has been cancelled and the script is about to exit!"
			exit 1
		fi
	fi
}

configNeedNginx() {
	local ws=$(grep wsSettings $CONFIG_FILE)
	[[ -z "$ws" ]] && echo no && return
	echo yes
}

needNginx() {
	[[ "$WS" == "false" ]] && echo no && return
	echo yes
}

status() {
	[[ ! -f /usr/local/bin/xray ]] && echo 0 && return
	[[ ! -f $CONFIG_FILE ]] && echo 1 && return
	port=$(grep port $CONFIG_FILE | head -n 1 | cut -d: -f2 | tr -d \",' ')
	res=$(ss -nutlp | grep ${port} | grep -i xray)
	[[ -z "$res" ]] && echo 2 && return

	if [[ $(configNeedNginx) != "yes" ]]; then
		echo 3
	else
		res=$(ss -nutlp | grep -i nginx)
		if [[ -z "$res" ]]; then
			echo 4
		else
			echo 5
		fi
	fi
}

statusText() {
	res=$(status)
	case $res in
		2) echo -e ${GREEN}Installed${PLAIN} ${RED}unrun${PLAIN} ;;
		3) echo -e ${GREEN}Installed${PLAIN} ${GREEN}Xray is running.${PLAIN} ;;
		4) echo -e ${GREEN}Installed${PLAIN} ${GREEN}Xray is running.${PLAIN}, ${RED}Nginx is not running${PLAIN} ;;
		5) echo -e ${GREEN}Installed${PLAIN} ${GREEN}Xray is running, Nginx is running${PLAIN} ;;
		*) echo -e ${RED}未安装${PLAIN} ;;
	esac
}

normalizeVersion() {
	latestXrayVer=v$(curl -Ls "https://data.jsdelivr.com/v1/package/resolve/gh/XTLS/Xray-core" | grep '"version":' | sed -E 's/.*"([^"]+)".*/\1/')
	if [ -n "$1" ]; then
		case "$1" in
			v*) echo "$1" ;;
			http*) echo $latestXrayVer ;;
			*) echo "v$1" ;;
		esac
	else
		echo ""
	fi
}

# 1: new Xray. 0: no. 1: yes. 2: not installed. 3: check failed.
getVersion() {
	VER=$(/usr/local/bin/xray version 2>/dev/null | head -n1 | awk '{print $2}')
	RETVAL=$?
	CUR_VER="$(normalizeVersion "$(echo "$VER" | head -n 1 | cut -d " " -f2)")"
	TAG_URL="https://data.jsdelivr.com/v1/package/resolve/gh/XTLS/Xray-core"
	NEW_VER="$(normalizeVersion "$(curl -s "${TAG_URL}" --connect-timeout 10 | grep 'version' | cut -d\" -f4)")"

	if [[ $? -ne 0 ]] || [[ $NEW_VER == "" ]]; then
		red "Failed to detect Xray version, may be VPS network error, please check and retry"
		return 3
	elif [[ $RETVAL -ne 0 ]]; then
		return 2
	elif [[ $NEW_VER != $CUR_VER ]]; then
		return 1
	fi
	return 0
}

archAffix() {
	case "$(uname -m)" in
		i686 | i386) echo '32' ;;
		x86_64 | amd64) echo '64' ;;
		armv5tel) echo 'arm32-v5' ;;
		armv6l) echo 'arm32-v6' ;;
		armv7 | armv7l) echo 'arm32-v7a' ;;
		armv8 | aarch64) echo 'arm64-v8a' ;;
		mips64le) echo 'mips64le' ;;
		mips64) echo 'mips64' ;;
		mipsle) echo 'mips32le' ;;
		mips) echo 'mips32' ;;
		ppc64le) echo 'ppc64le' ;;
		ppc64) echo 'ppc64' ;;
		ppc64le) echo 'ppc64le' ;;
		riscv64) echo 'riscv64' ;;
		s390x) echo 's390x' ;;
		*) red " Unsupported CPU architectures！" && exit 1 ;;
	esac

	return 0
}

getData() {
	if [[ "$TLS" == "true" || "$XTLS" == "true" ]]; then
		echo ""
		echo "Xray one-click script, please make sure the following conditions are in place before running："
		yellow " 1. A domain name"
		yellow " 2. domain DNS resolution to point to current server ip（${IP4} perhaps ${IP6}）"
		yellow " 3. If the xray.pem and xray.key certificate key files are available in the /root directory, ignore condition 2"
		echo " "
		read -p "Press y to confirm that the above conditions are met and press other keys to exit the script：" answer
		[[ "${answer,,}" != "y" ]] && exit 1
		echo ""
		while true; do
			read -p "Please enter a domain name：" DOMAIN
			if [[ -z "${DOMAIN}" ]]; then
				red " Domain name entered incorrectly, please re-enter！"
			else
				break
			fi
		done
		DOMAIN=${DOMAIN,,}
		yellow "Spoofed domain names(host)：$DOMAIN"
		echo ""
		if [[ -f ~/xray.pem && -f ~/xray.key ]]; then
			yellow "Own certificate detected, will deploy with own certificate"
			CERT_FILE="/usr/local/etc/xray/${DOMAIN}.pem"
			KEY_FILE="/usr/local/etc/xray/${DOMAIN}.key"
		else
			resolve=$(curl -sm8 ipget.net/?ip=${DOMAIN})
			if [[ $resolve != $IP6 ]] && [[ $resolve != $IP6 ]]; then
				yellow "${DOMAIN} parsing result：${resolve}"
				red "Domain name not resolving to current server IP(${IP4} perhaps ${IP6})！"
				green "The recommendations are as follows："
				yellow " 1. Please ensure that Cloudflare is turned off (DNS only), same for other DNS site settings"
				yellow " 2. Please check if the IP of the DNS resolution setting is the IP of the VPS"
				yellow " 3. The script may not be up to date, suggest screenshots to post to GitHub Issues or the TG group to ask"
				exit 1
			fi
		fi
	fi
	echo ""
	if [[ "$(needNginx)" == "no" ]]; then
		if [[ "$TLS" == "true" ]]; then
			read -p "Please enter the xray listening port [default 443]：" PORT
			[[ -z "${PORT}" ]] && PORT=443
		else
			read -p "Please enter the xray listening port [a number from 100-65535]：" PORT
			[[ -z "${PORT}" ]] && PORT=$(shuf -i200-65000 -n1)
			if [[ "${PORT:0:1}" == "0" ]]; then
				red "Ports cannot start with 0"
				exit 1
			fi
		fi
		yellow "xray port：$PORT"
	else
		read -p "Please enter the Nginx listening port [a number from 100-65535, default 443]：" PORT
		[[ -z "${PORT}" ]] && PORT=443
		[ "${PORT:0:1}" = "0" ] && red "Ports cannot start with 0" && exit 1
		yellow " Nginx ports：$PORT"
		XPORT=$(shuf -i10000-65000 -n1)
	fi
	if [[ "$KCP" == "true" ]]; then
		echo ""
		yellow "Please select the type of camouflage："
		echo "   1) not"
		echo "   2) BT Download"
		echo "   3) Video calls"
		echo "   4) WeChat Video Call"
		echo "   5) dtls"
		echo "   6) wiregard"
		read -p "Please select the type of camouflage [default: none]：" answer
		case $answer in
			2) HEADER_TYPE="utp" ;;
			3) HEADER_TYPE="srtp" ;;
			4) HEADER_TYPE="wechat-video" ;;
			5) HEADER_TYPE="dtls" ;;
			6) HEADER_TYPE="wireguard" ;;
			*) HEADER_TYPE="none" ;;
		esac
		yellow "Type of camouflage：$HEADER_TYPE"
		SEED=$(cat /proc/sys/kernel/random/uuid)
	fi
	if [[ "$TROJAN" == "true" ]]; then
		echo ""
		read -p "Please set trojan password (randomly generated if you don't enter):" PASSWORD
		[[ -z "$PASSWORD" ]] && PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
		yellow " trojan password：$PASSWORD"
	fi
	if [[ "$XTLS" == "true" ]]; then
		echo ""
		yellow "Please select the flow control mode:"
		echo -e "   1) xtls-rprx-direct [$REDrecommend$PLAIN]"
		echo "   2) xtls-rprx-origin"
        echo -e "   3) xtls-rprx-vision [$REDRecommended, but not perfect yet, only vless can use!!!$PLAIN]"
		read -p "Please select the flow control mode [default:direct]" answer
		[[ -z "$answer" ]] && answer=1
		case $answer in
			1) FLOW="xtls-rprx-direct" ;;
			2) FLOW="xtls-rprx-origin" ;;
            3) FLOW="xtls-rprx-vision" ;;
			*) red "Invalid option, use the default xtls-rprx-direct" && FLOW="xtls-rprx-direct" ;;
		esac
		yellow "flow control mode：$FLOW"
	fi
	if [[ "${WS}" == "true" ]]; then
		echo ""
		while true; do
			read -p "Please enter the camouflage path, starting with / (please just enter if you don't understand)：" WSPATH
			if [[ -z "${WSPATH}" ]]; then
				len=$(shuf -i5-12 -n1)
				ws=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $len | head -n 1)
				WSPATH="/$ws"
				break
			elif [[ "${WSPATH:0:1}" != "/" ]]; then
				red "The disguise path must start with /！"
			elif [[ "${WSPATH}" == "/" ]]; then
				red "Cannot use root path！"
			else
				break
			fi
		done
		yellow "ws path：$WSPATH"
	fi
	if [[ "$TLS" == "true" || "$XTLS" == "true" ]]; then
		echo ""
		yellow "Please select the type of camouflage station:"
		echo "   1) Static website (located at /usr/share/nginx/html)"
		echo "   2) Novel Station (much lapsed, suggest going custom)"
		echo "   3) HD Wallpaper Station (https://bing.wallpaper.pics)"
		echo "   4) Custom anti-generation site (needs to start with http or https))"
		read -p "Please select a disguise site type [Default: HD Wallpaper Station]：" answer
		if [[ -z "$answer" ]]; then
			PROXY_URL="https://bing.wallpaper.pics"
		else
			case $answer in
				1) PROXY_URL="" ;;
				2)
					len=${#SITES[@]}
					((len--))
					while true; do
						index=$(shuf -i0-${len} -n1)
						PROXY_URL=${SITES[$index]}
						host=$(echo ${PROXY_URL} | cut -d/ -f3)
						ip=$(curl -sm8 ipget.net/?ip=${host})
						res=$(echo -n ${ip} | grep ${host})
						if [[ "${res}" == "" ]]; then
							echo "$ip $host" >>/etc/hosts
							break
						fi
					done
					;;
				3) PROXY_URL="https://bing.wallpaper.pics" ;;
				4)
					read -p "Please enter the reverse proxy site (starting with http or https))：" PROXY_URL
					if [[ -z "$PROXY_URL" ]]; then
						red "请输入反代网站！"
						exit 1
					elif [[ "${PROXY_URL:0:4}" != "http" ]]; then
						red "Anti-generation sites must start with http or https！"
						exit 1
					fi
					;;
				*) red "Please enter the correct option！" && exit 1 ;;
			esac
		fi
		REMOTE_HOST=$(echo ${PROXY_URL} | cut -d/ -f3)
		yellow "Fake website：$PROXY_URL"
		echo ""
		yellow "Whether to allow search engines to crawl the site？[Default: not allowed]"
		echo "   y)Allowed, there will be more ip requests to the site, but it will consume some traffic, recommended if vps traffic is sufficient"
		echo "   n)Not allowed, the crawlers won't visit the site, the access ip is more single, but it saves vps traffic"
		read -p "Please select：[y/n]" answer
		if [[ -z "$answer" ]]; then
			ALLOW_SPIDER="n"
		elif [[ "${answer,,}" == "y" ]]; then
			ALLOW_SPIDER="y"
		else
			ALLOW_SPIDER="n"
		fi
		yellow "Allow search engines：$ALLOW_SPIDER"
	fi
	echo ""
	read -p "Whether to install BBR (default installation)?[y/n]:" NEED_BBR
	[[ -z "$NEED_BBR" ]] && NEED_BBR=y
	[[ "$NEED_BBR" == "Y" ]] && NEED_BBR=y
	yellow "Installation of BBR：$NEED_BBR"
}

installNginx() {
	echo ""
	yellow "nginx is being installed..."
	if [[ "$BT" == "false" ]]; then
		if [[ $SYSTEM == "CentOS" ]]; then
			${PACKAGE_INSTALL[int]} epel-release
			if [[ "$?" != "0" ]]; then
				echo '[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/$releasever/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true' >/etc/yum.repos.d/nginx.repo
			fi
		fi
		${PACKAGE_INSTALL[int]} nginx
		if [[ "$?" != "0" ]]; then
			red "Nginx installation failed！"
			green "The recommendations are as follows："
			yellow "1. Check the network settings and software source settings of the VPS system, it is highly recommended to use the official software source of the system！"
			yellow "2. The script may not be up to date, suggest screenshots to post to GitHub Issues or the TG group to ask"
			exit 1
		fi
		systemctl enable nginx
	else
		res=$(which nginx 2>/dev/null)
		if [[ "$?" != "0" ]]; then
			red "You have pagoda installed, please install nginx in the pagoda backend before running this script"
			exit 1
		fi
	fi
}

startNginx() {
	if [[ "$BT" == "false" ]]; then
		systemctl start nginx
	else
		nginx -c /www/server/nginx/conf/nginx.conf
	fi
}

stopNginx() {
	if [[ "$BT" == "false" ]]; then
		systemctl stop nginx
	else
		res=$(ps aux | grep -i nginx)
		if [[ "$res" != "" ]]; then
			nginx -s stop
		fi
	fi
}

getCert() {
	mkdir -p /usr/local/etc/xray
	if [[ -z ${CERT_FILE+x} ]]; then
		stopNginx
		systemctl stop xray
		res=$(netstat -ntlp | grep -E ':80 |:443 ')
		if [[ "${res}" != "" ]]; then
			red "Other processes are occupying port 80 or 443, please close them first before running the one-click script"
			echo " The port occupancy information is as follows："
			echo ${res}
			exit 1
		fi
		${PACKAGE_INSTALL[int]} socat openssl
		if [[ $SYSTEM == "CentOS" ]]; then
			${PACKAGE_INSTALL[int]} cronie
			systemctl start crond
			systemctl enable crond
		else
			${PACKAGE_INSTALL[int]} cron
			systemctl start cron
			systemctl enable cron
		fi
		autoEmail=$(date +%s%N | md5sum | cut -c 1-32)
		curl -sL https://get.acme.sh | sh -s email=$autoEmail@gmail.com
		source ~/.bashrc
		~/.acme.sh/acme.sh --upgrade --auto-upgrade
		~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
		if [[ $BT == "false" ]]; then
			if [[ -n $(curl -sm8 ip.sb | grep ":") ]]; then
				~/.acme.sh/acme.sh --issue -d $DOMAIN --keylength ec-256 --pre-hook "systemctl stop nginx" --post-hook "systemctl restart nginx" --standalone --listen-v6
			else
				~/.acme.sh/acme.sh --issue -d $DOMAIN --keylength ec-256 --pre-hook "systemctl stop nginx" --post-hook "systemctl restart nginx" --standalone
			fi
		else
			if [[ -n $(curl -sm8 ip.sb | grep ":") ]]; then
				~/.acme.sh/acme.sh --issue -d $DOMAIN --keylength ec-256 --pre-hook "nginx -s stop || { echo -n ''; }" --post-hook "nginx -c /www/server/nginx/conf/nginx.conf || { echo -n ''; }" --standalone --listen-v6
			else
				~/.acme.sh/acme.sh --issue -d $DOMAIN --keylength ec-256 --pre-hook "nginx -s stop || { echo -n ''; }" --post-hook "nginx -c /www/server/nginx/conf/nginx.conf || { echo -n ''; }" --standalone
			fi
		fi
		[[ -f ~/.acme.sh/${DOMAIN}_ecc/ca.cer ]] || {
			red "Sorry, certificate request failed"
			green "The recommendations are as follows："
			yellow " 1. Check whether the firewall is open, if the firewall is on, please close the firewall or release port 80"
			yellow " 2. Multiple applications for the same domain name triggers Acme.sh official risk control, please change the domain name or wait 7 days before trying to execute the script"
			yellow " 3. The script may not be up to date, suggest screenshots to post to GitHub Issues or the TG group to ask"
			exit 1
		}
		CERT_FILE="/usr/local/etc/xray/${DOMAIN}.pem"
		KEY_FILE="/usr/local/etc/xray/${DOMAIN}.key"
		~/.acme.sh/acme.sh --install-cert -d $DOMAIN --ecc \
		--key-file $KEY_FILE \
		--fullchain-file $CERT_FILE \
		--reloadcmd "service nginx force-reload"
		[[ -f $CERT_FILE && -f $KEY_FILE ]] || {
			red "Sorry, certificate request failed"
			green "The recommendations are as follows："
			yellow " 1. Check whether the firewall is open, if the firewall is on, please close the firewall or release port 80"
			yellow " 2. Multiple applications for the same domain name triggers Acme.sh official risk control, please change the domain name or wait 7 days before trying to execute the script"
			yellow " 3. The script may not be up to date, suggest screenshots to post to GitHub Issues or the TG group to ask"
			exit 1
		}
	else
		cp ~/xray.pem /usr/local/etc/xray/${DOMAIN}.pem
		cp ~/xray.key /usr/local/etc/xray/${DOMAIN}.key
	fi
}

configNginx() {
	mkdir -p /usr/share/nginx/html
	if [[ "$ALLOW_SPIDER" == "n" ]]; then
		echo 'User-Agent: *' >/usr/share/nginx/html/robots.txt
		echo 'Disallow: /' >>/usr/share/nginx/html/robots.txt
		ROBOT_CONFIG="    location = /robots.txt {}"
	else
		ROBOT_CONFIG=""
	fi

	if [[ "$BT" == "false" ]]; then
		if [[ ! -f /etc/nginx/nginx.conf.bak ]]; then
			mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
		fi
		res=$(id nginx 2>/dev/null)
		if [[ "$?" != "0" ]]; then
			user="www-data"
		else
			user="nginx"
		fi
		cat >/etc/nginx/nginx.conf <<-EOF
			user $user;
			worker_processes auto;
			error_log /var/log/nginx/error.log;
			pid /run/nginx.pid;
			
			# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
			include /usr/share/nginx/modules/*.conf;
			
			events {
			    worker_connections 1024;
			}
			
			http {
			    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
			                      '\$status \$body_bytes_sent "\$http_referer" '
			                      '"\$http_user_agent" "\$http_x_forwarded_for"';
			
			    access_log  /var/log/nginx/access.log  main;
			    server_tokens off;
			
			    sendfile            on;
			    tcp_nopush          on;
			    tcp_nodelay         on;
			    keepalive_timeout   65;
			    types_hash_max_size 2048;
			    gzip                on;
			
			    include             /etc/nginx/mime.types;
			    default_type        application/octet-stream;
			
			    # Load modular configuration files from the /etc/nginx/conf.d directory.
			    # See http://nginx.org/en/docs/ngx_core_module.html#include
			    # for more information.
			    include /etc/nginx/conf.d/*.conf;
			}
		EOF
	fi

	if [[ "$PROXY_URL" == "" ]]; then
		action=""
	else
		action="proxy_ssl_server_name on;
        proxy_pass $PROXY_URL;
        proxy_set_header Accept-Encoding '';
        sub_filter \"$REMOTE_HOST\" \"$DOMAIN\";
        sub_filter_once off;"
	fi

	if [[ "$TLS" == "true" || "$XTLS" == "true" ]]; then
		mkdir -p ${NGINX_CONF_PATH}
		# VMESS+WS+TLS
		# VLESS+WS+TLS
		if [[ "$WS" == "true" ]]; then
			cat >${NGINX_CONF_PATH}${DOMAIN}.conf <<-EOF
				server {
				    listen 80;
				    listen [::]:80;
				    server_name ${DOMAIN};
				    return 301 https://\$server_name:${PORT}\$request_uri;
				}
				
				server {
				    listen       ${PORT} ssl http2;
				    listen       [::]:${PORT} ssl http2;
				    server_name ${DOMAIN};
				    charset utf-8;
				
				    # ssl配置
				    ssl_protocols TLSv1.1 TLSv1.2;
				    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
				    ssl_ecdh_curve secp384r1;
				    ssl_prefer_server_ciphers on;
				    ssl_session_cache shared:SSL:10m;
				    ssl_session_timeout 10m;
				    ssl_session_tickets off;
				    ssl_certificate $CERT_FILE;
				    ssl_certificate_key $KEY_FILE;
				
				    root /usr/share/nginx/html;
				    location / {
				        $action
				    }
				    $ROBOT_CONFIG
				
				    location ${WSPATH} {
				      proxy_redirect off;
				      proxy_pass http://127.0.0.1:${XPORT};
				      proxy_http_version 1.1;
				      proxy_set_header Upgrade \$http_upgrade;
				      proxy_set_header Connection "upgrade";
				      proxy_set_header Host \$host;
				      proxy_set_header X-Real-IP \$remote_addr;
				      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
				    }
				}
			EOF
		else
			# VLESS+TCP+TLS
			# VLESS+TCP+XTLS
			# trojan
			cat >${NGINX_CONF_PATH}${DOMAIN}.conf <<-EOF
				server {
				    listen 80;
				    listen [::]:80;
				    listen 81 http2;
				    server_name ${DOMAIN};
				    root /usr/share/nginx/html;
				    location / {
				        $action
				    }
				    $ROBOT_CONFIG
				}
			EOF
		fi
	fi
}

setSelinux() {
	if [[ -s /etc/selinux/config ]] && grep 'SELINUX=enforcing' /etc/selinux/config; then
		sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
		setenforce 0
	fi
}

setFirewall() {
	res=$(which firewall-cmd 2>/dev/null)
	if [[ $? -eq 0 ]]; then
		systemctl status firewalld >/dev/null 2>&1
		if [[ $? -eq 0 ]]; then
			firewall-cmd --permanent --add-service=http
			firewall-cmd --permanent --add-service=https
			if [[ "$PORT" != "443" ]]; then
				firewall-cmd --permanent --add-port=${PORT}/tcp
				firewall-cmd --permanent --add-port=${PORT}/udp
			fi
			firewall-cmd --reload
		else
			nl=$(iptables -nL | nl | grep FORWARD | awk '{print $1}')
			if [[ "$nl" != "3" ]]; then
				iptables -I INPUT -p tcp --dport 80 -j ACCEPT
				iptables -I INPUT -p tcp --dport 443 -j ACCEPT
				if [[ "$PORT" != "443" ]]; then
					iptables -I INPUT -p tcp --dport ${PORT} -j ACCEPT
					iptables -I INPUT -p udp --dport ${PORT} -j ACCEPT
				fi
			fi
		fi
	else
		res=$(which iptables 2>/dev/null)
		if [[ $? -eq 0 ]]; then
			nl=$(iptables -nL | nl | grep FORWARD | awk '{print $1}')
			if [[ "$nl" != "3" ]]; then
				iptables -I INPUT -p tcp --dport 80 -j ACCEPT
				iptables -I INPUT -p tcp --dport 443 -j ACCEPT
				if [[ "$PORT" != "443" ]]; then
					iptables -I INPUT -p tcp --dport ${PORT} -j ACCEPT
					iptables -I INPUT -p udp --dport ${PORT} -j ACCEPT
				fi
			fi
		else
			res=$(which ufw 2>/dev/null)
			if [[ $? -eq 0 ]]; then
				res=$(ufw status | grep -i inactive)
				if [[ "$res" == "" ]]; then
					ufw allow http/tcp
					ufw allow https/tcp
					if [[ "$PORT" != "443" ]]; then
						ufw allow ${PORT}/tcp
						ufw allow ${PORT}/udp
					fi
				fi
			fi
		fi
	fi
}

installBBR() {
	if [[ "$NEED_BBR" != "y" ]]; then
		INSTALL_BBR=false
		return
	fi
	result=$(lsmod | grep bbr)
	if [[ "$result" != "" ]]; then
		yellow " BBR module installed"
		INSTALL_BBR=false
		return
	fi
	res=$(systemd-detect-virt)
	if [[ $res =~ lxc|openvz ]]; then
		yellow " Since your VPS is an OpenVZ or LXC architecture VPS, skip the installation"
		INSTALL_BBR=false
		return
	fi
	echo "net.core.default_qdisc=fq" >>/etc/sysctl.conf
	echo "net.ipv4.tcp_congestion_control=bbr" >>/etc/sysctl.conf
	sysctl -p
	result=$(lsmod | grep bbr)
	if [[ "$result" != "" ]]; then
		green " BBR module is enabled"
		INSTALL_BBR=false
		return
	fi
	yellow " Installing the BBR module..."
	if [[ $SYSTEM == "CentOS" ]]; then
		if [[ "$V6_PROXY" == "" ]]; then
			rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
			rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-4.el7.elrepo.noarch.rpm
			${PACKAGE_INSTALL[int]} --enablerepo=elrepo-kernel kernel-ml
			${PACKAGE_UNINSTALL[int]} kernel-3.*
			grub2-set-default 0
			echo "tcp_bbr" >>/etc/modules-load.d/modules.conf
			INSTALL_BBR=true
		fi
	else
		${PACKAGE_INSTALL[int]} --install-recommends linux-generic-hwe-16.04
		grub-set-default 0
		echo "tcp_bbr" >>/etc/modules-load.d/modules.conf
		INSTALL_BBR=true
	fi
}

installXray() {
	rm -rf /tmp/xray
	mkdir -p /tmp/xray
	DOWNLOAD_LINK="https://github.com/XTLS/Xray-core/releases/download/${NEW_VER}/Xray-linux-$(archAffix).zip"
	yellow "Downloading Xray files now"
	curl -L -H "Cache-Control: no-cache" -o /tmp/xray/xray.zip ${DOWNLOAD_LINK}
	if [ $? != 0 ]; then
		red "Download of Xray file failed, please check server network settings"
		exit 1
	fi
	systemctl stop xray
	mkdir -p /usr/local/etc/xray /usr/local/share/xray && \
	unzip /tmp/xray/xray.zip -d /tmp/xray
	cp /tmp/xray/xray /usr/local/bin
	cp /tmp/xray/geo* /usr/local/share/xray
	chmod +x /usr/local/bin/xray || {
		red "Xray installation failed"
		exit 1
	}

	cat >/etc/systemd/system/xray.service <<-EOF
		[Unit]
		Description=Xray Service by Misaka-blog
		Documentation=https://github.com/Misaka-blog
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
}

trojanConfig() {
	cat >$CONFIG_FILE <<-EOF
		{
		  "inbounds": [{
		    "port": $PORT,
		    "protocol": "trojan",
		    "settings": {
		      "clients": [
		        {
		          "password": "$PASSWORD"
		        }
		      ],
		      "fallbacks": [
		        {
		              "alpn": "http/1.1",
		              "dest": 80
		          },
		          {
		              "alpn": "h2",
		              "dest": 81
		          }
		      ]
		    },
		    "streamSettings": {
		        "network": "tcp",
		        "security": "tls",
		        "tlsSettings": {
		            "serverName": "$DOMAIN",
		            "alpn": ["http/1.1", "h2"],
		            "certificates": [
		                {
		                    "certificateFile": "$CERT_FILE",
		                    "keyFile": "$KEY_FILE"
		                }
		            ]
		        }
		    }
		  }],
		  "outbounds": [{
		    "protocol": "freedom",
		    "settings": {}
		  },{
		    "protocol": "blackhole",
		    "settings": {},
		    "tag": "blocked"
		  }]
		}
	EOF
}

trojanXTLSConfig() {
	cat >$CONFIG_FILE <<-EOF
		{
		  "inbounds": [{
		    "port": $PORT,
		    "protocol": "trojan",
		    "settings": {
		      "clients": [
		        {
		          "password": "$PASSWORD",
		          "flow": "$FLOW"
		        }
		      ],
		      "fallbacks": [
		        {
		              "alpn": "http/1.1",
		              "dest": 80
		          },
		          {
		              "alpn": "h2",
		              "dest": 81
		          }
		      ]
		    },
		    "streamSettings": {
		        "network": "tcp",
		        "security": "xtls",
		        "xtlsSettings": {
		            "serverName": "$DOMAIN",
		            "alpn": ["http/1.1", "h2"],
		            "certificates": [
		                {
		                    "certificateFile": "$CERT_FILE",
		                    "keyFile": "$KEY_FILE"
		                }
		            ]
		        }
		    }
		  }],
		  "outbounds": [{
		    "protocol": "freedom",
		    "settings": {}
		  },{
		    "protocol": "blackhole",
		    "settings": {},
		    "tag": "blocked"
		  }]
		}
	EOF
}

vmessConfig() {
	local uuid="$(cat '/proc/sys/kernel/random/uuid')"
	cat >$CONFIG_FILE <<-EOF
		{
		  "inbounds": [{
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
		    }
		  }],
		  "outbounds": [{
		    "protocol": "freedom",
		    "settings": {}
		  },{
		    "protocol": "blackhole",
		    "settings": {},
		    "tag": "blocked"
		  }]
		}
	EOF
}

vmessKCPConfig() {
	local uuid="$(cat '/proc/sys/kernel/random/uuid')"
	cat >$CONFIG_FILE <<-EOF
		{
		  "inbounds": [{
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
		            "uplinkCapacity": 100,
		            "downlinkCapacity": 100,
		            "congestion": true,
		            "header": {
		                "type": "$HEADER_TYPE"
		            },
		            "seed": "$SEED"
		        }
		    }
		  }],
		  "outbounds": [{
		    "protocol": "freedom",
		    "settings": {}
		  },{
		    "protocol": "blackhole",
		    "settings": {},
		    "tag": "blocked"
		  }]
		}
	EOF
}

vmessTLSConfig() {
	local uuid="$(cat '/proc/sys/kernel/random/uuid')"
	cat >$CONFIG_FILE <<-EOF
		{
		  "inbounds": [{
		    "port": $PORT,
		    "protocol": "vmess",
		    "settings": {
		      "clients": [
		        {
		          "id": "$uuid",
		          "level": 1,
		          "alterId": 0
		        }
		      ],
		      "disableInsecureEncryption": false
		    },
		    "streamSettings": {
		        "network": "tcp",
		        "security": "tls",
		        "tlsSettings": {
		            "serverName": "$DOMAIN",
		            "alpn": ["http/1.1", "h2"],
		            "certificates": [
		                {
		                    "certificateFile": "$CERT_FILE",
		                    "keyFile": "$KEY_FILE"
		                }
		            ]
		        }
		    }
		  }],
		  "outbounds": [{
		    "protocol": "freedom",
		    "settings": {}
		  },{
		    "protocol": "blackhole",
		    "settings": {},
		    "tag": "blocked"
		  }]
		}
	EOF
}

vmessWSConfig() {
	local uuid="$(cat '/proc/sys/kernel/random/uuid')"
	cat >$CONFIG_FILE <<-EOF
		{
		  "inbounds": [{
		    "port": $XPORT,
		    "listen": "127.0.0.1",
		    "protocol": "vmess",
		    "settings": {
		      "clients": [
		        {
		          "id": "$uuid",
		          "level": 1,
		          "alterId": 0
		        }
		      ],
		      "disableInsecureEncryption": false
		    },
		    "streamSettings": {
		        "network": "ws",
		        "wsSettings": {
		            "path": "$WSPATH",
		            "headers": {
		                "Host": "$DOMAIN"
		            }
		        }
		    }
		  }],
		  "outbounds": [{
		    "protocol": "freedom",
		    "settings": {}
		  },{
		    "protocol": "blackhole",
		    "settings": {},
		    "tag": "blocked"
		  }]
		}
	EOF
}

vlessTLSConfig() {
	local uuid="$(cat '/proc/sys/kernel/random/uuid')"
	cat >$CONFIG_FILE <<-EOF
		{
		  "inbounds": [{
		    "port": $PORT,
		    "protocol": "vless",
		    "settings": {
		      "clients": [
		        {
		          "id": "$uuid",
		          "level": 0
		        }
		      ],
		      "decryption": "none",
		      "fallbacks": [
		          {
		              "alpn": "http/1.1",
		              "dest": 80
		          },
		          {
		              "alpn": "h2",
		              "dest": 81
		          }
		      ]
		    },
		    "streamSettings": {
		        "network": "tcp",
		        "security": "tls",
		        "tlsSettings": {
		            "serverName": "$DOMAIN",
		            "alpn": ["http/1.1", "h2"],
		            "certificates": [
		                {
		                    "certificateFile": "$CERT_FILE",
		                    "keyFile": "$KEY_FILE"
		                }
		            ]
		        }
		    }
		  }],
		  "outbounds": [{
		    "protocol": "freedom",
		    "settings": {}
		  },{
		    "protocol": "blackhole",
		    "settings": {},
		    "tag": "blocked"
		  }]
		}
	EOF
}

vlessXTLSConfig() {
    if [[ "$xtls" == "xtls-rprx-vision" ]]; then
        	local uuid="$(cat '/proc/sys/kernel/random/uuid')"
	        cat >$CONFIG_FILE <<-EOF
				{
					"inbounds": [
						{
							"port": $PORT,
							"protocol": "vless",
							"settings": {
								"clients": [
									{
										"id": "$uuid",
										"flow": "$FLOW",
										"level": 0
									}
								],
								"decryption": "none",
								"fallbacks": [
									{
										"alpn": "http/1.1",
										"dest": 80
									},
									{
										"alpn": "h2",
										"dest": 81
									}
								]
							},
							"streamSettings": {
								"streamSettings": {
									"security": "xtls",
									"xtlsSettings": {
										"serverName": "$DOMAIN",
										"alpn": [
											"h2",
											"http/1.1"
										],
										"certificates": [
											{
												"certificateFile": "$CERT_FILE",
												"keyFile": "$KEY_FILE"
											}
										]
									}
								}
							}
						}
						]
				}
			EOF
	else
        	local uuid="$(cat '/proc/sys/kernel/random/uuid')"
	        cat >$CONFIG_FILE <<-EOF
				{
					"inbounds": [
						{
							"port": $PORT,
							"protocol": "vless",
							"settings": {
								"clients": [
									{
										"id": "$uuid",
										"flow": "$FLOW",
										"level": 0
									}
								],
								"decryption": "none",
								"fallbacks": [
									{
										"alpn": "http/1.1",
										"dest": 80
									},
									{
										"alpn": "h2",
										"dest": 81
									}
								]
							},
							"streamSettings": {
								"streamSettings": {
									"security": "tls",
									"tlsSettings": {
										"serverName": "$DOMAIN",
										"alpn": [
											"h2",
											"http/1.1"
										],
										"certificates": [
											{
												"certificateFile": "$CERT_FILE",
												"keyFile": "$KEY_FILE"
											}
										]
									}
								}
							}
						}
						]
				}
			EOF
	fi
}


vlessWSConfig() {
	local uuid="$(cat '/proc/sys/kernel/random/uuid')"
	cat >$CONFIG_FILE <<-EOF
		{
		  "inbounds": [{
		    "port": $XPORT,
		    "listen": "127.0.0.1",
		    "protocol": "vless",
		    "settings": {
		        "clients": [
		            {
		                "id": "$uuid",
		                "level": 0
		            }
		        ],
		        "decryption": "none"
		    },
		    "streamSettings": {
		        "network": "ws",
		        "security": "none",
		        "wsSettings": {
		            "path": "$WSPATH",
		            "headers": {
		                "Host": "$DOMAIN"
		            }
		        }
		    }
		  }],
		  "outbounds": [{
		    "protocol": "freedom",
		    "settings": {}
		  },{
		    "protocol": "blackhole",
		    "settings": {},
		    "tag": "blocked"
		  }]
		}
	EOF
}

vlessKCPConfig() {
	local uuid="$(cat '/proc/sys/kernel/random/uuid')"
	cat >$CONFIG_FILE <<-EOF
		{
		  "inbounds": [{
		    "port": $PORT,
		    "protocol": "vless",
		    "settings": {
		      "clients": [
		        {
		          "id": "$uuid",
		          "level": 0
		        }
		      ],
		      "decryption": "none"
		    },
		    "streamSettings": {
		        "streamSettings": {
		            "network": "mkcp",
		            "kcpSettings": {
		                "uplinkCapacity": 100,
		                "downlinkCapacity": 100,
		                "congestion": true,
		                "header": {
		                    "type": "$HEADER_TYPE"
		                },
		                "seed": "$SEED"
		            }
		        }
		    }
		  }],
		  "outbounds": [{
		    "protocol": "freedom",
		    "settings": {}
		  },{
		    "protocol": "blackhole",
		    "settings": {},
		    "tag": "blocked"
		  }]
		}
	EOF
}

configXray() {
	mkdir -p /usr/local/xray
	if [[ "$TROJAN" == "true" ]]; then
		if [[ "$XTLS" == "true" ]]; then
			trojanXTLSConfig
		else
			trojanConfig
		fi
		return 0
	fi
	if [[ "$VLESS" == "false" ]]; then
		# VMESS + kcp
		if [[ "$KCP" == "true" ]]; then
			vmessKCPConfig
			return 0
		fi
		# VMESS
		if [[ "$TLS" == "false" ]]; then
			vmessConfig
		elif [[ "$WS" == "false" ]]; then
			# VMESS+TCP+TLS
			vmessTLSConfig
		# VMESS+WS+TLS
		else
			vmessWSConfig
		fi
	#VLESS
	else
		if [[ "$KCP" == "true" ]]; then
			vlessKCPConfig
			return 0
		fi
		# VLESS+TCP
		if [[ "$WS" == "false" ]]; then
			# VLESS+TCP+TLS
			if [[ "$XTLS" == "false" ]]; then
				vlessTLSConfig
			# VLESS+TCP+XTLS
			else
				vlessXTLSConfig
			fi
		# VLESS+WS+TLS
		else
			vlessWSConfig
		fi
	fi
}

install() {
	getData
	checkCentOS8
	${PACKAGE_UPDATE[int]}
	${PACKAGE_INSTALL[int]} wget curl sudo vim unzip tar gcc openssl net-tools
	if [[ $SYSTEM != "CentOS" ]]; then
		${PACKAGE_INSTALL[int]} libssl-dev g++
	fi
	[[ -z $(type -P unzip) ]] && red "unzip installation failed, please check network" && exit 1
	installNginx
	setFirewall
	[[ $TLS == "true" || $XTLS == "true" ]] && getCert
	configNginx
	yellow "Installing Xray..."
	getVersion
	RETVAL="$?"
	if [[ $RETVAL == 0 ]]; then
		yellow "Xray Latest Version ${CUR_VER} Already installed"
	elif [[ $RETVAL == 3 ]]; then
		exit 1
	else
		yellow "Installing Xray ${NEW_VER} ，infrastructure$(archAffix)"
		installXray
	fi
	configXray
	setSelinux
	installBBR
	start
	showInfo
	bbrReboot
}

bbrReboot() {
	if [[ "${INSTALL_BBR}" == "true" ]]; then
		echo
		echo "For the BBR module to take effect, the system will reboot after 30 seconds"
		echo
		echo -e "You can press ctrl + c to cancel the reboot, and later type ${RED}reboot${PLAIN} to reboot the system"
		sleep 30
		reboot
	fi
}

update() {
	res=$(status)
	[[ $res -lt 2 ]] && red "Xray is not installed, please install it first！" && return
	getVersion
	RETVAL="$?"
	if [[ $RETVAL == 0 ]]; then
		yellow "Xray Latest Version ${CUR_VER} Already installed"
	elif [[ $RETVAL == 3 ]]; then
		exit 1
	else
		yellow "Installing Xray ${NEW_VER} ，infrastructure$(archAffix)"
		installXray
		stop
		start
		green "Latest version of Xray installed successfully！"
	fi
}

uninstall() {
	res=$(status)
	if [[ $res -lt 2 ]]; then
		red "Xray is not installed, please install it first！"
		return
	fi
	echo ""
	read -p "Make sure to uninstall Xray？[y/n]：" answer
	if [[ "${answer,,}" == "y" ]]; then
		domain=$(grep Host $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
		if [[ "$domain" == "" ]]; then
			domain=$(grep serverName $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
		fi
		stop
		systemctl disable xray
		rm -rf /etc/systemd/system/xray.service
		rm -rf /usr/local/bin/xray
		rm -rf /usr/local/etc/xray
		if [[ "$BT" == "false" ]]; then
			systemctl disable nginx
			${PACKAGE_UNINSTALL[int]} nginx
			if [[ "$PMT" == "apt" ]]; then
				${PACKAGE_UNINSTALL[int]} nginx-common
			fi
			rm -rf /etc/nginx/nginx.conf
			if [[ -f /etc/nginx/nginx.conf.bak ]]; then
				mv /etc/nginx/nginx.conf.bak /etc/nginx/nginx.conf
			fi
		fi
		if [[ "$domain" != "" ]]; then
			rm -rf ${NGINX_CONF_PATH}${domain}.conf
		fi
		[[ -f ~/.acme.sh/acme.sh ]] && ~/.acme.sh/acme.sh --uninstall
		green "Xray uninstallation successful"
	fi
}

start() {
	res=$(status)
	if [[ $res -lt 2 ]]; then
		red "Xray is not installed，Please install first！"
		return
	fi
	stopNginx
	startNginx
	systemctl restart xray
	sleep 2
	port=$(grep port $CONFIG_FILE | head -n 1 | cut -d: -f2 | tr -d \",' ')
	res=$(ss -nutlp | grep ${port} | grep -i xray)
	if [[ "$res" == "" ]]; then
		red "Xray failed to start, please check the logs or see if the port is occupied！"
	else
		yellow "Xray launch successful"
	fi
}

stop() {
	stopNginx
	systemctl stop xray
	yellow "Xray stop successful"
}

restart() {
	res=$(status)
	if [[ $res -lt 2 ]]; then
		red "Xray is not installed, please install it first！"
		return
	fi
	stop
	start
}

getConfigFileInfo() {
	vless="false"
	tls="false"
	ws="false"
	xtls="false"
	trojan="false"
	protocol="VMess"
	kcp="false"
	uid=$(grep id $CONFIG_FILE | head -n1 | cut -d: -f2 | tr -d \",' ')
	alterid=$(grep alterId $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
	network=$(grep network $CONFIG_FILE | tail -n1 | cut -d: -f2 | tr -d \",' ')
	[[ -z "$network" ]] && network="tcp"
	domain=$(grep serverName $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
	if [[ "$domain" == "" ]]; then
		domain=$(grep Host $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
		if [[ "$domain" != "" ]]; then
			ws="true"
			tls="true"
			wspath=$(grep path $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
		fi
	else
		tls="true"
	fi
	if [[ "$ws" == "true" ]]; then
		port=$(grep -i ssl $NGINX_CONF_PATH${domain}.conf | head -n1 | awk '{print $2}')
	else
		port=$(grep port $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
	fi
	res=$(grep -i kcp $CONFIG_FILE)
	if [[ "$res" != "" ]]; then
		kcp="true"
		type=$(grep header -A 3 $CONFIG_FILE | grep 'type' | cut -d: -f2 | tr -d \",' ')
		seed=$(grep seed $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
	fi
	vmess=$(grep vmess $CONFIG_FILE)
	if [[ "$vmess" == "" ]]; then
		trojan=$(grep trojan $CONFIG_FILE)
		if [[ "$trojan" == "" ]]; then
			vless="true"
			protocol="VLESS"
		else
			trojan="true"
			password=$(grep password $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
			protocol="trojan"
		fi
		tls="true"
		encryption="none"
		xtls=$(grep xtlsSettings $CONFIG_FILE)
		if [[ "$xtls" != "" ]]; then
			xtls="true"
			flow=$(grep flow $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
		else
			flow="not"
		fi
	fi
}

outputVmess() {
	raw="{
  \"v\":\"2\",
  \"ps\":\"\",
  \"add\":\"$IP\",
  \"port\":\"${port}\",
  \"id\":\"${uid}\",
  \"aid\":\"$alterid\",
  \"net\":\"tcp\",
  \"type\":\"none\",
  \"host\":\"\",
  \"path\":\"\",
  \"tls\":\"\"
}"
	link=$(echo -n ${raw} | base64 -w 0)
	link="vmess://${link}"

	echo -e "   ${BLUE}IP(address): ${PLAIN} ${RED}${IP}${PLAIN}"
	echo -e "   ${BLUE}port(port)：${PLAIN}${RED}${port}${PLAIN}"
	echo -e "   ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
	echo -e "   ${BLUE}Additional id(alterid)：${PLAIN} ${RED}${alterid}${PLAIN}"
	echo -e "   ${BLUE}encryption method(security)：${PLAIN} ${RED}auto${PLAIN}"
	echo -e "   ${BLUE}transfer protocol(network)：${PLAIN} ${RED}${network}${PLAIN}"
	echo -e "   ${BLUE}vmess link:${PLAIN} $RED$link$PLAIN"
}

outputVmessKCP() {
	echo -e "   ${BLUE}IP(address): ${PLAIN} ${RED}${IP}${PLAIN}"
	echo -e "   ${BLUE}port(port)：${PLAIN}${RED}${port}${PLAIN}"
	echo -e "   ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
	echo -e "   ${BLUE}Additional id(alterid)：${PLAIN} ${RED}${alterid}${PLAIN}"
	echo -e "   ${BLUE}encryption method(security)：${PLAIN} ${RED}auto${PLAIN}"
	echo -e "   ${BLUE}transfer protocol(network)：${PLAIN} ${RED}${network}${PLAIN}"
	echo -e "   ${BLUE}Type of camouflage(type)：${PLAIN} ${RED}${type}${PLAIN}"
	echo -e "   ${BLUE}mkcp seed：${PLAIN} ${RED}${seed}${PLAIN}"
}

outputTrojan() {
	if [[ "$xtls" == "true" ]]; then
		link="trojan://${password}@${domain}:${port}#"
		echo -e "   ${BLUE}IP/domain name(address): ${PLAIN} ${RED}${domain}${PLAIN}"
		echo -e "   ${BLUE}port(port)：${PLAIN}${RED}${port}${PLAIN}"
		echo -e "   ${BLUE}pin number(password)：${PLAIN}${RED}${password}${PLAIN}"
		echo -e "   ${BLUE}flow control(flow)：${PLAIN}$RED$flow${PLAIN}"
		echo -e "   ${BLUE}encrypted(encryption)：${PLAIN} ${RED}none${PLAIN}"
		echo -e "   ${BLUE}transfer protocol(network)：${PLAIN} ${RED}${network}${PLAIN}"
		echo -e "   ${BLUE}Underlying secure transmission(tls)：${PLAIN}${RED}XTLS${PLAIN}"
		echo -e "   ${BLUE}Trojan links:${PLAIN} $RED$link$PLAIN"
	else
		link="trojan://${password}@${domain}:${port}#"
		echo -e "   ${BLUE}IP/domain name(address): ${PLAIN} ${RED}${domain}${PLAIN}"
		echo -e "   ${BLUE}port(port)：${PLAIN}${RED}${port}${PLAIN}"
		echo -e "   ${BLUE}pin number(password)：${PLAIN}${RED}${password}${PLAIN}"
		echo -e "   ${BLUE}transfer protocol(network)：${PLAIN} ${RED}${network}${PLAIN}"
		echo -e "   ${BLUE}Underlying secure transmission(tls)：${PLAIN}${RED}TLS${PLAIN}"
		echo -e "   ${BLUE}Trojan links:${PLAIN} $RED$link$PLAIN"
	fi
}

outputVmessTLS() {
	raw="{
  \"v\":\"2\",
  \"ps\":\"\",
  \"add\":\"$IP\",
  \"port\":\"${port}\",
  \"id\":\"${uid}\",
  \"aid\":\"$alterid\",
  \"net\":\"${network}\",
  \"type\":\"none\",
  \"host\":\"${domain}\",
  \"path\":\"\",
  \"tls\":\"tls\"
}"
	link=$(echo -n ${raw} | base64 -w 0)
	link="vmess://${link}"
	echo -e "   ${BLUE}IP(address): ${PLAIN} ${RED}${IP}${PLAIN}"
	echo -e "   ${BLUE}port(port)：${PLAIN}${RED}${port}${PLAIN}"
	echo -e "   ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
	echo -e "   ${BLUE}Additional id(alterid)：${PLAIN} ${RED}${alterid}${PLAIN}"
	echo -e "   ${BLUE}encryption method(security)：${PLAIN} ${RED}none${PLAIN}"
	echo -e "   ${BLUE}transfer protocol(network)：${PLAIN} ${RED}${network}${PLAIN}"
	echo -e "   ${BLUE}Spoofed domain/host name(host)/SNI/peer名称：${PLAIN}${RED}${domain}${PLAIN}"
	echo -e "   ${BLUE}Underlying secure transmission(tls)：${PLAIN}${RED}TLS${PLAIN}"
	echo -e "   ${BLUE}vmess link: ${PLAIN}$RED$link$PLAIN"
}

outputVmessWS() {
	raw="{
  \"v\":\"2\",
  \"ps\":\"\",
  \"add\":\"$IP\",
  \"port\":\"${port}\",
  \"id\":\"${uid}\",
  \"aid\":\"$alterid\",
  \"net\":\"${network}\",
  \"type\":\"none\",
  \"host\":\"${domain}\",
  \"path\":\"${wspath}\",
  \"tls\":\"tls\"
}"
	link=$(echo -n ${raw} | base64 -w 0)
	link="vmess://${link}"

	echo -e "   ${BLUE}IP(address): ${PLAIN} ${RED}${IP}${PLAIN}"
	echo -e "   ${BLUE}port(port)：${PLAIN}${RED}${port}${PLAIN}"
	echo -e "   ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
	echo -e "   ${BLUE}Additional id(alterid)：${PLAIN} ${RED}${alterid}${PLAIN}"
	echo -e "   ${BLUE}encryption method(security)：${PLAIN} ${RED}none${PLAIN}"
	echo -e "   ${BLUE}transfer protocol(network)：${PLAIN} ${RED}${network}${PLAIN}"
	echo -e "   ${BLUE}Type of camouflage(type)：${PLAIN}${RED}none$PLAIN"
	echo -e "   ${BLUE}Fake domain/host name(host)/SNI/peer name：${PLAIN}${RED}${domain}${PLAIN}"
	echo -e "   ${BLUE}trails(path)：${PLAIN}${RED}${wspath}${PLAIN}"
	echo -e "   ${BLUE}Underlying secure transmission(tls)：${PLAIN}${RED}TLS${PLAIN}"
	echo -e "   ${BLUE}vmess link:${PLAIN} $RED$link$PLAIN"
}

showInfo() {
	res=$(status)
	if [[ $res -lt 2 ]]; then
		red "Xray is not installed, please install it first！"
		return
	fi

	echo ""
	yellow " Xray Profile: ${CONFIG_FILE}"
	yellow " Xray Configuration Information："

	getConfigFileInfo

	echo -e "   ${BLUE}agreements: ${PLAIN} ${RED}${protocol}${PLAIN}"
	if [[ "$trojan" == "true" ]]; then
		outputTrojan
		return 0
	fi
	if [[ "$vless" == "false" ]]; then
		if [[ "$kcp" == "true" ]]; then
			outputVmessKCP
			return 0
		fi
		if [[ "$tls" == "false" ]]; then
			outputVmess
		elif [[ "$ws" == "false" ]]; then
			outputVmessTLS
		else
			outputVmessWS
		fi
	else
		if [[ "$kcp" == "true" ]]; then
			echo -e "   ${BLUE}IP(address): ${PLAIN} ${RED}${IP}${PLAIN}"
			echo -e "   ${BLUE}port(port)：${PLAIN}${RED}${port}${PLAIN}"
			echo -e "   ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
			echo -e "   ${BLUE}encrypted(encryption)：${PLAIN} ${RED}none${PLAIN}"
			echo -e "   ${BLUE}transfer protocol(network)：${PLAIN} ${RED}${network}${PLAIN}"
			echo -e "   ${BLUE}Type of camouflage(type)：${PLAIN} ${RED}${type}${PLAIN}"
			echo -e "   ${BLUE}mkcp seed：${PLAIN} ${RED}${seed}${PLAIN}"
			return 0
		fi
		if [[ "$xtls" == "true" ]]; then
			echo -e " ${BLUE}IP(address): ${PLAIN} ${RED}${IP}${PLAIN}"
			echo -e " ${BLUE}port(port)：${PLAIN}${RED}${port}${PLAIN}"
			echo -e " ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
			echo -e " ${BLUE}flow control(flow)：${PLAIN}$RED$flow${PLAIN}"
			echo -e " ${BLUE}encrypted(encryption)：${PLAIN} ${RED}none${PLAIN}"
			echo -e " ${BLUE}transfer protocol(network)：${PLAIN} ${RED}${network}${PLAIN}"
			echo -e " ${BLUE}Type of camouflage(type)：${PLAIN}${RED}none$PLAIN"
			echo -e " ${BLUE}Fake domain/host name(host)/SNI/peer name：${PLAIN}${RED}${domain}${PLAIN}"
			echo -e " ${BLUE}Underlying secure transmission(tls)：${PLAIN}${RED}XTLS${PLAIN}"
		elif [[ "$ws" == "false" ]]; then
			echo -e " ${BLUE}IP(address):  ${PLAIN}${RED}${IP}${PLAIN}"
			echo -e " ${BLUE}port(port)：${PLAIN}${RED}${port}${PLAIN}"
			echo -e " ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
			echo -e " ${BLUE}flow control(flow)：${PLAIN}$RED$flow${PLAIN}"
			echo -e " ${BLUE}encrypted(encryption)：${PLAIN} ${RED}none${PLAIN}"
			echo -e " ${BLUE}transfer protocol(network)：${PLAIN} ${RED}${network}${PLAIN}"
			echo -e " ${BLUE}Type of camouflage(type)：${PLAIN}${RED}none$PLAIN"
			echo -e " ${BLUE}Fake domain/host name(host)/SNI/peer name：${PLAIN}${RED}${domain}${PLAIN}"
			echo -e " ${BLUE}Underlying secure transmission(tls)：${PLAIN}${RED}TLS${PLAIN}"
		else
			echo -e " ${BLUE}IP(address): ${PLAIN} ${RED}${IP}${PLAIN}"
			echo -e " ${BLUE}port(port)：${PLAIN}${RED}${port}${PLAIN}"
			echo -e " ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
			echo -e " ${BLUE}flow control(flow)：${PLAIN}$RED$flow${PLAIN}"
			echo -e " ${BLUE}encrypted(encryption)：${PLAIN} ${RED}none${PLAIN}"
			echo -e " ${BLUE}transfer protocol(network)：${PLAIN} ${RED}${network}${PLAIN}"
			echo -e " ${BLUE}Type of camouflage(type)：${PLAIN}${RED}none$PLAIN"
			echo -e " ${BLUE}Fake domain/host name(host)/SNI/peer name：${PLAIN}${RED}${domain}${PLAIN}"
			echo -e " ${BLUE}trails(path)：${PLAIN}${RED}${wspath}${PLAIN}"
			echo -e " ${BLUE}Underlying secure transmission(tls)：${PLAIN}${RED}TLS${PLAIN}"
		fi
	fi
}

showLog() {
	res=$(status)
	[[ $res -lt 2 ]] && red "Xray is not installed, please install it first！" && exit 1
	journalctl -xen -u xray --no-pager
}

warpmenu() {
	echo "There are many warp works currently available, so choose your own:"
	echo "fscarmen(https://github.com/fscarmen/warp/):"
	echo "warp: wget -N https://raw.githubusercontent.com/fscarmen/warp/main/menu.sh && bash menu.sh"
	echo "waro-go: wget -N https://raw.githubusercontent.com/fscarmen/warp/main/warp-go.sh && bash warp-go.sh"
	echo "P3TERX""
    echo "bash <(curl -fsSL git.io/warp.sh) d"
}

setdns64() {
	if [[ -n $(curl -s6m8 https://ip.gs) ]]; then
		echo -e nameserver 2a01:4f8:c2c:123f::1 >/etc/resolv.conf
	fi
}

system_optimize() {
	if [ ! -f "/etc/sysctl.conf" ]; then
		touch /etc/sysctl.conf
	fi
	sed -i '/net.ipv4.tcp_retries2/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_slow_start_after_idle/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_fastopen/d' /etc/sysctl.conf
	sed -i '/fs.file-max/d' /etc/sysctl.conf
	sed -i '/fs.inotify.max_user_instances/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_fin_timeout/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_tw_reuse/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_max_syn_backlog/d' /etc/sysctl.conf
	sed -i '/net.ipv4.ip_local_port_range/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_max_tw_buckets/d' /etc/sysctl.conf
	sed -i '/net.ipv4.route.gc_timeout/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_synack_retries/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_syn_retries/d' /etc/sysctl.conf
	sed -i '/net.core.somaxconn/d' /etc/sysctl.conf
	sed -i '/net.core.netdev_max_backlog/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_timestamps/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_max_orphans/d' /etc/sysctl.conf
	sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf

	echo "net.ipv4.tcp_retries2 = 8
	net.ipv4.tcp_slow_start_after_idle = 0
	fs.file-max = 1000000
	fs.inotify.max_user_instances = 8192
	net.ipv4.tcp_syncookies = 1
	net.ipv4.tcp_fin_timeout = 30
	net.ipv4.tcp_tw_reuse = 1
	net.ipv4.ip_local_port_range = 1024 65000
	net.ipv4.tcp_max_syn_backlog = 16384
	net.ipv4.tcp_max_tw_buckets = 6000
	net.ipv4.route.gc_timeout = 100
	net.ipv4.tcp_syn_retries = 1
	net.ipv4.tcp_synack_retries = 1
	net.core.somaxconn = 32768
	net.core.netdev_max_backlog = 32768
	net.ipv4.tcp_timestamps = 0
	net.ipv4.tcp_max_orphans = 32768
	# forward ipv4
	#net.ipv4.ip_forward = 1" >>/etc/sysctl.conf
	sysctl -p
	echo "*               soft    nofile           1000000
	*               hard    nofile          1000000" >/etc/security/limits.conf
	echo "ulimit -SHn 1000000" >>/etc/profile
	read -p "You need to restart the VPS for the system optimization configuration to take effect, do you want to restart now？ [Y/n] :" yn
	[[ -z $yn ]] && yn="y"
	if [[ $yn == [Yy] ]]; then
		yellow "VPS Rebooting in progress..."
		reboot
	fi
}

open_ports() {
	systemctl stop firewalld.service
	systemctl disable firewalld.service
	setenforce 0
	ufw disable
	iptables -P INPUT ACCEPT
	iptables -P FORWARD ACCEPT
	iptables -P OUTPUT ACCEPT
	iptables -t nat -F
	iptables -t mangle -F
	iptables -F
	iptables -X
	netfilter-persistent save
	yellow "All network ports in the VPS are open"
}

#Disabling IPv6
closeipv6() {
	clear
	sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.d/99-sysctl.conf
	sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.d/99-sysctl.conf
	sed -i '/net.ipv6.conf.lo.disable_ipv6/d' /etc/sysctl.d/99-sysctl.conf
	sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
	sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
	sed -i '/net.ipv6.conf.lo.disable_ipv6/d' /etc/sysctl.conf

	echo "net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1" >>/etc/sysctl.d/99-sysctl.conf
	sysctl --system
	green "End of IPv6 disabling, may require reboot！"
}

#Enabling IPv6
openipv6() {
	clear
	sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.d/99-sysctl.conf
	sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.d/99-sysctl.conf
	sed -i '/net.ipv6.conf.lo.disable_ipv6/d' /etc/sysctl.d/99-sysctl.conf
	sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
	sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
	sed -i '/net.ipv6.conf.lo.disable_ipv6/d' /etc/sysctl.conf

	echo "net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0" >>/etc/sysctl.d/99-sysctl.conf
	sysctl --system
	green "End of IPv6 enablement, may need to reboot！"
}

menu() {
	clear
	echo "#############################################################"
	echo -e "#                     ${RED}Xray One-Click Installation Script${PLAIN}                      #"
	echo -e "# ${GREEN}作者${PLAIN}: Network Jump Over (hijk) & MisakaNo                           #"
	echo -e "# ${GREEN}博客${PLAIN}: https://owo.misaka.rest                             #"
	echo -e "# ${GREEN}论坛${PLAIN}: https://vpsgo.co                                    #"
	echo -e "# ${GREEN}TG群${PLAIN}: https://t.me/misakanetcn                            #"
	echo "#############################################################"
	echo -e "  "
	echo -e "  ${GREEN}1.${PLAIN}   Installing Xray-VMESS${PLAIN}${RED}(would not recommend)${PLAIN}"
	echo -e "  ${GREEN}2.${PLAIN}   Installing Xray-${BLUE}VMESS+mKCP${PLAIN}"
	echo -e "  ${GREEN}3.${PLAIN}   Install Xray-VMESS+TCP+TLS"
	echo -e "  ${GREEN}4.${PLAIN}   Install Xray-${BLUE}VMESS+WS+TLS${PLAIN}${RED}(recommended)(can pass a WebSocket-enabled CDN) ${PLAIN}"
	echo -e "  ${GREEN}5.${PLAIN}   Install Xray-${BLUE}VLESS+mKCP${PLAIN}"
	echo -e "  ${GREEN}6.${PLAIN}   Install Xray-VLESS+TCP+TLS"
	echo -e "  ${GREEN}7.${PLAIN}   Install Xray-${BLUE}VLESS+WS+TLS${PLAIN}${RED}(recommended)(can pass a CDN with WebSocket support)${PLAIN}"
	echo -e "  ${GREEN}8.${PLAIN}   Install Xray-${BLUE}VLESS+TCP+XTLS${PLAIN}${RED}(not recommended)${PLAIN}"
	echo -e "  ${GREEN}9.${PLAIN}   Install ${BLUE}Trojan${PLAIN}${RED}(recommended)(low latency)${PLAIN}"
	echo -e "  ${GREEN}10.${PLAIN}  Install ${BLUE}Trojan+XTLS${PLAIN}${RED}(not recommended)${PLAIN}"
	echo " -------------"
	echo -e "  ${GREEN}11.${PLAIN}  Update Xray"
	echo -e "  ${GREEN}12.  ${RED} uninstall Xray ${PLAIN}"
	echo " -------------"
	echo -e "  ${GREEN}13.${PLAIN}  Start Xray"
	echo -e "  ${GREEN}14.${PLAIN}  Restart Xray"
	echo -e "  ${GREEN}15.${PLAIN}  Stop Xray"
	echo " -------------"
	echo -e "  ${GREEN}16.${PLAIN}  View Xray Configuration"
	echo -e "  ${GREEN}17.${PLAIN}  View Xray logs"
	echo " -------------"
	echo -e "  ${GREEN}18.${PLAIN}  Installing and managing WARP"
	echo -e "  ${GREEN}19.${PLAIN}  Setting up a DNS64 server"
	echo -e "  ${GREEN}20.${PLAIN}  VPS System Optimization"
	echo -e "  ${GREEN}21.${PLAIN}  Release all ports of the VPS"
	echo -e "  ${GREEN}22.${PLAIN}  Enabling IPv6"
	echo -e "  ${GREEN}23.${PLAIN}  Disabling IPv6"
	echo " -------------"
	echo -e "  ${GREEN}0.${PLAIN}   exit"
	echo -n " Current Xray Status："
	statusText
	echo

	read -p "Please select the operation[0-23]：" answer
	case $answer in
		0) exit 1 ;;
		1) install ;;
		2) KCP="true" && install ;;
		3) TLS="true" && install ;;
		4) TLS="true" && WS="true" && install ;;
		5) VLESS="true" && KCP="true" && install ;;
		6) VLESS="true" && TLS="true" && install ;;
		7) VLESS="true" && TLS="true" && WS="true" && install ;;
		8) VLESS="true" && TLS="true" && XTLS="true" && install ;;
		9) TROJAN="true" && TLS="true" && install ;;
		10) TROJAN="true" && TLS="true" && XTLS="true" && install ;;
		11) update ;;
		12) uninstall ;;
		13) start ;;
		14) restart ;;
		15) stop ;;
		16) showInfo ;;
		17) showLog ;;
		18) warpmenu ;;
		19) setdns64 ;;
		20) system_optimize ;;
		21) open_ports ;;
		22) openipv6 ;;
		23) closeipv6 ;;
		*) red "Please select the correct operation！" && exit 1 ;;
	esac
}

action=$1
[[ -z $1 ]] && action=menu

case "$action" in
	menu | update | uninstall | start | restart | stop | showInfo | showLog) ${action} ;;
	*) echo " Parameter error" && echo " usage: $(basename $0) [menu|update|uninstall|start|restart|stop|showInfo|showLog]" ;;
esac
