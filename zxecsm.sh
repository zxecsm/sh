#!/bin/bash

# 定义脚本链接
SCRIPT_LINK="https://raw.githubusercontent.com/zxecsm/sh/main/zxecsm.sh"
SCRIPT_FILE="$HOME/zxecsm.sh"

# 定义颜色常量
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"
RESET="\033[0m" # 重置颜色

# 自定义颜色输出函数
color_echo() {
  local color="$1"
  shift
  case "$color" in
  "red") color_code="$RED" ;;
  "green") color_code="$GREEN" ;;
  "yellow") color_code="$YELLOW" ;;
  "blue") color_code="$BLUE" ;;
  "magenta") color_code="$MAGENTA" ;;
  "cyan") color_code="$CYAN" ;;
  "white") color_code="$WHITE" ;;
  *) color_code="$RESET" ;; # 默认无颜色
  esac
  echo -e "${color_code}$@${RESET}"
}

# 确认
confirm() {
  # 提示用户确认操作
  echo
  read -p "${1:-确认操作?} [y/N]: " response
  case "$response" in
  [yY][eE][sS] | [yY])
    return 0 # 用户确认操作
    ;;
  *)
    return 1 # 用户取消操作
    ;;
  esac
}

# 检查是否安装
is_installed() {
  if command -v "$1" &>/dev/null; then
    return 0
  else
    return 1
  fi
}

# 清空屏幕
break_end() {
  echo
  color_echo green "按任意键继续"
  read -n 1 -s
  echo
  clear
}

# 延迟消息
sleepMsg() {
  local msg="$1"
  local delay="${2:-2}" # 如果没有指定延迟时间，则默认为 1 秒
  local color="${3:-red}"

  # 如果消息为空，则使用默认消息
  if [ -z "$msg" ]; then
    msg="没有提供消息。"
  fi

  echo
  color_echo "$color" "$msg"
  echo
  sleep "$delay"
}

# 获取本地 IPv4 和 IPv6 地址
get_ip_addresses() {
  ipv4_address=$(hostname -I | awk '{print $1}')
  ipv6_address=$(hostname -I | awk '{for(i=1;i<=NF;i++) if ($i ~ /:/) {print $i; exit}}')

  # 只有在IPv6地址存在时才设置
  if [ -z "$ipv6_address" ]; then
    ipv6_address="未配置IPv6"
  fi

  echo "$ipv4_address $ipv6_address"
}

# 获取网络状态
get_network_status() {
  result=$(awk 'BEGIN { rx_total = 0; tx_total = 0 }
        NR > 2 { rx_total += $2; tx_total += $10 }
        END {
            # 定义单位数组
            units[1] = "Bytes"; units[2] = "KB"; units[3] = "MB"; units[4] = "GB"; units[5] = "TB";

            # 接收数据处理
            rx_unit_idx = 1
            while (rx_total >= 1024 && rx_unit_idx < 5) {
                rx_total /= 1024
                rx_unit_idx++
            }

            # 发送数据处理
            tx_unit_idx = 1
            while (tx_total >= 1024 && tx_unit_idx < 5) {
                tx_total /= 1024
                tx_unit_idx++
            }

            # 将结果存储到 result 变量
            result = sprintf("总接收: %.2f %s\n总发送: %.2f %s", rx_total, units[rx_unit_idx], tx_total, units[tx_unit_idx])
            print result
        }' /proc/net/dev)

  echo "$result"
}

# 获取当前时区
current_timezone() {
  # 使用 timedatectl 获取时区信息
  timezone=$(timedatectl | grep "Time zone" | awk '{print $3}')

  # 如果 timedatectl 未能成功获取时区，返回默认值
  if [ -z "$timezone" ]; then
    echo "无法获取时区"
  else
    echo "$timezone"
  fi
}

# 系统信息
system_info() {
  clear
  # 获取IP
  addresses=$(get_ip_addresses)
  ipv4_address=$(echo "$addresses" | awk '{print $1}')
  ipv6_address=$(echo "$addresses" | awk '{print $2}')
  # 版本
  kernel_version=$(uname -r)
  # CPU架构
  cpu_arch=$(uname -m)
  # CPU型号
  if [ $cpu_arch == "x86_64" ]; then
    cpu_info=$(cat /proc/cpuinfo | grep 'model name' | uniq | sed -e 's/model name[[:space:]]*: //')
  else
    cpu_info=$(lscpu | grep 'BIOS Model name' | awk -F': ' '{print $2}' | sed 's/^[ \t]*//')
  fi
  # CPU 核心数
  cpu_cores=$(nproc)
  # 物理内存
  mem_info=$(free -b | awk 'NR==2{printf "%.2f/%.2f MB (%.2f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}')
  # 硬盘使用
  disk_info=$(df -h | awk '$NF=="/"{printf "%s/%s (%s)", $3, $2, $5}')
  # 主机名
  hostname=$(hostname)
  # bbr信息
  congestion_algorithm=$(sysctl -n net.ipv4.tcp_congestion_control)
  queue_algorithm=$(sysctl -n net.core.default_qdisc)

  # 尝试使用 lsb_release 获取系统信息
  os_info=$(lsb_release -ds 2>/dev/null)
  if [ -z "$os_info" ]; then
    os_info="Unknown"
  fi
  # 网络流量
  network_info=$(get_network_status)
  # 系统时间
  current_time=$(date "+%Y-%m-%d %I:%M %p")
  # 虚拟内存
  swap_used=0
  swap_total=0
  swap_percentage=0

  if free -m | awk 'NR==3{exit $2==0}'; then
    swap_used=$(free -m | awk 'NR==3{print $3}')
    swap_total=$(free -m | awk 'NR==3{print $2}')
    swap_percentage=$((swap_used * 100 / swap_total))
  fi

  swap_info="${swap_used}MB/${swap_total}MB (${swap_percentage}%)"

  # 运行时间
  runtime=$(cat /proc/uptime | awk -F. '{run_days=int($1 / 86400);run_hours=int(($1 % 86400) / 3600);run_minutes=int(($1 % 3600) / 60); if (run_days > 0) printf("%d天 ", run_days); if (run_hours > 0) printf("%d时 ", run_hours); printf("%d分\n", run_minutes)}')
  # 时区
  timezone=$(current_timezone)

  echo
  echo
  echo -e "主机名: ${CYAN}$hostname${RESET}"
  echo
  echo "系统版本: $os_info"
  echo "Linux版本: $kernel_version"
  echo
  echo -e "CPU架构: ${YELLOW}$cpu_arch${RESET}"
  echo "CPU型号: $cpu_info"
  echo "CPU核心数: $cpu_cores"
  echo
  echo "物理内存: $mem_info"
  echo "虚拟内存: $swap_info"
  echo "硬盘占用: $disk_info"
  echo
  echo "$network_info"
  echo
  echo "网络拥堵算法: $congestion_algorithm $queue_algorithm"
  echo
  echo -e "公网IPv4地址: ${MAGENTA}$ipv4_address${RESET}"
  echo "公网IPv6地址: $ipv6_address"
  echo
  echo -e "系统时区: ${YELLOW}$timezone${RESET}"
  echo "系统时间: $current_time"
  echo
  echo "系统运行时长: $runtime"
  break_end
}

# 检查UFW状态
before_ufw() {
  if ! is_installed "ufw"; then
    sleepMsg "未安装 ufw"
    return 1 # 未安装 ufw 时退出函数
  fi
  return 0
}

# 判断端口是否有效
is_valid_port() {
  local port="$1"

  # 检查端口号是否为数字
  if ! [[ "$port" =~ ^[0-9]+$ ]]; then
    sleepMsg "无效的端口：必须是数字"
    return 1
  fi

  # 检查端口号是否在1到65535之间
  if [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
    return 0 # 有效端口
  else
    sleepMsg "无效的端口：端口号必须在1到65535之间"
    return 1
  fi
}

# 输出UFW状态
output_ufw_status() {
  # 检查ufw是否安装
  if ! is_installed "ufw"; then
    echo
    color_echo red "未安装 ufw"
    return 1 # 未安装 ufw 时退出函数
  fi

  # 检查ss是否安装
  if ! is_installed "ss"; then
    sudo apt-get install -y iproute2
    clear
  fi

  # 获取UFW中开放的端口列表和状态
  local ufw_status
  ufw_status=$(sudo ufw status)

  # 获取当前系统所有的监听端口和对应的进程
  local listening_ports
  listening_ports=$(sudo ss -lpn)

  # 打印状态（第一行）
  color_echo cyan "$ufw_status" | head -n 1
  # 遍历UFW状态并处理每一行
  echo "$ufw_status" | while IFS= read -r line; do
    # 只处理包含"ALLOW"的行
    if echo "$line" | grep -q "ALLOW"; then
      # 提取端口和协议
      local port_protocol
      port_protocol=$(echo "$line" | awk '{print $1}')
      local port
      port=$(echo "$port_protocol" | grep -oP '\d{1,5}')

      if ! echo "$port_protocol" | grep -Pq '\d{1,5}:\d{1,5}'; then
        # 使用ss命令检查端口是否被占用
        if echo "$listening_ports" | grep -q ":$port "; then
          color_echo yellow "$line"
          continue
        fi
      fi

      # 打印结果
      echo "$line"
    fi
  done
}

# 删除未使用的端口
delete_unused_ports() {
  if ! before_ufw; then
    return 1
  fi

  if ! confirm "确认删除未使用的端口？"; then
    sleepMsg "操作已取消。" 2 yellow
    return 1
  fi

  if ! is_installed "ss"; then
    sudo apt-get install -y iproute2
  fi

  local ufw_status
  ufw_status=$(sudo ufw status)

  # 获取当前系统所有的监听端口和对应的进程
  local listening_ports
  listening_ports=$(sudo ss -lpn)

  # 遍历UFW状态并处理每一行
  echo "$ufw_status" | while IFS= read -r line; do
    # 判断是否包含 'ALLOW' 并且不包含端口范围格式
    if echo "$line" | grep -q "ALLOW" && ! echo "$line" | grep -Pq '\d{1,5}:\d{1,5}'; then
      # 提取端口和协议
      local port_protocol
      port_protocol=$(echo "$line" | awk '{print $1}')
      local port
      port=$(echo "$port_protocol" | grep -oP '\d{1,5}')

      # 检查是否有进程在监听此端口
      if ! echo "$listening_ports" | grep -q ":$port "; then
        sudo ufw delete allow "$port_protocol"
      fi
    fi
  done
}

# 配置防火墙
configure_ufw() {
  while true; do
    clear
    output_ufw_status
    echo
    echo "1. 添加   2. 删除   3. 删除未占用的端口"
    echo
    echo "4. 安装   5. 卸载"
    echo
    echo "6. 开启   7. 关闭   8. 重置"
    echo
    echo "0. 返回"
    echo
    read -p "请输入你的选择：" hd
    case $hd in
    1)
      if before_ufw; then
        echo
        read -p "请输入端口：" port
        sudo ufw allow $port
        if [ $? -eq 1 ]; then
          break_end
        fi
      fi
      ;;
    2)
      if before_ufw; then
        echo
        read -p "请输入端口：" port
        sudo ufw delete allow $port
        if [ $? -eq 1 ]; then
          break_end
        fi
      fi
      ;;
    3)
      delete_unused_ports
      break_end
      ;;
    4)
      if is_installed "ufw"; then
        sleepMsg "ufw 已安装" 2 green
      else
        sudo apt install -y ufw
        break_end
      fi
      ;;
    5)
      if before_ufw; then
        if confirm "确认卸载？"; then
          sudo apt remove --purge -y ufw
          break_end
        else
          sleepMsg "操作已取消。" 2 yellow
        fi
      fi
      ;;
    6)
      if before_ufw; then
        sudo ufw enable
        break_end
      fi
      ;;
    7)
      if before_ufw; then
        if confirm "确认关闭？"; then
          sudo ufw disable
          break_end
        else
          sleepMsg "操作已取消。" 2 yellow
        fi
      fi
      ;;
    8)
      if before_ufw; then
        if confirm "确认重置？"; then
          sudo ufw reset
          break_end
        else
          sleepMsg "操作已取消。" 2 yellow
        fi
      fi
      ;;
    0)
      break
      ;;
    *)
      sleepMsg "无效的输入!"
      ;;
    esac
  done
}

