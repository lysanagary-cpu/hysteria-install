#!/bin/bash

# Hysteria 2 一键安装脚本 (更新版)
# 原作者: MisakaNo の 小破站
# 更新日期: 2026-02-28
# 基于 Hysteria 2 v2.7.x 官方文档更新
# 官方项目: https://github.com/apernet/hysteria
# 官方文档: https://v2.hysteria.network/zh/

SCRIPT_VERSION="2.0.0"

export LANG=en_US.UTF-8

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN="\033[0m"

red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

blue(){
    echo -e "\033[36m\033[01m$1\033[0m"
}

# 判断系统及定义系统安装依赖方式
REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "fedora" "arch")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Fedora" "Arch")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update" "pacman -Sy")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "yum -y install" "pacman -S --noconfirm")
PACKAGE_REMOVE=("apt -y remove" "apt -y remove" "yum -y remove" "yum -y remove" "yum -y remove" "pacman -Rns --noconfirm")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove" "yum -y autoremove" "pacman -Rns --noconfirm")

[[ $EUID -ne 0 ]] && red "注意: 请在root用户下运行脚本" && exit 1

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i" && [[ -n $SYS ]] && break
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
done

[[ -z $SYSTEM ]] && red "目前暂不支持你的VPS的操作系统！" && exit 1

if [[ -z $(type -P curl) ]]; then
    if [[ ! $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_UPDATE[int]}
    fi
    ${PACKAGE_INSTALL[int]} curl
fi

# 获取服务器真实 IP
realip(){
    ip=$(curl -s4m8 ip.gs -k) || ip=$(curl -s6m8 ip.gs -k)
}

# 获取已安装的 Hysteria 版本
get_installed_version(){
    if [[ -f "/usr/local/bin/hysteria" ]]; then
        /usr/local/bin/hysteria version 2>/dev/null | grep '^Version' | grep -o 'v[.0-9]*' || echo "unknown"
    else
        echo "未安装"
    fi
}

# 检测系统架构
get_arch(){
    case "$(uname -m)" in
        x86_64 | amd64 ) echo 'amd64' ;;
        i686 | i386 ) echo '386' ;;
        armv7l | armv6l ) echo 'arm' ;;
        aarch64 | arm64 ) echo 'arm64' ;;
        s390x ) echo 's390x' ;;
        mips64le ) echo 'mipsle' ;;
        riscv64 ) echo 'riscv64' ;;
        * ) echo 'amd64' ;;
    esac
}

