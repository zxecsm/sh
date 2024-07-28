#!/bin/bash
# 获取ip地址
ip_address() {
  ipv4_address=$(curl -s ipv4.ip.sb)
  ipv6_address=$(curl -s --max-time 1 ipv6.ip.sb)
}
# 检查是否安装
is_installed() {
  if command -v "$1" &>/dev/null; then
    return 0
  else
    return 1
  fi
}
# 定义确认操作的函数
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
# 网络流量使用
output_status() {
  output=$(awk 'BEGIN { rx_total = 0; tx_total = 0 }
        NR > 2 { rx_total += $2; tx_total += $10 }
        END {
            rx_units = "Bytes";
            tx_units = "Bytes";
            if (rx_total > 1024) { rx_total /= 1024; rx_units = "KB"; }
            if (rx_total > 1024) { rx_total /= 1024; rx_units = "MB"; }
            if (rx_total > 1024) { rx_total /= 1024; rx_units = "GB"; }

            if (tx_total > 1024) { tx_total /= 1024; tx_units = "KB"; }
            if (tx_total > 1024) { tx_total /= 1024; tx_units = "MB"; }
            if (tx_total > 1024) { tx_total /= 1024; tx_units = "GB"; }

            printf("总接收: %.2f %s\n总发送: %.2f %s\n", rx_total, rx_units, tx_total, tx_units);
        }' /proc/net/dev)
}
# 设置时区
set_timedate() {
  shiqu="$1"
  if grep -q 'Alpine' /etc/issue; then
    install tzdata
    cp /usr/share/zoneinfo/${shiqu} /etc/localtime
    hwclock --systohc
  else
    timedatectl set-timezone ${shiqu}
  fi
}
# 删除文件匹配的行
remove_lines_with_regex() {
  local regex=$1
  local filename=$2

  # 检查文件是否存在
  if [[ ! -f $filename ]]; then
    echo "文件 $filename 不存在。"
    return 1
  fi

  # 从文件中筛选不包含正则表达式匹配的行，并将结果输出到临时文件
  grep -Ev "$regex" "$filename" >temp.txt

  # 将临时文件重命名为原文件名
  mv temp.txt "$filename"
}
# 重启ssh
restart_ssh() {
  if command -v dnf &>/dev/null; then
    systemctl restart sshd
  elif command -v yum &>/dev/null; then
    systemctl restart sshd
  elif command -v apt &>/dev/null; then
    service ssh restart
  elif command -v apk &>/dev/null; then
    service sshd restart
  else
    echo "未知的包管理器!"
    return 1
  fi
}
# 时区
current_timezone() {
  if grep -q 'Alpine' /etc/issue; then
    date +"%Z %z"
  else
    timedatectl | grep "Time zone" | awk '{print $3}'
  fi
}
# 系统信息
system_info() {
  clear
  # 获取IP
  ip_address
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
  # CPU占用
  cpu_usage_percent=$(awk '{u=$2+$4; t=$2+$4+$5; if (NR==1){u1=u; t1=t;} else printf "%.0f\n", (($2+$4-u1) * 100 / (t-t1))}' \
    <(grep 'cpu ' /proc/stat) <(
      sleep 1
      grep 'cpu ' /proc/stat
    ))
  # CPU 核心数
  cpu_cores=$(nproc)
  # 物理内存
  mem_info=$(free -b | awk 'NR==2{printf "%.2f/%.2f MB (%.2f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}')
  # 硬盘使用
  disk_info=$(df -h | awk '$NF=="/"{printf "%s/%s (%s)", $3, $2, $5}')
  # 地区
  country=$(curl -s ipinfo.io/country)
  city=$(curl -s ipinfo.io/city)
  # 运营商
  isp_info=$(curl -s ipinfo.io/org)
  # 主机名
  hostname=$(hostname)
  # bbr信息
  congestion_algorithm=$(sysctl -n net.ipv4.tcp_congestion_control)
  queue_algorithm=$(sysctl -n net.core.default_qdisc)

  # 尝试使用 lsb_release 获取系统信息
  os_info=$(lsb_release -ds 2>/dev/null)

  # 如果 lsb_release 命令失败，则尝试其他方法
  if [ -z "$os_info" ]; then
    # 检查常见的发行文件
    if [ -f "/etc/os-release" ]; then
      os_info=$(source /etc/os-release && echo "$PRETTY_NAME")
    elif [ -f "/etc/debian_version" ]; then
      os_info="Debian $(cat /etc/debian_version)"
    elif [ -f "/etc/redhat-release" ]; then
      os_info=$(cat /etc/redhat-release)
    else
      os_info="Unknown"
    fi
  fi
  # 网络流量
  output_status
  # 系统时间
  current_time=$(date "+%Y-%m-%d %I:%M %p")
  # 虚拟内存
  swap_used=$(free -m | awk 'NR==3{print $3}')
  swap_total=$(free -m | awk 'NR==3{print $2}')

  if [ "$swap_total" -eq 0 ]; then
    swap_percentage=0
  else
    swap_percentage=$((swap_used * 100 / swap_total))
  fi

  swap_info="${swap_used}MB/${swap_total}MB (${swap_percentage}%)"
  # 运行时间
  runtime=$(cat /proc/uptime | awk -F. '{run_days=int($1 / 86400);run_hours=int(($1 % 86400) / 3600);run_minutes=int(($1 % 3600) / 60); if (run_days > 0) printf("%d天 ", run_days); if (run_hours > 0) printf("%d时 ", run_hours); printf("%d分\n", run_minutes)}')
  # 时区
  timezone=$(current_timezone)

  echo
  echo
  echo "主机名: $hostname"
  echo "运营商: $isp_info"
  echo
  echo "系统版本: $os_info"
  echo "Linux版本: $kernel_version"
  echo
  echo "CPU架构: $cpu_arch"
  echo "CPU型号: $cpu_info"
  echo "CPU核心数: $cpu_cores"
  echo
  echo "CPU占用: $cpu_usage_percent%"
  echo "物理内存: $mem_info"
  echo "虚拟内存: $swap_info"
  echo "硬盘占用: $disk_info"
  echo
  echo "$output"
  echo
  echo "网络拥堵算法: $congestion_algorithm $queue_algorithm"
  echo
  echo "公网IPv4地址: $ipv4_address"
  echo "公网IPv6地址: $ipv6_address"
  echo
  echo "地理位置: $country $city"
  echo "系统时区: $timezone"
  echo "系统时间: $current_time"
  echo
  echo "系统运行时长: $runtime"
  echo
}
# 系统更新
linux_update() {

  # Update system on Debian-based systems
  if [ -f "/etc/debian_version" ]; then
    sudo apt update -y && DEBIAN_FRONTEND=noninteractive sudo apt full-upgrade -y
  fi

  # Update system on Red Hat-based systems
  if [ -f "/etc/redhat-release" ]; then
    yum -y update
  fi

  # Update system on Alpine Linux
  if [ -f "/etc/alpine-release" ]; then
    apk update && apk upgrade
  fi

}
break_end() {
  echo
  echo "运行完毕，按任意键继续"
  read -n 1 -s -r -p ""
  echo
  clear
}
# 安装node
install_nvm() {
  if is_installed "nvm"; then
    echo "nvm已经安装"
    sleep 1
  else
    mkdir -p /usr/local/nvm
    git clone https://github.com/nvm-sh/nvm.git /usr/local/nvm
    /usr/local/nvm/install.sh
    source ~/.bashrc
  fi
}
hander_nvm() {
  while true; do
    clear
    echo
    echo "1. 安装nvm    2. 安装node"
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
      echo
      read -p "请输入node版本: " node_choice
      nvm install $node_choice
      break_end
      ;;
    3)
      clear
      nvm ls
      break_end
      ;;
    4)
      clear
      nvm ls-remote
      break_end
      ;;
    5)
      echo
      read -p "请输入node版本: " node_choice
      nvm use $node_choice
      break_end
      ;;
    6)
      echo
      read -p "请输入node版本: " node_choice
      nvm uninstall $node_choice
      break_end
      ;;
    0)
      break
      ;;
    *)
      echo "无效的输入!"
      sleep 1
      ;;
    esac
  done
}
# 防火墙
hander_ufw() {
  while true; do
    clear
    ufw status
    echo
    echo "1. 添加   2. 删除"
    echo
    echo "3. 安装   4. 卸载"
    echo
    echo "5. 开启   6. 关闭   7. 重置"
    echo
    echo "0. 返回"
    echo
    read -p "请输入你的选择：" hd
    case $hd in
    1)
      echo
      read -p "请输入端口：" port
      sudo ufw allow $port
      ;;
    2)
      echo
      read -p "请输入端口：" port
      sudo ufw delete allow $port
      ;;
    3)
      if is_installed "ufw"; then
        echo "ufw已经安装"
        sleep 1
      else
        sudo apt install -y ufw
      fi
      ;;
    4)
      if confirm "确认卸载？"; then
        sudo apt remove -y ufw
      else
        echo "操作已取消。"
        sleep 1
      fi
      ;;
    5)
      sudo ufw enable
      ;;
    6)
      if confirm "确认关闭？"; then
        sudo ufw disable
      else
        echo "操作已取消。"
        sleep 1
      fi
      ;;
    7)
      if confirm "确认重置？"; then
        sudo ufw reset
      else
        echo "操作已取消。"
        sleep 1
      fi
      ;;
    0)
      break
      ;;
    *)
      echo "无效的输入!"
      sleep 1
      ;;
    esac
  done
}
# 修改时区
change_timezone() {
  while true; do
    clear
    # 获取当前系统时区
    timezone=$(current_timezone)
    # 获取当前系统时间
    current_time=$(date +"%Y-%m-%d %H:%M:%S")
    # 显示时区和时间
    echo "当前系统时区：$timezone"
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
      echo "无效的输入!"
      sleep 1
      ;;
    esac
  done
}
# 修改主机名
change_hostname() {
  current_hostname=$(hostname)
  echo "当前主机名: $current_hostname"
  # 获取新的主机名
  echo
  read -p "请输入新的主机名: " new_hostname
  if [ -n "$new_hostname" ]; then
    if confirm "确认更改？"; then
      if [ -f /etc/alpine-release ]; then
        # Alpine
        echo "$new_hostname" >/etc/hostname
        hostname "$new_hostname"
      else
        # 其他系统，如 Debian, Ubuntu, CentOS 等
        hostnamectl set-hostname "$new_hostname"
        sed -i "s/$current_hostname/$new_hostname/g" /etc/hostname
        systemctl restart systemd-hostnamed
      fi
      echo "主机名已更改为: $new_hostname"
    else
      echo "操作已取消。"
    fi
  else
    echo "无效的主机名。未更改主机名。"
  fi
  break_end
}
# 定时任务
hander_crontab() {
  while true; do
    clear
    echo
    crontab -l
    echo
    echo "1. 添加定时任务    2. 删除定时任务    3. 编辑定时任务"
    echo
    echo "0. 返回"
    echo
    read -p "请输入你的选择: " sub_choice

    case $sub_choice in
    1)
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
        read -p "选择每月的几号执行任务？ (1-30): " day
        (
          crontab -l
          echo "0 0 $day * * $newquest"
        ) | crontab - >/dev/null 2>&1
        ;;
      2)
        echo
        read -p "选择周几执行任务？ (0-6，0代表星期日): " weekday
        (
          crontab -l
          echo "0 0 * * $weekday $newquest"
        ) | crontab - >/dev/null 2>&1
        ;;
      3)
        echo
        read -p "选择每天几点执行任务？（小时，0-23）: " hour
        (
          crontab -l
          echo "0 $hour * * * $newquest"
        ) | crontab - >/dev/null 2>&1
        ;;
      4)
        echo
        read -p "输入每小时的第几分钟执行任务？（分钟，0-60）: " minute
        (
          crontab -l
          echo "$minute * * * * $newquest"
        ) | crontab - >/dev/null 2>&1
        ;;
      *)
        break
        ;;
      esac
      ;;
    2)
      echo
      read -p "请输入需要删除任务的关键字: " kquest
      crontab -l | grep -v "$kquest" | crontab -
      ;;
    3)
      crontab -e
      ;;
    0)
      break
      ;;
    *)
      echo "无效的输入!"
      sleep 1
      ;;
    esac
  done
}
# 检查用户是否存在
is_user() {
  if id "$1" &>/dev/null; then
    return 0
  else
    return 1
  fi
}
# 赋予sudo
add_sudo() {
  username="$1"
  if is_user $username; then
    # 检查操作系统类型并添加用户到适当的组
    if grep -q -E "^ID=debian|^ID=ubuntu" /etc/os-release; then
      usermod -aG sudo "$username"
    elif grep -q -E "^ID=fedora|^ID=centos|^ID=rhel" /etc/os-release; then
      usermod -aG wheel "$username"
    else
      echo "未识别的操作系统。请手动为用户 $username 配置 sudo 权限。"
      sleep 1
    fi
  else
    echo "用户 $username 不存在"
    sleep 1
  fi
}
# 取消sudo
del_sudo() {
  username="$1"
  if is_user $username; then
    # 检查操作系统类型并添加用户到适当的组
    if grep -q -E "^ID=debian|^ID=ubuntu" /etc/os-release; then
      deluser "$username" sudo
    elif grep -q -E "^ID=fedora|^ID=centos|^ID=rhel" /etc/os-release; then
      gpasswd -d "$username" wheel
    else
      echo "未识别的操作系统。请手动为用户 $username 配置 sudo 权限。"
      sleep 1
    fi
  else
    echo "用户 $username 不存在"
    sleep 1
  fi
}
# 用户管理
hander_user() {
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
    echo "5. 删除账号"
    echo
    echo "0. 返回"
    echo
    read -p "请输入你的选择: " sub_choice

    case $sub_choice in
    1)
      echo
      read -p "请输入新用户名: " new_username
      # 创建新用户并设置密码
      useradd -m -s /bin/bash "$new_username"
      passwd "$new_username"
      ;;
    2)
      echo
      read -p "请输入新用户名: " new_username
      # 创建新用户并设置密码
      useradd -m -s /bin/bash "$new_username"
      passwd "$new_username"
      add_sudo $new_username
      ;;
    3)
      echo
      read -p "请输入用户名: " username
      if confirm "确认赋予用户 $username sudo 权限？"; then
        add_sudo $username
      else
        echo "操作已取消。"
        sleep 1
      fi
      ;;
    4)
      echo
      read -p "请输入用户名: " username
      if confirm "确认移除用户 $username sudo 权限？"; then
        del_sudo $username
      else
        echo "操作已取消。"
        sleep 1
      fi
      ;;
    5)
      echo
      read -p "请输入要删除的用户名: " username
      if confirm "确认删除用户：$username？"; then
        # 删除用户及其主目录
        sudo pkill -u $username # 查找并终止与该用户关联的所有进程
        sudo userdel -r $username
      else
        echo "操作已取消。"
        sleep 1
      fi
      ;;
    0)
      break
      ;;
    *)
      echo "无效的输入!"
      sleep 1
      ;;
    esac
  done
}
# docker
hander_docker() {
  while true; do
    clear
    echo
    echo "1. 安装Docker    2. Docker状态"
    echo
    echo "3. 容器管理    4. 镜像管理"
    echo
    echo "5. 网络管理    6. 卷管理"
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
        echo "docker已经安装"
        sleep 1
      else
        wget -qO- get.docker.com | bash
        systemctl enable docker
      fi
      ;;
    2)
      clear
      echo "Docker版本"
      docker -v
      docker compose version
      echo
      echo "资源使用"
      docker stats --no-stream --all
      break_end
      ;;
    3)
      while true; do
        clear
        echo
        docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
        echo
        echo "1. 创建新的容器"
        echo
        echo "2. 启动指定容器    6. 启动所有容器"
        echo
        echo "3. 停止指定容器    7. 停止所有容器"
        echo
        echo "4. 删除指定容器    8. 删除所有容器"
        echo
        echo "5. 重启指定容器    9. 重启所有容器"
        echo
        echo "11. 进入指定容器    12. 查看容器日志    13. 查看容器网络"
        echo
        echo "0. 返回"
        echo
        read -p "请输入你的选择: " sub_choice

        case $sub_choice in
        1)
          echo
          read -p "请输入创建命令: " dockername
          $dockername
          ;;
        2)
          echo
          read -p "请输入启动的容器名: " dockername
          docker start $dockername
          ;;
        3)
          echo
          read -p "请输入停止的容器名: " dockername
          docker stop $dockername
          ;;
        4)
          echo
          read -p "请输入删除的容器名: " dockername
          docker rm -f $dockername
          ;;
        5)
          echo
          read -p "请输入重启的容器名: " dockername
          docker restart $dockername
          ;;
        6)
          if confirm "确认启动所有容器？"; then
            docker start $(docker ps -a -q)
          else
            echo "操作已取消。"
            sleep 1
          fi
          ;;
        7)
          if confirm "确认停止所有容器？"; then
            docker stop $(docker ps -q)
          else
            echo "操作已取消。"
            sleep 1
          fi
          ;;
        8)
          if confirm "确认删除所有容器？"; then
            docker rm -f $(docker ps -a -q)
          else
            echo "操作已取消。"
            sleep 1
          fi
          ;;
        9)
          if confirm "确认重启所有容器？"; then
            docker restart $(docker ps -q)
          else
            echo "操作已取消。"
            sleep 1
          fi
          ;;
        11)
          echo
          read -p "请输入进入的容器名: " dockername
          docker exec -it $dockername /bin/sh
          break_end
          ;;
        12)
          echo
          read -p "请输入查看日志的容器名: " dockername
          docker logs $dockername
          break_end
          ;;
        13)
          echo
          container_ids=$(docker ps -q)
          echo
          printf "%-25s %-25s %-25s\n" "容器名称" "网络名称" "IP地址"

          for container_id in $container_ids; do
            container_info=$(docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ $network }} {{ $config.IPAddress }}{{ end }}' "$container_id")

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
        0)
          break
          ;;
        *)
          echo "无效的输入!"
          sleep 1
          ;;
        esac
      done
      ;;
    4)
      while true; do
        clear
        echo
        docker image ls
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
          docker pull $dockername
          ;;
        2)
          echo
          read -p "请输入更新的镜像名: " dockername
          docker pull $dockername
          ;;
        3)
          echo
          read -p "请输入删除的镜像名: " dockername
          docker rmi -f $dockername
          ;;
        4)
          if confirm "确认删除所有镜像？"; then
            docker rmi -f $(docker images -q)
          else
            echo "操作已取消。"
            sleep 1
          fi
          ;;
        0)
          break
          ;;
        *)
          echo "无效的输入!"
          sleep 1
          ;;
        esac
      done
      ;;
    5)
      while true; do
        clear
        echo
        docker network ls
        echo
        container_ids=$(docker ps -q)
        printf "%-25s %-25s %-25s\n" "容器名称" "网络名称" "IP地址"

        for container_id in $container_ids; do
          container_info=$(docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ $network }} {{ $config.IPAddress }}{{ end }}' "$container_id")

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
          docker network create $dockernetwork
          ;;
        2)
          echo
          read -p "加入网络名: " dockernetwork
          echo
          read -p "哪些容器加入该网络: " dockername
          docker network connect $dockernetwork $dockername
          echo
          ;;
        3)
          echo
          read -p "退出网络名: " dockernetwork
          echo
          read -p "哪些容器退出该网络: " dockername
          docker network disconnect $dockernetwork $dockername
          echo
          ;;
        4)
          echo
          read -p "请输入要删除的网络名: " dockernetwork
          docker network rm $dockernetwork
          ;;
        0)
          break
          ;;
        *)
          echo "无效的输入!"
          sleep 1
          ;;
        esac
      done
      ;;
    6)
      while true; do
        clear
        echo
        docker volume ls
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
          docker volume create $dockerjuan
          ;;
        2)
          echo
          read -p "输入删除卷名: " dockerjuan
          docker volume rm $dockerjuan
          ;;
        0)
          break
          ;;
        *)
          echo "无效的输入!"
          sleep 1
          ;;
        esac
      done
      ;;
    7)
      if confirm "确认清理无用的镜像容器网络？"; then
        docker system prune -af --volumes
        break_end
      else
        echo "操作已取消。"
        sleep 1
      fi
      ;;
    8)
      if confirm "确认卸载docker环境？"; then
        sudo apt-get purge docker-ce docker-ce-cli containerd.io
        sudo rm -rf /var/lib/docker
        sudo rm -rf /var/lib/containerd
        break_end
      else
        echo "操作已取消。"
        sleep 1
      fi
      ;;
    0)
      break
      ;;
    *)
      echo "无效的输入!"
      sleep 1
      ;;
    esac
  done
}
# 设置ssh配置
set_ssh_config() {
  local SSHD_CONFIG="/etc/ssh/sshd_config"
  local key=$1
  local value=$2

  if [[ -z "$key" || -z "$value" ]]; then
    echo "缺少参数： key 或 value"
    return 1
  fi

  if [ ! -f "$SSHD_CONFIG" ]; then
    echo "配置文件 $SSHD_CONFIG 不存在"
    return 1
  fi
  # 启用指定配置项或更新其值
  if grep -q "^\s*#*\s*$key\s" "$SSHD_CONFIG"; then
    sudo sed -i "s/^\s*#*\s*$key\s.*/$key $value/" "$SSHD_CONFIG"
  else
    echo "$key $value" | sudo tee -a "$SSHD_CONFIG" >/dev/null
  fi

  # 重启SSH服务
  restart_ssh
}
# 修改ssh端口
change_ssh_port() {
  # 获取当前SSH端口
  current_port=$(grep ^Port /etc/ssh/sshd_config | awk '{print $2}')
  if [ -z "$current_port" ]; then
    current_port=22 # 如果未设置端口，默认为22
  fi
  echo "当前SSH端口：$current_port"

  # 提示用户输入新的SSH端口
  echo
  read -p "请输入新的SSH端口号: " new_port

  # 确认用户输入的端口号
  if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
    echo "无效的端口号。请输入1到65535之间的数字。"
    return 1
  fi

  # 提示用户确认更改
  if ! confirm "你确定要将SSH端口更改为：${new_port}"; then
    echo "操作已取消。"
    return 1
  fi

  # 修改sshd_config文件中的端口设置
  set_ssh_config "Port" $new_port

  echo "SSH 端口已修改为: $new_port"
}
# ssh配置项状态
check_ssh_config_status() {
  local SSHD_CONFIG="/etc/ssh/sshd_config"
  local key=$1

  if [ -z "$key" ]; then
    echo "缺少参数：key"
    return 1
  fi

  if [ ! -f "$SSHD_CONFIG" ]; then
    echo "配置文件 $SSHD_CONFIG 不存在"
    return 1
  fi

  # 获取配置项的状态
  status=$(grep -E "^#?\s*$key\s+" "$SSHD_CONFIG" | awk '{print $2}')

  if [ "$status" == "yes" ]; then
    return 0
  else
    return 1
  fi
}
# 处理ssh配置
hander_ssh_config_auth() {
  key="$1"
  text="$2"
  while true; do
    clear
    echo
    if check_ssh_config_status $key; then
      echo "$text：已启用"
    else
      echo "$text：已禁用"
    fi
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
      echo "无效的输入!"
      sleep 1
      ;;
    esac
  done
}
# 配置密钥
hander_ssh_key() {
  local passphrase=""
  local key_path="$HOME/.ssh/id_rsa_custom"
  echo
  read -p "请输入公钥标题: " title

  # 确认是否设置密钥密码短语
  if confirm "是否设置私钥密码短语？"; then
    echo
    read -s -p "请输入私钥密码短语: " passphrase
    echo
  fi

  # 确保 .ssh 目录存在
  mkdir -p ~/.ssh

  # 自动覆盖现有私钥
  if [ -f "$key_path" ]; then
    rm -f "$key_path" "$key_path.pub"
  fi

  # 生成 SSH 私钥
  ssh-keygen -t rsa -b 4096 -C "$title" -f "$key_path" -N "$passphrase"

  if [ $? -ne 0 ]; then
    echo "SSH 私钥生成失败"
    return 1
  fi

  # 将公钥添加到 authorized_keys
  cat "$key_path.pub" >>~/.ssh/authorized_keys

  # 设置正确的文件权限
  chmod 700 ~/.ssh
  chmod 600 ~/.ssh/id_rsa_custom
  chmod 644 ~/.ssh/id_rsa_custom.pub
  chmod 600 ~/.ssh/authorized_keys

  echo
  echo "SSH 私钥信息已生成，请务必复制保存以下私钥内容:"
  cat "$key_path"
}
# 关闭登录提示信息
disable_motd() {
  # 移除 /etc/update-motd.d/ 目录下文件的执行权限
  sudo chmod -x /etc/update-motd.d/*

  # 禁用 PAM MOTD 模块
  sudo sed -i.bak -e '/pam_motd.so/ s/^/#/' /etc/pam.d/sshd

  # 禁用 SSH 配置中的 PrintMotd 和 PrintLastLog
  sudo sed -i.bak -e '/^#PrintMotd/s/^#//' -e '/^PrintMotd/s/yes/no/' -e '/^#PrintLastLog/s/^#//' -e '/^PrintLastLog/s/yes/no/' /etc/ssh/sshd_config
  sudo systemctl restart sshd

  # 禁用 /etc/profile.d/ 目录下的所有脚本
  sudo chmod -x /etc/profile.d/*

  # 禁用 /etc/profile 和 /etc/bash.bashrc 中的 MOTD 相关行
  sudo sed -i.bak -e '/motd/ s/^/#/' /etc/profile
  sudo sed -i.bak -e '/motd/ s/^/#/' /etc/bash.bashrc

  echo "MOTD 提示信息已禁用，请重新登录以查看效果。"
}
# ssh配置
hander_ssh() {
  while true; do
    clear
    echo
    echo "1. 修改ssh端口       2. ssh公钥认证"
    echo
    echo "3. root登录          4. 密码登录"
    echo
    echo "5. 生成密钥          6. 编辑authorized_keys"
    echo
    echo "7. 编辑sshd_config   8. 重启ssh"
    echo
    echo "9. 关闭ssh登录提示信息"
    echo
    echo "0. 返回"
    echo
    read -p "请输入你的选择：" hd
    case $hd in
    1)
      change_ssh_port
      sleep 1
      ;;
    2)
      hander_ssh_config_auth "PubkeyAuthentication" "SSH公钥认证状态"
      ;;
    3)
      hander_ssh_config_auth "PermitRootLogin" "root账户SSH登录状态"
      ;;
    4)
      hander_ssh_config_auth "PasswordAuthentication" "密码登录状态"
      ;;
    5)
      if confirm "清除之前的公钥？"; then
        >~/.ssh/authorized_keys
      fi
      hander_ssh_key
      break_end
      ;;
    6)
      vim ~/.ssh/authorized_keys
      ;;
    7)
      vim /etc/ssh/sshd_config
      restart_ssh
      echo "更新配置成功"
      break_end
      ;;
    8)
      restart_ssh
      break_end
      ;;
    9)
      disable_motd
      break_end
      ;;
    0)
      break
      ;;
    *)
      echo "无效的输入!"
      sleep 1
      ;;
    esac
  done
}
# 调整swap
add_swap() {
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

  # 创建新的 swap 分区
  dd if=/dev/zero of=/swapfile bs=1M count=$new_swap
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile

  remove_lines_with_regex "swap swap defaults" "/etc/fstab"

  # 添加新swapfile到/etc/fstab
  echo "/swapfile swap swap defaults 0 0" >>/etc/fstab

  # 针对Alpine Linux，添加启动脚本
  if [ -f /etc/alpine-release ]; then
    echo "nohup swapon /swapfile" >>/etc/local.d/swap.start
    chmod +x /etc/local.d/swap.start
    rc-update add local
  fi

  echo "虚拟内存大小已调整为 ${new_swap}MB"
}
hander_swap() {
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
  echo "当前虚拟内存: $swap_info"
  echo
  if confirm "调整swap大小？"; then
    echo
    read -p "请输入虚拟内存大小MB: " new_swap
    add_swap
    break_end
  else
    echo "操作已取消。"
    sleep 1
  fi
}
install_hello() {
  PROJECT_PATH="/opt/hello/hello"
  SERVER_PATH="$PROJECT_PATH/server"
  WEB_PATH="$PROJECT_PATH/web"
  GIT_REPO="https://github.com/zxecsm/hello.git"

  git clone "$GIT_REPO" "$PROJECT_PATH"

  pnpm install --prefix "$SERVER_PATH"
  pnpm install --prefix "$WEB_PATH"

  pnpm --prefix "$WEB_PATH" run build
}
hander_hello() {
  PROJECT_PATH="/opt/hello/hello"
  SERVER_PATH="$PROJECT_PATH/server"
  WEB_PATH="$PROJECT_PATH/web"
  while true; do
    clear
    echo
    echo "1. 安装pm2、pnpm    2. 部署"
    echo
    echo "3. 更新server       4. 更新web"
    echo
    echo "5. 停止        6. 启动       7. 重启"
    echo
    echo "0. 返回"
    echo
    read -p "请输入你的选择：" hd
    case $hd in
    1)
      npm i -g pm2 pnpm
      break_end
      ;;
    2)
      if [ -d "$PROJECT_PATH" ]; then
        if confirm "项目目录已存在，重新部署？"; then
          pm2 stop "$SERVER_PATH/app.js"
          rm -rf "$PROJECT_PATH"
          install_hello
        else
          echo "操作已取消。"
        fi
      else
        install_hello
      fi
      break_end
      ;;
    3)
      git --git-dir="$PROJECT_PATH/.git" --work-tree="$PROJECT_PATH" pull
      pm2 restart "$SERVER_PATH/app.js"
      break_end
      ;;
    4)
      git --git-dir="$PROJECT_PATH/.git" --work-tree="$PROJECT_PATH" pull
      pnpm --prefix "$WEB_PATH" run build
      break_end
      ;;
    5)
      pm2 stop "$SERVER_PATH/app.js"
      break_end
      ;;
    6)
      pm2 start "$SERVER_PATH/app.js"
      break_end
      ;;
    7)
      pm2 restart "$SERVER_PATH/app.js"
      break_end
      ;;
    0)
      break
      ;;
    *)
      echo "无效的输入!"
      sleep 1
      ;;
    esac
  done
}
## 开启bbr
hander_bbr() {
  ARR=(
    "net.core.default_qdisc=fq"
    "net.ipv4.tcp_congestion_control=bbr"
  )

  SYSCTL_FILE="/etc/sysctl.conf"

  for ITEM in "${ARR[@]}"; do
    if ! grep -Fxq "$ITEM" "$SYSCTL_FILE"; then
      echo "$ITEM" >>"$SYSCTL_FILE"
    fi
  done

  sysctl -p
}
# 常用
hander_common() {
  while true; do
    clear
    echo
    echo "1. 常用工具    2. xui"
    echo
    echo "3. rclone     4. Hello"
    echo
    echo "5. bbr"
    echo
    echo "0. 返回"
    echo
    read -p "请输入你的选择：" hd
    case $hd in
    1)
      clear
      apt install -y htop ufw vim git bash sudo wget curl trash-cli rsync zip
      break_end
      ;;
    2)
      if is_installed "x-ui"; then
        x-ui
      else
        bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
      fi
      break_end
      ;;
    3)
      if is_installed "rclone"; then
        rclone config
      else
        curl https://rclone.org/install.sh | sudo bash
      fi
      break_end
      ;;
    4)
      hander_hello
      ;;
    5)
      hander_bbr
      break_end
      ;;
    0)
      break
      ;;
    *)
      echo "无效的输入!"
      sleep 1
      ;;
    esac
  done
}
# 开启Debian ls快捷别名
hander_bashrc_ll() {
  # 定义别名
  ALIASES=(
    "alias la='ls -A'"
    "alias ll='ls -alF'"
    "alias l='ls -CF'"
  )

  # 定义 .bashrc 文件路径
  BASHRC_FILE="$HOME/.bashrc"

  # 检查并添加别名
  for ALIAS in "${ALIASES[@]}"; do
    if ! grep -Fxq "$ALIAS" "$BASHRC_FILE"; then
      echo "$ALIAS" >>"$BASHRC_FILE"
    fi
  done
}
# 清理系统垃圾
linux_clean() {
  # 定义一个函数，用于清理日志文件
  clean_logs() {
    journalctl --rotate          # 旋转系统日志文件
    journalctl --vacuum-time=1s  # 清除所有早于 1 秒的日志
    journalctl --vacuum-size=50M # 将日志文件大小限制为 50MB
  }

  # 定义一个函数，用于清理基于 Debian 的系统
  clean_debian() {
    apt autoremove --purge -y                                                                                                          # 自动移除不再需要的包
    apt clean -y                                                                                                                       # 清除本地存储库中的包文件
    apt autoclean -y                                                                                                                   # 清除本地存储库中过时的包文件
    apt remove --purge $(dpkg -l | awk '/^rc/ {print $2}') -y                                                                          # 移除所有配置文件已被删除的包
    clean_logs                                                                                                                         # 调用日志清理函数
    apt remove --purge $(dpkg -l | awk '/^ii linux-(image|headers)-[^ ]+/{print $2}' | grep -v $(uname -r | sed 's/-.*//') | xargs) -y # 移除旧的内核映像和头文件
  }

  # 定义一个函数，用于清理基于 Red Hat 的系统
  clean_redhat() {
    yum autoremove -y                                    # 自动移除不再需要的包
    yum clean all                                        # 清除本地存储库中的包文件
    clean_logs                                           # 调用日志清理函数
    yum remove $(rpm -q kernel | grep -v $(uname -r)) -y # 移除旧的内核
  }

  # 定义一个函数，用于清理 Alpine Linux 系统
  clean_alpine() {
    apk del --purge $(apk info --installed | awk '{print $1}' | grep -v $(apk info --available | awk '{print $1}')) # 移除不再需要的包
    apk autoremove                                                                                                  # 自动移除不再需要的包
    apk cache clean                                                                                                 # 清除本地存储库中的包文件
    rm -rf /var/log/*                                                                                               # 删除所有日志文件
    rm -rf /var/cache/apk/*                                                                                         # 删除 APK 缓存文件
  }

  # 主脚本逻辑，根据系统类型调用相应的清理函数
  if [ -f "/etc/debian_version" ]; then
    # 如果系统是基于 Debian 的，调用 clean_debian 函数
    clean_debian
  elif [ -f "/etc/redhat-release" ]; then
    # 如果系统是基于 Red Hat 的，调用 clean_redhat 函数
    clean_redhat
  elif [ -f "/etc/alpine-release" ]; then
    # 如果系统是 Alpine Linux，调用 clean_alpine 函数
    clean_alpine
  fi
}
# swap阈值
set_swappiness() {
  echo
  echo "值越大表示越倾向于使用swap"
  echo
  read -p "请输入阈值 (0-100): " val

  # 验证输入是否为空以及是否为有效的数字
  if [[ -z "$val" || ! "$val" =~ ^[0-9]+$ || "$val" -lt 0 || "$val" -gt 100 ]]; then
    echo "请输入一个有效的数字 (0-100)。"
    return 1
  fi

  SWAPPINESS_CMD="vm.swappiness = $val"
  SWAPPINESS_PATTERN="^vm.swappiness = .*"

  # 检查是否已经存在 swappiness 配置
  if grep -qE "$SWAPPINESS_PATTERN" "/etc/sysctl.conf"; then
    sed -i "s|$SWAPPINESS_PATTERN|$SWAPPINESS_CMD|" "/etc/sysctl.conf"
    echo "已更新阈值为 '$val'"
  else
    echo "$SWAPPINESS_CMD" >>"/etc/sysctl.conf"
    echo "已添加阈值为 '$val'"
  fi

  # 应用新配置
  sysctl -p
}
# 禁止ping
set_ping_block() {
  while true; do
    clear
    echo
    # 显示当前 ping 状态
    current_status=$(sysctl net.ipv4.icmp_echo_ignore_all | awk '{print $3}')
    if [ "$current_status" -eq 1 ]; then
      echo "当前状态: 已禁用 ping"
    else
      echo "当前状态: 已启用 ping"
    fi
    echo
    echo "1. 禁用     2. 启用"
    echo
    echo "0. 返回"
    echo
    read -p "请输入选择: " choice

    case "$choice" in
    1)
      sysctl -w net.ipv4.icmp_echo_ignore_all=1
      if grep -q "^net.ipv4.icmp_echo_ignore_all" "/etc/sysctl.conf"; then
        sed -i "s/^net.ipv4.icmp_echo_ignore_all=.*/net.ipv4.icmp_echo_ignore_all=1/" "/etc/sysctl.conf"
      else
        echo "net.ipv4.icmp_echo_ignore_all=1" >>"/etc/sysctl.conf"
      fi
      sysctl -p
      ;;
    2)
      sysctl -w net.ipv4.icmp_echo_ignore_all=0
      if grep -q "^net.ipv4.icmp_echo_ignore_all" "/etc/sysctl.conf"; then
        sed -i "s/^net.ipv4.icmp_echo_ignore_all=.*/net.ipv4.icmp_echo_ignore_all=0/" "/etc/sysctl.conf"
      else
        echo "net.ipv4.icmp_echo_ignore_all=0" >>"/etc/sysctl.conf"
      fi
      sysctl -p
      ;;
    0)
      break
      ;;
    *)
      echo "无效的输入!"
      sleep 1
      ;;
    esac
  done
}
# 系统工具
hander_system_tool() {
  while true; do
    clear
    echo
    echo "1. 修改登录密码    2. 查看端口状态"
    echo
    echo "3. 修改时区        4. 修改主机名"
    echo
    echo "5. 定时任务        6. swap"
    echo
    echo "7. ll别名          8. 编辑别名"
    echo
    echo "9. 系统清理        10. swap阈值"
    echo
    echo "11. 禁ping        12. 编辑sysctl.conf"
    echo
    echo "0. 返回"
    echo
    read -p "请输入你的选择：" hd
    case $hd in
    1)
      passwd
      break_end
      ;;
    2)
      clear
      ss -tulnape
      break_end
      ;;
    3)
      change_timezone
      ;;
    4)
      change_hostname
      ;;
    5)
      hander_crontab
      ;;
    6)
      hander_swap
      ;;
    7)
      hander_bashrc_ll
      source ~/.bashrc
      ;;
    8)
      vim "$HOME/.bashrc"
      source ~/.bashrc
      ;;
    9)
      linux_clean
      break_end
      ;;
    10)
      set_swappiness
      break_end
      ;;
    11)
      set_ping_block
      ;;
    12)
      vim /etc/sysctl.conf
      sysctl -p
      ;;
    0)
      break
      ;;
    *)
      echo "无效的输入!"
      sleep 1
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
    echo "快捷键不能为空。"
    return 1
  fi

  # 定义别名命令
  ALIAS_CMD="alias $key='source <(curl -s https://raw.githubusercontent.com/zxecsm/sh/main/zxecsm.sh)'"
  ALIAS_PATTERN="alias .*='source <(curl -s https://raw.githubusercontent.com/zxecsm/sh/main/zxecsm.sh)'"

  # 检查 .bashrc 文件中是否已经存在相同的别名
  if grep -q "$ALIAS_PATTERN" "$HOME/.bashrc"; then
    # 如果存在，使用新的别名替换旧的别名
    sed -i "s|$ALIAS_PATTERN|$ALIAS_CMD|" "$HOME/.bashrc"
    echo "已更新快捷键为 '$key'"
  else
    # 如果不存在，追加新的别名
    echo "$ALIAS_CMD" >>"$HOME/.bashrc"
    echo "已添加快捷键为 '$key'"
  fi

  # 重新加载 .bashrc 文件
  source "$HOME/.bashrc"

  # 确认操作成功
  echo "快捷键已添加成功。你可以使用 '$key' 来运行命令。"

}
while true; do
  clear
  echo
  echo "1. 系统信息    2. 系统更新"
  echo
  echo "3. 常用        4. nvm"
  echo
  echo "5. 防火墙      6. 系统工具"
  echo
  echo "7. Docker      8. SSH"
  echo
  echo "9. 用户管理"
  echo
  echo "10. 重启"
  echo
  echo "00. 快捷键"
  echo
  echo "0. 退出"
  echo
  read -p "请输入你的选择: " choice
  case $choice in
  1)
    system_info
    break_end
    ;;
  2)
    clear
    linux_update
    break_end
    ;;
  3)
    hander_common
    ;;
  4)
    hander_nvm
    ;;
  5)
    hander_ufw
    ;;
  6)
    hander_system_tool
    ;;
  7)
    hander_docker
    ;;
  8)
    hander_ssh
    ;;
  9)
    hander_user
    ;;
  10)
    if confirm "确认重启服务器？"; then
      clear
      reboot
    else
      echo "操作已取消。"
      sleep 1
    fi
    ;;
  00)
    set_alias
    break_end
    ;;
  0)
    clear
    break
    ;;
  *)
    echo "无效的输入!"
    sleep 1
    ;;
  esac
done