# 验证输入的 Node.js 版本是否有效（支持整数和浮动版本）
validate_node_version() {
  local node_version="$1"

  # 检查版本是否符合 "x" 或 "x.x.x" 的格式
  if [[ "$node_version" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    return 0
  else
    sleepMsg "无效的版本号格式，请输入正确的 Node.js 版本（例如：14 或 14.18.1）"
    return 1
  fi
}

# 安装nvm
install_nvm() {
  if is_installed "nvm"; then
    sleepMsg "nvm 已安装" 2 green
  else
    sudo mkdir -p /usr/local/nvm
    sudo git clone https://github.com/nvm-sh/nvm.git /usr/local/nvm
    bash /usr/local/nvm/install.sh
    source ~/.bashrc
    break_end
  fi
}

# 指定 nvm 的完整路径
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# 检查 nvm 是否已经安装
before_nvm() {
  if ! is_installed "nvm"; then
    sleepMsg "未安装 nvm"
  else
    return 0
  fi
}

# 配置nvm
configure_nvm() {
  while true; do
    clear
    echo
    echo "1. 安装nvm     2. 安装node"
    echo
    echo "3. 已安装版本  4. 可安装版本"
    echo
    echo "5. 指定版本    6. 卸载node"
    echo
    echo "0. 返回"
    echo
    read -p "请输入你的选择: " nvm_choice
    case $nvm_choice in
    1)
      install_nvm
      ;;
    2)
      if before_nvm; then
        echo
        read -p "请输入node版本: " node_choice
        if validate_node_version "$node_choice"; then
          nvm install $node_choice
          break_end
        fi
      fi
      ;;
    3)
      if before_nvm; then
        clear
        nvm ls
        break_end
      fi
      ;;
    4)
      if before_nvm; then
        clear
        nvm ls-remote
        break_end
      fi
      ;;
    5)
      if before_nvm; then
        echo
        read -p "请输入node版本: " node_choice
        if validate_node_version "$node_choice"; then
          nvm use $node_choice
          break_end
        fi
      fi
      ;;
    6)
      if before_nvm; then
        echo
        read -p "请输入node版本: " node_choice
        if validate_node_version "$node_choice"; then
          if confirm "确认卸载 $node_choice 版本？"; then
            nvm uninstall $node_choice
            break_end
          fi
        fi
      fi
      ;;
    0)
      break
      ;;
    *)
      sleepMsg "无效的输入!"
      ;;
    esac
  done
}

