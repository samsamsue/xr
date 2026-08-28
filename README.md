# xr：Xray VLESS + Reality 管理脚本

一键安装（Debian / Ubuntu，使用 root 或 sudo）：

```bash
curl -fsSL https://raw.githubusercontent.com/samsamsue/xr/main/xr.sh -o /tmp/xr.sh && sudo bash /tmp/xr.sh install
```

安装完成后直接运行 `xr` 打开中文管理菜单。也可以使用命令行：

```text
xr install       安装或修复
xr status        查看服务状态和监听端口
xr sub           查看 Clash Party / Mihomo 订阅地址
xr restart       重启 Xray 和订阅服务
xr check         检查配置及订阅是否正常
xr logs xray     查看 Xray 日志
xr logs xray-sub 查看订阅服务日志
xr uninstall     卸载
```

脚本会配置两个节点：`VLESS + XHTTP + Reality`（TCP 2053）和 `VLESS + TCP + Reality` 备用节点（TCP 2055），订阅服务使用 TCP 2054。请在服务器防火墙 / 安全组放行 `2053`、`2054`、`2055`。

修复或重复安装时会保留 `/root/xray-credentials.txt`，因此 UUID、Reality 密钥和订阅 Token 不会改变。自动识别公网 IP 失败时，可手动指定：

```bash
XRAY_SERVER=你的公网IP bash /tmp/xr.sh install
```
