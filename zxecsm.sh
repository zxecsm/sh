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
  local response
  echo
  read -e -p "${1:-确认操作?} [y/N]: " response
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
  # 临时将 /usr/sbin 加入到 PATH
  export PATH=$PATH:/usr/sbin

  # 返回命令是否存在，0 表示存在，1 表示不存在
  command -v "$1" &>/dev/null
}

# 等待
waiting() {
  echo
  color_echo green "按任意键继续"
  read -n 1 -s
  echo
  clear
}

# 判断字符串是否为空
is_empty_string() {
  if [ -z "$1" ]; then
    return 0
  else
    return 1
  fi
}

# 文件是否存在
is_file_exist() {
  if [ -f "$1" ]; then
    return 0
  else
    return 1
  fi
}

# 是否数字
is_number() {
  if [[ $1 =~ ^[0-9]+$ ]]; then
    return 0
  else
    return 1
  fi
}

# 数值是否在范围内
is_in_range() {
  local number="$1"
  local min="$2"
  local max="$3"

  if ((number >= min && number <= max)); then
    return 0
  else
    return 1
  fi
}

# 命令是否执行成功
is_success() {
  if [ $? -eq 0 ]; then
    return 0
  else
    return 1
  fi
}

# 延迟消息
sleepMsg() {
  local msg="$1"
  local delay="${2:-2}" # 如果没有指定延迟时间，则默认为 2 秒
  local color="${3:-red}"

  # 如果消息为空，则使用默认消息
  if is_empty_string "$msg"; then
    msg="没有提供消息。"
  fi

  echo
  color_echo "$color" "$msg"
  echo
  sleep "$delay"
}

# 获取本地 IPv4 和 IPv6 地址
get_ip_addresses() {
  local address=$(hostname -I)
  local ipv4_address=$(echo "$address" | awk '{print $1}')
  local ipv6_address=$(echo "$address" | awk '{for(i=1;i<=NF;i++) if ($i ~ /:/) {print $i; exit}}')

  ipv6_address="${ipv6_address:-未配置IPv6}"
  ipv4_address="${ipv4_address:-未配置IPv4}"

  echo "$ipv4_address $ipv6_address"
}

# 格式化字节
format_bytes() {
  local bytes=$1
  local suffixes=("B" "KB" "MB" "GB" "TB")
  local suffix_index=0

  # 保留两位小数
  while [ $(echo "$bytes >= 1024" | awk '{print ($1 >= 1024)}') -eq 1 ]; do
    bytes=$(echo "$bytes 1024" | awk '{printf "%.2f", $1 / $2}')
    suffix_index=$((suffix_index + 1))
  done

  # 格式化输出，确保小数点后有两位
  printf "%.2f${suffixes[$suffix_index]}\n" "$bytes"
}

# 获取网络状态
get_network_status() {
  local rx_total tx_total
  # 获取接收和发送的字节数
  read rx_total tx_total < <(awk 'NR > 2 { rx_total += $2; tx_total += $10 }
    END { printf("%.0f %.0f", rx_total, tx_total) }' /proc/net/dev)

  rx_total=$(format_bytes $rx_total)
  tx_total=$(format_bytes $tx_total)

  echo "$rx_total $tx_total"
}

# 获取当前时区
current_timezone() {
  # 检查 timedatectl 命令是否存在
  if is_installed "timedatectl"; then
    # 使用 timedatectl 获取时区信息
    local timezone_output=$(timedatectl | grep "Time zone" | awk '{print $3}')

    # 提取时区名称
    if ! is_empty_string "$timezone_output"; then
      echo "$timezone_output"
    else
      echo "无法从 timedatectl 获取时区信息"
    fi
  else
    echo "系统未安装 timedatectl 命令，请尝试使用其他方法获取时区"
  fi
}

# 安装 sysctl
install_sysctl() {
  if ! is_installed "sysctl"; then
    sudo apt install procps -y
  fi
}

# 系统信息
system_info() {
  clear
  # 获取IP
  local addresses=$(get_ip_addresses)
  local ipv4_address=$(echo "$addresses" | awk '{print $1}')
  local ipv6_address=$(echo "$addresses" | awk '{print $2}')

  # 版本
  local kernel_version=$(uname -r)

  # CPU架构
  local cpu_arch=$(uname -m)

  # CPU型号
  local cpu_info
  if [ $cpu_arch == "x86_64" ]; then
    cpu_info=$(cat /proc/cpuinfo | grep 'model name' | uniq | sed -e 's/model name[[:space:]]*: //')
  else
    cpu_info=$(lscpu | grep 'BIOS Model name' | awk -F': ' '{print $2}' | sed 's/^[ \t]*//')
  fi

  # CPU 核心数
  local cpu_cores=$(nproc)

  # 物理内存
  local mem_info=$(free -b | awk 'NR==2{printf "%.2f/%.2f MB (%.2f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}')

  # 硬盘使用
  local disk_info=$(df -h | awk '$NF=="/"{printf "%s/%s (%s)", $3, $2, $5}')

  # 主机名
  local hostname=$(hostname)

  # bbr信息
  install_sysctl
  local congestion_algorithm=$(sudo sysctl -n net.ipv4.tcp_congestion_control)
  local queue_algorithm=$(sudo sysctl -n net.core.default_qdisc)

  # 尝试使用 lsb_release 获取系统信息
  local os_info=$(lsb_release -ds 2>/dev/null)
  if is_empty_string "$os_info"; then
    os_info="Unknown"
  fi

  # 网络流量
  local network=($(get_network_status))
  local network_info="总接收：${network[0]}      总发送：${network[1]}"

  # 系统时间
  local current_time=$(date +"%Y-%m-%d %H:%M:%S")

  # 虚拟内存
  local swap_used=0
  local swap_total=0
  local swap_percentage=0

  if free -m | awk 'NR==3{exit $2==0}'; then
    swap_used=$(free -m | awk 'NR==3{print $3}')
    swap_total=$(free -m | awk 'NR==3{print $2}')
    swap_percentage=$((swap_used * 100 / swap_total))
  fi

  local swap_info="${swap_used}MB/${swap_total}MB (${swap_percentage}%)"

  # 运行时间
  local runtime=$(cat /proc/uptime | awk -F. '{run_days=int($1 / 86400);run_hours=int(($1 % 86400) / 3600);run_minutes=int(($1 % 3600) / 60); if (run_days > 0) printf("%d天 ", run_days); if (run_hours > 0) printf("%d时 ", run_hours); printf("%d分\n", run_minutes)}')

  # 时区
  local timezone=$(current_timezone)

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
  waiting
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
  if ! is_number "$port"; then
    sleepMsg "无效的端口：必须是数字"
    return 1
  fi

  # 检查端口号是否在1到65535之间
  if is_in_range "$port" 1 65535; then
    return 0 # 有效端口
  else
    sleepMsg "无效的端口：端口号必须在1到65535之间"
    return 1
  fi
}

install_ss() {
  if ! is_installed "ss"; then
    sudo apt-get install -y iproute2
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

  # 获取UFW中开放的端口列表和状态
  local ufw_status=$(sudo ufw status)

  install_ss

  # 获取当前系统所有的监听端口和对应的进程
  local listening_ports=$(sudo ss -lpn)

  # 遍历UFW状态并处理每一行
  echo "$ufw_status" | while IFS= read -r line; do
    # 只处理包含"ALLOW"的行
    if echo "$line" | grep -q "ALLOW"; then
      # 提取端口和协议
      local port_protocol=$(echo "$line" | awk '{print $1}')
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
    else
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

  # 获取UFW中开放的端口列表和状态
  local ufw_status=$(sudo ufw status)

  install_ss

  # 获取当前系统所有的监听端口和对应的进程
  local listening_ports=$(sudo ss -lpn)

  # 遍历UFW状态并处理每一行
  echo "$ufw_status" | while IFS= read -r line; do
    # 判断是否包含 'ALLOW' 并且不包含端口范围格式
    if echo "$line" | grep -q "ALLOW" && ! echo "$line" | grep -Pq '\d{1,5}:\d{1,5}'; then
      # 提取端口和协议
      local port_protocol=$(echo "$line" | awk '{print $1}')
      local port=$(echo "$port_protocol" | grep -oP '\d{1,5}')

      # 检查是否有进程在监听此端口
      if ! echo "$listening_ports" | grep -q ":$port "; then
        sudo ufw delete allow "$port_protocol"
      fi
    fi
  done

  waiting
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
    local hd
    local port
    read -e -p "请输入你的选择：" hd
    case $hd in
    1)
      if before_ufw; then
        echo
        read -e -p "请输入端口：" port
        if is_empty_string "$port"; then
          sleepMsg "无效的端口。"
          continue
        fi

        sudo ufw allow $port
        if ! is_success; then
          waiting
        fi
      fi
      ;;
    2)
      if before_ufw; then
        echo
        read -e -p "请输入端口：" port
        if is_empty_string "$port"; then
          sleepMsg "无效的端口。"
          continue
        fi

        sudo ufw delete allow $port
        if ! is_success; then
          waiting
        fi
      fi
      ;;
    3)
      delete_unused_ports
      ;;
    4)
      if is_installed "ufw"; then
        sleepMsg "ufw 已安装" 2 green
      else
        sudo apt install -y ufw
        waiting
      fi
      ;;
    5)
      if before_ufw; then
        if confirm "确认卸载？"; then
          sudo apt remove --purge -y ufw
          waiting
        else
          sleepMsg "操作已取消。" 2 yellow
        fi
      fi
      ;;
    6)
      if before_ufw; then
        sudo ufw enable
        waiting
      fi
      ;;
    7)
      if before_ufw; then
        if confirm "确认关闭？"; then
          sudo ufw disable
          waiting
        else
          sleepMsg "操作已取消。" 2 yellow
        fi
      fi
      ;;
    8)
      if before_ufw; then
        if confirm "确认重置？"; then
          sudo ufw reset
          waiting
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
    waiting
  fi
}