# 验证用户名格式
validate_username() {
  local username="$1"

  # 用户名应该是 1 到 32 个字符，且只能包含小写字母、数字、下划线和短横线
  if [[ "$username" =~ ^[a-z0-9_-]{1,32}$ ]] && ! [[ "$username" =~ ^[0-9] ]]; then
    return 0 # 验证通过
  else
    sleepMsg "无效的用户名格式！用户名应由小写字母、数字、下划线和短横线组成，且不能以数字开头。"
    return 1 # 验证失败
  fi
}

# 检查用户是否存在
is_user() {
  if id "$1" &>/dev/null; then
    return 0
  else
    return 1
  fi
}

before_user() {
  if is_user "$1"; then
    return 0
  else
    sleepMsg "用户 $1 不存在"
    return 1
  fi
}

# 添加 sudo 权限
add_sudo() {
  username="$1"
  if before_user "$username"; then
    sudo usermod -aG sudo "$username"
    if [ $? -eq 0 ]; then
      sleepMsg "用户 $username 已成功添加到 sudo 组" 2 green
    else
      break_end
    fi
  fi
}

# 取消 sudo 权限
del_sudo() {
  username="$1"
  if before_user "$username"; then
    sudo gpasswd -d "$username" sudo
    if [ $? -eq 0 ]; then
      sleepMsg "用户 $username 已成功从 sudo 组中移除" 2 green
    else
      break_end
    fi
  fi
}

# 修改用户密码
change_password() {
  username="$1"
  if before_user "$username"; then
    sudo passwd "$username" # 修改用户密码
    break_end
  fi
}

# 配置用户
configure_user() {
  while true; do
    clear
    # 显示所有用户、用户权限、用户组和是否在sudoers中
    echo
    printf "%-24s %-34s %-20s %-10s\n" "用户名" "用户权限" "用户组" "sudo权限"
    while IFS=: read -r username _ userid groupid _ _ homedir shell; do
      groups=$(groups "$username" | cut -d : -f 2)
      sudo_status=$(sudo -n -lU "$username" 2>/dev/null | grep -q '(ALL : ALL)' && echo "Yes" || echo "No")
      printf "%-20s %-30s %-20s %-10s\n" "$username" "$homedir" "$groups" "$sudo_status"
    done </etc/passwd
    echo
    echo
    echo "1. 创建普通账户    2. 创建高级账户"
    echo
    echo "3. 赋予最高权限    4. 取消最高权限"
    echo
    echo "5. 修改用户密码    6. 删除用户"
    echo
    echo "0. 返回"
    echo
    read -p "请输入你的选择: " sub_choice

    case $sub_choice in
    1)
      echo
      read -p "请输入用户名: " new_username
      if validate_username "$new_username"; then
        if is_user "$new_username"; then
          sleepMsg "用户 $new_username 已经存在"
        else
          # 创建新用户并设置密码
          sudo useradd -m -s /bin/bash "$new_username" && sudo passwd "$new_username"
          break_end
        fi
      fi
      ;;
    2)
      echo
      read -p "请输入用户名: " new_username
      if validate_username "$new_username"; then
        if is_user "$new_username"; then
          sleepMsg "用户 $new_username 已经存在"
        else
          # 创建新用户并设置密码
          sudo useradd -m -s /bin/bash "$new_username" && sudo passwd "$new_username"
          add_sudo "$new_username"
        fi
      fi
      ;;
    3)
      echo
      read -p "请输入用户名: " username
      if confirm "确认赋予用户 $username sudo 权限？"; then
        add_sudo $username
      else
        sleepMsg "操作已取消。" 2 yellow
      fi
      ;;
    4)
      echo
      read -p "请输入用户名: " username
      if confirm "确认移除用户 $username sudo 权限？"; then
        del_sudo $username
      else
        sleepMsg "操作已取消。" 2 yellow
      fi
      ;;
    5)
      echo
      read -p "请输入用户名: " username
      change_password $username
      ;;
    6)
      echo
      read -p "请输入用户名: " username
      if confirm "确认删除用户：$username？"; then
        # 删除用户及其主目录
        sudo pkill -u $username # 查找并终止与该用户关联的所有进程
        sudo userdel -r $username
        break_end
      else
        sleepMsg "操作已取消。" 2 yellow
      fi
      ;;
    0)
      break
      ;;
    *)
      sleepMsg "无效的输入！"
      ;;
    esac
  done
}

# 设置时区
set_timedate() {
  sudo timedatectl set-timezone "$1"
}

# 切换时区
change_timezone() {
  while true; do
    clear
    # 获取当前系统时区
    timezone=$(current_timezone)
    # 获取当前系统时间
    current_time=$(date +"%Y-%m-%d %H:%M:%S")
    # 显示时区和时间
    echo -e "当前系统时区：${CYAN}$timezone${RESET}"
    echo "当前系统时间：$current_time"
    echo
    echo "时区切换"
    echo "亚洲------------------------"
    echo "1. 中国上海时间          2. 中国香港时间"
    echo "3. 日本东京时间          4. 韩国首尔时间"
    echo "5. 新加坡时间            6. 印度加尔各答时间"
    echo "7. 阿联酋迪拜时间        8. 澳大利亚悉尼时间"
    echo "欧洲------------------------"
    echo "11. 英国伦敦时间         12. 法国巴黎时间"
    echo "13. 德国柏林时间         14. 俄罗斯莫斯科时间"
    echo "15. 荷兰尤特赖赫特时间   16. 西班牙马德里时间"
    echo "美洲------------------------"
    echo "21. 美国西部时间         22. 美国东部时间"
    echo "23. 加拿大时间           24. 墨西哥时间"
    echo "25. 巴西时间             26. 阿根廷时间"
    echo
    echo "0. 返回"
    echo
    read -p "请输入你的选择: " sub_choice

    case $sub_choice in
    1) set_timedate Asia/Shanghai ;;
    2) set_timedate Asia/Hong_Kong ;;
    3) set_timedate Asia/Tokyo ;;
    4) set_timedate Asia/Seoul ;;
    5) set_timedate Asia/Singapore ;;
    6) set_timedate Asia/Kolkata ;;
    7) set_timedate Asia/Dubai ;;
    8) set_timedate Australia/Sydney ;;
    11) set_timedate Europe/London ;;
    12) set_timedate Europe/Paris ;;
    13) set_timedate Europe/Berlin ;;
    14) set_timedate Europe/Moscow ;;
    15) set_timedate Europe/Amsterdam ;;
    16) set_timedate Europe/Madrid ;;
    21) set_timedate America/Los_Angeles ;;
    22) set_timedate America/New_York ;;
    23) set_timedate America/Vancouver ;;
    24) set_timedate America/Mexico_City ;;
    25) set_timedate America/Sao_Paulo ;;
    26) set_timedate America/Argentina/Buenos_Aires ;;
    0)
      break
      ;;
    *)
      sleepMsg "无效的输入！"
      ;;
    esac
  done
}

