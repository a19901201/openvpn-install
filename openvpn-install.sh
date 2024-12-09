#!/bin/bash
# shellcheck disable=SC1091,SC2164,SC2034,SC1072,SC1073,SC1009

# Secure OpenVPN server installer for Debian, Ubuntu, CentOS, Amazon Linux 2, Fedora, Oracle Linux 8, Arch Linux, Rocky Linux, and AlmaLinux.
# https://github.com/a19901201/openvpn-install

function isRoot() {
	if [ "$EUID" -ne 0 ]; then
		return 1
	fi
}

function tunAvailable() {
	if [ ! -e /dev/net/tun ]; then
		return 1
	fi
}

function checkOS() {
	if [[ -e /etc/debian_version ]]; then
		OS="debian"
		source /etc/os-release

		if [[ $ID == "debian" || $ID == "raspbian" ]]; then
			if [[ $VERSION_ID -lt 9 ]]; then
				echo "⚠️ 您的 Debian 版本不受支援。"
				echo ""
				echo "但是，如果您使用 Debian >= 9 或不穩定/測試版，您可以自行承擔風險繼續執行。"
				echo ""
				until [[ $CONTINUE =~ (y|n) ]]; do
					read -rp "繼續嗎？[y/n]：" -e CONTINUE
				done
				if [[ $CONTINUE == "n" ]]; then
					exit 1
				fi
			fi
		elif [[ $ID == "ubuntu" ]]; then
			OS="ubuntu"
			MAJOR_UBUNTU_VERSION=$(echo "$VERSION_ID" | cut -d '.' -f1)
			if [[ $MAJOR_UBUNTU_VERSION -lt 16 ]]; then
				echo "⚠️ 您的 Ubuntu 版本不受支援。"
				echo ""
				echo "但是，如果您使用 Ubuntu >= 16.04 或測試版，您可以自行承擔風險繼續執行。"
				echo ""
				until [[ $CONTINUE =~ (y|n) ]]; do
					read -rp "繼續嗎？[y/n]：" -e CONTINUE
				done
				if [[ $CONTINUE == "n" ]]; then
					exit 1
				fi
			fi
		fi
	elif [[ -e /etc/system-release ]]; then
		source /etc/os-release
		if [[ $ID == "fedora" || $ID_LIKE == "fedora" ]]; then
			OS="fedora"
		fi
		if [[ $ID == "centos" || $ID == "rocky" || $ID == "almalinux" ]]; then
			OS="centos"
			if [[ $VERSION_ID -lt 7 ]]; then
				echo "⚠️ 您的 CentOS 版本不受支援。"
				echo ""
				echo "此腳本僅支援 CentOS 7 和 CentOS 8。"
				echo ""
				exit 1
			fi
		fi
		if [[ $ID == "ol" ]]; then
			OS="oracle"
			if [[ ! $VERSION_ID =~ (8) ]]; then
				echo "您的 Oracle Linux 版本不受支援。"
				echo ""
				echo "此腳本僅支援 Oracle Linux 8。"
				exit 1
			fi
		fi
		if [[ $ID == "amzn" ]]; then
			OS="amzn"
			if [[ $VERSION_ID != "2" ]]; then
				echo "⚠️ 您的 Amazon Linux 版本不受支援。"
				echo ""
				echo "此腳本僅支援 Amazon Linux 2。"
				echo ""
				exit 1
			fi
		fi
	elif [[ -e /etc/arch-release ]]; then
		OS=arch
	else
		echo "看起來您並未在 Debian、Ubuntu、Fedora、CentOS、Amazon Linux 2、Oracle Linux 8 或 Arch Linux 系統上執行此安裝程式"
		exit 1
	fi
}

function initialCheck() {
	if ! isRoot; then
		echo "抱歉，您需要以 root 權限執行此腳本"
		exit 1
	fi
	if ! tunAvailable; then
		echo "TUN 不可用"
		exit 1
	fi
	checkOS
}

function installUnbound() {
	# 如果尚未安裝 Unbound，則進行安裝
	if [[ ! -e /etc/unbound/unbound.conf ]]; then

		if [[ $OS =~ (debian|ubuntu) ]]; then
			apt-get install -y unbound

			# 設定檔
			echo 'interface: 10.8.0.1
access-control: 10.8.0.1/24 allow
hide-identity: yes
hide-version: yes
use-caps-for-id: yes
prefetch: yes' >>/etc/unbound/unbound.conf

		elif [[ $OS =~ (centos|amzn|oracle) ]]; then
			yum install -y unbound

			# 設定檔
			sed -i 's|# interface: 0.0.0.0$|interface: 10.8.0.1|' /etc/unbound/unbound.conf
			sed -i 's|# access-control: 127.0.0.0/8 allow|access-control: 10.8.0.1/24 allow|' /etc/unbound/unbound.conf
			sed -i 's|# hide-identity: no|hide-identity: yes|' /etc/unbound/unbound.conf
			sed -i 's|# hide-version: no|hide-version: yes|' /etc/unbound/unbound.conf
			sed -i 's|use-caps-for-id: no|use-caps-for-id: yes|' /etc/unbound/unbound.conf

		elif [[ $OS == "fedora" ]]; then
			dnf install -y unbound

			# 設定檔
			sed -i 's|# interface: 0.0.0.0$|interface: 10.8.0.1|' /etc/unbound/unbound.conf
			sed -i 's|# access-control: 127.0.0.0/8 allow|access-control: 10.8.0.1/24 allow|' /etc/unbound/unbound.conf
			sed -i 's|# hide-identity: no|hide-identity: yes|' /etc/unbound/unbound.conf
			sed -i 's|# hide-version: no|hide-version: yes|' /etc/unbound/unbound.conf
			sed -i 's|# use-caps-for-id: no|use-caps-for-id: yes|' /etc/unbound/unbound.conf

		elif [[ $OS == "arch" ]]; then
			pacman -Syu --noconfirm unbound

			# 取得根 DNS 伺服器清單
			curl -o /etc/unbound/root.hints https://www.internic.net/domain/named.cache

			if [[ ! -f /etc/unbound/unbound.conf.old ]]; then
				mv /etc/unbound/unbound.conf /etc/unbound/unbound.conf.old
			fi

			echo 'server:
	use-syslog: yes
	do-daemonize: no
	username: "unbound"
	directory: "/etc/unbound"
	trust-anchor-file: trusted-key.key
	root-hints: root.hints
	interface: 10.8.0.1
	access-control: 10.8.0.1/24 allow
	port: 53
	num-threads: 2
	use-caps-for-id: yes
	harden-glue: yes
	hide-identity: yes
	hide-version: yes
	qname-minimisation: yes
	prefetch: yes' >/etc/unbound/unbound.conf
		fi

		# IPv6 DNS 支援
		if [[ $IPV6_SUPPORT == 'y' ]]; then
			echo 'interface: fd42:42:42:42::1
access-control: fd42:42:42:42::/112 allow' >>/etc/unbound/unbound.conf
		fi

		if [[ ! $OS =~ (fedora|centos|amzn|oracle) ]]; then
			# 解決 DNS 重新繫結問題
			echo "private-address: 10.0.0.0/8
private-address: fd42:42:42:42::/112
private-address: 172.16.0.0/12
private-address: 192.168.0.0/16
private-address: 169.254.0.0/16
private-address: fd00::/8
private-address: fe80::/10
private-address: 127.0.0.0/8
private-address: ::ffff:0:0/96" >>/etc/unbound/unbound.conf
		fi
	else # Unbound 已經安裝
		echo 'include: /etc/unbound/openvpn.conf' >>/etc/unbound/unbound.conf

		# 為 OpenVPN 子網段新增 Unbound 'server'
		echo 'server:
interface: 10.8.0.1
access-control: 10.8.0.1/24 allow
hide-identity: yes
hide-version: yes
use-caps-for-id: yes
prefetch: yes
private-address: 10.0.0.0/8
private-address: fd42:42:42:42::/112
private-address: 172.16.0.0/12
private-address: 192.168.0.0/16
private-address: 169.254.0.0/16
private-address: fd00::/8
private-address: fe80::/10
private-address: 127.0.0.0/8
private-address: ::ffff:0:0/96' >/etc/unbound/openvpn.conf
		if [[ $IPV6_SUPPORT == 'y' ]]; then
			echo 'interface: fd42:42:42:42::1
access-control: fd42:42:42:42::/112 allow' >>/etc/unbound/openvpn.conf
		fi
	fi

	systemctl enable unbound
	systemctl restart unbound
}