# 指定 nvm 的完整路径
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# 检查 nvm 是否已经安装
before_nvm() {
  if ! is_installed "nvm"; then
    sleepMsg "未安装 nvm"
    return 1
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
    local nvm_choice
    local node_choice
    read -e -p "请输入你的选择: " nvm_choice
    case $nvm_choice in
    1)
      install_nvm
      ;;
    2)
      if before_nvm; then
        echo
        read -e -p "请输入node版本: " node_choice
        if validate_node_version "$node_choice"; then
          nvm install $node_choice
          waiting
        fi
      fi
      ;;
    3)
      if before_nvm; then
        clear
        nvm ls
        waiting
      fi
      ;;
    4)
      if before_nvm; then
        clear
        nvm ls-remote
        waiting
      fi
      ;;
    5)
      if before_nvm; then
        echo
        read -e -p "请输入node版本: " node_choice
        if validate_node_version "$node_choice"; then
          nvm use $node_choice
          waiting
        fi
      fi
      ;;
    6)
      if before_nvm; then
        echo
        read -e -p "请输入node版本: " node_choice
        if validate_node_version "$node_choice"; then
          if confirm "确认卸载 $node_choice 版本？"; then
            nvm uninstall $node_choice
            waiting
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
    if is_success; then
      sleepMsg "用户 $username 已成功添加到 sudo 组" 2 green
    else
      waiting
    fi
  fi
}

# 取消 sudo 权限
del_sudo() {
  username="$1"
  if before_user "$username"; then
    sudo gpasswd -d "$username" sudo
    if is_success; then
      sleepMsg "用户 $username 已成功从 sudo 组中移除" 2 green
    else
      waiting
    fi
  fi
}

# 修改用户密码
change_password() {
  username="$1"
  if before_user "$username"; then
    sudo passwd "$username" # 修改用户密码
    waiting
  fi
}

# 输出用户列表
output_user_list() {
  printf "%-30s %-34s %-20s %-10s\n" "用户名" "用户权限" "用户组" "sudo权限"
  while IFS=: read -r username _ uid _ _ homedir shell; do
    # 获取用户的组信息
    groups=$(groups "$username" | cut -d ' ' -f 2-)

    # 判断用户是否属于 sudo 组
    if echo "$groups" | grep -qw "sudo"; then
      sudo_status="Yes"
    else
      # 检查 sudo 权限
      if sudo -lU "$username" 2>/dev/null | grep -q "(ALL)"; then
        sudo_status="Yes"
      else
        sudo_status="No"
      fi
    fi

    # 输出用户信息，格式为 username(uid)
    printf "%-26s %-30s %-20s %-10s\n" "$username($uid)" "$homedir" "$groups" "$sudo_status"
  done </etc/passwd
}