# 修改主机名
change_hostname() {
  current_hostname=$(hostname)
  echo -e "当前主机名: ${CYAN}$current_hostname${RESET}"
  # 获取新的主机名
  echo
  read -p "请输入新的主机名: " new_hostname
  # 主机名验证：只允许字母、数字、短横线的组合，且不以数字开头
  if [[ ! "$new_hostname" =~ ^[a-zA-Z][a-zA-Z0-9-]*$ || ${#new_hostname} -gt 63 || ${#new_hostname} -lt 1 ]]; then
    sleepMsg "无效的主机名。主机名必须以字母开头，且只能包含字母、数字和短横线，长度不超过63个字符。"
    return 1
  fi

  if [ -n "$new_hostname" ]; then
    if confirm "确认更改主机名为 $new_hostname 吗？"; then
      # 更新主机名
      hostnamectl set-hostname "$new_hostname"
      sed -i "s/$current_hostname/$new_hostname/g" /etc/hostname
      systemctl restart systemd-hostnamed

      # 修改 /etc/hosts 中的主机名（只替换包含当前主机名的行）
      if grep -q "$current_hostname" /etc/hosts; then
        sed -i "s/$current_hostname/$new_hostname/g" /etc/hosts
      else
        # 如果没有找到，则添加新的主机名到 /etc/hosts
        echo "127.0.0.1 $new_hostname" | sudo tee -a /etc/hosts >/dev/null
      fi
      sleepMsg "主机名已更改为: $new_hostname" 2 green
    else
      sleepMsg "操作已取消。" 2 yellow
    fi
  else
    sleepMsg "无效的主机名。未更改主机名。"
  fi
}

before_crontab() {
  if ! is_installed "crontab"; then
    sleepMsg "未安装 crontab"
    return 1
  fi
  return 0
}

add_crontab() {
  if ! before_crontab; then
    return 1
  fi
  echo
  read -p "请输入新任务的执行命令: " newquest
  echo
  echo "1. 每月任务    2. 每周任务"
  echo
  echo "3. 每天任务    4. 每小时任务"
  echo
  read -p "请输入你的选择: " dingshi

  case $dingshi in
  1)
    echo
    read -p "选择每月的几号执行任务？ (1-31): " day
    if [[ ! "$day" =~ ^[0-9]+$ ]] || [[ "$day" -lt 1 || "$day" -gt 31 ]]; then
      sleepMsg "无效的日期，必须在 1 到 31 之间。"
    else
      (
        crontab -l
        echo "0 0 $day * * $newquest"
      ) | crontab - >/dev/null 2>&1
    fi
    ;;
  2)
    echo
    read -p "选择周几执行任务？ (0-6，0代表星期日): " weekday
    if [[ ! "$day" =~ ^[0-9]+$ ]] || [[ "$weekday" -lt 0 || "$weekday" -gt 6 ]]; then
      sleepMsg "无效的星期数，必须在 0 到 6 之间。"
    else
      (
        crontab -l
        echo "0 0 * * $weekday $newquest"
      ) | crontab - >/dev/null 2>&1
    fi
    ;;
  3)
    echo
    read -p "选择每天几点执行任务？（小时，0-23）: " hour
    if [[ ! "$day" =~ ^[0-9]+$ ]] || [[ "$hour" -lt 0 || "$hour" -gt 23 ]]; then
      sleepMsg "无效的小时数，必须在 0 到 23 之间。"
    else
      (
        crontab -l
        echo "0 $hour * * * $newquest"
      ) | crontab - >/dev/null 2>&1
    fi
    ;;
  4)
    echo
    read -p "输入每小时的第几分钟执行任务？（分钟，0-59）: " minute
    if [[ ! "$day" =~ ^[0-9]+$ ]] || [[ "$minute" -lt 0 || "$minute" -gt 59 ]]; then
      sleepMsg "无效的分钟数，必须在 0 到 59 之间。"
    else
      (
        crontab -l
        echo "$minute * * * * $newquest"
      ) | crontab - >/dev/null 2>&1
    fi
    ;;
  *)
    sleepMsg "无效的输入!"
    break
    ;;
  esac
}

# 配置定时任务
configure_crontab() {
  while true; do
    clear
    echo
    if ! is_installed "crontab"; then
      color_echo red "未安装 crontab"
    else
      crontab -l 2>/dev/null || color_echo yellow "当前没有定时任务"
    fi
    echo
    echo "1. 添加定时任务    2. 删除定时任务    3. 编辑定时任务"
    echo
    echo "4. 安装crontab     5. 卸载crontab"
    echo
    echo "0. 返回"
    echo
    read -p "请输入你的选择: " sub_choice

    case $sub_choice in
    1)
      add_crontab
      ;;
    2)
      if before_crontab; then
        echo
        read -p "请输入需要删除任务的关键字: " kquest
        crontab -l | grep -v "$kquest" | crontab -
      fi
      ;;
    3)
      if before_crontab; then
        crontab -e
      fi
      ;;
    4)
      if (! is_installed "crontab"); then
        sudo apt install -y cron
        break_end
      else
        sleepMsg "crontab 已安装。" 2 yellow
      fi
      ;;
    5)
      if before_crontab; then
        if confirm "确认要卸载 crontab 吗？"; then
          sudo apt remove --purge -y cron
          break_end
        fi
      fi
      ;;
    0)
      break
      ;;
    *)
      sleepMsg "无效的输入!"
      ;;
    esac
  done
}

# 删除文件匹配的行
remove_lines_with_regex() {
  local regex=$1
  local filename=$2

  # 检查文件是否存在
  if [[ ! -f $filename ]]; then
    color_echo red "文件 $filename 不存在。"
    return 1
  fi

  # 使用 mktemp 创建临时文件
  local temp_file=$(mktemp)

  # 从文件中筛选不包含正则表达式匹配的行，并将结果输出到临时文件
  sudo grep -Ev "$regex" "$filename" >"$temp_file"

  # 将临时文件重命名为原文件名
  sudo mv "$temp_file" "$filename"
}

# 添加虚拟内存
add_swap() {
  # 获取用户输入的新 swap 大小（MB）
  read -p "请输入新的虚拟内存大小 (MB): " new_swap

  # 确保输入有效
  if ! [[ "$new_swap" =~ ^[0-9]+$ ]] || [ "$new_swap" -lt 0 ]; then
    sleepMsg "无效的输入！请输入一个有效的正整数值。"
    return 1
  fi
  # 获取当前系统中所有的 swap 分区
  swap_partitions=$(grep -E '^/dev/' /proc/swaps | awk '{print $1}')

  # 遍历并删除所有的 swap 分区
  for partition in $swap_partitions; do
    swapoff "$partition"
    wipefs -a "$partition" # 清除文件系统标识符
    mkswap -f "$partition"
  done

  # 删除旧的swapfile（如果存在）
  if [ -f "/swapfile" ]; then
    swapoff /swapfile
    rm -f "/swapfile"
  fi

  # 移除/etc/fstab中的swap配置
  remove_lines_with_regex "swap swap defaults" "/etc/fstab"

  if [ "$new_swap" -gt 0 ]; then
    # 创建新的 swap 分区
    dd if=/dev/zero of=/swapfile bs=1M count=$new_swap
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile

    # 添加新swapfile到/etc/fstab
    echo "/swapfile swap swap defaults 0 0" >>/etc/fstab
  fi

  color_echo green "虚拟内存大小已调整为 ${new_swap}MB"
  break_end
}

# 配置虚拟内存
configure_swap() {
  # 获取当前交换空间信息
  swap_used=$(free -m | awk 'NR==3{print $3}')
  swap_total=$(free -m | awk 'NR==3{print $2}')

  if [ "$swap_total" -eq 0 ]; then
    swap_percentage=0
  else
    swap_percentage=$((swap_used * 100 / swap_total))
  fi

  swap_info="${swap_used}MB/${swap_total}MB (${swap_percentage}%)"
  echo
  echo -e "当前虚拟内存: ${CYAN}$swap_info${RESET}"
  if confirm "调整swap大小？"; then
    add_swap
  else
    sleepMsg "操作已取消。" 2 yellow
  fi
}

