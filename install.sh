#!/bin/bash
GREEN="\e[32m"
RESET="\e[0m"
HAPROXY_CFG="/etc/haproxy/haproxy.cfg"
BACKUP_CFG="/etc/haproxy/haproxy.cfg.bak"

if [ "$EUID" -ne 0 ]; then
    echo -e "${GREEN}请以 root 用户运行此脚本。${RESET}"
    exit 1
fi

install_haproxy() {
    echo -e "${GREEN}正在安装 HAProxy...${RESET}"
    if command -v apt >/dev/null 2>&1; then
        apt update && apt install -y haproxy
    elif command -v yum >/dev/null 2>&1; then
        yum install -y haproxy
    else
        echo "不支持的包管理器，请手动安装 haproxy"
        exit 1
    fi

    [ ! -f "$HAPROXY_CFG" ] && touch "$HAPROXY_CFG"
    cp "$HAPROXY_CFG" "$BACKUP_CFG"
    echo -e "${GREEN}HAProxy 安装完成！配置文件备份为 $BACKUP_CFG${RESET}"
}

add_rule() {
    cp "$HAPROXY_CFG" "$BACKUP_CFG"
    read -p "请输入本机监听端口: " LOCAL_PORT
    while [[ -z "$LOCAL_PORT" ]] || ! [[ "$LOCAL_PORT" =~ ^[0-9]{1,5}$ ]] || [ "$LOCAL_PORT" -lt 1 ] || [ "$LOCAL_PORT" -gt 65535 ]; do
        echo -e "${GREEN}端口不能为空且必须是1-65535之间的数字，请重新输入。${RESET}"
        read -p "请输入本机监听端口: " LOCAL_PORT
    done

    echo "请选择协议类型："
    echo "1. tcp"
    echo "2. udp"
    echo "3. tcp+udp"
    read -p "输入数字选择协议类型 (默认1=tcp): " PROTO_SELECT
    case "$PROTO_SELECT" in
        2) PROTO="udp" ;;
        3) PROTO="both" ;;
        *) PROTO="tcp" ;;
    esac

    read -p "请输入目标 IP:PORT (如 198.176.54.80:18744): " TARGET_ADDR
    while [[ -z "$TARGET_ADDR" ]] || ! [[ "$TARGET_ADDR" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}:[0-9]{1,5}$ ]]; do
        echo -e "${GREEN}格式不正确！应为 1.2.3.4:5678，请重新输入。${RESET}"
        read -p "请输入目标 IP:PORT: " TARGET_ADDR
    done

    if [[ "$PROTO" == "tcp" || "$PROTO" == "both" ]]; then
cat >> "$HAPROXY_CFG" <<EOF

frontend f_tcp_$LOCAL_PORT
    bind 0.0.0.0:$LOCAL_PORT
    mode tcp
    default_backend b_tcp_$LOCAL_PORT

backend b_tcp_$LOCAL_PORT
    mode tcp
    server s_tcp_$LOCAL_PORT $TARGET_ADDR check
EOF
    fi

    if [[ "$PROTO" == "udp" || "$PROTO" == "both" ]]; then
cat >> "$HAPROXY_CFG" <<EOF

frontend f_udp_$LOCAL_PORT
    bind 0.0.0.0:$LOCAL_PORT
    mode udp
    default_backend b_udp_$LOCAL_PORT

backend b_udp_$LOCAL_PORT
    mode udp
    server s_udp_$LOCAL_PORT $TARGET_ADDR check
EOF
    fi

    echo -e "${GREEN}规则已添加，正在重启 HAProxy...${RESET}"
    systemctl restart haproxy
    echo -e "${GREEN}已完成。${RESET}"
}

delete_rule() {
    cp "$HAPROXY_CFG" "$BACKUP_CFG"
    read -p "请输入要删除的监听端口: " DEL_PORT
    # 直接通过注释配置来“屏蔽”，并不直接物理删除（安全/可逆）
    sed -i "/frontend f_tcp_$DEL_PORT/,/backend b_tcp_$DEL_PORT/ s/^/#/" "$HAPROXY_CFG"
    sed -i "/frontend f_udp_$DEL_PORT/,/backend b_udp_$DEL_PORT/ s/^/#/" "$HAPROXY_CFG"
    systemctl restart haproxy
    echo -e "${GREEN}规则已注释屏蔽。需要彻底清理请手动编辑 $HAPROXY_CFG。${RESET}"
}

view_cfg() {
    echo -e "${GREEN}当前 HAProxy 配置:${RESET}"
    cat "$HAPROXY_CFG"
}

main_menu() {
    while true; do
        echo -e "${GREEN}===== HAProxy 端口转发管理脚本 =====${RESET}"
        echo "1. 安装 HAProxy"
        echo "2. 新增转发规则"
        echo "3. 注释删除规则"
        echo "4. 查看配置"
        echo "5. 退出"
        read -p "请选择一个操作 [1-5]: " choice
        case "$choice" in
            1) install_haproxy ;;
            2) add_rule ;;
            3) delete_rule ;;
            4) view_cfg ;;
            5) exit 0 ;;
            *) echo -e "${GREEN}请输入正确的选项！${RESET}" ;;
        esac
    done
}

main_menu