# 安装 Hysteria 2 二进制文件 (多源下载，自动回退)
install_hysteria_binary(){
    local arch=$(get_arch)
    local installed=false

    # 方式1: 官方安装脚本
    green "[1/3] 尝试使用官方脚本安装..."
    if bash <(curl -fsSL https://get.hy2.sh/) 2>/dev/null; then
        if [[ -f "/usr/local/bin/hysteria" ]]; then
            installed=true
        fi
    fi

    # 方式2: 官方下载站直接下载
    if [[ $installed == false ]]; then
        yellow "官方脚本安装失败，尝试从官方下载站直接下载..."
        green "[2/3] 从 download.hysteria.network 下载..."
        if curl -L -o /tmp/hysteria --retry 3 --retry-delay 3 -m 60 "https://download.hysteria.network/app/latest/hysteria-linux-${arch}" 2>/dev/null; then
            if [[ -s /tmp/hysteria ]]; then
                install -Dm755 /tmp/hysteria /usr/local/bin/hysteria
                rm -f /tmp/hysteria
                installed=true
            fi
        fi
    fi

    # 方式3: GitHub 代理镜像
    if [[ $installed == false ]]; then
        yellow "官方下载站也失败了，尝试 GitHub 代理镜像..."
        green "[3/3] 从 GitHub 代理镜像下载..."
        local mirrors=(
            "https://ghproxy.cc/https://github.com/apernet/hysteria/releases/download/app/v2.7.1/hysteria-linux-${arch}"
            "https://gh-proxy.com/https://github.com/apernet/hysteria/releases/download/app/v2.7.1/hysteria-linux-${arch}"
            "https://mirror.ghproxy.com/https://github.com/apernet/hysteria/releases/download/app/v2.7.1/hysteria-linux-${arch}"
        )
        for mirror_url in "${mirrors[@]}"; do
            yellow "尝试镜像: $mirror_url"
            if curl -L -o /tmp/hysteria --retry 2 --retry-delay 3 -m 120 "$mirror_url" 2>/dev/null; then
                if [[ -s /tmp/hysteria ]]; then
                    install -Dm755 /tmp/hysteria /usr/local/bin/hysteria
                    rm -f /tmp/hysteria
                    installed=true
                    break
                fi
            fi
        done
    fi

    # 如果所有方式都失败，提示用户手动下载
    if [[ $installed == false ]]; then
        red "所有下载方式均失败！"
        yellow "请手动下载 Hysteria 2 二进制文件："
        yellow "  下载地址: https://download.hysteria.network/app/latest/hysteria-linux-${arch}"
        yellow "  放置路径: /usr/local/bin/hysteria"
        yellow "  赋权命令: chmod +x /usr/local/bin/hysteria"
        exit 1
    fi

    # 创建 systemd 服务文件 (如果不存在)
    if [[ ! -f /etc/systemd/system/hysteria-server.service ]]; then
        cat << 'SEOF' > /etc/systemd/system/hysteria-server.service
[Unit]
Description=Hysteria Server Service (config.yaml)
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server --config /etc/hysteria/config.yaml
WorkingDirectory=/etc/hysteria
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
SEOF
        systemctl daemon-reload
    fi

    if [[ ! -f /etc/systemd/system/hysteria-server@.service ]]; then
        cat << 'SEOF' > /etc/systemd/system/hysteria-server@.service
[Unit]
Description=Hysteria Server Service (%i.yaml)
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server --config /etc/hysteria/%i.yaml
WorkingDirectory=/etc/hysteria
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
SEOF
        systemctl daemon-reload
    fi
}

# 证书申请
inst_cert(){
    green "Hysteria 2 协议证书申请方式如下："
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 必应自签证书 ${YELLOW}（默认）${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} Acme 脚本自动申请"
    echo -e " ${GREEN}3.${PLAIN} 自定义证书路径"
    echo ""
    read -rp "请输入选项 [1-3]: " certInput
    if [[ $certInput == 2 ]]; then
        cert_path="/root/cert.crt"
        key_path="/root/private.key"

        chmod -R 777 /root

        chmod +rw /root/cert.crt 2>/dev/null
        chmod +rw /root/private.key 2>/dev/null

        if [[ -f /root/cert.crt && -f /root/private.key ]] && [[ -s /root/cert.crt && -s /root/private.key ]] && [[ -f /root/ca.log ]]; then
            domain=$(cat /root/ca.log)
            green "检测到原有域名：$domain 的证书，正在应用"
            hy_domain=$domain
        else
            WARPv4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
            WARPv6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
            if [[ $WARPv4Status =~ on|plus ]] || [[ $WARPv6Status =~ on|plus ]]; then
                wg-quick down wgcf >/dev/null 2>&1
                systemctl stop warp-go >/dev/null 2>&1
                realip
                wg-quick up wgcf >/dev/null 2>&1
                systemctl start warp-go >/dev/null 2>&1
            else
                realip
            fi

            read -p "请输入需要申请证书的域名：" domain
            [[ -z $domain ]] && red "未输入域名，无法执行操作！" && exit 1
            green "已输入的域名：$domain" && sleep 1
            domainIP=$(dig @8.8.8.8 +time=2 +short "$domain" 2>/dev/null)
            if echo $domainIP | grep -q "network unreachable\|timed out" || [[ -z $domainIP ]]; then
                domainIP=$(dig @2001:4860:4860::8888 +time=2 aaaa +short "$domain" 2>/dev/null)
            fi
            if echo $domainIP | grep -q "network unreachable\|timed out" || [[ -z $domainIP ]] ; then
                red "未解析出 IP，请检查域名是否输入有误"
                yellow "是否尝试强行匹配？"
                green "1. 是，将使用强行匹配"
                green "2. 否，退出脚本"
                read -p "请输入选项 [1-2]：" ipChoice
                if [[ $ipChoice == 1 ]]; then
                    yellow "将尝试强行匹配以申请域名证书"
                else
                    red "将退出脚本"
                    exit 1
                fi
            fi
            if [[ $domainIP == $ip ]] || [[ $ipChoice == 1 ]]; then
                ${PACKAGE_INSTALL[int]} curl wget sudo socat openssl
                if [[ $SYSTEM == "CentOS" ]]; then
                    ${PACKAGE_INSTALL[int]} cronie
                    systemctl start crond
                    systemctl enable crond
                else
                    ${PACKAGE_INSTALL[int]} cron
                    systemctl start cron
                    systemctl enable cron
                fi
                curl https://get.acme.sh | sh -s email=$(date +%s%N | md5sum | cut -c 1-16)@gmail.com
                source ~/.bashrc
                bash ~/.acme.sh/acme.sh --upgrade --auto-upgrade
                bash ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
                if [[ -n $(echo $ip | grep ":") ]]; then
                    bash ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256 --listen-v6 --insecure
                else
                    bash ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256 --insecure
                fi
                bash ~/.acme.sh/acme.sh --install-cert -d ${domain} --key-file /root/private.key --fullchain-file /root/cert.crt --ecc
                if [[ -f /root/cert.crt && -f /root/private.key ]] && [[ -s /root/cert.crt && -s /root/private.key ]]; then
                    echo $domain > /root/ca.log
                    sed -i '/--cron/d' /etc/crontab >/dev/null 2>&1
                    echo "0 0 * * * root bash /root/.acme.sh/acme.sh --cron -f >/dev/null 2>&1" >> /etc/crontab
                    green "证书申请成功! 脚本申请到的证书 (cert.crt) 和私钥 (private.key) 文件已保存到 /root 文件夹下"
                    yellow "证书crt文件路径如下: /root/cert.crt"
                    yellow "私钥key文件路径如下: /root/private.key"
                    hy_domain=$domain
                fi
            else
                red "当前域名解析的IP与当前VPS使用的真实IP不匹配"
                green "建议如下："
                yellow "1. 请确保CloudFlare小云朵为关闭状态(仅限DNS), 其他域名解析或CDN网站设置同理"
                yellow "2. 请检查DNS解析设置的IP是否为VPS的真实IP"
                yellow "3. 脚本可能跟不上时代, 建议截图发布到GitHub Issues、GitLab Issues、论坛或TG群询问"
                exit 1
            fi
        fi
    elif [[ $certInput == 3 ]]; then
        read -p "请输入公钥文件 crt 的路径：" cert_path
        yellow "公钥文件 crt 的路径：$cert_path "
        read -p "请输入密钥文件 key 的路径：" key_path
        yellow "密钥文件 key 的路径：$key_path "
        read -p "请输入证书的域名：" domain
        yellow "证书域名：$domain"
        hy_domain=$domain

        chmod +rw $cert_path
        chmod +rw $key_path
    else
        green "将使用必应自签证书作为 Hysteria 2 的节点证书"

        cert_path="/etc/hysteria/cert.crt"
        key_path="/etc/hysteria/private.key"
        openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/private.key
        openssl req -new -x509 -days 36500 -key /etc/hysteria/private.key -out /etc/hysteria/cert.crt -subj "/CN=www.bing.com"
        chmod 777 /etc/hysteria/cert.crt
        chmod 777 /etc/hysteria/private.key
        hy_domain="www.bing.com"
        domain="www.bing.com"

        # 获取自签证书的 pinSHA256
        cert_fingerprint=$(openssl x509 -noout -fingerprint -sha256 -in /etc/hysteria/cert.crt | cut -d= -f2)
        green "自签证书指纹 (pinSHA256): $cert_fingerprint"
    fi
}

# 设置端口
inst_port(){
    iptables -t nat -F PREROUTING >/dev/null 2>&1

    read -p "设置 Hysteria 2 端口 [1-65535]（回车则随机分配端口）：" port
    [[ -z $port ]] && port=$(shuf -i 2000-65535 -n 1)
    until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]; do
        if [[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]; then
            echo -e "${RED} $port ${PLAIN} 端口已经被其他程序占用，请更换端口重试！"
            read -p "设置 Hysteria 2 端口 [1-65535]（回车则随机分配端口）：" port
            [[ -z $port ]] && port=$(shuf -i 2000-65535 -n 1)
        fi
    done

    yellow "将在 Hysteria 2 节点使用的端口是：$port"
    inst_jump
}

# 端口跳跃
inst_jump(){
    green "Hysteria 2 端口使用模式如下："
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 单端口 ${YELLOW}（默认）${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} 端口跳跃"
    echo ""
    read -rp "请输入选项 [1-2]: " jumpInput
    if [[ $jumpInput == 2 ]]; then
        read -p "设置范围端口的起始端口 (建议10000-65535之间)：" firstport
        read -p "设置一个范围端口的末尾端口 (建议10000-65535之间，一定要比上面起始端口大)：" endport
        if [[ $firstport -ge $endport ]]; then
            until [[ $firstport -le $endport ]]; do
                if [[ $firstport -ge $endport ]]; then
                    red "你设置的起始端口小于末尾端口，请重新输入起始和末尾端口"
                    read -p "设置范围端口的起始端口 (建议10000-65535之间)：" firstport
                    read -p "设置一个范围端口的末尾端口 (建议10000-65535之间，一定要比上面起始端口大)：" endport
                fi
            done
        fi
        iptables -t nat -A PREROUTING -p udp --dport $firstport:$endport -j DNAT --to-destination :$port
        ip6tables -t nat -A PREROUTING -p udp --dport $firstport:$endport -j DNAT --to-destination :$port
        netfilter-persistent save >/dev/null 2>&1
    else
        red "将继续使用单端口模式"
    fi
}

# 设置密码
inst_pwd(){
    read -p "设置 Hysteria 2 密码（回车跳过为随机字符）：" auth_pwd
    [[ -z $auth_pwd ]] && auth_pwd=$(date +%s%N | md5sum | cut -c 1-8)
    yellow "使用在 Hysteria 2 节点的密码为：$auth_pwd"
}

# 设置伪装网站 (自动检测可用性)
inst_site(){
    green "正在自动检测可用的伪装网站..."
    echo ""

    # 候选伪装网站列表
    local sites=(
        "www.wikipedia.org"
        "www.yahoo.com"
        "www.speedtest.net"
        "www.amazon.com"
        "www.bing.com"
        "news.ycombinator.com"
        "www.github.com"
        "www.cloudflare.com"
        "www.apple.com"
        "www.microsoft.com"
    )

    local available_sites=()
    local idx=0

    for site in "${sites[@]}"; do
        local http_code=$(curl -o /dev/null -s -w '%{http_code}' --max-time 5 "https://$site" 2>/dev/null)
        if [[ $http_code -ge 200 ]] && [[ $http_code -lt 400 ]]; then
            idx=$((idx + 1))
            available_sites+=("$site")
            echo -e " ${GREEN}${idx}.${PLAIN} $site ${GREEN}✓ (HTTP $http_code)${PLAIN}"
        else
            echo -e "    $site ${RED}✗ (HTTP $http_code)${PLAIN}"
        fi
    done

    echo ""

    if [[ ${#available_sites[@]} -gt 0 ]]; then
        green "检测到 ${#available_sites[@]} 个可用网站，推荐使用: ${available_sites[0]}"
        echo ""
        echo -e " ${GREEN}0.${PLAIN} 使用推荐: ${available_sites[0]} ${YELLOW}（默认）${PLAIN}"
        for i in "${!available_sites[@]}"; do
            echo -e " ${GREEN}$((i + 1)).${PLAIN} ${available_sites[$i]}"
        done
        echo -e " ${GREEN}c.${PLAIN} 自定义输入"
        echo ""
        read -rp "请选择 [0-${#available_sites[@]}/c] (回车使用推荐): " siteChoice

        if [[ -z $siteChoice ]] || [[ $siteChoice == "0" ]]; then
            proxysite="${available_sites[0]}"
        elif [[ $siteChoice == "c" ]] || [[ $siteChoice == "C" ]]; then
            read -rp "请输入自定义伪装网站地址（去除https://）：" proxysite
            [[ -z $proxysite ]] && proxysite="${available_sites[0]}"
        elif [[ $siteChoice =~ ^[0-9]+$ ]] && [[ $siteChoice -le ${#available_sites[@]} ]] && [[ $siteChoice -ge 1 ]]; then
            proxysite="${available_sites[$((siteChoice - 1))]}"
        else
            proxysite="${available_sites[0]}"
        fi
    else
        yellow "未检测到可用网站，请手动输入"
        read -rp "请输入伪装网站地址（去除https://）：" proxysite
        [[ -z $proxysite ]] && proxysite="www.wikipedia.org"
    fi

    yellow "使用在 Hysteria 2 节点的伪装网站为：$proxysite"
}

# 安装 Hysteria 2
insthysteria(){
    warpv6=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    warpv4=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    if [[ $warpv4 =~ on|plus || $warpv6 =~ on|plus ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        systemctl stop warp-go >/dev/null 2>&1
        realip
        systemctl start warp-go >/dev/null 2>&1
        wg-quick up wgcf >/dev/null 2>&1
    else
        realip
    fi

    if [[ ! ${SYSTEM} == "CentOS" ]]; then
        ${PACKAGE_UPDATE[int]}
    fi
    ${PACKAGE_INSTALL[int]} curl wget sudo qrencode procps iptables-persistent netfilter-persistent openssl

    # 安装 Hysteria 2 (多源下载，自动回退)
    install_hysteria_binary

    if [[ -f "/usr/local/bin/hysteria" ]]; then
        green "Hysteria 2 安装成功！"
        green "当前版本: $(get_installed_version)"
    else
        red "Hysteria 2 安装失败！"
        exit 1
    fi

    # 确保配置目录存在
    mkdir -p /etc/hysteria

    # 询问用户 Hysteria 配置
    inst_cert
    inst_port
    inst_pwd
    inst_site

    # 设置 Hysteria 服务端配置文件
    cat << EOF > /etc/hysteria/config.yaml
listen: :$port

tls:
  cert: $cert_path
  key: $key_path

auth:
  type: password
  password: $auth_pwd

masquerade:
  type: proxy
  proxy:
    url: https://$proxysite
    rewriteHost: true
EOF

    # 确定最终入站端口范围
    if [[ -n $firstport ]]; then
        last_port="$port,$firstport-$endport"
    else
        last_port=$port
    fi

    # 给 IPv6 地址加中括号
    if [[ -n $(echo $ip | grep ":") ]]; then
        last_ip="[$ip]"
    else
        last_ip=$ip
    fi

    # 生成客户端配置文件目录
    mkdir -p /root/hy

    # 计算自签证书指纹 (用于 pinSHA256)
    if [[ -z $cert_fingerprint ]]; then
        cert_fingerprint=$(openssl x509 -noout -fingerprint -sha256 -in "$cert_path" 2>/dev/null | cut -d= -f2)
    fi

    # 判断是否为自签证书
    if [[ $hy_domain == "www.bing.com" ]]; then
        is_selfsigned=true
    else
        is_selfsigned=false
    fi

    # 生成 Hysteria 2 客户端 YAML 配置
    cat << EOF > /root/hy/hy-client.yaml
server: $last_ip:$last_port

auth: $auth_pwd

tls:
  sni: $hy_domain
  insecure: $is_selfsigned
EOF

    # 如果是自签证书，添加 pinSHA256
    if [[ $is_selfsigned == true ]] && [[ -n $cert_fingerprint ]]; then
        cat << EOF >> /root/hy/hy-client.yaml
  pinSHA256: $cert_fingerprint
EOF
    fi

    cat << EOF >> /root/hy/hy-client.yaml

fastOpen: true

socks5:
  listen: 127.0.0.1:5080

http:
  listen: 127.0.0.1:8080

transport:
  udp:
    hopInterval: 30s
EOF

    # 生成 Hysteria 2 客户端 JSON 配置
    if [[ $is_selfsigned == true ]] && [[ -n $cert_fingerprint ]]; then
        pin_json="\"pinSHA256\": \"$cert_fingerprint\","
    else
        pin_json=""
    fi

    cat << EOF > /root/hy/hy-client.json
{
  "server": "$last_ip:$last_port",
  "auth": "$auth_pwd",
  "tls": {
    "sni": "$hy_domain",
    "insecure": $is_selfsigned,
    $pin_json
    "_comment": "如不需要 pinSHA256 可删除该行和上一行"
  },
  "fastOpen": true,
  "socks5": {
    "listen": "127.0.0.1:5080"
  },
  "http": {
    "listen": "127.0.0.1:8080"
  },
  "transport": {
    "udp": {
      "hopInterval": "30s"
    }
  }
}
EOF

    # 生成 Clash Meta 客户端配置
    cat <<EOF > /root/hy/clash-meta.yaml
mixed-port: 7890
external-controller: 127.0.0.1:9090
allow-lan: false
mode: rule
log-level: debug
ipv6: true
dns:
  enable: true
  listen: 0.0.0.0:53
  enhanced-mode: fake-ip
  nameserver:
    - 8.8.8.8
    - 1.1.1.1
    - 114.114.114.114
proxies:
  - name: Misaka-Hysteria2
    type: hysteria2
    server: $last_ip
    port: $port
    password: $auth_pwd
    sni: $hy_domain
    skip-cert-verify: $is_selfsigned
proxy-groups:
  - name: Proxy
    type: select
    proxies:
      - Misaka-Hysteria2

rules:
  - GEOIP,CN,DIRECT
  - MATCH,Proxy
EOF

    # 生成分享链接
    url="hysteria2://$auth_pwd@$last_ip:$last_port/?insecure=1&sni=$hy_domain#Misaka-Hysteria2"
    echo $url > /root/hy/url.txt
    nohopurl="hysteria2://$auth_pwd@$last_ip:$port/?insecure=1&sni=$hy_domain#Misaka-Hysteria2"
    echo $nohopurl > /root/hy/url-nohop.txt

    # 启动服务
    systemctl daemon-reload
    systemctl enable hysteria-server
    systemctl start hysteria-server
    if [[ -n $(systemctl status hysteria-server 2>/dev/null | grep -w active) && -f '/etc/hysteria/config.yaml' ]]; then
        green "Hysteria 2 服务启动成功"
    else
        red "Hysteria 2 服务启动失败，请运行 systemctl status hysteria-server 查看服务状态并反馈，脚本退出" && exit 1
    fi

    # 显示配置信息
    red "======================================================================================"
    green "Hysteria 2 代理服务安装完成"
    green "当前 Hysteria 2 版本: $(get_installed_version)"
    echo ""
    yellow "Hysteria 2 客户端 YAML 配置文件 hy-client.yaml 内容如下，并保存到 /root/hy/hy-client.yaml"
    red "$(cat /root/hy/hy-client.yaml)"
    echo ""
    yellow "Hysteria 2 客户端 JSON 配置文件 hy-client.json 内容如下，并保存到 /root/hy/hy-client.json"
    red "$(cat /root/hy/hy-client.json)"
    echo ""
    yellow "Clash Meta 客户端配置文件已保存到 /root/hy/clash-meta.yaml"
    echo ""
    yellow "Hysteria 2 节点分享链接如下，并保存到 /root/hy/url.txt"
    red "$(cat /root/hy/url.txt)"
    echo ""
    if [[ -n $firstport ]]; then
        yellow "Hysteria 2 节点单端口的分享链接如下，并保存到 /root/hy/url-nohop.txt"
        red "$(cat /root/hy/url-nohop.txt)"
    fi
    echo ""
    if [[ $is_selfsigned == true ]] && [[ -n $cert_fingerprint ]]; then
        blue "提示: 使用自签证书，建议客户端配置 pinSHA256: $cert_fingerprint"
    fi
}

# 卸载 Hysteria 2
unsthysteria(){
    systemctl stop hysteria-server.service >/dev/null 2>&1
    systemctl disable hysteria-server.service >/dev/null 2>&1

    # 尝试使用官方脚本卸载，失败则手动移除
    bash <(curl -fsSL https://get.hy2.sh/) --remove 2>/dev/null || {
        yellow "官方卸载脚本不可用，手动移除..."
        rm -f /usr/local/bin/hysteria
        rm -f /etc/systemd/system/hysteria-server.service
        rm -f /etc/systemd/system/hysteria-server@.service
        systemctl daemon-reload
    }

    rm -rf /etc/hysteria /root/hy /root/hysteria.sh
    iptables -t nat -F PREROUTING >/dev/null 2>&1
    netfilter-persistent save >/dev/null 2>&1

    green "Hysteria 2 已彻底卸载完成！"
}

# 启动 Hysteria 2
starthysteria(){
    systemctl start hysteria-server
    systemctl enable hysteria-server >/dev/null 2>&1
    green "Hysteria 2 已启动"
}

# 停止 Hysteria 2
stophysteria(){
    systemctl stop hysteria-server
    systemctl disable hysteria-server >/dev/null 2>&1
    green "Hysteria 2 已停止"
}

# 启停切换
hysteriaswitch(){
    yellow "请选择你需要的操作："
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 启动 Hysteria 2"
    echo -e " ${GREEN}2.${PLAIN} 关闭 Hysteria 2"
    echo -e " ${GREEN}3.${PLAIN} 重启 Hysteria 2"
    echo ""
    read -rp "请输入选项 [1-3]: " switchInput
    case $switchInput in
        1 ) starthysteria ;;
        2 ) stophysteria ;;
        3 ) stophysteria && starthysteria ;;
        * ) exit 1 ;;
    esac
}

# 修改端口
changeport(){
    oldport=$(cat /etc/hysteria/config.yaml 2>/dev/null | sed -n 1p | awk '{print $2}' | awk -F ":" '{print $2}')

    read -p "设置 Hysteria 2 端口[1-65535]（回车则随机分配端口）：" port
    [[ -z $port ]] && port=$(shuf -i 2000-65535 -n 1)

    until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]; do
        if [[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]; then
            echo -e "${RED} $port ${PLAIN} 端口已经被其他程序占用，请更换端口重试！"
            read -p "设置 Hysteria 2 端口 [1-65535]（回车则随机分配端口）：" port
            [[ -z $port ]] && port=$(shuf -i 2000-65535 -n 1)
        fi
    done

    sed -i "1s#$oldport#$port#g" /etc/hysteria/config.yaml
    sed -i "1s#$oldport#$port#g" /root/hy/hy-client.yaml
    sed -i "s#$oldport#$port#g" /root/hy/hy-client.json

    stophysteria && starthysteria

    green "Hysteria 2 端口已成功修改为：$port"
    yellow "请手动更新客户端配置文件以使用节点"
    showconf
}

# 修改密码
changepasswd(){
    oldpasswd=$(cat /etc/hysteria/config.yaml 2>/dev/null | grep "password:" | tail -1 | awk '{print $2}')

    read -p "设置 Hysteria 2 密码（回车跳过为随机字符）：" passwd
    [[ -z $passwd ]] && passwd=$(date +%s%N | md5sum | cut -c 1-8)

    sed -i "s#password: $oldpasswd#password: $passwd#g" /etc/hysteria/config.yaml
    sed -i "s#auth: $oldpasswd#auth: $passwd#g" /root/hy/hy-client.yaml
    sed -i "s#\"auth\": \"$oldpasswd\"#\"auth\": \"$passwd\"#g" /root/hy/hy-client.json

    stophysteria && starthysteria

    green "Hysteria 2 节点密码已成功修改为：$passwd"
    yellow "请手动更新客户端配置文件以使用节点"
    showconf
}

# 修改证书
change_cert(){
    old_cert=$(cat /etc/hysteria/config.yaml | grep cert | awk -F " " '{print $2}')
    old_key=$(cat /etc/hysteria/config.yaml | grep key | awk -F " " '{print $2}')
    old_hydomain=$(cat /root/hy/hy-client.yaml | grep sni | awk '{print $2}')

    inst_cert

    sed -i "s!$old_cert!$cert_path!g" /etc/hysteria/config.yaml
    sed -i "s!$old_key!$key_path!g" /etc/hysteria/config.yaml
    sed -i "s/$old_hydomain/$hy_domain/g" /root/hy/hy-client.yaml
    sed -i "s/$old_hydomain/$hy_domain/g" /root/hy/hy-client.json

    stophysteria && starthysteria

    green "Hysteria 2 节点证书类型已成功修改"
    yellow "请手动更新客户端配置文件以使用节点"
    showconf
}

# 修改伪装网站
changeproxysite(){
    oldproxysite=$(cat /etc/hysteria/config.yaml | grep url | awk -F " " '{print $2}' | awk -F "https://" '{print $2}')

    inst_site

    sed -i "s#$oldproxysite#$proxysite#g" /etc/hysteria/config.yaml

    stophysteria && starthysteria

    green "Hysteria 2 节点伪装网站已成功修改为：$proxysite"
}

# 修改配置菜单
changeconf(){
    green "Hysteria 2 配置变更选择如下:"
    echo -e " ${GREEN}1.${PLAIN} 修改端口"
    echo -e " ${GREEN}2.${PLAIN} 修改密码"
    echo -e " ${GREEN}3.${PLAIN} 修改证书类型"
    echo -e " ${GREEN}4.${PLAIN} 修改伪装网站"
    echo ""
    read -p " 请选择操作 [1-4]：" confAnswer
    case $confAnswer in
        1 ) changeport ;;
        2 ) changepasswd ;;
        3 ) change_cert ;;
        4 ) changeproxysite ;;
        * ) exit 1 ;;
    esac
}