# 清理系统日志
clean_logs() {
  # 清理系统日志文件
  sudo journalctl --rotate         # 旋转日志文件
  sudo journalctl --vacuum-time=1s # 删除1秒前的日志
  break_end
}

# 禁用 ping
disable_ping() {
  while true; do
    clear
    echo
    # 显示当前 ping 状态
    current_status=$(sysctl net.ipv4.icmp_echo_ignore_all | awk '{print $3}')
    if [ "$current_status" -eq 1 ]; then
      echo -e "当前状态: ${RED}已禁用${RESET} ping"
    else
      echo -e "当前状态: ${GREEN}已启用${RESET} ping"
    fi
    echo
    echo "1. 禁用     2. 启用"
    echo
    echo "0. 返回"
    echo
    read -p "请输入选择: " choice

    case "$choice" in
    1)
      # 禁用 ping
      sudo sysctl -w net.ipv4.icmp_echo_ignore_all=1
      if sudo grep -q "^net.ipv4.icmp_echo_ignore_all" "/etc/sysctl.conf"; then
        sudo sed -i "s/^net.ipv4.icmp_echo_ignore_all=.*/net.ipv4.icmp_echo_ignore_all=1/" "/etc/sysctl.conf"
      else
        echo "net.ipv4.icmp_echo_ignore_all=1" | sudo tee -a "/etc/sysctl.conf" >/dev/null
      fi
      sudo sysctl -p
      ;;
    2)
      # 启用 ping
      sudo sysctl -w net.ipv4.icmp_echo_ignore_all=0
      if sudo grep -q "^net.ipv4.icmp_echo_ignore_all" "/etc/sysctl.conf"; then
        sudo sed -i "s/^net.ipv4.icmp_echo_ignore_all=.*/net.ipv4.icmp_echo_ignore_all=0/" "/etc/sysctl.conf"
      else
        echo "net.ipv4.icmp_echo_ignore_all=0" | sudo tee -a "/etc/sysctl.conf" >/dev/null
      fi
      sudo sysctl -p
      ;;
    0)
      break
      ;;
    *)
      sleepMsg "无效的输入!"
      ;;
    esac
  done
}

# 编辑文件
edit_file() {
  local filepath=$1

  if [ -f "$filepath" ]; then
    if ! is_installed nano; then
      sudo apt install -y nano
    fi
    sudo nano "$filepath"
    return 0
  else
    sleepMsg "$filepath 文件不存在！"
    return 1
  fi
}

# 编辑 /etc/rc.local
edit_rc_local() {
  if [ ! -f "/etc/rc.local" ]; then
    color_echo yellow "初始化 /etc/rc.local..."
    # 确保 /etc/rc.local 存在并设置合适权限
    echo -e '#!/bin/bash\n# 在此处添加您需要开机运行的脚本\n\n\n\n\nexit 0' | sudo tee /etc/rc.local >/dev/null
    sudo chmod +x /etc/rc.local

    # 检查并生成 rc-local.service 服务（仅当服务文件不存在时）
    if [ ! -f "/etc/systemd/system/rc-local.service" ]; then
      # 创建 rc-local.service 文件
      sudo bash -c 'cat > /etc/systemd/system/rc-local.service <<EOF
[Unit]
Description=/etc/rc.local Compatibility
Documentation=man:systemd-rc-local-generator(8)
ConditionFileIsExecutable=/etc/rc.local
After=network.target

[Service]
Type=forking
ExecStart=/etc/rc.local start

[Install]
WantedBy=multi-user.target
EOF'

      # 重新加载 systemd 配置，启用 rc-local 服务
      sudo systemctl daemon-reload
    fi

    sudo systemctl start rc-local.service
    sudo systemctl enable rc-local.service
    break_end
  fi

  # 直接编辑 /etc/rc.local 文件
  edit_file "/etc/rc.local"
}

# 系统工具
system_tool() {
  while true; do
    clear
    echo
    echo "1. 修改时区        2. 修改主机名"
    echo
    echo "3. 定时任务        4. 虚拟内存"
    echo
    echo "5. 清理日志        6. 禁ping"
    echo
    echo "7. 编辑.bashrc     8. 编辑sysctl.conf"
    echo
    echo "9. 开机运行脚本"
    echo
    echo "0. 返回"
    echo
    read -p "请输入你的选择：" hd
    case $hd in
    1)
      change_timezone
      ;;
    2)
      change_hostname
      ;;
    3)
      configure_crontab
      ;;
    4)
      configure_swap
      ;;
    5)
      if confirm "确认要清理日志文件吗？"; then
        clean_logs
      fi
      ;;
    6)
      disable_ping
      ;;
    7)
      if edit_file "$HOME/.bashrc"; then
        source ~/.bashrc
      fi
      ;;
    8)
      if edit_file "/etc/sysctl.conf"; then
        sysctl -p
      fi
      ;;
    9)
      edit_rc_local
      ;;
    0)
      break
      ;;
    *)
      sleepMsg "无效的输入!"
      ;;
    esac
  done
}

# 检查docker
before_docker() {
  if ! is_installed "docker"; then
    sleepMsg "未安装 docker!"
    return 1
  fi
  return 0
}