# 配置用户
configure_user() {
  while true; do
    clear
    echo

    output_user_list

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
    local sub_choice
    local username
    read -e -p "请输入你的选择: " sub_choice

    case $sub_choice in
    1)
      echo
      read -e -p "请输入用户名: " username
      if ! validate_username "$username"; then
        continue
      fi

      if is_user "$username"; then
        sleepMsg "用户 $username 已经存在"
      else
        # 创建新用户并设置密码
        sudo useradd -m -s /bin/bash "$username" && sudo passwd "$username"
        waiting
      fi
      ;;
    2)
      echo
      read -e -p "请输入用户名: " username
      if ! validate_username "$username"; then
        continue
      fi

      if is_user "$username"; then
        sleepMsg "用户 $username 已经存在"
      else
        # 创建新用户并设置密码
        sudo useradd -m -s /bin/bash "$username" && sudo passwd "$username"
        add_sudo "$username"
      fi
      ;;
    3)
      echo
      read -e -p "请输入用户名: " username
      if ! validate_username "$username"; then
        continue
      fi

      if confirm "确认赋予用户 $username sudo 权限？"; then
        add_sudo $username
      else
        sleepMsg "操作已取消。" 2 yellow
      fi
      ;;
    4)
      echo
      read -e -p "请输入用户名: " username
      if ! validate_username "$username"; then
        continue
      fi

      if confirm "确认移除用户 $username sudo 权限？"; then
        del_sudo $username
      else
        sleepMsg "操作已取消。" 2 yellow
      fi
      ;;
    5)
      echo
      read -e -p "请输入用户名: " username
      if ! validate_username "$username"; then
        continue
      fi

      change_password $username
      ;;
    6)
      echo
      read -e -p "请输入用户名: " username
      if ! validate_username "$username"; then
        continue
      fi

      if confirm "确认删除用户：$username？"; then
        # 删除用户及其主目录
        sudo pkill -u $username # 查找并终止与该用户关联的所有进程
        sudo userdel -r $username
        waiting
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
    local timezone=$(current_timezone)

    # 获取当前系统时间
    local current_time=$(date +"%Y-%m-%d %H:%M:%S")

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
    local sub_choice
    read -e -p "请输入你的选择: " sub_choice

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
  local current_hostname=$(hostname)

  echo -e "当前主机名: ${CYAN}$current_hostname${RESET}"

  # 获取新的主机名
  echo
  local new_hostname
  read -e -p "请输入新的主机名: " new_hostname

  # 主机名验证：只允许字母、数字、短横线的组合，且不以数字开头
  if [[ ! "$new_hostname" =~ ^[a-zA-Z][a-zA-Z0-9-]*$ || ${#new_hostname} -gt 63 || ${#new_hostname} -lt 1 ]]; then
    sleepMsg "无效的主机名。主机名必须以字母开头，且只能包含字母、数字和短横线，长度不超过63个字符。"
    return 1
  fi

  if ! is_empty_string "$new_hostname"; then
    if confirm "确认更改主机名为 $new_hostname 吗？"; then
      # 更新主机名
      sudo hostnamectl set-hostname "$new_hostname"
      sudo sed -i "s/$current_hostname/$new_hostname/g" /etc/hostname
      sudo systemctl restart systemd-hostnamed

      # 修改 /etc/hosts 中的主机名（只替换包含当前主机名的行）
      if sudo grep -q "$current_hostname" /etc/hosts; then
        sudo sed -i "s/$current_hostname/$new_hostname/g" /etc/hosts
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
  local newquest
  read -e -p "请输入新任务的执行命令: " newquest
  echo
  echo "1. 每月任务    2. 每周任务"
  echo
  echo "3. 每天任务    4. 每小时任务"
  echo
  local dingshi
  read -e -p "请输入你的选择: " dingshi

  case $dingshi in
  1)
    echo
    local day
    read -e -p "选择每月的几号执行任务？ (1-31): " day
    if ! is_number "$day" || ! is_in_range "$day" 1 31; then
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
    local weekday
    read -e -p "选择周几执行任务？ (0-6，0代表星期日): " weekday
    if ! is_number "$weekday" || ! is_in_range "$weekday" 0 6; then
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
    local hour
    read -e -p "选择每天几点执行任务？（小时，0-23）: " hour
    if ! is_number "$hour" || ! is_in_range "$hour" 0 23; then
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
    local minute
    read -e -p "输入每小时的第几分钟执行任务？（分钟，0-59）: " minute
    if ! is_number "$minute" || ! is_in_range "$minute" 0 59; then
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
    local sub_choice
    read -e -p "请输入你的选择: " sub_choice

    case $sub_choice in
    1)
      add_crontab
      ;;
    2)
      if before_crontab; then
        echo
        local kquest
        read -e -p "请输入需要删除任务的关键字: " kquest
        if is_empty_string "$kquest"; then
          sleepMsg "无效的关键字。"
          continue
        fi

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
        waiting
      else
        sleepMsg "crontab 已安装。" 2 yellow
      fi
      ;;
    5)
      if before_crontab; then
        if confirm "确认要卸载 crontab 吗？"; then
          sudo apt remove --purge -y cron
          waiting
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
  if ! is_file_exist "$filename"; then
    color_echo red "文件 $filename 不存在。"
    return 1
  fi

  # 使用 mktemp 创建临时文件
  local temp_file=$(mktemp)

  # 从文件中筛选不包含正则表达式匹配的行，并将结果输出到临时文件
  sudo grep -Ev "$regex" "$filename" >"$temp_file"

  # 将临时文件替换原文件
  sudo mv "$temp_file" "$filename"

  sudo rm -f "$temp_file"
}

# 添加虚拟内存
add_swap() {
  # 获取用户输入的新 swap 大小（MB）
  local new_swap
  read -e -p "请输入新的虚拟内存大小 (MB): " new_swap

  # 确保输入有效
  if ! is_number "$new_swap" || [ "$new_swap" -lt 0 ]; then
    sleepMsg "无效的输入！请输入一个有效的正整数值。"
    return 1
  fi

  # 获取当前系统中所有的 swap 分区
  local swap_partitions=$(sudo swapon --show=NAME | awk 'NR>1 {print $1}')

  local swapfile="/swap.img"

  # 遍历并删除所有的 swap 分区
  for partition in $swap_partitions; do
    sudo swapoff "$partition"

    # 如果当前分区不是 swapfile，则清除文件系统标识符
    if [ "$partition" != "$swapfile" ]; then
      sudo wipefs -a "$partition" # 清除文件系统标识符
    else
      sudo rm -f "$swapfile" # 删除 swapfile
    fi
  done

  # 移除/etc/fstab中的swap配置
  remove_lines_with_regex "swap" "/etc/fstab"

  if [ "$new_swap" -gt 0 ]; then
    # 创建新的 swap 分区
    sudo dd if=/dev/zero of=$swapfile bs=1M count=$new_swap
    sudo chmod 600 $swapfile
    sudo mkswap $swapfile
    sudo swapon $swapfile

    # 添加新swapfile到/etc/fstab
    echo "$swapfile swap swap defaults 0 0" | sudo tee -a /etc/fstab
  fi

  color_echo green "虚拟内存大小已调整为 ${new_swap}MB"
  waiting
}

# 配置虚拟内存
configure_swap() {
  # 获取当前交换空间信息
  local swap_used=$(free -m | awk 'NR==3{print $3}')
  local swap_total=$(free -m | awk 'NR==3{print $2}')
  local swap_percentage

  # 计算交换空间百分比
  if [ "$swap_total" -eq 0 ]; then
    swap_percentage=0
  else
    swap_percentage=$((swap_used * 100 / swap_total))
  fi

  local swap_info="${swap_used}MB/${swap_total}MB (${swap_percentage}%)"

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
  waiting
}

