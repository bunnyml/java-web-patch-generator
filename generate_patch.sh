#!/bin/bash

# Git变更文件补丁包生成脚本 (Mac优化版本)
# 使用方法: ./generate_patch.sh 2025-02-01

# Mac系统优化设置
export COPYFILE_DISABLE=1  # 禁用Mac的._文件生成
export COPY_EXTENDED_ATTRIBUTES_DISABLE=1  # 禁用扩展属性复制

# 配置参数
START_DATE=$1
if [ -z "$START_DATE" ]; then
    echo "请提供开始日期，格式: YYYY-MM-DD"
    echo "使用方法: ./generate_patch.sh 2025-02-01"
    exit 1
fi

# 项目配置 - 请根据实际情况修改这些路径
PROJECT_ROOT=$(pwd)
SRC_MAIN_JAVA="src/main/java"
SRC_MAIN_RESOURCES="src/main/resources"
SRC_MAIN_WEBAPP="src/main/webapp"
TARGET_CLASSES="target/classes"

# 输出目录
PATCH_DIR="patch_$(date +%Y%m%d_%H%M%S)"
WEBAPP_DIR="$PATCH_DIR/webapp"
WEBINF_DIR="$WEBAPP_DIR/WEB-INF"
CLASSES_DIR="$WEBINF_DIR/classes"

echo "=== 开始生成补丁包 ==="
echo "起始日期: $START_DATE"
echo "输出目录: $PATCH_DIR"

# 创建输出目录结构
mkdir -p "$WEBAPP_DIR"
mkdir -p "$CLASSES_DIR"
mkdir -p "$WEBINF_DIR/lib"

# 获取变更文件列表
echo "=== 获取Git变更文件列表 ==="
CHANGED_FILES=$(git log --name-only --pretty=format: --since="$START_DATE" | sort | uniq | grep -v "^$")

if [ -z "$CHANGED_FILES" ]; then
    echo "没有找到变更文件"
    exit 1
fi

echo "发现以下变更文件:"
echo "$CHANGED_FILES"
echo ""

# 确保项目已编译
echo "=== 编译项目 ==="
if [ -f "pom.xml" ]; then
    mvn clean compile -q
elif [ -f "build.gradle" ]; then
    ./gradlew compileJava -q
else
    echo "警告: 未找到Maven或Gradle构建文件，请手动编译项目"
fi