# 配置docker
configure_docker() {
  while true; do
    clear
    echo
    echo "1. 安装Docker   2. Docker状态"
    echo
    echo "3. 容器管理     4. 镜像管理"
    echo
    echo "5. 网络管理     6. 卷管理"
    echo
    echo "7. 清理无用的docker容器和镜像网络数据卷"
    echo
    echo "8. 卸载Docker"
    echo
    echo "0. 返回"
    echo
    read -p "请输入你的选择: " sub_choice

    case $sub_choice in
    1)
      if is_installed "docker"; then
        sleepMsg "docker 已安装" 2 green
      else
        wget -qO- get.docker.com | bash
        sudo systemctl enable docker
        break_end
      fi
      ;;
    2)
      if ! before_docker; then
        continue
      fi
      clear
      echo "Docker版本"
      sudo docker -v
      sudo docker compose version
      echo
      echo "资源使用"
      sudo docker stats --no-stream --all
      break_end
      ;;
    3)
      if ! before_docker; then
        continue
      fi
      while true; do
        clear
        echo
        sudo docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
        echo
        echo "1. 创建新的容器      6. 更新指定容器"
        echo
        echo "2. 启动指定容器      7. 启动所有容器"
        echo
        echo "3. 停止指定容器      8. 停止所有容器"
        echo
        echo "4. 删除指定容器      9. 删除所有容器"
        echo
        echo "5. 重启指定容器      10. 重启所有容器"
        echo
        echo "11. 进入指定容器     12. 查看容器日志"
        echo
        echo "13. 查看容器网络     14. 更新所有容器"
        echo
        echo "0. 返回"
        echo
        read -p "请输入你的选择: " sub_choice

        case $sub_choice in
        1)
          echo
          read -p "请输入创建命令: " dockername
          $dockername
          break_end
          ;;
        2)
          echo
          read -p "请输入启动的容器名: " dockername
          sudo docker start $dockername
          break_end
          ;;
        3)
          echo
          read -p "请输入停止的容器名: " dockername
          sudo docker stop $dockername
          break_end
          ;;
        4)
          echo
          read -p "请输入删除的容器名: " dockername
          sudo docker rm -f $dockername
          break_end
          ;;
        5)
          echo
          read -p "请输入重启的容器名: " dockername
          sudo docker restart $dockername
          break_end
          ;;
        6)
          echo
          read -p "请输入更新的容器名: " dockername
          sudo docker run --rm -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower -R $dockername
          break_end
          ;;
        7)
          if confirm "确认启动所有容器？"; then
            sudo docker start $(sudo docker ps -a -q)
            break_end
          else
            sleepMsg "操作已取消。" 2 yellow
          fi
          ;;
        8)
          if confirm "确认停止所有容器？"; then
            sudo docker stop $(sudo docker ps -q)
            break_end
          else
            sleepMsg "操作已取消。" 2 yellow
          fi
          ;;
        9)
          if confirm "确认删除所有容器？"; then
            sudo docker rm -f $(sudo docker ps -a -q)
            break_end
          else
            sleepMsg "操作已取消。" 2 yellow
          fi
          ;;
        10)
          if confirm "确认重启所有容器？"; then
            sudo docker restart $(sudo docker ps -q)
            break_end
          else
            sleepMsg "操作已取消。" 2 yellow
          fi
          ;;
        11)
          echo
          read -p "请输入进入的容器名: " dockername
          sudo docker exec -it $dockername /bin/sh
          break_end
          ;;
        12)
          echo
          read -p "请输入查看日志的容器名: " dockername
          sudo docker logs $dockername
          break_end
          ;;
        13)
          echo
          container_ids=$(sudo docker ps -q)
          echo
          printf "%-25s %-25s %-25s\n" "容器名称" "网络名称" "IP地址"

          for container_id in $container_ids; do
            container_info=$(sudo docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ $network }} {{ $config.IPAddress }}{{ end }}' "$container_id")

            container_name=$(echo "$container_info" | awk '{print $1}')
            network_info=$(echo "$container_info" | cut -d' ' -f2-)

            while IFS= read -r line; do
              network_name=$(echo "$line" | awk '{print $1}')
              ip_address=$(echo "$line" | awk '{print $2}')

              printf "%-20s %-20s %-15s\n" "$container_name" "$network_name" "$ip_address"
            done <<<"$network_info"
          done
          break_end
          ;;
        14)
          if confirm "确认更新所有容器？"; then
            sudo docker run --rm -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower -R
            break_end
          else
            sleepMsg "操作已取消。" 2 yellow
          fi
          ;;
        0)
          break
          ;;
        *)
          sleepMsg "无效的输入!"
          ;;
        esac
      done
      ;;
    4)
      if ! before_docker; then
        continue
      fi
      while true; do
        clear
        echo
        sudo docker image ls
        echo
        echo
        echo "1. 获取指定镜像    3. 删除指定镜像"
        echo
        echo "2. 更新指定镜像    4. 删除所有镜像"
        echo
        echo "0. 返回"
        echo
        read -p "请输入你的选择: " sub_choice

        case $sub_choice in
        1)
          echo
          read -p "请输入获取的镜像名: " dockername
          sudo docker pull $dockername
          break_end
          ;;
        2)
          echo
          read -p "请输入更新的镜像名: " dockername
          sudo docker pull $dockername
          break_end
          ;;
        3)
          echo
          read -p "请输入删除的镜像名: " dockername
          sudo docker rmi -f $dockername
          break_end
          ;;
        4)
          if confirm "确认删除所有镜像？"; then
            sudo docker rmi -f $(sudo docker images -q)
            break_end
          else
            sleepMsg "操作已取消。" 2 yellow
          fi
          ;;
        0)
          break
          ;;
        *)
          sleepMsg "无效的输入!"
          ;;
        esac
      done
      ;;
    5)
      if ! before_docker; then
        continue
      fi
      while true; do
        clear
        echo
        sudo docker network ls
        echo
        container_ids=$(sudo docker ps -q)
        printf "%-25s %-25s %-25s\n" "容器名称" "网络名称" "IP地址"

        for container_id in $container_ids; do
          container_info=$(sudo docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ $network }} {{ $config.IPAddress }}{{ end }}' "$container_id")

          container_name=$(echo "$container_info" | awk '{print $1}')
          network_info=$(echo "$container_info" | cut -d' ' -f2-)

          while IFS= read -r line; do
            network_name=$(echo "$line" | awk '{print $1}')
            ip_address=$(echo "$line" | awk '{print $2}')

            printf "%-20s %-20s %-15s\n" "$container_name" "$network_name" "$ip_address"
          done <<<"$network_info"
        done

        echo
        echo "1. 创建网络    2. 加入网络"
        echo
        echo "3. 退出网络    4. 删除网络"
        echo
        echo "0. 返回"
        echo
        read -p "请输入你的选择: " sub_choice

        case $sub_choice in
        1)
          echo
          read -p "设置新网络名: " dockernetwork
          sudo docker network create $dockernetwork
          break_end
          ;;
        2)
          echo
          read -p "加入网络名: " dockernetwork
          echo
          read -p "哪些容器加入该网络: " dockername
          sudo docker network connect $dockernetwork $dockername
          break_end
          echo
          ;;
        3)
          echo
          read -p "退出网络名: " dockernetwork
          echo
          read -p "哪些容器退出该网络: " dockername
          sudo docker network disconnect $dockernetwork $dockername
          break_end
          echo
          ;;
        4)
          echo
          read -p "请输入要删除的网络名: " dockernetwork
          suso docker network rm $dockernetwork
          break_end
          ;;
        0)
          break
          ;;
        *)
          sleepMsg "无效的输入!"
          ;;
        esac
      done
      ;;
    6)
      if ! before_docker; then
        continue
      fi
      while true; do
        clear
        echo
        sudo docker volume ls
        echo
        echo "1. 创建新卷    2. 删除卷"
        echo
        echo "0. 返回"
        echo
        read -p "请输入你的选择: " sub_choice

        case $sub_choice in
        1)
          echo
          read -p "设置新卷名: " dockerjuan
          sudo docker volume create $dockerjuan
          break_end
          ;;
        2)
          echo
          read -p "输入删除卷名: " dockerjuan
          sudo docker volume rm $dockerjuan
          break_end
          ;;
        0)
          break
          ;;
        *)
          sleepMsg "无效的输入!"
          ;;
        esac
      done
      ;;
    7)
      if ! before_docker; then
        continue
      fi
      if confirm "确认清理无用的镜像容器网络？"; then
        sudo docker system prune -af --volumes
        break_end
      else
        sleepMsg "操作已取消。" 2 yellow
      fi
      ;;
    8)
      if ! before_docker; then
        continue
      fi
      if confirm "确认卸载docker环境？"; then
        sudo apt-get purge docker-ce docker-ce-cli containerd.io
        sudo rm -rf /var/lib/docker
        sudo rm -rf /var/lib/containerd
        break_end
      else
        sleepMsg "操作已取消。" 2 yellow
      fi
      ;;
    0)
      break
      ;;
    *)
      sleepMsg "无效的输入!"
      ;;
    esac
  done
}

# 重启ssh
restart_ssh() {
  sudo systemctl restart ssh.service
  if [ $? -eq 0 ]; then
    sleepMsg "SSH 服务重启成功。" 2 green
    return 0
  else
    sleepMsg "SSH 服务重启失败，请检查。"
    return 1
  fi
}