function installQuestions() {
    echo "歡迎使用 OpenVPN 安裝程式！"
    echo "Git 儲存庫位於：https://github.com/a19901201/openvpn-install"
    echo ""

    echo "在開始設定之前，我需要問您幾個問題。"
    echo "如果您對預設選項滿意，只需按 Enter 鍵即可。"
    echo ""
    echo "我需要知道您希望 OpenVPN 監聽的網路介面的 IPv4 位址。"
    echo "除非您的伺服器位於 NAT 後，否則應該是您的公共 IPv4 位址。"

    # 使用 curl 從 Cloudflare 獲取公共 IPv4 位址
    response=$(curl -s https://www.cloudflare.com/cdn-cgi/trace)
    
    # 提取 'ip=' 之後的 IP 位址
    detected_ip=$(echo "$response" | grep 'ip=' | awk -F= '{print $2}')

    if [[ -n "$detected_ip" ]]; then
        echo "偵測到的公共 IPv4 位址是：$detected_ip"
        while true; do
            read -p "是否使用這個 IP 地址？[Y/n]: " choice
            case "$choice" in
                [Yy]* )
                    IP="$detected_ip"
                    break
                    ;;
                [Nn]* )
                    while true; do
                        read -p "請手動輸入您的公共 IPv4 位址: " IP
                        # 檢查 IPv4 的格式和範圍
                        if [[ $IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
                            IFS='.' read -r -a octets <<< "$IP"
                            valid=true
                            for octet in "${octets[@]}"; do
                                if ((octet < 0 || octet > 255)); then
                                    valid=false
                                    break
                                fi
                            done
                            if $valid; then
                                break
                            fi
                        fi
                        echo "無效的 IPv4 位址，請再試一次。"
                    done
                    break
                    ;;
                * )
                    echo "請輸入 Y 或 N。"
                    ;;
            esac
        done
    else
        echo "無法從 Cloudflare 獲取公共 IPv4 位址。"
        while true; do
            read -p "請手動輸入您的公共 IPv4 位址: " IP
            # 檢查 IPv4 的格式和範圍
            if [[ $IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
                IFS='.' read -r -a octets <<< "$IP"
                valid=true
                for octet in "${octets[@]}"; do
                    if ((octet < 0 || octet > 255)); then
                        valid=false
                        break
                    fi
                done
                if $valid; then
                    break
                fi
            fi
            echo "無效的 IPv4 位址，請再試一次。"
        done
    fi

    echo "使用的 IPv4 位址是：$IP"

	if [[ -z $IP ]]; then
		# 偵測公共 IPv6 位址
		IP=$(ip -6 addr | sed -ne 's|^.* inet6 \([^/]*\)/.* scope global.*$|\1|p' | head -1)
	fi
	APPROVE_IP=${APPROVE_IP:-n}
	if [[ $APPROVE_IP =~ n ]]; then
		read -rp "IP 位址： " -e -i "$IP" IP
	fi
	# 如果 $IP 是私有 IP 位址，則伺服器必須位於 NAT 後
	if echo "$IP" | grep -qE '^(10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.|192\.168)'; then
		echo ""
		echo "看起來這台伺服器位於 NAT 後。請問它的公共 IPv4 位址或主機名是什麼？"
		echo "我們需要這個資訊，以便讓客戶端連接到伺服器。"

		PUBLICIP=$(curl -s https://api.ipify.org)
		until [[ $ENDPOINT != "" ]]; do
			read -rp "公共 IPv4 位址或主機名： " -e -i "$PUBLICIP" ENDPOINT
		done
	fi

	echo ""
	echo "正在檢查 IPv6 連線狀態..."
	echo ""
	# "ping6" 和 "ping -6" 的可用性因發行版而異
	if type ping6 >/dev/null 2>&1; then
		PING6="ping6 -c3 ipv6.google.com > /dev/null 2>&1"
	else
		PING6="ping -6 -c3 ipv6.google.com > /dev/null 2>&1"
	fi
	if eval "$PING6"; then
		echo "主機似乎具有 IPv6 連線功能。"
		SUGGESTION="y"
	else
		echo "主機似乎沒有 IPv6 連線功能。"
		SUGGESTION="n"
	fi
	echo ""
	# 詢問使用者是否要啟用 IPv6，無論其可用性如何
	until [[ $IPV6_SUPPORT =~ (y|n) ]]; do
		read -rp "是否要啟用 IPv6 支援（NAT）？[y/n]：" -e -i $SUGGESTION IPV6_SUPPORT
	done
	echo ""
	echo "您希望 OpenVPN 監聽的埠號是多少？"
	echo "   1) 預設：1194"
	echo "   2) 自訂"
	echo "   3) 隨機 [49152-65535]"
	until [[ $PORT_CHOICE =~ ^[1-3]$ ]]; do
		read -rp "埠號選擇 [1-3]：" -e -i 1 PORT_CHOICE
	done
	case $PORT_CHOICE in
	1)
		PORT="1194"
		;;
	2)
		until [[ $PORT =~ ^[0-9]+$ ]] && [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ]; do
			read -rp "自訂埠號 [1-65535]：" -e -i 1194 PORT
		done
		;;
	3)
		# 在私有埠號範圍內產生隨機數字
		PORT=$(shuf -i49152-65535 -n1)
		echo "隨機埠號：$PORT"
		;;
	esac
	echo ""
	echo "您希望 OpenVPN 使用哪種協定？"
	echo "UDP 是較快的選項。除非無法使用，否則不建議使用 TCP。"
	echo "   1) UDP"
	echo "   2) TCP"
	until [[ $PROTOCOL_CHOICE =~ ^[1-2]$ ]]; do
		read -rp "協定 [1-2]：" -e -i 1 PROTOCOL_CHOICE
	done
	case $PROTOCOL_CHOICE in
	1)
		PROTOCOL="udp"
		;;
	2)
		PROTOCOL="tcp"
		;;
	esac
	echo ""
	echo "您希望使用哪些 DNS 解析器與 VPN 一起使用？"
	echo "   1) 現有系統解析器（來自 /etc/resolv.conf）"
	echo "   2) 自架 DNS 解析器（Unbound）"
	echo "   3) Cloudflare（全球範圍的 Anycast）"
	echo "   4) Quad9（全球範圍的 Anycast）"
	echo "   5) Quad9 不受審查（全球範圍的 Anycast）"
	echo "   6) FDN（法國）"
	echo "   7) DNS.WATCH（德國）"
	echo "   8) OpenDNS（全球範圍的 Anycast）"
	echo "   9) Google（全球範圍的 Anycast）"
	echo "   10) Yandex 基礎版（俄羅斯）"
	echo "   11) AdGuard DNS（全球範圍的 Anycast）"
	echo "   12) NextDNS（全球範圍的 Anycast）"
	echo "   13) 自訂"
	until [[ $DNS =~ ^[0-9]+$ ]] && [ "$DNS" -ge 1 ] && [ "$DNS" -le 13 ]; do
		read -rp "DNS [1-12]：" -e -i 5 DNS
		if [[ $DNS == 2 ]] && [[ -e /etc/unbound/unbound.conf ]]; then
			echo ""
			echo "Unbound 已經安裝。"
			echo "您可以允許腳本配置它以供您的 OpenVPN 客戶端使用。"
			echo "我們將在 /etc/unbound/unbound.conf 中為 OpenVPN 子網段新增第二個伺服器。"
			echo "不會對當前配置進行任何更改。"
			echo ""

			until [[ $CONTINUE =~ (y|n) ]]; do
				read -rp "要套用配置更改至 Unbound 嗎？[y/n]：" -e CONTINUE
			done
			if [[ $CONTINUE == "n" ]]; then
				# 中斷迴圈並清理
				unset DNS
				unset CONTINUE
			fi
		elif [[ $DNS == "13" ]]; then
			until [[ $DNS1 =~ ^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]; do
				read -rp "主要 DNS：" -e DNS1
			done
			until [[ $DNS2 =~ ^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]; do
				read -rp "次要 DNS（選填）：" -e DNS2
				if [[ $DNS2 == "" ]]; then
					break
				fi
			done
		fi
	done
	echo ""
	echo "您想使用壓縮嗎？不建議使用，因為 VORACLE 攻擊利用了它。"
	until [[ $COMPRESSION_ENABLED =~ (y|n) ]]; do
		read -rp"啟用壓縮？[y/n]：" -e -i n COMPRESSION_ENABLED
	done
	if [[ $COMPRESSION_ENABLED == "y" ]]; then
		echo "選擇要使用的壓縮算法：（按效能順序排列）"
		echo "   1) LZ4-v2"
		echo "   2) LZ4"
		echo "   3) LZ0"
		until [[ $COMPRESSION_CHOICE =~ ^[1-3]$ ]]; do
			read -rp"壓縮算法 [1-3]：" -e -i 1 COMPRESSION_CHOICE
		done
		case $COMPRESSION_CHOICE in
		1)
			COMPRESSION_ALG="lz4-v2"
			;;
		2)
			COMPRESSION_ALG="lz4"
			;;
		3)
			COMPRESSION_ALG="lzo"
			;;
		esac
	fi
	echo ""
	echo "是否要自訂加密設定？"
	echo "除非您知道自己在做什麼，否則應該使用腳本提供的預設參數。"
	echo "請注意，無論您選擇什麼，腳本中提供的所有選項都是安全的。（不像 OpenVPN 的預設值）"
	echo "請參閱 https://github.com/a19901201/openvpn-install#security-and-encryption 了解更多資訊。"
	echo ""
	until [[ $CUSTOMIZE_ENC =~ (y|n) ]]; do
		read -rp "自訂加密設定？[y/n]：" -e -i n CUSTOMIZE_ENC
	done
	if [[ $CUSTOMIZE_ENC == "n" ]]; then
		# 使用預設、合理且快速的參數
		CIPHER="AES-128-GCM"
		CERT_TYPE="1" # ECDSA
		CERT_CURVE="prime256v1"
		CC_CIPHER="TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256"
		DH_TYPE="1" # ECDH
		DH_CURVE="prime256v1"
		HMAC_ALG="SHA256"
		TLS_SIG="1" # tls-crypt
	else
		echo ""
		echo "選擇您希望用於資料通道的加密演算法："
		echo "   1) AES-128-GCM（推薦）"
		echo "   2) AES-192-GCM"
		echo "   3) AES-256-GCM"
		echo "   4) AES-128-CBC"
		echo "   5) AES-192-CBC"
		echo "   6) AES-256-CBC"
		until [[ $CIPHER_CHOICE =~ ^[1-6]$ ]]; do
			read -rp "加密演算法 [1-6]：" -e -i 1 CIPHER_CHOICE
		done
		case $CIPHER_CHOICE in
		1)
			CIPHER="AES-128-GCM"
			;;
		2)
			CIPHER="AES-192-GCM"
			;;
		3)
			CIPHER="AES-256-GCM"
			;;
		4)
			CIPHER="AES-128-CBC"
			;;
		5)
			CIPHER="AES-192-CBC"
			;;
		6)
			CIPHER="AES-256-CBC"
			;;
		esac
		echo ""
		echo "選擇您希望使用的憑證類型："
		echo "   1) ECDSA（推薦）"
		echo "   2) RSA"
		until [[ $CERT_TYPE =~ ^[1-2]$ ]]; do
			read -rp"憑證金鑰類型 [1-2]：" -e -i 1 CERT_TYPE
		done
		case $CERT_TYPE in
		1)
			echo ""
			echo "選擇您希望用於憑證金鑰的曲線："
			echo "   1) prime256v1（推薦）"
			echo "   2) secp384r1"
			echo "   3) secp521r1"
			until [[ $CERT_CURVE_CHOICE =~ ^[1-3]$ ]]; do
				read -rp"曲線 [1-3]：" -e -i 1 CERT_CURVE_CHOICE
			done
			case $CERT_CURVE_CHOICE in
			1)
				CERT_CURVE="prime256v1"
				;;
			2)
				CERT_CURVE="secp384r1"
				;;
			3)
				CERT_CURVE="secp521r1"
				;;
			esac
			;;
		2)
			echo ""
			echo "選擇您希望使用的憑證 RSA 金鑰大小："
			echo "   1) 2048 位元（推薦）"
			echo "   2) 3072 位元"
			echo "   3) 4096 位元"
			until [[ $RSA_KEY_SIZE_CHOICE =~ ^[1-3]$ ]]; do
				read -rp "RSA 金鑰大小 [1-3]：" -e -i 1 RSA_KEY_SIZE_CHOICE
			done
			case $RSA_KEY_SIZE_CHOICE in
			1)
				RSA_KEY_SIZE="2048"
				;;
			2)
				RSA_KEY_SIZE="3072"
				;;
			3)
				RSA_KEY_SIZE="4096"
				;;
			esac
			;;
		esac
		echo ""
		echo "選擇您希望用於控制通道的加密演算法："
		case $CERT_TYPE in
		1)
			echo "   1) ECDHE-ECDSA-AES-128-GCM-SHA256（推薦）"
			echo "   2) ECDHE-ECDSA-AES-256-GCM-SHA384"
			until [[ $CC_CIPHER_CHOICE =~ ^[1-2]$ ]]; do
				read -rp"控制通道加密演算法 [1-2]：" -e -i 1 CC_CIPHER_CHOICE
			done
			case $CC_CIPHER_CHOICE in
			1)
				CC_CIPHER="TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256"
				;;
			2)
				CC_CIPHER="TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384"
				;;
			esac
			;;
		2)
			echo "   1) ECDHE-RSA-AES-128-GCM-SHA256（推薦）"
			echo "   2) ECDHE-RSA-AES-256-GCM-SHA384"
			until [[ $CC_CIPHER_CHOICE =~ ^[1-2]$ ]]; do
				read -rp"控制通道加密演算法 [1-2]：" -e -i 1 CC_CIPHER_CHOICE
			done
			case $CC_CIPHER_CHOICE in
			1)
				CC_CIPHER="TLS-ECDHE-RSA-WITH-AES-128-GCM-SHA256"
				;;
			2)
				CC_CIPHER="TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384"
				;;
			esac
			;;
		esac
		echo ""
		echo "選擇您希望使用的 Diffie-Hellman 金鑰類型："
		echo "   1) ECDH（推薦）"
		echo "   2) DH"
		until [[ $DH_TYPE =~ [1-2] ]]; do
			read -rp"DH 金鑰類型 [1-2]：" -e -i 1 DH_TYPE
		done
		case $DH_TYPE in
		1)
			echo ""
			echo "選擇您希望用於 ECDH 金鑰的曲線："
			echo "   1) prime256v1（推薦）"
			echo "   2) secp384r1"
			echo "   3) secp521r1"
			while [[ $DH_CURVE_CHOICE != "1" && $DH_CURVE_CHOICE != "2" && $DH_CURVE_CHOICE != "3" ]]; do
				read -rp"曲線 [1-3]：" -e -i 1 DH_CURVE_CHOICE
			done
			case $DH_CURVE_CHOICE in
			1)
				DH_CURVE="prime256v1"
				;;
			2)
				DH_CURVE="secp384r1"
				;;
			3)
				DH_CURVE="secp521r1"
				;;
			esac
			;;
		2)
			echo ""
			echo "選擇您希望使用的 Diffie-Hellman 金鑰大小："
			echo "   1) 2048 位元（推薦）"
			echo "   2) 3072 位元"
			echo "   3) 4096 位元"
			until [[ $DH_KEY_SIZE_CHOICE =~ ^[1-3]$ ]]; do
				read -rp "DH 金鑰大小 [1-3]：" -e -i 1 DH_KEY_SIZE_CHOICE
			done
			case $DH_KEY_SIZE_CHOICE in
			1)
				DH_KEY_SIZE="2048"
				;;
			2)
				DH_KEY_SIZE="3072"
				;;
			3)
				DH_KEY_SIZE="4096"
				;;
			esac
			;;
		esac
		echo ""
		# 對 AEAD 加密算法，"auth" 選項的行為不同
		if [[ $CIPHER =~ CBC$ ]]; then
			echo "雜湊演算法用於驗證資料通道封包和控制通道的 tls-auth 封包。"
		elif [[ $CIPHER =~ GCM$ ]]; then
			echo "雜湊演算法用於驗證控制通道的 tls-auth 封包。"
		fi
		echo "選擇您希望用於 HMAC 的雜湊演算法："
		echo "   1) SHA-256（推薦）"
		echo "   2) SHA-384"
		echo "   3) SHA-512"
		until [[ $HMAC_ALG_CHOICE =~ ^[1-3]$ ]]; do
			read -rp "雜湊演算法 [1-3]：" -e -i 1 HMAC_ALG_CHOICE
		done
		case $HMAC_ALG_CHOICE in
		1)
			HMAC_ALG="SHA256"
			;;
		2)
			HMAC_ALG="SHA384"
			;;
		3)
			HMAC_ALG="SHA512"
			;;
		esac
		echo ""
		echo "您可以使用 tls-auth 和 tls-crypt 來為控制通道添加額外的安全性"
		echo "tls-auth 用於驗證封包，而 tls-crypt 用於驗證並加密封包。"
		echo "   1) tls-crypt（推薦）"
		echo "   2) tls-auth"
		until [[ $TLS_SIG =~ [1-2] ]]; do
			read -rp "控制通道附加安全機制 [1-2]：" -e -i 1 TLS_SIG
		done
	fi
	echo ""
	echo "好的，這就是我需要的所有資訊。現在我們準備設定您的 OpenVPN 伺服器。"
	echo "安裝完成後，您將能夠生成一個用戶端檔案。"
	APPROVE_INSTALL=${APPROVE_INSTALL:-n}
	if [[ $APPROVE_INSTALL =~ n ]]; then
		read -n1 -r -p "按任意鍵繼續..."
	fi
}

