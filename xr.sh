#!/usr/bin/env bash
set -Eeuo pipefail
C=/root/xray-credentials.txt
X=/usr/local/etc/xray/config.json
D=/var/www/xray-sub
T=$D/.token
S=$D/config.yaml
U=/etc/systemd/system/xray-sub.service
B=/usr/local/bin/xray
need(){ [ "$(id -u)" -eq 0 ] || { echo "错误：请使用 root 用户运行，或在命令前加 sudo。" >&2; exit 1; }; }
get(){ [ -r "$C" ] && awk -F= -v k="$1" '$1==k{print substr($0,index($0,"=")+1);exit}' "$C" || true; }
url(){ printf 'http://%s:2054/sub/%s\n' "$(get SERVER)" "$(get TOKEN)"; }
install_all(){
 need; export DEBIAN_FRONTEND=noninteractive
 install -m 755 "$0" /usr/local/bin/xr
 apt-get update -qq; apt-get install -y -qq ca-certificates curl openssl python3 util-linux >/dev/null
 [ -x $B ] || curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh | bash -s -- install
 local server uuid private public sid token out
 server=${XRAY_SERVER:-$(get SERVER)}; server=${server:-$(curl -4fsS --max-time 8 https://api.ipify.org)}
 uuid=$(get UUID); uuid=${uuid:-$(python3 -c 'import uuid;print(uuid.uuid4())')}
 private=$(get PRIVATE_KEY); public=$(get PUBLIC_KEY)
 if [ -z "$private" ] || [ -z "$public" ]; then
   out=$($B x25519); private=$(printf '%s\n' "$out"|awk -F': ' '/^PrivateKey:/{print $2;exit}'); public=$(printf '%s\n' "$out"|awk -F': ' '/^Password \(PublicKey\):/{print $2;exit}')
 fi
 sid=${sid:-$(get SHORT_ID)}; sid=${sid:-$(openssl rand -hex 8)}
 token=${token:-$(get TOKEN)}; token=${token:-$(openssl rand -hex 24)}
 umask 077; cat > $C <<EOF
SERVER=$server
UUID=$uuid
PRIVATE_KEY=$private
PUBLIC_KEY=$public
SHORT_ID=$sid
TOKEN=$token
EOF
 install -d -m 755 /usr/local/etc/xray $D
 SERVER=$server UUID=$uuid PRIVATE_KEY=$private PUBLIC_KEY=$public SHORT_ID=$sid XRAY_PORT=2053 TCP_PORT=2055 python3 - $X <<'PY'
import json,os,sys
u=os.environ["UUID"]; p=os.environ["PRIVATE_KEY"]; k=os.environ["PUBLIC_KEY"]; sid=os.environ["SHORT_ID"]
def i(port,net):
 s={"network":net,"security":"reality","realitySettings":{"show":False,"dest":"www.cloudflare.com:443","serverNames":["www.cloudflare.com","cloudflare.com"],"privateKey":p,"shortIds":[sid]}}
 if net=="xhttp": s["xhttpSettings"]={"path":"/xhttp","mode":"auto"}
 return {"listen":"0.0.0.0","port":port,"protocol":"vless","settings":{"clients":[{"id":u,"email":"clash-party"}],"decryption":"none"},"streamSettings":s}
with open(sys.argv[1],"w") as f: json.dump({"log":{"loglevel":"warning"},"inbounds":[i(2053,"xhttp"),i(2055,"tcp")],"outbounds":[{"protocol":"freedom","tag":"direct"}]},f,indent=2); f.write("\n")
PY
 SERVER=$server UUID=$uuid PUBLIC_KEY=$public SHORT_ID=$sid TOKEN=$token python3 - $S $T <<'PY'
import os,sys
v=os.environ
a=["proxies:","  - name: hostdzire-reality","    type: vless",f"    server: {v['SERVER']}","    port: 2053",f"    uuid: {v['UUID']}","    tls: true","    udp: true","    servername: www.cloudflare.com","    client-fingerprint: chrome","    reality-opts:",f"      public-key: {v['PUBLIC_KEY']}",f"      short-id: {v['SHORT_ID']}","    network: xhttp","    xhttp-opts:","      path: /xhttp","      mode: auto","",
"  - name: hostdzire-reality-tcp","    type: vless",f"    server: {v['SERVER']}","    port: 2055",f"    uuid: {v['UUID']}","    tls: true","    udp: true","    servername: www.cloudflare.com","    client-fingerprint: chrome","    reality-opts:",f"      public-key: {v['PUBLIC_KEY']}",f"      short-id: {v['SHORT_ID']}","    network: tcp","","proxy-groups:","  - name: PROXY","    type: select","    proxies:","      - hostdzire-reality","      - hostdzire-reality-tcp","      - DIRECT","rules:","  - MATCH,PROXY"]
open(sys.argv[1],"w").write("\n".join(a)+"\n"); open(sys.argv[2],"w").write(v["TOKEN"]+"\n")
PY
 cat > $U <<EOF
[Unit]
Description=Private Clash subscription endpoint
After=network-online.target
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/xray-sub-auth.py
WorkingDirectory=/var/www/xray-sub
Restart=on-failure
User=nobody
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
[Install]
WantedBy=multi-user.target
EOF
 cat > /usr/local/bin/xray-sub-auth.py <<'PY'
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
r=Path("/var/www/xray-sub")
class H(BaseHTTPRequestHandler):
 def do_GET(self):
  if self.path!="/sub/"+(r/".token").read_text().strip(): self.send_error(404); return
  b=(r/"config.yaml").read_bytes(); self.send_response(200); self.send_header("Content-Type","text/yaml"); self.send_header("Content-Length",str(len(b))); self.end_headers(); self.wfile.write(b)
 def log_message(self,*a): pass
ThreadingHTTPServer(("0.0.0.0",2054),H).serve_forever()
PY
 chmod 755 /usr/local/bin/xray-sub-auth.py; $B run -test -config $X; systemctl daemon-reload; systemctl enable xray >/dev/null; systemctl restart xray; systemctl enable --now xray-sub >/dev/null
 echo "订阅地址：$(url)"
}
status(){ need; echo "Xray 服务状态："; systemctl is-active xray xray-sub || true; echo "监听端口："; ss -lntp|grep -E ':(2053|2054|2055)\b' || true; }
check(){ need; echo "正在检查 Xray 配置和订阅服务..."; $B run -test -config $X; curl -fsS "$(url)" >/dev/null; echo "检查通过。"; }
menu(){ while true; do printf '\n===== xr 管理菜单 =====\n1. 安装 / 修复 Xray\n2. 查看服务状态\n3. 查看订阅地址\n4. 重启服务\n5. 检查配置和订阅\n6. 查看 Xray 日志\n7. 查看订阅服务日志\n8. 卸载\n0. 退出\n请选择：'; read -r n; case $n in 1)install_all;;2)status;;3)need;url;;4)need;systemctl restart xray xray-sub; echo "服务已重启。";;5)check;;6)need;journalctl -u xray -n 80 --no-pager;;7)need;journalctl -u xray-sub -n 80 --no-pager;;8)uninstall;;0)return;;*) echo "无效选项，请输入 0-8。";; esac; done; }
uninstall(){ need; read -r -p "请输入 REMOVE 确认卸载：" n; [ "$n" = REMOVE ] || { echo "已取消卸载。"; return; }; systemctl disable --now xray-sub xray 2>/dev/null||true; rm -f $U /usr/local/bin/xray-sub-auth.py /usr/local/bin/xr; rm -rf $D /usr/local/etc/xray $C; systemctl daemon-reload; echo "已卸载 xr、Xray 和订阅服务。"; }
case ${1:-menu} in install)install_all;;menu)need;menu;;status)status;;sub|info)need;url;;restart)need;systemctl restart xray xray-sub; echo "服务已重启。";;check)check;;logs)need;journalctl -u ${2:-xray} -n 80 --no-pager;;uninstall)uninstall;;help|-h|--help)echo '用法：xr [install|menu|status|sub|restart|check|logs|uninstall]';;*)echo '错误：无效命令。使用 xr --help 查看用法。';exit 2;;esac