# 设置ssh配置
set_ssh_config() {
  local SSHD_CONFIG="/etc/ssh/sshd_config"
  local key=$1
  local value=$2

  if [[ -z "$key" || -z "$value" ]]; then
    sleepMsg "缺少参数： key 或 value"
    return 1
  fi

  if [ ! -f "$SSHD_CONFIG" ]; then
    sleepMsg "配置文件 $SSHD_CONFIG 不存在"
    return 1
  fi

  # 备份配置文件
  sudo cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"

  # 启用指定配置项或更新其值
  if grep -q "^\s*#*\s*$key\s" "$SSHD_CONFIG"; then
    sudo sed -i "s/^\s*#*\s*$key\s.*/$key $value/" "$SSHD_CONFIG"
  else
    echo "$key $value" | sudo tee -a "$SSHD_CONFIG" >/dev/null
  fi

  # 重启SSH服务
  restart_ssh
}

# 检查sshd是否已安装
before_ssh() {
  if is_installed "sshd"; then
    return 0
  else
    sleepMsg "未安装 ssh服务"
    return 1
  fi
}

# 修改ssh端口
change_ssh_port() {
  if ! before_ssh; then
    return 1
  fi
  # 获取当前SSH端口
  current_port=$(grep ^Port /etc/ssh/sshd_config | awk '{print $2}')
  if [ -z "$current_port" ]; then
    current_port=22 # 如果未设置端口，默认为22
  fi
  echo -e "当前SSH端口：${CYAN}$current_port${RESET}"

  # 提示用户输入新的SSH端口
  echo
  read -p "请输入新的SSH端口号: " new_port

  # 确认用户输入的端口号
  if ! is_valid_port "$new_port"; then
    return 1
  fi

  # 提示用户确认更改
  if ! confirm "确认要将SSH端口更改为：${new_port}"; then
    sleepMsg "操作已取消。" 2 yellow
    return 1
  fi

  color_echo green "SSH 端口已修改为: $new_port"

  # 修改sshd_config文件中的端口设置
  set_ssh_config "Port" $new_port
}

# 检查ssh配置项状态
check_ssh_config_status() {
  local SSHD_CONFIG="/etc/ssh/sshd_config"
  local key=$1

  if [ -z "$key" ]; then
    echo "unknown" # 输出 unknown
    return
  fi

  if [ ! -f "$SSHD_CONFIG" ]; then
    echo "unknown" # 输出 unknown
    return
  fi

  # 获取包含该配置项的完整行，保留注释信息
  local line
  line=$(grep -E "^\s*#?\s*${key}\s+" "$SSHD_CONFIG")

  # 如果没有匹配到该配置项
  if [ -z "$line" ]; then
    echo "unknown" # 输出 unknown
    return
  fi

  # 判断该行是否被注释（以#开头），如果是，返回unknown
  if [[ "$line" =~ ^\s*# ]]; then
    echo "unknown" # 输出 unknown
    return
  fi

  # 提取配置项的值
  local status
  status=$(echo "$line" | awk '{print $2}')

  # 根据状态值输出相应结果
  case "$status" in
  yes)
    echo "yes" # 输出 yes
    ;;
  no)
    echo "no" # 输出 no
    ;;
  *)
    echo "unknown" # 输出 unknown
    ;;
  esac
}

# 处理ssh配置项状态
handle_ssh_config_auth() {
  key="$1"
  text="$2"
  while true; do
    clear
    echo
    local status
    status=$(check_ssh_config_status $key)
    # 根据状态输出对应的结果
    case $status in
    yes) # yes
      echo -e "$text：${GREEN}已启用${RESET}"
      ;;
    no) # no
      echo -e "$text：${RED}已禁用${RESET}"
      ;;
    unknown) # unknown
      echo -e "$text：${YELLOW}未知状态${RESET}"
      ;;
    esac
    echo
    echo "1. 开启    2. 关闭"
    echo
    echo "0. 返回"
    echo
    read -p "请输入你的选择：" hd
    case $hd in
    1)
      set_ssh_config $key "yes"
      ;;
    2)
      set_ssh_config $key "no"
      ;;
    0)
      break
      ;;
    *)
      sleepMsg "无效的输入!"
      ;;
    esac
  done
}

# 配置SSH公钥
configure_ssh_key() {
  if ! before_ssh; then
    return 1
  fi
  local passphrase=""
  local key_path="$HOME/.ssh/id_rsa_custom"
  echo
  read -p "请输入公钥标题: " title
  if [ -z "$title" ]; then
    sleepMsg "标题不能为空！"
    return 1
  fi
  # 确认是否设置密钥密码短语
  if confirm "是否设置私钥密码短语？"; then
    echo
    read -p "请输入私钥密码短语: " passphrase
    echo
  fi

  # 确保 .ssh 目录存在
  if ! mkdir -p $HOME/.ssh; then
    sleepMsg "无法创建 $HOME/.ssh 目录"
    return 1
  fi

  # 自动覆盖现有私钥
  if [ -f "$key_path" ]; then
    rm -f "$key_path" "$key_path.pub"
  fi

  # 生成 SSH 私钥
  if ! ssh-keygen -t rsa -b 4096 -C "$title" -f "$key_path" -N "$passphrase"; then
    sleepMsg "SSH 私钥生成失败"
    return 1
  fi

  # 将公钥添加到 authorized_keys
  if ! cat "$key_path.pub" >>$HOME/.ssh/authorized_keys; then
    sleepMsg "无法写入公钥到 authorized_keys"
    return 1
  fi

  # 设置正确的文件权限
  chmod 700 $HOME/.ssh || echo "无法设置 $HOME/.ssh 的权限"
  chmod 600 "$key_path" || echo "无法设置私钥文件的权限"
  chmod 644 "$key_path.pub" || echo "无法设置公钥文件的权限"
  chmod 600 $HOME/.ssh/authorized_keys || echo "无法设置 authorized_keys 的权限"

  # 提示用户保存私钥
  echo
  echo "SSH 私钥已生成，请务必保存以下私钥内容。不要与他人共享此内容："
  echo
  cat "$key_path"
  echo

  break_end
}

# 配置ssh
configure_ssh() {
  while true; do
    clear
    echo
    echo "1. 安装SSH           2. 卸载SSH"
    echo
    echo "3. 修改ssh端口       4. ssh公钥认证"
    echo
    echo "5. root登录          6. 密码登录"
    echo
    echo "7. 生成密钥          8. 编辑authorized_keys"
    echo
    echo "9. 编辑sshd_config   10. 重启ssh"
    echo
    echo "0. 返回"
    echo
    read -p "请输入你的选择：" hd
    case $hd in
    1)
      if is_installed "sshd"; then
        sleepMsg "ssh 服务已安装" 2 green
      else
        sudo apt install -y openssh-server
        sudo systemctl start ssh
        sudo systemctl enable ssh
        break_end
      fi
      ;;
    2)
      if before_ssh; then
        if confirm "确认卸载ssh环境？"; then
          sudo systemctl disable ssh
          sudo systemctl stop ssh
          sudo apt-get purge openssh-server
          break_end
        else
          sleepMsg "操作已取消。" 2 yellow
        fi
      fi
      ;;
    3)
      change_ssh_port
      ;;
    4)
      if before_ssh; then
        handle_ssh_config_auth "PubkeyAuthentication" "SSH公钥认证状态"
      fi
      ;;
    5)
      if before_ssh; then
        handle_ssh_config_auth "PermitRootLogin" "root账户SSH登录状态"
      fi
      ;;
    6)
      if before_ssh; then
        handle_ssh_config_auth "PasswordAuthentication" "密码登录状态"
      fi
      ;;
    7)
      if before_ssh; then
        if confirm "清除之前的公钥？"; then
          >$HOME/.ssh/authorized_keys
        fi
        configure_ssh_key
      fi
      ;;
    8)
      edit_file $HOME/.ssh/authorized_keys
      ;;
    9)
      if edit_file "/etc/ssh/sshd_config"; then
        restart_ssh
      fi
      ;;
    10)
      if before_ssh; then
        restart_ssh
      fi
      ;;
    0)
      break
      ;;
    *)
      sleepMsg "无效的输入!"
      ;;
    esac
  done
}