function installOpenVPN() {
	if [[ $AUTO_INSTALL == "y" ]]; then
		# 設定預設選項，以免問到任何問題。
		APPROVE_INSTALL=${APPROVE_INSTALL:-y}
		APPROVE_IP=${APPROVE_IP:-y}
		IPV6_SUPPORT=${IPV6_SUPPORT:-n}
		PORT_CHOICE=${PORT_CHOICE:-1}
		PROTOCOL_CHOICE=${PROTOCOL_CHOICE:-1}
		DNS=${DNS:-1}
		COMPRESSION_ENABLED=${COMPRESSION_ENABLED:-n}
		CUSTOMIZE_ENC=${CUSTOMIZE_ENC:-n}
		CLIENT=${CLIENT:-client}
		PASS=${PASS:-1}
		CONTINUE=${CONTINUE:-y}

		# 在NAT後面，我們將預設為可以公開訪問的IPv4/IPv6。
		if [[ $IPV6_SUPPORT == "y" ]]; then
			if ! PUBLIC_IP=$(curl -f --retry 5 --retry-connrefused https://ip.seeip.org); then
				PUBLIC_IP=$(dig -6 TXT +short o-o.myaddr.l.google.com @ns1.google.com | tr -d '"')
			fi
		else
			if ! PUBLIC_IP=$(curl -f --retry 5 --retry-connrefused -4 https://ip.seeip.org); then
				PUBLIC_IP=$(dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com | tr -d '"')
			fi
		fi
		ENDPOINT=${ENDPOINT:-$PUBLIC_IP}
	fi

	# 先執行設定問題，如果是自動安裝，則設置其他變數
	installQuestions

	# 從預設路由中獲取“公共”接口
	NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
	if [[ -z $NIC ]] && [[ $IPV6_SUPPORT == 'y' ]]; then
		NIC=$(ip -6 route show default | sed -ne 's/^default .* dev \([^ ]*\) .*$/\1/p')
	fi

	# 腳本rm-openvpn-rules.sh需要$NIC不能為空
	if [[ -z $NIC ]]; then
		echo
		echo "無法檢測到公共接口。"
		echo "這是設置MASQUERADE所需的。"
		until [[ $CONTINUE =~ (y|n) ]]; do
			read -rp "是否繼續？ [y/n]: " -e CONTINUE
		done
		if [[ $CONTINUE == "n" ]]; then
			exit 1
		fi
	fi

	# 如果尚未安裝OpenVPN，則安裝它。 這個腳本在多次運行時基本上是幂等的，但只會從第一次開始安裝OpenVPN。
	if [[ ! -e /etc/openvpn/server.conf ]]; then
		if [[ $OS =~ (debian|ubuntu) ]]; then
			apt-get update
			apt-get -y install ca-certificates gnupg
			# 我們添加OpenVPN存儲庫以獲取最新版本。
			if [[ $VERSION_ID == "16.04" ]]; then
				echo "deb http://build.openvpn.net/debian/openvpn/stable xenial main" >/etc/apt/sources.list.d/openvpn.list
				wget -O - https://swupdate.openvpn.net/repos/repo-public.gpg | apt-key add -
				apt-get update
			fi
			# Ubuntu > 16.04和Debian > 8都有OpenVPN >= 2.4，無需第三方存儲庫。
			apt-get install -y openvpn iptables openssl wget ca-certificates curl
		elif [[ $OS == 'centos' ]]; then
			yum install -y epel-release
			yum install -y openvpn iptables openssl wget ca-certificates curl tar 'policycoreutils-python*'
		elif [[ $OS == 'oracle' ]]; then
			yum install -y oracle-epel-release-el8
			yum-config-manager --enable ol8_developer_EPEL
			yum install -y openvpn iptables openssl wget ca-certificates curl tar policycoreutils-python-utils
		elif [[ $OS == 'amzn' ]]; then
			amazon-linux-extras install -y epel
			yum install -y openvpn iptables openssl wget ca-certificates curl
		elif [[ $OS == 'fedora' ]]; then
			dnf install -y openvpn iptables openssl wget ca-certificates curl policycoreutils-python-utils
		elif [[ $OS == 'arch' ]]; then
			# 安裝必要的依賴項並升級系統
			pacman --needed --noconfirm -Syu openvpn iptables openssl wget ca-certificates curl
		fi
		# 一些OpenVPN套件中預設提供了舊版本的easy-rsa
		if [[ -d /etc/openvpn/easy-rsa/ ]]; then
			rm -rf /etc/openvpn/easy-rsa/
		fi
	fi

	# 查看機器是否使用nogroup或nobody作為無權限組
	if grep -qs "^nogroup:" /etc/group; then
		NOGROUP=nogroup
	else
		NOGROUP=nobody
	fi

	# 從源代碼安裝最新版本的easy-rsa，如果尚未安裝。
	if [[ ! -d /etc/openvpn/easy-rsa/ ]]; then
		local version="3.1.2"
		wget -O ~/easy-rsa.tgz https://github.com/OpenVPN/easy-rsa/releases/download/v${version}/EasyRSA-${version}.tgz
		mkdir -p /etc/openvpn/easy-rsa
		tar xzf ~/easy-rsa.tgz --strip-components=1 --no-same-owner --directory /etc/openvpn/easy-rsa
		rm -f ~/easy-rsa.tgz

		cd /etc/openvpn/easy-rsa/ || return
		case $CERT_TYPE in
		1)
			echo "set_var EASYRSA_ALGO ec" >vars
			echo "set_var EASYRSA_CURVE $CERT_CURVE" >>vars
			;;
		2)
			echo "set_var EASYRSA_KEY_SIZE $RSA_KEY_SIZE" >vars
			;;
		esac

		# 為CN和服務器名稱生成一個16個字符的隨機字母數字標識符
		SERVER_CN="cn_$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)"
		echo "$SERVER_CN" >SERVER_CN_GENERATED
		SERVER_NAME="server_$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)"
		echo "$SERVER_NAME" >SERVER_NAME_GENERATED

		# 創建PKI，設置CA，DH參數和服務器證書
		./easyrsa init-pki
		./easyrsa --batch --req-cn="$SERVER_CN" build-ca nopass

		if [[ $DH_TYPE == "2" ]]; then
			# ECDH密鑰是即時生成的，所以我們不需要事先生成它們
			openssl dhparam -out dh.pem $DH_KEY_SIZE
		fi

		./easyrsa --batch build-server-full "$SERVER_NAME" nopass
		EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl

		case $TLS_SIG in
		1)
			# 生成tls-crypt密鑰
			openvpn --genkey --secret /etc/openvpn/tls-crypt.key
			;;
		2)
			# 生成tls-auth密鑰
			openvpn --genkey --secret /etc/openvpn/tls-auth.key
			;;
		esac
	else
		# 如果已經安裝了easy-rsa，則獲取生成的SERVER_NAME以供客戶端配置使用
		cd /etc/openvpn/easy-rsa/ || return
		SERVER_NAME=$(cat SERVER_NAME_GENERATED)
	fi

	# 移動所有生成的文件
	cp pki/ca.crt pki/private/ca.key "pki/issued/$SERVER_NAME.crt" "pki/private/$SERVER_NAME.key" /etc/openvpn/easy-rsa/pki/crl.pem /etc/openvpn
	if [[ $DH_TYPE == "2" ]]; then
		cp dh.pem /etc/openvpn
	fi

	# 讓cert撤銷列表對非root用戶可讀
	chmod 644 /etc/openvpn/crl.pem

	# 生成server.conf
	echo "port $PORT" >/etc/openvpn/server.conf
	if [[ $IPV6_SUPPORT == 'n' ]]; then
		echo "proto $PROTOCOL" >>/etc/openvpn/server.conf
	elif [[ $IPV6_SUPPORT == 'y' ]]; then
		echo "proto ${PROTOCOL}6" >>/etc/openvpn/server.conf
	fi

	echo "dev tun
