# openvpn-install

![Test](https://github.com/angristan/openvpn-install/workflows/Test/badge.svg)
![Lint](https://github.com/angristan/openvpn-install/workflows/Lint/badge.svg)
[![Say Thanks!](https://img.shields.io/badge/Say%20Thanks-!-1EAEDB.svg)](https://saythanks.io/to/angristan)

適用於 Debian、Ubuntu、Fedora、CentOS、Arch Linux、Oracle Linux、Rocky Linux 和 AlmaLinux 的 OpenVPN 安裝程序。

該腳本可讓您在短短幾秒鐘內設置自己的安全 VPN 服務器。
您還可以查看 [wireguard-install](https://github.com/angristan/wireguard-install)，這是一個簡單的安裝程序，可實現更簡單、更安全、更快和更現代的 VPN 協議。

## Usage

首先，獲取腳本並使其可執行：

```bash
curl -O https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
chmod +x openvpn-install.sh
```

然後運行它：

```sh
./openvpn-install.sh
```

您需要以 root 身份運行該腳本並啟用 TUN 模塊。

第一次運行它時，您必須跟隨助手並回答幾個問題來設置您的 VPN 服務器。

安裝 OpenVPN 後，您可以再次運行該腳本，您將獲得以下選擇：

- 添加客戶
- 刪除客戶端
- 卸載 OpenVPN

在您的主目錄中，您將有`.ovpn`文件。這些是客戶端配置文件。從您的服務器下載它們並使用您最喜歡的 OpenVPN 客戶端進行連接。

如果您有任何疑問，請先前往[常見問題解答](#faq)。請在打開問題之前閱讀所有內容。

**請不要向我發送電子郵件或私人消息尋求幫助。**獲得幫助的唯一地方是問題。其他人也許能夠提供幫助，並且將來其他用戶也可能會遇到與您相同的問題。我的時間不只是為你免費提供的，你並不特別。

### 無頭安裝

也可以無頭運行腳本，例如無需等待用戶輸入，以自動方式。

用法示例：

```bash
AUTO_INSTALL=y ./openvpn-install.sh

# or

export AUTO_INSTALL=y
./openvpn-install.sh
```

然後將通過傳遞用戶輸入的需要來設置一組默認變量。

如果您想自定義安裝，可以導出它們或在同一行中指定它們，如上所示。
- `APPROVE_INSTALL=y`
- `APPROVE_IP=y`
- `IPV6_SUPPORT=n`
- `PORT_CHOICE=1`
- `PROTOCOL_CHOICE=1`
- `DNS=1`
- `COMPRESSION_ENABLED=n`
- `CUSTOMIZE_ENC=n`
- `CLIENT=clientname`
- `PASS=1`

如果服務器位於 NAT 之後，您可以使用`ENDPOINT`變量指定其端點。如果端點是其後面的公共IP地址，您可以使用`ENDPOINT=$(curl -4 ifconfig.co)`（腳本將默認為此）。端點可以是 IPv4 或域。

可以根據您的選擇設置其他變量（加密、壓縮）。您可以在腳本的 installQuestions() 函數中搜索它們。

無頭安裝方法不支持受密碼保護的客戶端，因為 Easy-RSA 需要用戶輸入。

無頭安裝或多或少是冪等的，因為它可以安全地使用相同的參數多次運行，例如由 Ansible/Terraform/Salt/Chef/Puppet 等國家供應者提供。如果 Easy-RSA PKI 尚不存在，它只會安裝並重新生成它；如果 OpenVPN 尚未安裝，它只會安裝 OpenVPN 和其他上游依賴項。它將在每次無頭運行時重新創建所有本地配置並重新生成客戶端文件。

### 無頭用戶添加

還可以自動添加新用戶。這裡的關鍵是在調用腳本之前提供`MENU_OPTION`變量的（字符串）值以及其餘的強制變量。

以下 Bash 腳本將新用戶`foo`添加到現有 OpenVPN 配置中

```bash
#!/bin/bash
export MENU_OPTION="1"
export CLIENT="foo"
export PASS="1"
./openvpn-install.sh
```

## 特徵

- 安裝並配置現成的 OpenVPN 服務器
- 以無縫方式管理 Iptables 規則和轉發
- 如果需要，該腳本可以乾淨地刪除 OpenVPN，包括配置和 iptables 規則
- 可自定義的加密設置，增強的默認設置（請參閱下面的[安全和加密](#security-and-encryption)）
- OpenVPN 2.4 功能，主要是加密改進（請參閱下面的[安全和加密](#security-and-encryption)）
- 推送給客戶端的各種 DNS 解析器
- 選擇使用帶有 Unbound 的自託管解析器（支持現有的 Unbound 安裝）
- TCP 和 UDP 之間的選擇
- NAT IPv6 支持
- 默認情況下禁用壓縮以防止 VORACLE。其他情況下也可使用 LZ4 (v1/v2) 和 LZ0 算法。
- 非特權模式：以`nobody`/`nogroup`身份運行
- 阻止 Windows 10 上的 DNS 洩漏
- 隨機服務器證書名稱
- 選擇使用密碼保護客戶端（私鑰加密）
- 許多其他小事！

## 兼容性

該腳本支持以下 Linux 發行版：
|                    | Support |
| ------------------ | ------- |
| AlmaLinux 8        | ✅       |
| Amazon Linux 2     | ✅       |
| Arch Linux         | ✅       |
| CentOS 7           | ✅ 🤖     |
| CentOS Stream >= 8 | ✅ 🤖     |
| Debian >= 10       | ✅ 🤖     |
| Fedora >= 35       | ✅ 🤖     |
| Oracle Linux 8     | ✅       |
| Rocky Linux 8      | ✅       |
| Ubuntu >= 18.04    | ✅ 🤖     |

需要注意的是:

- 該腳本定期針對僅標有 🤖 的發行版進行測試。
  - 僅在`amd64`架構上進行測試。
- 它應該適用於舊版本，例如 Debian 8+、Ubuntu 16.04+ 和以前的 Fedora 版本。但上表中未列出的版本不受官方支持。
  - 它還應該支持 LTS 版本之間的版本，但這些版本尚未經過測試。
- 該腳本需要`systemd`。

## 叉

該腳本基於 [Nyr 及其貢獻者](https://github.com/Nyr/openvpn-install) 的偉大工作。

自 2016 年以來，這兩個腳本已經出現分歧，不再相似，尤其是在幕後。該腳本的主要目標是增強安全性。但從那時起，腳本被完全重寫，並添加了很多功能。不過，該腳本僅與最近的發行版兼容，因此如果您需要使用非常舊的服務器或客戶端，我建議使用 Nyr 的腳本。

## FAQ

更多問答請參見[FAQ.md](FAQ.md)。

**問：**您推薦哪家提供商？

**答：**我推薦這些：

- [Vultr](https://www.vultr.com/?ref=8948982-8H)：全球位置，IPv6 支持，起價 5 美元/月
- [Hetzner](https://hetzner.cloud/?ref=ywtlvZsjgeDq)：德國、芬蘭和美國。 IPv6，20 TB 流量，起價 4.5 歐元/月
- [Digital Ocean](https://m.do.co/c/ed0ba143fe53)：全球位置，IPv6 支持，起價 4 美元/月

---

**問:**您推薦哪種 OpenVPN 客戶端？

**答:**如果可能的話，官方 OpenVPN 2.4 客戶端。

-Windows：[官方 OpenVPN 社區客戶端](https://openvpn.net/index.php/download/community-downloads.html)。
-Linux：您的發行版中的`openvpn`軟件包。對於基於 Debian/Ubuntu 的發行版，有一個 [官方 APT 存儲庫](https://community.openvpn.net/openvpn/wiki/OpenvpnSoftwareRepos)。
-macOS：[Tunnelblick](https://tunnelblick.net/)、[Viscosity](https://www.sparklabs.com/viscosity/)、[OpenVPN for Mac](https://openvpn.net/client -connect-vpn-for-mac-os/)。
-Android：[Android 版 OpenVPN](https://play.google.com/store/apps/details?id=de.blinkt.openvpn)。
-iOS：[官方 OpenVPN Connect 客戶端](https://itunes.apple.com/us/app/openvpn-connect/id590379981)。

---

**問:** 使用你的腳本我可以免受國家安全局的威脅嗎？

**答:** 請檢查您的威脅模型。即使此腳本考慮到安全性並使用最先進的加密，如果您想躲避 NSA，也不應該使用 VPN。

---

**問:** 有 OpenVPN 文檔嗎？

**答:** 是的，請前往 [OpenVPN 手冊](https://community.openvpn.net/openvpn/wiki/Openvpn24ManPage)，其中引用了所有選項。
---

更多問答請參見[FAQ.md](FAQ.md)。

## 公有云一站式解決方案

基於此腳本一次性提供現成可用的 OpenVPN 服務器的解決方案可用於：

- AWS 在 [`openvpn-terraform-install`](https://github.com/dumrauf/openvpn-terraform-install) 使用 Terraform
- Terraform AWS 模塊 [`openvpn-ephemeral`](https://registry.terraform.io/modules/paulmarsicloud/openvpn-ephemeral/aws/latest)

## 貢獻

## 討論改變

如果您想討論更改，尤其是重大更改，請在提交 PR 之前打開一個問題。

### 代碼格式化

我們使用 [shellcheck](https://github.com/koalaman/shellcheck) 和 [shfmt](https://github.com/mvdan/sh) 來強制執行 bash 樣式指南和良好實踐。它們是通過 GitHub Actions 針對每個提交/PR 執行的，因此您可以在[此處](https://github.com/angristan/openvpn-install/blob/master/.github/workflows/push.yml)檢查配置。

## 安全與加密

> **警告**
> OpenVPN 2.5 及更高版本尚未更新。

OpenVPN 的默認設置在加密方面相當薄弱。該腳本旨在改進這一點。

OpenVPN 2.4 是有關加密的重大更新。它增加了對 ECDSA、ECDH、AES GCM、NCP 和 tls-crypt 的支持。

如果您想了解有關下面提到的選項的更多信息，請參閱 [OpenVPN 手冊](https://community.openvpn.net/openvpn/wiki/Openvpn24ManPage)。它非常完整。
OpenVPN 的大部分加密相關內容均由 [Easy-RSA](https://github.com/OpenVPN/easy-rsa) 管理。默認參數位於 [vars.example](https://github.com/OpenVPN/easy-rsa/blob/v3.0.7/easyrsa3/vars.example) 文件中。

### 壓縮

默認情況下，OpenVPN 不啟用壓縮。該腳本提供對 LZ0 和 LZ4 (v1/v2) 算法的支持，後者效率更高。

然而，不鼓勵使用壓縮，因為 [VORACLE 攻擊](https://protonvpn.com/blog/voracle-attack/) 利用了它。

### TLS版本

OpenVPN 默認接受 TLS 1.0，該版本已有近 [20 年曆史](https://en.wikipedia.org/wiki/Transport_Layer_Security#TLS_1.0)。

通過`tls-version-min 1.2`，我們強制執行 TLS 1.2，這是當前 OpenVPN 可用的最佳協議。

自 OpenVPN 2.3.3 起支持 TLS 1.2。

### 證書

OpenVPN 默認使用帶有 2048 位密鑰的 RSA 證書。

OpenVPN 2.4 添加了對 ECDSA 的支持。橢圓曲線加密更快、更輕、更安全。

該腳本提供：

- ECDSA: `prime256v1`/`secp384r1`/`secp521r1` curves
- RSA: `2048`/`3072`/`4096` bits keys

它默認為帶有`prime256v1`的 ECDSA。

OpenVPN 默認使用`SHA-256`作為簽名哈希，腳本也是如此。到目前為止，它沒有提供其他選擇。

### 數據通道

默認情況下，OpenVPN 使用`BF-CBC`作為數據通道密碼。 Blowfish 是一種古老的（1993 年）且較弱的算法。甚至 OpenVPN 官方文檔也承認這一點。

> 默認值為 BF-CBC，是密碼塊鏈模式中 Blowfish 的縮寫。
>
> Using BF-CBC is no longer recommended, because of its 64-bit block size. This small block size allows attacks based on collisions, as demonstrated by SWEET32. See <https://community.openvpn.net/openvpn/wiki/SWEET32> for details.
> Security researchers at INRIA published an attack on 64-bit block ciphers, such as 3DES and Blowfish. They show that they are able to recover plaintext when the same data is sent often enough, and show how they can use cross-site scripting vulnerabilities to send data of interest often enough. This works over HTTPS, but also works for HTTP-over-OpenVPN. See <https://sweet32.info/> for a much better and more elaborate explanation.
>
> OpenVPN's default cipher, BF-CBC, is affected by this attack.

事實上，AES 是當今的標準。它是當今最快、更安全的密碼。 [SEED](https://en.wikipedia.org/wiki/SEED) 和 [Camellia](<https://en.wikipedia.org/wiki/Camellia_(cipher)>) 迄今為止不易受到攻擊，但速度較慢與 AES 相比，可信度相對較低。

> Of the currently supported ciphers, OpenVPN currently recommends using AES-256-CBC or AES-128-CBC. OpenVPN 2.4 and newer will also support GCM. For 2.4+, we recommend using AES-256-GCM or AES-128-GCM.

AES-256 比 AES-128 慢 40%，並且沒有任何真正的理由在 AES 中使用 256 位密鑰而不是 128 位密鑰。 （來源：[1](http://security.stackexchange.com/questions/14068/why-most-people-use-256-bit-encryption-instead-of-128-bit),[2](http: //security.stackexchange.com/questions/6141/amount-of-simple-operations-that-is-safely-out-of-reach-for-all-humanity/6149#6149))。此外，AES-256 更容易受到[計時攻擊](https://en.wikipedia.org/wiki/Timing_attack)。

AES-GCM 是一種 [AEAD 密碼](https://en.wikipedia.org/wiki/Authenticated_encryption)，這意味著它同時提供數據的機密性、完整性和真實性保證。

該腳本支持以下密碼：
- `AES-128-GCM`
- `AES-192-GCM`
- `AES-256-GCM`
- `AES-128-CBC`
- `AES-192-CBC`
- `AES-256-CBC`

並默認為 `AES-128-GCM`.

OpenVPN 2.4 添加了一項名為"NCP"的功能：_可協商加密參數_。這意味著您可以提供類似於 HTTPS 的密碼套件。它被設置為 `AES-256-GCM:AES-128-GCM` 默認情況下並覆蓋 `--cipher` 與 OpenVPN 2.4 客戶端一起使用時的參數。為了簡單起見，該腳本設置了 `--cipher` 和 `--ncp-cipher` 到上面選擇的密碼。

### 控制通道

OpenVPN 2.4 將協商默認可用的最佳密碼（例如 ECDHE+AES-256-GCM）

該腳本根據證書建議以下選項：
- ECDSA:
  - `TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256`
  - `TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384`
- RSA:
  - `TLS-ECDHE-RSA-WITH-AES-128-GCM-SHA256`
  - `TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384`

它默認為 `TLS-ECDHE-*-WITH-AES-128-GCM-SHA256`.

### 迪菲-赫爾曼密鑰交換

OpenVPN 默認使用 2048 位 DH 密鑰。

OpenVPN 2.4 添加了對 ECDH 密鑰的支持。橢圓曲線加密更快、更輕、更安全。

此外，生成經典 DH 密鑰可能需要很長的時間。 ECDH 密鑰是短暫的：它們是即時生成的。

該腳本提供以下選項：

- ECDH: `prime256v1`/`secp384r1`/`secp521r1` curves
- DH: `2048`/`3072`/`4096` bits keys

它默認為 `prime256v1`.

### HMAC摘要算法

來自 OpenVPN wiki，關於 `--auth`:

> 使用消息摘要算法 alg 通過 HMAC 驗證數據通道數據包和（如果啟用）tls-auth 控制通道數據包。 （默認為 SHA1 ）。 HMAC 是一種常用的消息身份驗證算法 (MAC)，它使用數據字符串、安全哈希算法和密鑰來生成數字簽名。
>
> 如果選擇 AEAD 密碼模式（例如 GCM），則數據通道將忽略指定的 --auth 算法，而是使用 AEAD 密碼的身份驗證方法。請注意，alg 仍然指定用於 tls-auth 的摘要。

該腳本提供以下選擇：
- `SHA256`
- `SHA384`
- `SHA512`

它默認為 `SHA256`.

### `tls-auth` 和 `tls-crypt`

來自 OpenVPN wiki，關於 `tls-auth`:

> 在 TLS 控制通道之上添加額外的 HMAC 身份驗證層，以減輕 DoS 攻擊和對 TLS 堆棧的攻擊。
>
> 簡而言之，--tls-auth 在 OpenVPN 的 TCP/UDP 端口上啟用一種“HMAC 防火牆”，其中帶有不正確 HMAC 簽名的 TLS 控制通道數據包可以立即丟棄而不會得到響應。

關於 `tls-crypt`:

> 使用密鑰文件中的密鑰對所有控制通道數據包進行加密和驗證。 （有關更多背景信息，請參閱 --tls-auth。）
>
> 加密（和驗證）控制通道數據包：
>
> - 通過隱藏用於 TLS 連接的證書來提供更多隱私，
> - 使得識別 OpenVPN 流量變得更加困難，
> - 提供`窮人`的後量子安全，針對永遠不知道預共享密鑰（即沒有前向保密）的攻擊者。

因此，兩者都提供了額外的安全層並減輕 DoS 攻擊。 OpenVPN 默認情況下不使用它們。

`tls-crypt` 是 OpenVPN 2.4 的一項功能，除了身份驗證之外還提供加密功能 (不像 `tls-auth`). It 更加註重隱私。

該腳本支持兩者並默認使用`tls-crypt`。

## 說謝謝

如果您願意，可以[說聲謝謝](https://saythanks.io/to/angristan)！

## 學分和許可

非常感謝[貢獻者](https://github.com/Angristan/OpenVPN-install/graphs/contributors) 和 Nyr 的原創作品。

該項目已獲得[MIT許可證](https://raw.githubusercontent.com/Angristan/openvpn-install/master/LICENSE)

## 明星曆史

[![明星曆史圖表](https://api.star-history.com/svg?repos=angristan/openvpn-install&type=Date)](https://star-history.com/#angristan/openvpn-install&Date ）