# 设置快捷键
set_alias() {
  # 提示用户输入快捷按键
  echo
  read -p "请输入你的快捷键: " key

  # 检查用户输入是否为空
  if [ -z "$key" ]; then
    color_echo red "快捷键不能为空。"
    return 1
  fi

  # 定义别名命令
  ALIAS_CMD="alias $key='source $SCRIPT_FILE'"
  ALIAS_PATTERN="alias .*='source $SCRIPT_FILE'"

  # 检查 .bashrc 文件中是否已经存在相同的别名
  if grep -q "$ALIAS_PATTERN" "$HOME/.bashrc"; then
    # 如果存在，使用新的别名替换旧的别名
    sed -i "s|$ALIAS_PATTERN|$ALIAS_CMD|" "$HOME/.bashrc"
  else
    # 如果不存在，追加新的别名
    echo "$ALIAS_CMD" >>"$HOME/.bashrc"
  fi

  # 重新加载 .bashrc 文件
  source "$HOME/.bashrc"

  # 确认操作成功
  color_echo green "快捷键已添加成功。你可以使用 '$key' 来运行命令。"
  break_end
}

# 更新脚本
update_script() {
  if ! is_installed "curl"; then
    sudo apt install -y curl
  fi

  curl -L "$SCRIPT_LINK" -o "$SCRIPT_FILE"

  clear
  source "$SCRIPT_FILE"
}

# 查找进程
find_process() {
  clear
  echo
  read -p "请输入要查找的进程名称: " process_name
  # 显示进程信息，排除 grep 命令
  process_info=$(ps aux | grep "$process_name" | grep -v grep)
  if [ -z "$process_info" ]; then
    color_echo red "未找到与 $process_name 相关的进程"
  else
    echo
    echo "$process_info"
  fi
  echo
  echo "1. 结束进程      2. 重启进程"
  echo
  echo "0. 返回"
  echo
  while true; do
    read -p "请输入你的选择: " choice
    case $choice in
    1)
      read -p "请输入要结束的进程ID: " process_id
      if [[ -z "$process_id" || ! "$process_id" =~ ^[0-9]+$ ]]; then
        sleepMsg "无效的进程ID!"
        break
      fi
      kill -9 $process_id
      if [ $? -eq 0 ]; then
        sleepMsg "进程 $process_id 已成功结束" 2 green
      else
        color_echo red "进程 $process_id 结束失败，请检查。"
        break_end
      fi
      break
      ;;
    2)
      read -p "请输入要重启的进程ID: " process_id
      if [[ -z "$process_id" || ! "$process_id" =~ ^[0-9]+$ ]]; then
        sleepMsg "无效的进程ID!"
        break
      fi
      kill -HUP $process_id
      if [ $? -eq 0 ]; then
        sleepMsg "进程 $process_id 已成功重启" 2 green
      else
        color_echo red "进程 $process_id 重启失败，请检查。"
        break_end
      fi
      break
      ;;
    0)
      break
      ;;
    *)
      sleepMsg "无效的输入!"
      break
      ;;
    esac
  done
}

# 查找系统中的服务
find_service() {
  clear
  echo
  read -p "请输入要查找的服务名称: " service_name
  # 列出所有服务并过滤包含服务名称的服务
  service_info=$(systemctl list-units --type=service --all | grep "$service_name" | grep -v grep)
  if [ -z "$service_info" ]; then
    color_echo red "未找到与 $service_name 相关的服务"
  else
    echo
    echo "$service_info"
  fi
  echo
  echo "1. 启动服务      2. 停止服务      3. 重启服务"
  echo
  echo "4. 查看状态      5. 重新加载服务配置"
  echo
  echo "6. 开机自启      7. 关闭自启"
  echo
  echo "8. 重新加载服务配置"
  echo
  echo "0. 返回"
  echo
  while true; do
    read -p "请输入你的选择: " choice
    case $choice in
    1)
      # 启动服务
      read -p "请输入要启动的服务名称: " service_name
      systemctl start "$service_name"
      break_end
      break
      ;;
    2)
      # 停止服务
      read -p "请输入要停止的服务名称: " service_name
      systemctl stop "$service_name"
      break_end
      break
      ;;
    3)
      # 重启服务
      read -p "请输入要重启的服务名称: " service_name
      systemctl restart "$service_name"
      break_end
      break
      ;;
    4)
      # 查看服务状态
      read -p "请输入要查看状态的服务名称: " service_name
      echo -e "开机启动状态：${GREEN}$(systemctl is-enabled "$service_name")${RESET}"
      systemctl status "$service_name"
      break_end
      break
      ;;
    5)
      # 重新加载服务配置
      read -p "请输入要重新加载配置的服务名称: " service_name
      systemctl reload "$service_name"
      break_end
      break
      ;;
    6)
      # 开机自启
      read -p "请输入要开启自启的服务名称: " service_name
      systemctl enable "$service_name"
      break_end
      break
      ;;
    7)
      # 关闭自启
      read -p "请输入要关闭自启的服务名称: " service_name
      systemctl disable "$service_name"
      break_end
      break
      ;;
    8)
      # 重新加载服务配置
      sudo systemctl daemon-reload
      break_end
      break
      ;;
    0)
      break
      ;;
    *)
      sleepMsg "无效的输入!"
      break
      ;;
    esac
  done
}

# 处理查找
handle_find() {
  while true; do
    clear
    echo
    echo "1. 查找进程    2. 查找服务"
    echo
    echo "0. 返回"
    echo
    read -p "请输入你的选择: " choice
    case $choice in
    1)
      find_process
      ;;
    2)
      find_service
      ;;
    0)
      break
      ;;
    *)
      sleepMsg "无效的输入!"
      ;;
    esac
  done
}

while true; do
  clear
  echo
  echo "1. 系统信息      2. 系统更新"
  echo
  echo "3. 防火墙        4. nvm"
  echo
  echo "5. 用户管理      6. 系统工具"
  echo
  echo "7. Docker        8. SSH"
  echo
  echo "9. 查找服务进程"
  echo
  echo "00. 快捷键       000. 更新脚本"
  echo
  echo "0. 退出"
  echo
  read -p "请输入你的选择: " choice
  case $choice in
  1)
    system_info
    ;;
  2)
    clear
    sudo apt update -y && sudo apt upgrade -y
    break_end
    ;;
  3)
    configure_ufw
    ;;
  4)
    configure_nvm
    ;;
  5)
    configure_user
    ;;
  6)
    system_tool
    ;;
  7)
    configure_docker
    ;;
  8)
    configure_ssh
    ;;
  9)
    handle_find
    ;;
  00)
    set_alias
    ;;
  000)
    update_script
    break
    ;;
  0)
    clear
    break
    ;;
  *)
    sleepMsg "无效的输入!"
    ;;
  esac
done