user nobody
group $NOGROUP
persist-key
persist-tun
keepalive 10 120
topology subnet
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt" >>/etc/openvpn/server.conf

	# DNS解析器
	case $DNS in
	1) # 當前系統的解析器
		# 找到正確的resolv.conf
		# 對於運行systemd-resolved的系統需要
		if grep -q "127.0.0.53" "/etc/resolv.conf"; then
			RESOLVCONF='/run/systemd/resolve/resolv.conf'
		else
			RESOLVCONF='/etc/resolv.conf'
		fi
		# 從resolv.conf獲取解析器並用於OpenVPN
		sed -ne 's/^nameserver[[:space:]]\+\([^[:space:]]\+\).*$/\1/p' $RESOLVCONF | while read -r line; do
			# 如果是IPv4，或者啟用了IPv6，則不管IPv4/IPv6
			if [[ $line =~ ^[0-9.]*$ ]] || [[ $IPV6_SUPPORT == 'y' ]]; then
				echo "push \"dhcp-option DNS $line\"" >>/etc/openvpn/server.conf
			fi
		done
		;;
	2) # 自建DNS解析器（Unbound）
		echo 'push "dhcp-option DNS 10.8.0.1"' >>/etc/openvpn/server.conf
		if [[ $IPV6_SUPPORT == 'y' ]]; then
			echo 'push "dhcp-option DNS fd42:42:42:42::1"' >>/etc/openvpn/server.conf
		fi
		;;
	3) # Cloudflare
		echo 'push "dhcp-option DNS 1.0.0.1"' >>/etc/openvpn/server.conf
		echo 'push "dhcp-option DNS 1.1.1.1"' >>/etc/openvpn/server.conf
		;;
	4) # Quad9
		echo 'push "dhcp-option DNS 9.9.9.9"' >>/etc/openvpn/server.conf
		echo 'push "dhcp-option DNS 149.112.112.112"' >>/etc/openvpn/server.conf
		;;
	5) # Quad9 uncensored
		echo 'push "dhcp-option DNS 9.9.9.10"' >>/etc/openvpn/server.conf
		echo 'push "dhcp-option DNS 149.112.112.10"' >>/etc/openvpn/server.conf
		;;
	6) # FDN
		echo 'push "dhcp-option DNS 80.67.169.40"' >>/etc/openvpn/server.conf
		echo 'push "dhcp-option DNS 80.67.169.12"' >>/etc/openvpn/server.conf
		;;
	7) # DNS.WATCH
		echo 'push "dhcp-option DNS 84.200.69.80"' >>/etc/openvpn/server.conf
		echo 'push "dhcp-option DNS 84.200.70.40"' >>/etc/openvpn/server.conf
		;;
	8) # OpenDNS
		echo 'push "dhcp-option DNS 208.67.222.222"' >>/etc/openvpn/server.conf
		echo 'push "dhcp-option DNS 208.67.220.220"' >>/etc/openvpn/server.conf
		;;
	9) # Google
		echo 'push "dhcp-option DNS 8.8.8.8"' >>/etc/openvpn/server.conf
		echo 'push "dhcp-option DNS 8.8.4.4"' >>/etc/openvpn/server.conf
		;;
	10) # Yandex Basic
		echo 'push "dhcp-option DNS 77.88.8.8"' >>/etc/openvpn/server.conf
		echo 'push "dhcp-option DNS 77.88.8.1"' >>/etc/openvpn/server.conf
		;;
	11) # AdGuard DNS
		echo 'push "dhcp-option DNS 94.140.14.14"' >>/etc/openvpn/server.conf
		echo 'push "dhcp-option DNS 94.140.15.15"' >>/etc/openvpn/server.conf
		;;
	12) # NextDNS
		echo 'push "dhcp-option DNS 45.90.28.167"' >>/etc/openvpn/server.conf
		echo 'push "dhcp-option DNS 45.90.30.167"' >>/etc/openvpn/server.conf
		;;
	13) # 自定義DNS
		echo "push \"dhcp-option DNS $DNS1\"" >>/etc/openvpn/server.conf
		if [[ $DNS2 != "" ]]; then
			echo "push \"dhcp-option DNS $DNS2\"" >>/etc/openvpn/server.conf
		fi
		;;
	esac
	echo 'push "redirect-gateway def1 bypass-dhcp"' >>/etc/openvpn/server.conf

	# 如果需要IPv6網絡設置
	if [[ $IPV6_SUPPORT == 'y' ]]; then
		echo 'server-ipv6 fd42:42:42:42::/112
