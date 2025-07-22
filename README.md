# java-web-patch-generator
基于 Git 变更的 Java Web 应用程序自动补丁生成器。通过智能文件映射和跨平台支持，为 Tomcat 生成可部署的软件包。

基于Git变更历史生成可直接部署到Tomcat的补丁包，支持：
- 自动识别变更的Java、JSP、JS、CSS等文件
- 将Java源码编译并映射到WEB-INF/classes目录结构
- 将前端资源映射到正确的webapp目录结构
- 生成部署脚本和说明文档

## 前置要求

### 必需环境
- Git (已配置并能正常使用，确认所有变更已合并到master分支)
- Java开发环境 (JDK)
- Maven或Gradle (用于编译Java代码)

### 项目结构要求
你的项目应该遵循标准的Maven/Gradle目录结构：
```
your-project/
├── src/
│   └── main/
│       ├── java/           # Java源码
│       ├── resources/      # 资源文件
│       └── webapp/         # Web资源(JSP, JS, CSS等)
├── target/classes/         # 编译输出(Maven)
├── build/classes/          # 编译输出(Gradle)
├── pom.xml                 # Maven配置
└── build.gradle           # Gradle配置
```

## 使用步骤

### 1. 下载脚本（注意：脚本文件应该放置在项目根目录中）
根据你的操作系统选择对应的脚本：
- Linux/Mac: `generate_patch.sh`
- Windows: `generate_patch.bat`

### 2. 配置脚本参数
编辑脚本中的项目配置部分，确保路径正确：

```bash
# Linux/Mac版本中需要确认的配置
SRC_MAIN_JAVA="src/main/java"
SRC_MAIN_RESOURCES="src/main/resources"  
SRC_MAIN_WEBAPP="src/main/webapp"
TARGET_CLASSES="target/classes"  # Maven用这个
# TARGET_CLASSES="build/classes/java/main"  # Gradle用这个
```

### 3. 运行脚本（自定义起始日期），注意运行脚本前请确保项目已经编译
```bash
# Linux/Mac
chmod +x generate_patch.sh
./generate_patch.sh 2025-02-01

# Windows
generate_patch.bat 2025-02-01
```

### 4. 检查输出
脚本会生成以下内容：
```
patch_20250721_143022/
├── webapp/                 # 完整的webapp目录结构
│   ├── WEB-INF/
│   │   ├── classes/       # 编译后的Java类和资源文件
│   │   └── lib/           # 依赖库目录(预留)
│   ├── js/               # 前端JavaScript文件
│   ├── css/              # 样式文件
│   ├── images/           # 图片资源
│   └── *.jsp             # JSP页面
├── README.md             # 部署说明
├── deploy.sh             # 自动部署脚本(Linux)
└── deploy.bat            # 自动部署脚本(Windows)
```

## 部署流程

### 手动部署
1. 停止Tomcat服务
2. 备份当前应用目录
3. 将`patch_xxx/webapp/`下的所有内容复制到Tomcat的`webapps/你的应用名/`目录
4. 重启Tomcat服务

### 自动部署(不推荐)
```bash
# Linux/Mac
cd patch_20250721_143022
chmod +x deploy.sh
./deploy.sh /path/to/tomcat your-app-name

# Windows  
cd patch_20250721_143022
deploy.bat C:\apache-tomcat your-app-name
```

## 文件类型处理说明

### Java源文件 (.java)
- **源路径**: `src/main/java/com/example/Controller.java`
- **编译后**: `target/classes/com/example/Controller.class`
- **输出路径**: `webapp/WEB-INF/classes/com/example/Controller.class`

### 资源文件 (.properties, .xml等)
- **源路径**: `src/main/resources/config.properties`
- **输出路径**: `webapp/WEB-INF/classes/config.properties`

### JSP文件 (.jsp)
- **源路径**: `src/main/webapp/views/user.jsp`
- **输出路径**: `webapp/views/user.jsp`

### 前端资源 (.js, .css, .html)
- **源路径**: `src/main/webapp/static/js/app.js`
- **输出路径**: `webapp/static/js/app.js`

### 配置文件 (web.xml等)
- **源路径**: `src/main/webapp/WEB-INF/web.xml`
- **输出路径**: `webapp/WEB-INF/web.xml`

## 高级配置

### 自定义文件处理规则
你可以修改脚本来处理特殊的文件类型或路径映射：

```bash
# 在脚本中添加新的文件处理逻辑
elif [[ $file == *.properties ]] && [[ $file == config/* ]]; then
    # 特殊配置文件处理
    target_path="$WEBINF_DIR/$(basename "$file")"
    cp "$file" "$target_path"
    echo "  -> WEB-INF/$(basename "$file") (特殊配置)"
```

### 排除特定文件
如果需要排除某些文件，可以添加过滤条件：

```bash
# 跳过测试文件
if [[ $file == *Test.java ]] || [[ $file == *test* ]]; then
    echo "  -> 跳过测试文件: $file"
    continue
fi
```

## 常见问题解决

### 1. 找不到编译后的class文件
**问题**: 脚本提示"未找到编译后的class文件"
**解决**: 
- 确保项目已经编译：`mvn compile` 或 `gradle compileJava`
- 检查`TARGET_CLASSES`路径配置是否正确
- 对于Gradle项目，class文件通常在`build/classes/java/main/`

### 2. Git日期格式问题
**问题**: Git日期解析错误
**解决**: 确保日期格式为`YYYY-MM-DD`，例如`2025-02-01`

### 3. 权限问题(Linux/Mac)
**问题**: 脚本无法执行
**解决**: 
```bash
chmod +x generate_patch.sh
chmod +x deploy.sh
```

### 4. 中文路径问题(Windows)
**问题**: 包含中文的文件路径处理异常
**解决**: 
- 确保项目路径不包含中文字符
- 或使用PowerShell版本的脚本

### 5. Maven多模块项目
**问题**: 多模块项目编译输出分散在不同目录
**解决**: 修改脚本中的`TARGET_CLASSES`变量，支持多个路径：
```bash
TARGET_CLASSES_PATHS=("module1/target/classes" "module2/target/classes")
```


依赖库处理
如果项目依赖发生变化，可以添加lib目录处理：
```bash
# 复制新的依赖jar包
if [ -d "target/dependency" ]; then
    cp target/dependency/*.jar "$WEBINF_DIR/lib/"
fi
```


