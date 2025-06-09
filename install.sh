add_forward_rule() {
    read -p "请输入本机监听端口: " LISTEN_PORT
    read -p "请输入目标 IP:PORT: " TARGET_ADDR
    RULE_NAME="hia-${LISTEN_PORT}-tcp"
    # 删除同名 listen 避免重复
    sed -i "/^listen $RULE_NAME\b/,/^$/d" "$HAPROXY_CFG"
    echo -e "\nlisten $RULE_NAME\n    bind *:${LISTEN_PORT}\n    mode tcp\n    server $RULE_NAME $TARGET_ADDR\n" >> "$HAPROXY_CFG"
    restart_haproxy
    echo -e "${GREEN}TCP 转发规则已添加并应用。${RESET}"
}

delete_single_rule() {
    echo -e "${GREEN}现有转发规则：${RESET}"
    grep -E '^listen hia-[0-9]+-tcp$' "$HAPROXY_CFG" | nl
    RULES=($(grep -Eo '^listen hia-[0-9]+-tcp$' "$HAPROXY_CFG"))
    if [ ${#RULES[@]} -eq 0 ]; then
        echo "无自定义转发规则。"
        return
    fi
    read -p "请输入要删除的规则编号: " DEL_NO
    DEL_NAME="${RULES[$((DEL_NO-1))]}"
    if [ -z "$DEL_NAME" ]; then
        echo "编号无效。"
        return
    fi
    sed -i "/^$DEL_NAME\b/,/^$/d" "$HAPROXY_CFG"
    restart_haproxy
    echo -e "${GREEN}规则 $DEL_NAME 已删除。${RESET}"
}

delete_all_rules() {
    sed -i '/^listen hia-[0-9]\+-tcp$/,/^$/d' "$HAPROXY_CFG"
    restart_haproxy
    echo -e "${GREEN}全部自定义转发规则已删除。${RESET}"
}

list_rules() {
    echo -e "${GREEN}现有自定义转发规则：${RESET}"
    grep -E '^listen hia-[0-9]+-tcp$' "$HAPROXY_CFG" | nl
}

main_menu() {
    while true; do
        echo -e "${GREEN}===== HAProxy TCP转发管理脚本 =====${RESET}"
        echo "1. 安装 HAProxy"
        echo "2. 卸载 HAProxy"
        echo "3. 更新 HAProxy"
        echo "4. 重启 HAProxy"
        echo "--------------------"
        echo "5. 新增转发规则"
        echo "6. 删除单条规则"
        echo "7. 删除全部规则"
        echo "8. 查看现有规则"
        echo "9. 查看日志"
        echo "10. 查看完整配置"
        echo "11. 退出"
        read -p "请选择一个操作 [1-11]: " CHOICE
        case "$CHOICE" in
            1) install_haproxy ;;
            2) uninstall_haproxy ;;
            3) update_haproxy ;;
            4) restart_haproxy ;;
            5) add_forward_rule ;;
            6) delete_single_rule ;;
            7) delete_all_rules ;;
            8) list_rules ;;
            9) view_log ;;
            10) view_config ;;
            11) exit 0 ;;
            *) echo -e "${GREEN}请输入正确的选项！${RESET}" ;;
        esac
    done
}

main_menu