tun-ipv6
push tun-ipv6
push "route-ipv6 2000::/3"
push "redirect-gateway ipv6"' >>/etc/openvpn/server.conf
	fi

	if [[ $COMPRESSION_ENABLED == "y" ]]; then
		echo "compress $COMPRESSION_ALG" >>/etc/openvpn/server.conf
	fi

	if [[ $DH_TYPE == "1" ]]; then
		echo "dh none" >>/etc/openvpn/server.conf
		echo "ecdh-curve $DH_CURVE" >>/etc/openvpn/server.conf
	elif [[ $DH_TYPE == "2" ]]; then
		echo "dh dh.pem" >>/etc/openvpn/server.conf
	fi

	case $TLS_SIG in
	1)
		echo "tls-crypt tls-crypt.key" >>/etc/openvpn/server.conf
		;;
	2)
		echo "tls-auth tls-auth.key 0" >>/etc/openvpn/server.conf
		;;
	esac

	echo "crl-verify crl.pem
ca ca.crt
cert $SERVER_NAME.crt
key $SERVER_NAME.key
auth $HMAC_ALG
cipher $CIPHER
ncp-ciphers $CIPHER
tls-server
tls-version-min 1.2
tls-cipher $CC_CIPHER
client-config-dir /etc/openvpn/ccd
status /var/log/openvpn/status.log
verb 3" >>/etc/openvpn/server.conf

	# 創建client-config-dir目錄
	mkdir -p /etc/openvpn/ccd
	# 創建日誌目錄
	mkdir -p /var/log/openvpn

	# 啟用路由
	echo 'net.ipv4.ip_forward=1' >/etc/sysctl.d/99-openvpn.conf
	if [[ $IPV6_SUPPORT == 'y' ]]; then
		echo 'net.ipv6.conf.all.forwarding=1' >>/etc/sysctl.d/99-openvpn.conf
	fi
	# 應用sysctl規則
	sysctl --system

	# 如果SELinux已啟用並且選擇了自定義端口，我們需要進行下面的操作
	if hash sestatus 2>/dev/null; then
		if sestatus | grep "Current mode" | grep -qs "enforcing"; then
			if [[ $PORT != '1194' ]]; then
				semanage port -a -t openvpn_port_t -p "$PROTOCOL" "$PORT"
			fi
		fi
	fi

	# 最後，重新啟動和啟用OpenVPN
	if [[ $OS == 'arch' || $OS == 'fedora' || $OS == 'centos' || $OS == 'oracle' ]]; then
		# 不要修改提供的服務包
		cp /usr/lib/systemd/system/openvpn-server@.service /etc/systemd/system/openvpn-server@.service

		# 解決OpenVPN服務在OpenVZ上的問題
		sed -i 's|LimitNPROC|#LimitNPROC|' /etc/systemd/system/openvpn-server@.service
		# 另一種解決OpenVPN服務仍然使用/etc/openvpn/的方法
		sed -i 's|/etc/openvpn/server|/etc/openvpn|' /etc/systemd/system/openvpn-server@.service

		systemctl daemon-reload
		systemctl enable openvpn-server@server
		systemctl restart openvpn-server@server
	elif [[ $OS == "ubuntu" ]] && [[ $VERSION_ID == "16.04" ]]; then
		# 在Ubuntu 16.04上，我們使用OpenVPN存儲庫中的軟件包
		# 這個軟件包使用sysvinit服務
		systemctl enable openvpn
		systemctl start openvpn
	else
		# 不要修改提供的服務包
		cp /lib/systemd/system/openvpn\@.service /etc/systemd/system/openvpn\@.service

		# 解決OpenVPN服務在OpenVZ上的問題
		sed -i 's|LimitNPROC|#LimitNPROC|' /etc/systemd/system/openvpn\@.service
		# 另一種解決OpenVPN服務仍然使用/etc/openvpn/的方法
		sed -i 's|/etc/openvpn/server|/etc/openvpn|' /etc/systemd/system/openvpn\@.service

		systemctl daemon-reload
		systemctl enable openvpn@server
		systemctl restart openvpn@server
	fi

	if [[ $DNS == 2 ]]; then
		installUnbound
	fi

	# 在兩個腳本中添加iptables規則
	mkdir -p /etc/iptables

	# 添加規則的腳本
	echo "#!/bin/sh