# 禁用 ping
disable_ping() {
  while true; do
    clear
    echo

    # 显示当前 ping 状态
    install_sysctl
    local current_status=$(sudo sysctl net.ipv4.icmp_echo_ignore_all | awk '{print $3}')
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
    local choice
    read -e -p "请输入选择: " choice

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

      if ! is_success; then
        color_echo red "禁用 ping 失败，请检查配置文件。"
        waiting
      fi
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

      if ! is_success; then
        color_echo red "启用 ping 失败，请检查配置文件。"
        waiting
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

# 编辑文件
edit_file() {
  local filepath=$1

  if confirm "开启自动换行？"; then
    sudo nano --softwrap "$filepath"
  else
    sudo nano --nowrap "$filepath"
  fi
}

# 编辑 /etc/rc.local
edit_rc_local() {
  local rc_local="/etc/rc.local"
  local rc_service="/etc/systemd/system/rc-local.service"

  if ! is_file_exist "$rc_local"; then
    color_echo yellow "初始化 ${rc_local}..."

    # 确保 /etc/rc.local 存在并设置合适权限
    echo -e '#!/bin/bash\nLOG_DIR="/var/log"\nLOG_FILE="$LOG_DIR/startup_script.log"\n\n# 确保日志目录存在\n[ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"\n\nCURRENT_TIME=$(date "+%Y-%m-%d %H:%M:%S")\necho "$CURRENT_TIME: 开机脚本开始执行" >> $LOG_FILE\n\n# 在此处添加您需要开机运行的脚本\n\n\n\nCURRENT_TIME=$(date "+%Y-%m-%d %H:%M:%S")\necho "$CURRENT_TIME: 开机脚本执行完成" >> $LOG_FILE\n\nexit 0' | sudo tee "$rc_local" >/dev/null
    sudo chmod +x "$rc_local"
  fi

  # 检查并生成 rc-local.service 服务（仅当服务文件不存在时）
  if ! is_file_exist "$rc_service"; then
    # 创建 rc-local.service 文件
    sudo bash -c "cat > $rc_service <<EOF
[Unit]
Description=${rc_local} Compatibility
Documentation=man:systemd-rc-local-generator(8)
ConditionFileIsExecutable=${rc_local}
After=network.target

[Service]
Type=forking
ExecStart=${rc_local} start

[Install]
WantedBy=multi-user.target
EOF"

    # 重新加载 systemd 配置，启用 rc-local 服务
    sudo systemctl daemon-reload
    sudo systemctl start rc-local.service
    sudo systemctl enable rc-local.service
    waiting
  fi

  # 直接编辑 /etc/rc.local 文件
  edit_file "$rc_local"
}

# 开启 BBR
open_bbr() {
  # 设置需要添加到 sysctl.conf 的配置项
  local arr=(
    "net.core.default_qdisc=fq"
    "net.ipv4.tcp_congestion_control=bbr"
  )

  # sysctl 配置文件路径
  local config_file="/etc/sysctl.conf"

  if ! is_file_exist "$config_file"; then
    sudo touch "$config_file"
  fi

  # 遍历配置项，检查是否已经存在
  for item in "${arr[@]}"; do
    # 如果配置项不在文件中，则追加到文件末尾
    if ! sudo grep -Fxq "$item" "$config_file"; then
      echo "$item" | sudo tee -a "$config_file" >/dev/null
    fi
  done

  # 重新加载 sysctl 配置，使改动生效
  install_sysctl
  sudo sysctl -p

  waiting
}

# swap阈值
set_swappiness() {
  echo
  color_echo cyan "值越大表示越倾向于使用虚拟内存。"
  echo

  # 显示当前 vm.swappiness 值
  install_sysctl
  local current_swappiness=$(sudo sysctl -n vm.swappiness)
  echo "当前阈值为: $current_swappiness"

  if ! confirm "是否修改阈值？"; then
    sleepMsg "操作已取消。" 2 yellow
    return 1
  fi

  local val
  read -p "请输入阈值 (0-100): " val

  # 验证输入是否为空以及是否为有效的数字
  if ! is_number "$val" || ! is_in_range "$val" 0 100; then
    sleepMsg "请输入一个有效的数字 (0-100)。"
    return 1
  fi

  local SWAPPINESS_CMD="vm.swappiness=$val"
  local SWAPPINESS_PATTERN="^vm.swappiness=.*"

  # sysctl 配置文件路径
  local config_file="/etc/sysctl.conf"

  if ! is_file_exist "$config_file"; then
    sudo touch "$config_file"
  fi

  # 检查是否已经存在 swappiness 配置
  if sudo grep -qE "$SWAPPINESS_PATTERN" "$config_file"; then
    sudo sed -i "s|$SWAPPINESS_PATTERN|$SWAPPINESS_CMD|" "$config_file"
  else
    echo "$SWAPPINESS_CMD" | sudo tee -a "$config_file"
  fi

  # 应用新配置
  sudo sysctl -p

  waiting
}

# 关闭d 快捷键
close_d_key() {
  local bashrc_file="$HOME/.bashrc"

  # 删除 .bashrc 中已存在的 cd 函数定义
  sed -i '/^function cd()/,/^}/d' "$bashrc_file"

  # 删除 .bashrc 中已存在的 d 函数定义
  sed -i '/^function d()/,/^}/d' "$bashrc_file"

  # 从当前 shell 中移除函数
  unset -f cd d 2>/dev/null
}

# 开启d 快捷键
open_d_key() {
  local bashrc_file="$HOME/.bashrc"
  close_d_key
  # 确保文件以换行符结尾（自动处理不存在/无换行符的情况）
  tail -c1 "$bashrc_file" 2>/dev/null | read -r _ || echo >> "$bashrc_file"
  cat <<'EOF' >> "$bashrc_file"
function cd() {
    builtin cd "$@" || return 1

    local current_dir=$(pwd)
    local history_file="$HOME/.cd_history"

    if [ ! -f "$history_file" ]; then
        touch "$history_file"
    fi

    sed -i "\|^$current_dir$|d" "$history_file"
    echo "$current_dir" >> "$history_file"

    local max_entries=35
    local num_entries=$(wc -l < "$history_file")
    if [ "$num_entries" -gt "$max_entries" ]; then
        sed -i '1d' "$history_file"
    fi
}
function d() {
    local history_file="$HOME/.cd_history"

    if [ -f "$history_file" ] && [ -s "$history_file" ]; then
        mapfile -t DIRS < <(tail -n 35 "$history_file")
    else
        echo '无目录历史'
        return
    fi

    local COLOR='\033[1;36m'
    local NUMBER_COLOR='\033[1;33m'
    local NC='\033[0m'

    local letters=({1..9} {a..z})

    while true; do
        echo "请选择历史目录："
        for i in "${!DIRS[@]}"; do
            local dir="${DIRS[i]}"
            local dirname_part=$(dirname "$dir")
            local basename_part=$(basename "$dir")
            if [ "$dirname_part" = "/" ]; then
                dirname_part="/"
            else
                dirname_part="${dirname_part}/"
            fi
            echo -e "${NUMBER_COLOR}${letters[i]}${NC}) ${dirname_part}${COLOR}${basename_part}${NC}"
        done
        echo -e "${NUMBER_COLOR}0${NC}) 取消"

        read -rp "输入序号：" choice

        choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

        if [ "$choice" = "0" ]; then
            break
        elif [[ "$choice" =~ ^[1-9a-z]$ ]]; then
            local index=-1
            for i in "${!letters[@]}"; do
                if [ "${letters[i]}" = "$choice" ]; then
                    index=$i
                    break
                fi
            done
            
            if [ $index -ge 0 ] && [ $index -lt "${#DIRS[@]}" ]; then
                local TARGET_DIR="${DIRS[index]}"
                if [ -d "$TARGET_DIR" ]; then
                    cd "$TARGET_DIR" || echo "跳转失败"
                    break
                else
                    echo "跳转失败：目录不存在"
                fi
            else
                echo "输入超出范围"
            fi
        else
            echo "输入无效"
        fi
    done
}
EOF
}

setup_d_key() {
  while true; do
    clear
    color_echo cyan "d 快捷键: 用于快速切换cd历史目录"
    echo
    echo "1. 开启      2. 关闭"
    echo
    echo "0. 返回"
    echo
    local choice
    read -e -p "请输入你的选择: " choice
    case $choice in
    1)
      open_d_key
      source ~/.bashrc
      sleepMsg "d 快捷键已开启" 2 green
      break
      ;;
    2)
      close_d_key
      source ~/.bashrc
      sleepMsg "d 快捷键已关闭" 2 red
      break
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
    echo "9. 开机运行脚本    a. 登录运行脚本"
    echo
    echo "b. 开启bbr         c. 虚拟内存使用率"
    echo
    echo "d. 编辑fstab       e. d 快捷键"
    echo
    echo "0. 返回"
    echo
    local hd
    read -e -p "请输入你的选择：" hd
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
      local bashrc="$HOME/.bashrc"

      # 检查文件是否存在
      if ! is_file_exist "$bashrc"; then
        touch "$bashrc"
      fi

      # 备份
      local temp_file=$(mktemp)
      cp "$bashrc" "$temp_file"

      edit_file "$bashrc"
      source ~/.bashrc

      if is_success; then
        sleepMsg ".bashrc 文件更新成功！" 2 green
      else
        color_echo red ".bashrc 文件更新失败！"
        # 恢复
        mv "$temp_file" "$bashrc"
        waiting
      fi

      rm -f "$temp_file"
      ;;
    8)
      local sysctl="/etc/sysctl.conf"

      if ! is_file_exist "$sysctl"; then
        sudo touch "$sysctl"
      fi

      local temp_file=$(mktemp)
      sudo cp "$sysctl" "$temp_file"

      edit_file "$sysctl"
      install_sysctl
      sudo sysctl -p

      if is_success; then
        sleepMsg "sysctl.conf 文件更新成功！" 2 green
      else
        color_echo red "sysctl.conf 文件更新失败！"
        # 恢复
        sudo mv "$temp_file" "$sysctl"
        waiting
      fi

      sudo rm -f "$temp_file"
      ;;
    9)
      edit_rc_local
      ;;
    a)
      edit_file "/etc/profile"
      ;;
    b)
      open_bbr
      ;;
    c)
      set_swappiness
      ;;
    d)
      edit_file "/etc/fstab"
      ;;
    e)
      setup_d_key
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
    local sub_choice
    local dockername
    read -e -p "请输入你的选择: " sub_choice

    case $sub_choice in
    1)
      if is_installed "docker"; then
        sleepMsg "docker 已安装" 2 green
      else
        wget -qO- get.docker.com | bash
        sudo systemctl enable docker
        waiting
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
      waiting
      ;;
    3)
      if ! before_docker; then
        continue
      fi
      while true; do
        clear
        echo

        # 列出所有容器
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
        echo "5. 重启指定容器      a. 重启所有容器"
        echo
        echo "b. 进入指定容器      c. 查看容器日志"
        echo
        echo "d. 查看容器网络      e. 检查容器更新"
        echo
        echo "f. 更新所有容器"
        echo
        echo "0. 返回"
        echo
        read -e -p "请输入你的选择: " sub_choice

        case $sub_choice in
        1)
          echo
          read -e -p "请输入创建命令: " dockername
          if (is_empty_string "$dockername"); then
            sleepMsg "命令不能为空!"
            continue
          fi
          $dockername
          waiting
          ;;
        2)
          echo
          read -e -p "请输入启动的容器名: " dockername
          if (is_empty_string "$dockername"); then
            sleepMsg "容器名不能为空!"
            continue
          fi
          sudo docker start $dockername
          waiting
          ;;
        3)
          echo
          read -e -p "请输入停止的容器名: " dockername
          if (is_empty_string "$dockername"); then
            sleepMsg "容器名不能为空!"
            continue
          fi
          sudo docker stop $dockername
          waiting
          ;;
        4)
          echo
          read -e -p "请输入删除的容器名: " dockername
          if (is_empty_string "$dockername"); then
            sleepMsg "容器名不能为空!"
            continue
          fi
          sudo docker rm -f $dockername
          waiting
          ;;
        5)
          echo
          read -e -p "请输入重启的容器名: " dockername
          if (is_empty_string "$dockername"); then
            sleepMsg "容器名不能为空!"
            continue
          fi
          sudo docker restart $dockername
          waiting
          ;;
        6)
          echo
          read -e -p "请输入更新的容器名: " dockername
          if (is_empty_string "$dockername"); then
            sleepMsg "容器名不能为空!"
            continue
          fi
          if confirm "删除旧镜像吗？"; then
            sudo docker run --rm -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --cleanup -R $dockername
          else
            sudo docker run --rm -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower -R $dockername
          fi
          waiting
          ;;
        7)
          if confirm "确认启动所有容器？"; then
            sudo docker start $(sudo docker ps -a -q)
            waiting
          else
            sleepMsg "操作已取消。" 2 yellow
          fi
          ;;
        8)
          if confirm "确认停止所有容器？"; then
            sudo docker stop $(sudo docker ps -q)
            waiting
          else
            sleepMsg "操作已取消。" 2 yellow
          fi
          ;;
        9)
          if confirm "确认删除所有容器？"; then
            sudo docker rm -f $(sudo docker ps -a -q)
            waiting
          else
            sleepMsg "操作已取消。" 2 yellow
          fi
          ;;
        a)
          if confirm "确认重启所有容器？"; then
            sudo docker restart $(sudo docker ps -q)
            waiting
          else
            sleepMsg "操作已取消。" 2 yellow
          fi
          ;;
        b)
          echo
          read -e -p "请输入进入的容器名: " dockername
          if (is_empty_string "$dockername"); then
            sleepMsg "容器名不能为空!"
            continue
          fi
          sudo docker exec -it $dockername /bin/sh
          waiting
          ;;
        c)
          echo
          read -e -p "请输入查看日志的容器名: " dockername
          if (is_empty_string "$dockername"); then
            sleepMsg "容器名不能为空!"
            continue
          fi
          sudo docker logs $dockername
          waiting
          ;;
        d)
          echo
          local container_ids=$(sudo docker ps -q)
          echo
          printf "%-25s %-25s %-25s\n" "容器名称" "网络名称" "IP地址"

          for container_id in $container_ids; do
            local container_info=$(sudo docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ $network }} {{ $config.IPAddress }}{{ end }}' "$container_id")

            local container_name=$(echo "$container_info" | awk '{print $1}')
            local network_info=$(echo "$container_info" | cut -d' ' -f2-)

            while IFS= read -r line; do
              local network_name=$(echo "$line" | awk '{print $1}')
              local ip_address=$(echo "$line" | awk '{print $2}')

              printf "%-20s %-20s %-15s\n" "$container_name" "$network_name" "$ip_address"
            done <<<"$network_info"
          done
          waiting
          ;;
        e)
          sudo docker run --rm -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --run-once --monitor-only --no-startup-message
          waiting
          ;;
        f)
          if confirm "确认更新所有容器？"; then
            if confirm "删除旧镜像吗？"; then
              sudo docker run --rm -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --cleanup -R
            else
              sudo docker run --rm -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower -R
            fi
            waiting
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
        echo "5. 导出指定镜像    6. 导入指定镜像"
        echo
        echo "7. 指定镜像标签"
        echo
        echo "0. 返回"
        echo
        read -e -p "请输入你的选择: " sub_choice

        case $sub_choice in
        1)
          echo
          read -e -p "请输入获取的镜像名: " dockername
          if (is_empty_string "$dockername"); then
            sleepMsg "镜像名不能为空!"
            continue
          fi
          sudo docker pull $dockername
          waiting
          ;;
        2)
          echo
          read -e -p "请输入更新的镜像名: " dockername
          if (is_empty_string "$dockername"); then
            sleepMsg "镜像名不能为空!"
            continue
          fi
          sudo docker pull $dockername
          waiting
          ;;
        3)
          echo
          read -e -p "请输入删除的镜像名: " dockername
          if (is_empty_string "$dockername"); then
            sleepMsg "镜像名不能为空!"
            continue
          fi
          sudo docker rmi -f $dockername
          waiting
          ;;
        4)
          if confirm "确认删除所有镜像？"; then
            sudo docker rmi -f $(sudo docker images -q)
            waiting
          else
            sleepMsg "操作已取消。" 2 yellow
          fi
          ;;
        5)
          local imgpath
          echo
          read -e -p "请输入导出的镜像名(例如: zxecsm/hello:latest): " dockername
          if (is_empty_string "$dockername"); then
            sleepMsg "镜像名不能为空!"
            continue
          fi
          read -e -p "请输入导出的镜像路径: " imgpath
          if (is_empty_string "$imgpath"); then
            sleepMsg "导出路径不能为空!"
            continue
          fi
          sudo docker save -o $imgpath $dockername
          waiting
          ;;
        6)
          echo
          read -e -p "请输入导入的镜像路径: " dockername
          if (is_empty_string "$dockername"); then
            sleepMsg "导入路径不能为空!"
            continue
          fi
          sudo docker load -i $dockername
          waiting
          ;;
        7)
          local newname
          echo
          read -e -p "请输入镜像ID: " dockername
          if (is_empty_string "$dockername"); then
            sleepMsg "镜像ID不能为空!"
            continue
          fi
          read -e -p "请输入镜像标签(例如: zxecsm/hello:latest): " newname
          if (is_empty_string "$newname"); then
            sleepMsg "镜像标签不能为空!"
            continue
          fi
          sudo docker tag $dockername $newname
          waiting
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
        local container_ids=$(sudo docker ps -q)
        printf "%-25s %-25s %-25s\n" "容器名称" "网络名称" "IP地址"

        for container_id in $container_ids; do
          local container_info=$(sudo docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ $network }} {{ $config.IPAddress }}{{ end }}' "$container_id")

          local container_name=$(echo "$container_info" | awk '{print $1}')
          local network_info=$(echo "$container_info" | cut -d' ' -f2-)

          while IFS= read -r line; do
            local network_name=$(echo "$line" | awk '{print $1}')
            local ip_address=$(echo "$line" | awk '{print $2}')

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
        local dockernetwork
        read -e -p "请输入你的选择: " sub_choice

        case $sub_choice in
        1)
          echo
          read -e -p "设置新网络名: " dockernetwork
          if (is_empty_string "$dockernetwork"); then
            sleepMsg "网络名不能为空!"
            continue
          fi
          sudo docker network create $dockernetwork
          waiting
          ;;
        2)
          echo
          read -e -p "加入网络名: " dockernetwork
          if (is_empty_string "$dockernetwork"); then
            sleepMsg "网络名不能为空!"
            continue
          fi
          echo
          read -e -p "哪些容器加入该网络: " dockername
          if (is_empty_string "$dockername"); then
            sleepMsg "容器名不能为空!"
            continue
          fi
          sudo docker network connect $dockernetwork $dockername
          waiting
          echo
          ;;
        3)
          echo
          read -e -p "退出网络名: " dockernetwork
          if (is_empty_string "$dockernetwork"); then
            sleepMsg "网络名不能为空!"
            continue
          fi
          echo
          read -e -p "哪些容器退出该网络: " dockername
          if (is_empty_string "$dockername"); then
            sleepMsg "容器名不能为空!"
            continue
          fi
          sudo docker network disconnect $dockernetwork $dockername
          waiting
          echo
          ;;
        4)
          echo
          read -e -p "请输入要删除的网络名: " dockernetwork
          if (is_empty_string "$dockernetwork"); then
            sleepMsg "网络名不能为空!"
            continue
          fi
          sudo docker network rm $dockernetwork
          waiting
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
        local dockerjuan
        read -e -p "请输入你的选择: " sub_choice

        case $sub_choice in
        1)
          echo
          read -e -p "设置新卷名: " dockerjuan
          if (is_empty_string "$dockerjuan"); then
            sleepMsg "卷名不能为空!"
            continue
          fi
          sudo docker volume create $dockerjuan
          waiting
          ;;
        2)
          echo
          read -e -p "输入删除卷名: " dockerjuan
          if (is_empty_string "$dockerjuan"); then
            sleepMsg "卷名不能为空!"
            continue
          fi
          sudo docker volume rm $dockerjuan
          waiting
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
        waiting
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
        waiting
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

  if is_success; then
    return 0
  else
    return 1
  fi
}

