# Xray manager

Upload `xr.sh` to GitHub, then install with (replace the owner/repository/branch):

    curl -fsSL https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/xr.sh -o /tmp/xr.sh && sudo bash /tmp/xr.sh install

After installation run `xr` for the menu. Commands: `xr install`, `xr status`, `xr sub`, `xr restart`, `xr check`, `xr logs xray`, and `xr uninstall`. The generated subscription includes VLESS XHTTP + Reality on 2053 and TCP + Reality fallback on 2055. Open TCP ports 2053, 2054, and 2055.

The installer preserves `/root/xray-credentials.txt` during repair, so UUID, Reality keys, and the subscription URL do not change. To set a fixed public address when automatic detection is unavailable, run `XRAY_SERVER=203.0.113.10 bash /tmp/xr.sh install`.