iptables -t nat -I POSTROUTING 1 -s 10.8.0.0/24 -o $NIC -j MASQUERADE
iptables -I INPUT 1 -i tun0 -j ACCEPT
iptables -I FORWARD 1 -i $NIC -o tun0 -j ACCEPT
iptables -I FORWARD 1 -i tun0 -o $NIC -j ACCEPT
iptables -I INPUT 1 -i $NIC -p $PROTOCOL --dport $PORT -j ACCEPT" >/etc/iptables/add-openvpn-rules.sh

	if [[ $IPV6_SUPPORT == 'y' ]]; then
		echo "ip6tables -t nat -I POSTROUTING 1 -s fd42:42:42:42::/112 -o $NIC -j MASQUERADE
ip6tables -I INPUT 1 -i tun0 -j ACCEPT
ip6tables -I FORWARD 1 -i $NIC -o tun0 -j ACCEPT
ip6tables -I FORWARD 1 -i tun0 -o $NIC -j ACCEPT
ip6tables -I INPUT 1 -i $NIC -p $PROTOCOL --dport $PORT -j ACCEPT" >>/etc/iptables/add-openvpn-rules.sh
	fi

	# 刪除規則的腳本
	echo "#!/bin/sh
iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -o $NIC -j MASQUERADE
iptables -D INPUT -i tun0 -j ACCEPT
iptables -D FORWARD -i $NIC -o tun0 -j ACCEPT
iptables -D FORWARD -i tun0 -o $NIC -j ACCEPT
iptables -D INPUT -i $NIC -p $PROTOCOL --dport $PORT -j ACCEPT" >/etc/iptables/rm-openvpn-rules.sh

	if [[ $IPV6_SUPPORT == 'y' ]]; then
		echo "ip6tables -t nat -D POSTROUTING -s fd42:42:42:42::/112 -o $NIC -j MASQUERADE