# 设置ssh配置
set_ssh_config() {
  local SSHD_CONFIG="/etc/ssh/sshd_config"
  local key=$1
  local value=$2

  if is_empty_string "$key" || is_empty_string "$value"; then
    sleepMsg "缺少参数： key 或 value"
    return 1
  fi

  if ! is_file_exist "$SSHD_CONFIG"; then
    sudo touch "$SSHD_CONFIG"
  fi

  local temp_file=$(mktemp)

  # 备份配置文件
  sudo cp "$SSHD_CONFIG" "$temp_file"

  # 删除所有非注释的 key
  sudo sed -i "/^\s*$key\b/d" "$SSHD_CONFIG"

  # 追加新的配置
  echo "$key $value" | sudo tee -a "$SSHD_CONFIG" >/dev/null

  # 重启SSH服务
  if restart_ssh; then
    sleepMsg "SSH配置已更新" 2 green
  else
    color_echo red "SSH配置更新失败"
    sudo mv "$temp_file" "$SSHD_CONFIG"
    waiting
  fi

  sudo rm -f "$temp_file"
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

  local sshd_config="/etc/ssh/sshd_config"

  if ! is_file_exist "$sshd_config"; then
    sudo touch "$sshd_config"
  fi

  # 获取当前SSH端口
  local current_port=$(sudo grep ^Port "$sshd_config" | awk '{print $2}')
  if is_empty_string "$current_port"; then
    current_port=22 # 如果未设置端口，默认为22
  fi

  echo -e "当前SSH端口：${CYAN}$current_port${RESET}"

  # 提示用户输入新的SSH端口
  echo
  local new_port
  read -e -p "请输入新的SSH端口号: " new_port

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

  if is_empty_string "$key"; then
    echo "unknown" # 输出 unknown
    return
  fi

  if ! is_file_exist "$SSHD_CONFIG"; then
    echo "unknown" # 输出 unknown
    return
  fi

  # 提取配置项的值
  local status=$(sudo awk -v key="$key" '
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*#/ { next }
    $1 == key { print $2 }
  ' "$SSHD_CONFIG")

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
  local key="$1"
  local text="$2"

  while true; do
    clear
    echo
    local status=$(check_ssh_config_status $key)

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
    local hd
    read -e -p "请输入你的选择：" hd
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
  local title
  read -e -p "请输入公钥标题: " title

  if is_empty_string "$title"; then
    sleepMsg "标题不能为空！"
    return 1
  fi

  # 确认是否设置密钥密码短语
  if confirm "是否设置私钥密码短语？"; then
    echo
    read -e -p "请输入私钥密码短语: " passphrase
    echo
  fi

  # 确保 .ssh 目录存在
  if ! mkdir -p $HOME/.ssh; then
    sleepMsg "无法创建 $HOME/.ssh 目录"
    return 1
  fi

  # 自动覆盖现有私钥
  if is_file_exist "$key_path"; then
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
  chmod 700 $HOME/.ssh || color_echo red "无法设置 $HOME/.ssh 的权限"
  chmod 600 "$key_path" || color_echo red "无法设置私钥文件的权限"
  chmod 644 "$key_path.pub" || color_echo red "无法设置公钥文件的权限"
  chmod 600 $HOME/.ssh/authorized_keys || color_echo red "无法设置 authorized_keys 的权限"

  # 提示用户保存私钥
  echo
  echo "SSH 私钥已生成，请务必保存以下私钥内容。不要与他人共享此内容："
  echo
  cat "$key_path"

  waiting
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
    echo "9. 编辑sshd_config   a. 重启ssh"
    echo
    echo "0. 返回"
    echo
    local hd
    read -e -p "请输入你的选择：" hd
    case $hd in
    1)
      if is_installed "sshd"; then
        sleepMsg "ssh 服务已安装" 2 green
      else
        sudo apt install -y openssh-server
        sudo systemctl start ssh
        sudo systemctl enable ssh
        waiting
      fi
      ;;
    2)
      if before_ssh; then
        if confirm "确认卸载ssh环境？"; then
          sudo systemctl disable ssh
          sudo systemctl stop ssh
          sudo apt-get purge openssh-server
          waiting
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
      local sshd_config="/etc/ssh/sshd_config"

      if ! is_file_exist "$sshd_config"; then
        sudo touch "$sshd_config"
      fi

      # 备份sshd_config
      local temp_file=$(mktemp)
      sudo cp "$sshd_config" "$temp_file"

      edit_file "$sshd_config"
      if restart_ssh; then
        sleepMsg "SSH配置已更新" 2 green
      else
        # 恢复sshd_config
        sudo mv "$temp_file" "$sshd_config"
        color_echo red "SSH配置更新失败"
        waiting
      fi

      sudo rm -f "$temp_file"
      ;;
    a)
      if before_ssh; then
        if restart_ssh; then
          sleepMsg "SSH服务已重启" 2 green
        else
          color_echo red "SSH服务重启失败"
          waiting
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