# 显示配置
showconf(){
    yellow "Hysteria 2 客户端 YAML 配置文件 hy-client.yaml 内容如下，并保存到 /root/hy/hy-client.yaml"
    red "$(cat /root/hy/hy-client.yaml)"
    echo ""
    yellow "Hysteria 2 客户端 JSON 配置文件 hy-client.json 内容如下，并保存到 /root/hy/hy-client.json"
    red "$(cat /root/hy/hy-client.json)"
    echo ""
    yellow "Clash Meta 客户端配置文件已保存到 /root/hy/clash-meta.yaml"
    echo ""
    yellow "Hysteria 2 节点分享链接如下，并保存到 /root/hy/url.txt"
    red "$(cat /root/hy/url.txt)"
    echo ""
    yellow "Hysteria 2 节点单端口的分享链接如下，并保存到 /root/hy/url-nohop.txt"
    red "$(cat /root/hy/url-nohop.txt)"
}

# 查看服务状态
showstatus(){
    echo ""
    green "===== Hysteria 2 服务状态 ====="
    echo ""
    systemctl status hysteria-server --no-pager
    echo ""
    green "===== 已安装版本 ====="
    echo ""
    green "版本: $(get_installed_version)"
    echo ""
}

# 查看运行日志
showlog(){
    echo ""
    green "===== Hysteria 2 运行日志 (最近50行) ====="
    echo ""
    journalctl -u hysteria-server --no-pager -n 50
    echo ""
}