ip6tables -D INPUT -i tun0 -j ACCEPT
ip6tables -D FORWARD -i $NIC -o tun0 -j ACCEPT
ip6tables -D FORWARD -i tun0 -o $NIC -j ACCEPT
ip6tables -D INPUT -i $NIC -p $PROTOCOL --dport $PORT -j ACCEPT" >>/etc/iptables/rm-openvpn-rules.sh
	fi

	chmod +x /etc/iptables/add-openvpn-rules.sh
	chmod +x /etc/iptables/rm-openvpn-rules.sh

	# 通過systemd腳本處理規則
	echo "[Unit]
Description=iptables rules for OpenVPN
Before=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/etc/iptables/add-openvpn-rules.sh
ExecStop=/etc/iptables/rm-openvpn-rules.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target" >/etc/systemd/system/iptables-openvpn.service

	# 啟用服務並應用規則
	systemctl daemon-reload
	systemctl enable iptables-openvpn
	systemctl start iptables-openvpn

	# 如果服務器在NAT後面，則使用正確的IP地址供客戶端連接
	if [[ $ENDPOINT != "" ]]; then
		IP=$ENDPOINT
	fi

	# client-template.txt 已創建，因此我們有一個模板可以稍後添加更多用戶
	echo "client" >/etc/openvpn/client-template.txt
	if [[ $PROTOCOL == 'udp' ]]; then
		echo "proto udp" >>/etc/openvpn/client-template.txt
		echo "explicit-exit-notify" >>/etc/openvpn/client-template.txt
	elif [[ $PROTOCOL == 'tcp' ]]; then
		echo "proto tcp-client" >>/etc/openvpn/client-template.txt
	fi
	echo "remote $IP $PORT
dev tun
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
verify-x509-name $SERVER_NAME name
auth $HMAC_ALG
auth-nocache
cipher $CIPHER
tls-client
tls-version-min 1.2
tls-cipher $CC_CIPHER
ignore-unknown-option block-outside-dns
setenv opt block-outside-dns # Prevent Windows 10 DNS leak
verb 3" >>/etc/openvpn/client-template.txt

	if [[ $COMPRESSION_ENABLED == "y" ]]; then
		echo "compress $COMPRESSION_ALG" >>/etc/openvpn/client-template.txt
	fi

	# Generate the custom client.ovpn
	newClient
	echo "如果您想添加更多客戶端，只需再次運行此腳本！"
}

function newClient() {
	echo ""
	echo "請為客戶端指定一個名稱。"
	echo "名稱必須由字母數字組成，也可以包含下劃線或破折號。"

	until [[ $CLIENT =~ ^[a-zA-Z0-9_-]+$ ]]; do
		read -rp "客戶端名稱： " -e CLIENT
	done

	echo ""
	echo "您是否希望使用密碼保護配置文件？"
	echo "（例如，使用密碼對私鑰進行加密）"
	echo "   1）添加一個無密碼的客戶端"
	echo "   2）為客戶端使用密碼"

	until [[ $PASS =~ ^[1-2]$ ]]; do
		read -rp "選擇一個選項 [1-2]： " -e -i 1 PASS
	done

	CLIENTEXISTS=$(tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep -c -E "/CN=$CLIENT\$")
	if [[ $CLIENTEXISTS == '1' ]]; then
		echo ""
		echo "指定的客戶端CN已在easy-rsa中找到，請選擇另一個名稱。"
		exit
	else
		cd /etc/openvpn/easy-rsa/ || return
		case $PASS in
		1)
			./easyrsa --batch build-client-full "$CLIENT" nopass
			;;
		2)
			echo "⚠️ 下面將要求您輸入客戶端密碼 ⚠️"
			./easyrsa --batch build-client-full "$CLIENT"
			;;
		esac
		echo "已添加客戶端 $CLIENT。"
	fi

	# 用戶的家目錄，其中將寫入客戶端配置
	if [ -e "/home/${CLIENT}" ]; then
		# 如果$1是用戶名
		homeDir="/home/${CLIENT}"
	elif [ "${SUDO_USER}" ]; then
		# 如果不是，使用SUDO_USER
		if [ "${SUDO_USER}" == "root" ]; then
			# 如果以root身份運行sudo
			homeDir="/root"
		else
			homeDir="/home/${SUDO_USER}"
		fi
	else
		# 如果沒有SUDO_USER，使用/root
		homeDir="/root"
	fi

	# 確定我們使用的是tls-auth還是tls-crypt
	if grep -qs "^tls-crypt" /etc/openvpn/server.conf; then
		TLS_SIG="1"
	elif grep -qs "^tls-auth" /etc/openvpn/server.conf; then
		TLS_SIG="2"
	fi

	# 生成自定義的client.ovpn
	cp /etc/openvpn/client-template.txt "$homeDir/$CLIENT.ovpn"
	{
		echo "<ca>"
		cat "/etc/openvpn/easy-rsa/pki/ca.crt"
		echo "</ca>"

		echo "<cert>"
		awk '/BEGIN/,/END CERTIFICATE/' "/etc/openvpn/easy-rsa/pki/issued/$CLIENT.crt"
		echo "</cert>"

		echo "<key>"
		cat "/etc/openvpn/easy-rsa/pki/private/$CLIENT.key"
		echo "</key>"

		case $TLS_SIG in
		1)
			echo "<tls-crypt>"
			cat /etc/openvpn/tls-crypt.key
			echo "</tls-crypt>"
			;;
		2)
			echo "key-direction 1"
			echo "<tls-auth>"
			cat /etc/openvpn/tls-auth.key
			echo "</tls-auth>"
			;;
		esac
	} >>"$homeDir/$CLIENT.ovpn"

	echo ""
	echo "配置文件已經寫入到 $homeDir/$CLIENT.ovpn。"
	echo "下載 .ovpn 文件並將其導入您的OpenVPN客戶端。"

	exit 0
}