# 设置快捷键
set_alias() {
  # 提示用户输入快捷按键
  echo
  local key
  read -e -p "请输入你的快捷键: " key

  # 检查用户输入是否为空
  if is_empty_string "$key"; then
    color_echo red "快捷键不能为空。"
    waiting
    return 1
  fi

  local bashrc="$HOME/.bashrc"

  if ! is_file_exist "$bashrc"; then
    touch "$bashrc"
  fi

  # 备份 .bashrc 文件
  local temp_file=$(mktemp)
  cp "$bashrc" "$temp_file"

  # 定义别名命令
  local alias_cmd="alias $key='source $SCRIPT_FILE'"
  local alias_pattern="alias .*='source $SCRIPT_FILE'"

  # 检查 .bashrc 文件中是否已经存在相同的别名
  if grep -q "$alias_pattern" "$bashrc"; then
    # 如果存在，使用新的别名替换旧的别名
    sed -i "s|$alias_pattern|$alias_cmd|" "$bashrc"
  else
    # 如果不存在，追加新的别名
    echo "$alias_cmd" >>"$bashrc"
  fi

  # 重新加载 .bashrc 文件
  source "$bashrc"

  if is_success; then
    color_echo green "快捷键已添加成功。你可以使用 '$key' 来运行命令。"
  else
    color_echo red "快捷键添加失败。"
    # 恢复 .bashrc 文件
    mv "$temp_file" "$bashrc"
  fi

  # 删除临时文件
  rm -f "$temp_file"
  waiting
}