# 更新 Hysteria 2 内核
update_core(){
    green "正在更新 Hysteria 2..."
    install_hysteria_binary
    green "Hysteria 2 更新完成！当前版本: $(get_installed_version)"

    # 重启运行中的服务
    if [[ -n $(systemctl status hysteria-server 2>/dev/null | grep -w active) ]]; then
        systemctl restart hysteria-server
        green "Hysteria 2 服务已自动重启"
    fi
}

# 主菜单
menu() {
    clear
    echo "#############################################################"
    echo -e "#          ${RED}Hysteria 2 一键安装脚本${PLAIN} ${GREEN}v${SCRIPT_VERSION}${PLAIN}               #"
    echo -e "# ${GREEN}原作者${PLAIN}: MisakaNo の 小破站                                #"
    echo -e "# ${GREEN}更新${PLAIN}: 基于 Hysteria 2 v2.7.x 官方文档                     #"
    echo -e "# ${GREEN}官方项目${PLAIN}: https://github.com/apernet/hysteria            #"
    echo -e "# ${GREEN}官方文档${PLAIN}: https://v2.hysteria.network/zh/                 #"
    echo "#############################################################"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 安装 Hysteria 2"
    echo -e " ${GREEN}2.${PLAIN} ${RED}卸载 Hysteria 2${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}3.${PLAIN} 关闭、开启、重启 Hysteria 2"
    echo -e " ${GREEN}4.${PLAIN} 修改 Hysteria 2 配置"
    echo -e " ${GREEN}5.${PLAIN} 显示 Hysteria 2 配置文件"
    echo " -------------"
    echo -e " ${GREEN}6.${PLAIN} 更新 Hysteria 2 内核"
    echo -e " ${GREEN}7.${PLAIN} 查看 Hysteria 2 服务状态"
    echo -e " ${GREEN}8.${PLAIN} 查看 Hysteria 2 运行日志"
    echo " -------------"
    echo -e " ${GREEN}0.${PLAIN} 退出脚本"
    echo ""
    read -rp "请输入选项 [0-8]: " menuInput
    case $menuInput in
        1 ) insthysteria ;;
        2 ) unsthysteria ;;
        3 ) hysteriaswitch ;;
        4 ) changeconf ;;
        5 ) showconf ;;
        6 ) update_core ;;
        7 ) showstatus ;;
        8 ) showlog ;;
        * ) exit 1 ;;
    esac
}

menu