function revokeClient() {
	NUMBEROFCLIENTS=$(tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep -c "^V")
	if [[ $NUMBEROFCLIENTS == '0' ]]; then
		echo ""
		echo "您沒有現有的客戶端！"
		exit 1
	fi

	echo ""
	echo "選擇要撤銷的現有客戶端證書"
	tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | nl -s ') '
	until [[ $CLIENTNUMBER -ge 1 && $CLIENTNUMBER -le $NUMBEROFCLIENTS ]]; do
		if [[ $CLIENTNUMBER == '1' ]]; then
			read -rp "選擇一個客戶端 [1]: " CLIENTNUMBER
		else
			read -rp "選擇一個客戶端 [1-$NUMBEROFCLIENTS]: " CLIENTNUMBER
		fi
	done
	CLIENT=$(tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | sed -n "$CLIENTNUMBER"p)
	cd /etc/openvpn/easy-rsa/ || return
	./easyrsa --batch revoke "$CLIENT"
	EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl
	rm -f /etc/openvpn/crl.pem
	cp /etc/openvpn/easy-rsa/pki/crl.pem /etc/openvpn/crl.pem
	chmod 644 /etc/openvpn/crl.pem
	find /home/ -maxdepth 2 -name "$CLIENT.ovpn" -delete
	rm -f "/root/$CLIENT.ovpn"
	sed -i "/^$CLIENT,.*/d" /etc/openvpn/ipp.txt
	cp /etc/openvpn/easy-rsa/pki/index.txt{,.bk}

	echo ""
	echo "客戶端 $CLIENT 的證書已撤銷。"
}

function removeUnbound() {
	# 刪除與OpenVPN相關的配置
	sed -i '/include: \/etc\/unbound\/openvpn.conf/d' /etc/unbound/unbound.conf
	rm /etc/unbound/openvpn.conf

	until [[ $REMOVE_UNBOUND =~ (y|n) ]]; do
		echo ""
		echo "如果在安裝OpenVPN之前已經使用Unbound，我將刪除與OpenVPN相關的配置。"
		read -rp "是否要完全刪除Unbound？ [y/n]: " -e REMOVE_UNBOUND
	done

	if [[ $REMOVE_UNBOUND == 'y' ]]; then
		# 停止Unbound服務
		systemctl stop unbound

		if [[ $OS =~ (debian|ubuntu) ]]; then
			apt-get remove --purge -y unbound
		elif [[ $OS == 'arch' ]]; then
			pacman --noconfirm -R unbound
		elif [[ $OS =~ (centos|amzn|oracle) ]]; then
			yum remove -y unbound
		elif [[ $OS == 'fedora' ]]; then
			dnf remove -y unbound
		fi

		rm -rf /etc/unbound/

		echo ""
		echo "Unbound已刪除！"
	else
		systemctl restart unbound
		echo ""
		echo "未刪除Unbound。"
	fi
}

function removeOpenVPN() {
	echo ""
	read -rp "您是否確定要刪除OpenVPN？ [y/n]: " -e -i n REMOVE
	if [[ $REMOVE == 'y' ]]; then
		# 從配置中獲取OpenVPN端口
		PORT=$(grep '^port ' /etc/openvpn/server.conf | cut -d " " -f 2)
		PROTOCOL=$(grep '^proto ' /etc/openvpn/server.conf | cut -d " " -f 2)

		# 停止OpenVPN服務
		if [[ $OS =~ (fedora|arch|centos|oracle) ]]; then
			systemctl disable openvpn-server@server
			systemctl stop openvpn-server@server
			# 刪除自定義服務
			rm /etc/systemd/system/openvpn-server@.service
		elif [[ $OS == "ubuntu" ]] && [[ $VERSION_ID == "16.04" ]]; then
			systemctl disable openvpn
			systemctl stop openvpn
		else
			systemctl disable openvpn@server
			systemctl stop openvpn@server
			# 刪除自定義服務
			rm /etc/systemd/system/openvpn\@.service
		fi

		# 刪除與腳本相關的iptables規則
		systemctl stop iptables-openvpn
		# 清理
		systemctl disable iptables-openvpn
		rm /etc/systemd/system/iptables-openvpn.service
		systemctl daemon-reload
		rm /etc/iptables/add-openvpn-rules.sh
		rm /etc/iptables/rm-openvpn-rules.sh

		# SELinux
		if hash sestatus 2>/dev/null; then
			if sestatus | grep "Current mode" | grep -qs "enforcing"; then
				if [[ $PORT != '1194' ]]; then
					semanage port -d -t openvpn_port_t -p "$PROTOCOL" "$PORT"
				fi
			fi
		fi

		if [[ $OS =~ (debian|ubuntu) ]]; then
			apt-get remove --purge -y openvpn
			if [[ -e /etc/apt/sources.list.d/openvpn.list ]]; then
				rm /etc/apt/sources.list.d/openvpn.list
				apt-get update
			fi
		elif [[ $OS == 'arch' ]]; then
			pacman --noconfirm -R openvpn
		elif [[ $OS =~ (centos|amzn|oracle) ]]; then
			yum remove -y openvpn
		elif [[ $OS == 'fedora' ]]; then
			dnf remove -y openvpn
		fi

		# 清理
		find /home/ -maxdepth 2 -name "*.ovpn" -delete
		find /root/ -maxdepth 1 -name "*.ovpn" -delete
		rm -rf /etc/openvpn
		rm -rf /usr/share/doc/openvpn*
		rm -f /etc/sysctl.d/99-openvpn.conf
		rm -rf /var/log/openvpn

		# Unbound
		if [[ -e /etc/unbound/openvpn.conf ]]; then
			removeUnbound
		fi
		echo ""
		echo "OpenVPN已刪除！"
	else
		echo ""
		echo "刪除操作已中止！"
	fi
}

function manageMenu() {
	echo "歡迎使用OpenVPN-install！"
	echo "Git倉庫位於：https://github.com/a19901201/openvpn-install"
	echo ""
	echo "看起來OpenVPN已經安裝。"
	echo ""
	echo "您想要做什麼？"
	echo "   1）添加一個新用戶"
	echo "   2）撤銷現有用戶"
	echo "   3）刪除OpenVPN"
	echo "   4）退出"
	until [[ $MENU_OPTION =~ ^[1-4]$ ]]; do
		read -rp "選擇一個選項 [1-4]： " MENU_OPTION
	done

	case $MENU_OPTION in
	1)
		newClient
		;;
	2)
		revokeClient
		;;
	3)
		removeOpenVPN
		;;
	4)
		exit 0
		;;
	esac
}

# 檢查是否具有root權限，TUN設備，操作系統...
initialCheck

# 檢查OpenVPN是否已經安裝
if [[ -e /etc/openvpn/server.conf && $AUTO_INSTALL != "y" ]]; then
	manageMenu
else
	installOpenVPN
fi

rm $(basename "$0")