# 更新脚本
update_script() {
  # 临时文件
  local temp_file=$(mktemp)

  if ! curl -L "$SCRIPT_LINK" -o "$temp_file"; then
    color_echo red "更新脚本失败"
  else
    # 检查临时文件是否以 '#!/bin/bash' 开头
    if [[ $(head -n 1 "$temp_file") != "#!/bin/bash" ]]; then
      color_echo red "更新脚本失败"
    else
      sudo mv "$temp_file" "$SCRIPT_FILE"
      color_echo green "更新脚本成功"
    fi
  fi

  sudo rm -f "$temp_file"

  waiting
  clear
  source "$SCRIPT_FILE"
}

# 查找进程
find_process() {
  local process_name
  if ! is_empty_string "$1"; then
    process_name=$1
  else
    read -e -p "请输入要查找的进程名称: " process_name
  fi

  local ps_list=$(sudo ps aux)
  # 获取第一行
  local head="$(echo "$ps_list" | head -n 1)"

  clear
  echo

  # 显示进程信息，排除标题和 grep 命令
  local process_info=$(echo "$ps_list" | sed '1d' | grep -i "$process_name" | grep -v grep)
  if is_empty_string "$process_info"; then
    color_echo red "未找到与 $process_name 相关的进程"
  else
    echo "$head"
    echo "$process_info"
  fi

  echo
  echo "1. 结束进程      2. 重启进程"
  echo
  echo "0. 返回"
  echo
  while true; do
    local choice
    local process_id
    read -e -p "请输入你的选择: " choice
    case $choice in
    1)
      read -e -p "请输入要结束的进程ID: " process_id
      if ! is_number "$process_id"; then
        sleepMsg "无效的进程ID!"
      else
        sudo kill -9 $process_id

        if is_success; then
          sleepMsg "进程 $process_id 已成功结束" 2 green
        else
          color_echo red "进程 $process_id 结束失败，请检查。"
          waiting
        fi
      fi

      find_process $process_name
      break
      ;;
    2)
      read -e -p "请输入要重启的进程ID: " process_id
      if is_number "$process_id"; then
        sleepMsg "无效的进程ID!"
      else
        sudo kill -HUP $process_id

        if is_success; then
          sleepMsg "进程 $process_id 已成功重启" 2 green
        else
          color_echo red "进程 $process_id 重启失败，请检查。"
          waiting
        fi
      fi

      find_process $process_name
      break
      ;;
    0)
      break
      ;;
    *)
      sleepMsg "无效的输入!"
      find_process $process_name
      break
      ;;
    esac
  done
}

