#!/bin/bash
set -e

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

HAPROXY_CFG="/etc/haproxy/haproxy.cfg"
HAPROXY_BAK="/etc/haproxy/haproxy.cfg.bak"
HAPROXY_SERVICE="haproxy"

# 检查 root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请以 root 用户运行此脚本。${RESET}"
    exit 1
fi

function backup_config() {
    [ -f "$HAPROXY_CFG" ] && cp "$HAPROXY_CFG" "$HAPROXY_BAK"
}

function restore_backup() {
    [ -f "$HAPROXY_BAK" ] && cp "$HAPROXY_BAK" "$HAPROXY_CFG"
}

function install_haproxy() {
    apt update
    apt install -y haproxy
    backup_config
    systemctl enable $HAPROXY_SERVICE
    systemctl start $HAPROXY_SERVICE
    echo -e "${GREEN}HAProxy 已安装并启动。${RESET}"
}

function update_haproxy() {
    apt update
    apt install --only-upgrade -y haproxy
    echo -e "${GREEN}HAProxy 已升级。${RESET}"
}

function restart_haproxy() {
    systemctl restart $HAPROXY_SERVICE
    echo -e "${GREEN}HAProxy 已重启。${RESET}"
}

function uninstall_haproxy() {
    systemctl stop $HAPROXY_SERVICE || true
    apt purge -y haproxy
    rm -f "$HAPROXY_CFG" "$HAPROXY_BAK"
    systemctl daemon-reload
    exit 0
}

function add_forward_rule() {
    read -p "请输入本机监听端口: " LISTEN_PORT
    read -p "请输入目标 IP:PORT: " TARGET_ADDR
    RULE_NAME="hia-${LISTEN_PORT}-tcp"
    # 删除同名 listen
    sed -i "/^listen $RULE_NAME\b/,/^$/d" "$HAPROXY_CFG"
    cat >> "$HAPROXY_CFG" <<EOF

listen $RULE_NAME
    bind *:$LISTEN_PORT
    mode tcp
    server $RULE_NAME $TARGET_ADDR
EOF
    restart_haproxy
    echo -e "${GREEN}TCP 转发规则已添加并应用。${RESET}"
}

function delete_single_rule() {
    RULES=($(grep -Eo '^listen hia-[0-9]+-tcp$' "$HAPROXY_CFG"))
    [ ${#RULES[@]} -eq 0 ] && echo "无自定义转发规则。" && return
    grep -E '^listen hia-[0-9]+-tcp$' "$HAPROXY_CFG" | nl
    read -p "请输入要删除的规则编号: " DEL_NO
    DEL_NAME="${RULES[$((DEL_NO-1))]}"
    [ -z "$DEL_NAME" ] && echo "编号无效。" && return
    sed -i "/^$DEL_NAME\b/,/^$/d" "$HAPROXY_CFG"
    restart_haproxy
    echo -e "${GREEN}规则 $DEL_NAME 已删除。${RESET}"
}

function delete_all_rules() {
    sed -i '/^listen hia-[0-9]\+-tcp$/,/^$/d' "$HAPROXY_CFG"
    restart_haproxy
    echo -e "${GREEN}全部自定义转发规则已删除。${RESET}"
}

function list_rules() {
    grep -E '^listen hia-[0-9]+-tcp$' "$HAPROXY_CFG" | nl || echo "(无自定义转发规则)"
}

function view_log() {
    journalctl -u $HAPROXY_SERVICE -n 30 --no-pager 2>/dev/null || echo "(暂无日志)"
}

function view_config() {
    cat "$HAPROXY_CFG"
}

while true; do
    echo -e "${GREEN}
======= HAProxy TCP转发管理 =======

  1. 安装 HAProxy
  2. 更新 HAProxy
  3. 卸载 HAProxy

  4. 新增转发规则
  5. 删除单条规则
  6. 删除全部规则
  7. 查看现有规则
  8. 查看日志
  9. 查看完整配置

  0. 退出
==================================
${RESET}"
    read -p "选择操作 [0-9]: " opt
    case $opt in
        1) install_haproxy ;;
        2) update_haproxy ;;
        3) uninstall_haproxy ;;    # 卸载并立即 exit
        4) add_forward_rule ;;
        5) delete_single_rule ;;
        6) delete_all_rules ;;
        7) list_rules ;;
        8) view_log ;;
        9) view_config ;;
        0) exit 0 ;;               # 直接退出，无提示
        *) ;;
    esac
done
