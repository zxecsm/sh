`/home/xxx/b.sh`

```bash
#!/bin/bash

# 读取历史目录文件
history_file="$HOME/.cd_history"

# 如果历史文件存在并且不为空，获取历史目录
if [ -f "$history_file" ] && [ -s "$history_file" ]; then
    DIRS=($(tail -n 10 "$history_file"))
else
    echo '无目录历史'
    return
fi

# 进入选择目录的循环
while true; do
    # 列出可选目录
    for i in "${!DIRS[@]}"; do
        echo "$((i + 1))) => ${DIRS[i]}"
    done
    echo "0) 取消"

    read -r choice

    # 校验用户的输入
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#DIRS[@]}" ]; then
        break
    fi

    # 获取选择的目录
    TARGET_DIR="${DIRS[choice - 1]}"

    # 跳转到目标目录
    if [ -d "$TARGET_DIR" ]; then
        cd "$TARGET_DIR" || echo "跳转失败"
        break
    else
        echo "跳转失败：目录不存在。"
    fi
done
```

`/home/xxx/.bashrc`

```bash
alias d='source /home/xxx/d.sh'
function cd() {
    # 先执行 cd 命令
    builtin cd "$@" || return 1
    
    # 获取当前目录
    local current_dir=$(pwd)
    
    # 历史记录文件
    local history_file="$HOME/.cd_history"
    
    # 如果历史记录文件不存在，创建一个空文件
    if [ ! -f "$history_file" ]; then
        touch "$history_file"
    fi
    
    # 删除历史记录文件中与当前目录相同的条目
    sed -i "\|^$current_dir$|d" "$history_file"
    
    # 在文件中添加当前目录
    echo "$current_dir" >> "$history_file"
    
    # 限制历史记录的个数
    local max_entries=20
    local num_entries=$(wc -l < "$history_file")
    
    if [ "$num_entries" -gt "$max_entries" ]; then
        # 删除最旧的目录（第一个目录）
        sed -i '1d' "$history_file"
    fi
}
```

```bash
source ~/.bashrc
```