# 处理变更文件
echo "=== 处理变更文件 ==="
for file in $CHANGED_FILES; do
    # 检查文件是否存在
    if [ ! -f "$file" ]; then
        echo "跳过已删除的文件: $file"
        continue
    fi
    
    echo "处理文件: $file"
    
    # 处理Java源文件
    if [[ $file == $SRC_MAIN_JAVA/* && $file == *.java ]]; then
        # 获取相对于java源码根目录的路径
        relative_path=${file#$SRC_MAIN_JAVA/}
        # 转换为class文件路径
        class_path=${relative_path%.java}.class
        class_file="$TARGET_CLASSES/$class_path"
        
        if [ -f "$class_file" ]; then
            target_path="$CLASSES_DIR/$class_path"
            mkdir -p "$(dirname "$target_path")"
            # Mac优化: 使用rsync避免._文件
            rsync -a --exclude="._*" --exclude="*/.DS_Store" "$class_file" "$target_path"
            echo "  -> $class_path (已编译)"
        else
            echo "  -> 警告: 未找到编译后的class文件: $class_file"
        fi
    
    # 处理资源文件
    elif [[ $file == $SRC_MAIN_RESOURCES/* ]]; then
        relative_path=${file#$SRC_MAIN_RESOURCES/}
        target_path="$CLASSES_DIR/$relative_path"
        mkdir -p "$(dirname "$target_path")"
        # Mac优化: 使用rsync避免._文件
        rsync -a --exclude="._*" --exclude="*/.DS_Store" "$file" "$target_path"
        echo "  -> $relative_path (资源文件)"
    
    # 处理webapp文件 (JSP, JS, CSS, HTML等)
    elif [[ $file == $SRC_MAIN_WEBAPP/* ]]; then
        relative_path=${file#$SRC_MAIN_WEBAPP/}
        target_path="$WEBAPP_DIR/$relative_path"
        mkdir -p "$(dirname "$target_path")"
        # Mac优化: 使用rsync避免._文件
        rsync -a --exclude="._*" --exclude="*/.DS_Store" "$file" "$target_path"
        echo "  -> $relative_path (webapp文件)"
    
    # 处理web.xml等配置文件
    elif [[ $file == *web.xml ]] || [[ $file == *spring*.xml ]] || [[ $file == *mybatis*.xml ]]; then
        target_path="$WEBINF_DIR/$(basename "$file")"
        # Mac优化: 使用rsync避免._文件
        rsync -a --exclude="._*" --exclude="*/.DS_Store" "$file" "$target_path"
        echo "  -> WEB-INF/$(basename "$file") (配置文件)"
    
    else
        echo "  -> 跳过: $file (未匹配的文件类型)"
    fi
done

# 生成部署说明
cat > "$PATCH_DIR/README.md" << EOF
# 补丁包部署说明

## 生成信息
- 生成时间: $(date)
- Git变更起始时间: $START_DATE
- 当前Git提交: $(git rev-parse HEAD)
- 当前分支: $(git branch --show-current)

## 部署步骤

### 1. 备份服务器文件
建议在部署前备份Tomcat webapps目录下的应用

### 2. 停止Tomcat服务
\`\`\`bash
sudo systemctl stop tomcat
# 或
sudo service tomcat stop
\`\`\`

### 3. 部署文件
将 webapp 目录下的所有内容复制到Tomcat的webapps/你的应用名/目录下
\`\`\`bash
# 示例 (请替换为实际的应用名)
cp -r webapp/* /path/to/tomcat/webapps/your-app-name/
\`\`\`

### 4. 重启Tomcat服务
\`\`\`bash
sudo systemctl start tomcat
# 或
sudo service tomcat start
\`\`\`

## 变更文件清单
EOF

# 将变更文件列表添加到README
echo "$CHANGED_FILES" | while read -r file; do
    if [ -n "$file" ]; then
        echo "- $file" >> "$PATCH_DIR/README.md"
    fi
done

# 创建部署脚本
cat > "$PATCH_DIR/deploy.sh" << 'EOF'
#!/bin/bash
# 自动部署脚本 (Mac优化版本)

# Mac系统优化设置
export COPYFILE_DISABLE=1
export COPY_EXTENDED_ATTRIBUTES_DISABLE=1

TOMCAT_HOME=${1:-"/usr/local/tomcat"}
APP_NAME=${2:-"your-app-name"}
WEBAPP_PATH="$TOMCAT_HOME/webapps/$APP_NAME"

if [ ! -d "$WEBAPP_PATH" ]; then
    echo "错误: 未找到应用目录 $WEBAPP_PATH"
    echo "使用方法: ./deploy.sh [TOMCAT_HOME] [APP_NAME]"
    exit 1
fi

echo "开始部署到: $WEBAPP_PATH"
echo "按Enter继续，Ctrl+C取消..."
read

# 备份
BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"
echo "创建备份: $BACKUP_DIR"
mkdir -p "../$BACKUP_DIR"
# Mac优化: 使用rsync进行备份，排除系统文件
rsync -a --exclude="._*" --exclude=".DS_Store" --exclude="PaxHeader*" "$WEBAPP_PATH/" "../$BACKUP_DIR/"

# 停止Tomcat
echo "停止Tomcat..."
sudo systemctl stop tomcat 2>/dev/null || sudo service tomcat stop 2>/dev/null

# 复制文件 (Mac优化)
echo "复制文件..."
rsync -a --exclude="._*" --exclude=".DS_Store" --exclude="PaxHeader*" webapp/ "$WEBAPP_PATH/"

# 启动Tomcat
echo "启动Tomcat..."
sudo systemctl start tomcat 2>/dev/null || sudo service tomcat start 2>/dev/null

echo "部署完成！"
EOF

chmod +x "$PATCH_DIR/deploy.sh"

# Mac系统清理函数
cleanup_mac_files() {
    echo "=== 清理Mac系统文件 ==="
    # 删除._文件
    find "$PATCH_DIR" -name "._*" -type f -delete
    # 删除.DS_Store文件
    find "$PATCH_DIR" -name ".DS_Store" -type f -delete
    # 删除PaxHeader目录
    find "$PATCH_DIR" -name "PaxHeader" -type d -exec rm -rf {} + 2>/dev/null || true
    echo "Mac系统文件清理完成"
}

# 执行清理
cleanup_mac_files

# 生成压缩包 (Mac优化版本)
echo "=== 生成压缩包 ==="
# 设置tar格式为ustar避免PaxHeader，并排除Mac特有文件
GNUTAR=$(which gtar 2>/dev/null)
if [ -n "$GNUTAR" ] && [ -x "$GNUTAR" ]; then
    # 如果安装了GNU tar，使用它
    "$GNUTAR" --format=ustar --exclude="._*" --exclude=".DS_Store" --exclude="PaxHeader*" -czf "${PATCH_DIR}.tar.gz" "$PATCH_DIR"
else
    # 使用系统默认tar，但加上Mac优化参数
    tar --exclude="._*" --exclude=".DS_Store" --exclude="PaxHeader*" -czf "${PATCH_DIR}.tar.gz" "$PATCH_DIR"
fi

echo "=== 补丁包生成完成 ==="
echo "输出目录: $PATCH_DIR"
echo "压缩包: ${PATCH_DIR}.tar.gz"
echo ""
echo "请检查 $PATCH_DIR/README.md 获取详细的部署说明"