# 查找系统中的服务
find_service() {
  local service_name
  if ! is_empty_string "$1"; then
    service_name=$1
  else
    read -e -p "请输入要查找的服务名称: " service_name
  fi

  local sys_list=$(sudo systemctl list-units --type=service --all)
  local head="$(echo "$sys_list" | head -n 1)"

  clear
  echo

  # 列出所有服务并过滤标题和grep服务
  service_info=$(echo "$sys_list" | sed '1d' | grep -i "$service_name" | grep -v grep)
  if is_empty_string "$service_info"; then
    color_echo red "未找到与 $service_name 相关的服务"
  else
    echo "$head"
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
    local choice
    local s_name
    read -e -p "请输入你的选择: " choice
    case $choice in
    1)
      # 启动服务
      read -e -p "请输入要启动的服务名称: " s_name
      if is_empty_string "$s_name"; then
        sleepMsg "无效的服务名称!"
      else
        sudo systemctl start "$s_name"
        waiting
      fi

      find_service "$service_name"
      break
      ;;
    2)
      # 停止服务
      read -e -p "请输入要停止的服务名称: " s_name
      if is_empty_string "$s_name"; then
        sleepMsg "无效的服务名称!"
      else
        sudo systemctl stop "$s_name"
        waiting
      fi

      find_service "$service_name"
      break
      ;;
    3)
      # 重启服务
      read -e -p "请输入要重启的服务名称: " s_name
      sudo systemctl restart "$s_name"
      waiting
      find_service "$service_name"
      break
      ;;
    4)
      # 查看服务状态
      read -e -p "请输入要查看状态的服务名称: " s_name
      if is_empty_string "$s_name"; then
        sleepMsg "无效的服务名称!"
      else
        echo -e "开机启动状态：${GREEN}$(sudo systemctl is-enabled "$s_name")${RESET}"
        sudo systemctl status "$s_name"
        waiting
      fi

      find_service "$service_name"
      break
      ;;
    5)
      # 重新加载服务配置
      read -e -p "请输入要重新加载配置的服务名称: " s_name
      if is_empty_string "$s_name"; then
        sleepMsg "无效的服务名称!"
      else
        sudo systemctl reload "$s_name"
        waiting
      fi

      find_service "$service_name"
      break
      ;;
    6)
      # 开机自启
      read -e -p "请输入要开启自启的服务名称: " s_name
      if is_empty_string "$s_name"; then
        sleepMsg "无效的服务名称!"
      else
        sudo systemctl enable "$s_name"
        waiting
      fi

      find_service "$service_name"
      break
      ;;
    7)
      # 关闭自启
      read -e -p "请输入要关闭自启的服务名称: " s_name
      if is_empty_string "$s_name"; then
        sleepMsg "无效的服务名称!"
      else
        sudo systemctl disable "$s_name"
        waiting
      fi

      find_service "$service_name"
      break
      ;;
    8)
      # 重新加载服务配置
      sudo systemctl daemon-reload
      waiting
      find_service "$service_name"
      break
      ;;
    0)
      break
      ;;
    *)
      sleepMsg "无效的输入!"
      find_service "$service_name"
      break
      ;;
    esac
  done
}

# 查找进程通过端口
find_process_by_port() {
  local process_port
  if ! is_empty_string "$1"; then
    process_port=$1
  else
    read -e -p "请输入要查找的进程端口: " process_port
  fi

  if ! is_valid_port "$process_port"; then
    return 1
  fi

  clear
  echo

  # 显示进程信息
  process_info=$(sudo lsof -i:"$process_port")
  if is_empty_string "$process_info"; then
    color_echo red "未找到与端口 $process_port 相关的进程"
  else
    echo "$process_info"
  fi

  echo
  echo "1. 结束进程      2. 重启进程"
  echo
  echo "0. 返回"
  echo
  while true; do
    local choice
    local process_id
    read -e -p "请输入你的选择: " choice
    case $choice in
    1)
      read -e -p "请输入要结束的进程ID: " process_id
      if ! is_number $process_id; then
        sleepMsg "无效的进程ID!"
      else
        sudo kill -9 $process_id

        if is_success; then
          sleepMsg "进程 $process_id 已成功结束" 2 green
        else
          color_echo red "进程 $process_id 结束失败，请检查。"
          waiting
        fi
      fi

      find_process_by_port $process_port
      break
      ;;
    2)
      read -e -p "请输入要重启的进程ID: " process_id
      if ! is_number $process_id; then
        sleepMsg "无效的进程ID!"
      else
        sudo kill -HUP $process_id

        if is_success; then
          sleepMsg "进程 $process_id 已成功重启" 2 green
        else
          color_echo red "进程 $process_id 重启失败，请检查。"
          waiting
        fi
      fi

      find_process_by_port $process_port
      break
      ;;
    0)
      break
      ;;
    *)
      sleepMsg "无效的输入!"
      find_process_by_port $process_port
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
    echo "1. 查找进程    2. 端口查找进程     3. 查找服务      "
    echo
    echo "0. 返回"
    echo
    local choice
    read -e -p "请输入你的选择: " choice
    case $choice in
    1)
      find_process
      ;;
    2)
      find_process_by_port
      ;;
    3)
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

before_share_dir() {
  if is_installed "samba"; then
    return 0
  else
    sleepMsg "未安装 samba"
    return 1
  fi
}

# 分享目录
share_dir() {
  while true; do
    clear
    if is_installed "samba"; then
      echo
      sudo pdbedit -L
    else
      color_echo red "未安装 samba"
    fi

    echo
    echo "1. 安装samba        2. 卸载samba      3. 重启samba"
    echo
    echo "4. 创建samba用户    5. 删除samba用户"
    echo
    echo "6. 编辑配置文件"
    echo
    echo "0. 返回"
    echo
    local choice
    local username
    read -e -p "请输入你的选择: " choice
    case $choice in
    1)
      if is_installed "samba"; then
        sleepMsg "已安装 samba" 2 green
      else
        sudo apt install samba -y
        sudo systemctl start smbd
        sudo systemctl enable smbd
        if is_installed "ufw"; then
          sudo ufw allow samba
        fi
        waiting
      fi
      ;;
    2)
      if before_share_dir; then
        if confirm "确定要卸载 samba 吗？"; then
          sudo apt remove samba -y
          if is_installed "ufw"; then
            sudo ufw delete allow samba
          fi
          waiting
        fi
      fi
      ;;
    3)
      if before_share_dir; then
        sudo systemctl restart smbd
        waiting
      fi
      ;;
    4)
      if before_share_dir; then
        read -e -p "请输入用户名: " username
        if before_user "$username"; then
          sudo smbpasswd -a "$username"
          waiting
        fi
      fi
      ;;
    5)
      if before_share_dir; then
        read -e -p "请输入要删除的用户名: " username
        if before_user "$username"; then
          sudo smbpasswd -x "$username"
          waiting
        fi
      fi
      ;;
    6)
      local smb_conf="/etc/samba/smb.conf"
      if before_share_dir; then
        if ! is_file_exist "$smb_conf"; then
          # 创建smb.conf文件
          sudo touch "$smb_conf"
          sudo tee "$smb_conf" >/dev/null <<EOF
# [标题]
# path = 共享目录路径
# browseable = yes
# writable = yes
# valid users = 允许的用户1,允许的用户2
EOF
        fi

        edit_file "$smb_conf"
        sudo systemctl restart smbd
        waiting
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

# 主菜单
while true; do
  clear
  echo
  echo "1. 系统信息        2. 系统更新"
  echo
  echo "3. 防火墙          4. nvm"
  echo
  echo "5. 用户管理        6. 系统工具"
  echo
  echo "7. Docker          8. SSH"
  echo
  echo "9. 查找服务进程    a. 共享目录"
  echo
  echo "x. 快捷键          y. 更新脚本"
  echo
  echo "z. 重启系统"
  echo
  echo "0. 退出"
  echo
  read -e -p "请输入你的选择: " choice
  case $choice in
  1)
    system_info
    ;;
  2)
    clear
    sudo apt update -y && sudo apt upgrade -y && sudo apt autoremove --purge -y
    if is_file_exist "/var/run/reboot-required"; then
      echo
      color_echo red "系统需要重启"
      if confirm "立即重启系统？"; then
        sudo reboot
      fi
    fi
    waiting
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
  a)
    share_dir
    ;;
  x)
    set_alias
    ;;
  y)
    update_script
    break
    ;;
  z)
    if confirm "确认重启系统？"; then
      sudo reboot
      waiting
    else
      sleepMsg "操作已取消。" 2 yellow
    fi
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
