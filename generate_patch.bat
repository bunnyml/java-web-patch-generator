@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: Git变更文件补丁包生成脚本 (Windows版本)
:: 使用方法: generate_patch.bat 2025-02-01

set START_DATE=%1
if "%START_DATE%"=="" (
    echo 请提供开始日期，格式: YYYY-MM-DD
    echo 使用方法: generate_patch.bat 2025-02-01
    pause
    exit /b 1
)

:: 项目配置 - 请根据实际情况修改这些路径
set PROJECT_ROOT=%cd%
set SRC_MAIN_JAVA=src\main\java
set SRC_MAIN_RESOURCES=src\main\resources
set SRC_MAIN_WEBAPP=src\main\webapp
set TARGET_CLASSES=target\classes

:: 输出目录
for /f "tokens=1-4 delims=/ " %%a in ('date /t') do set mydate=%%c%%a%%b
for /f "tokens=1-2 delims=: " %%a in ('time /t') do set mytime=%%a%%b
set PATCH_DIR=patch_%mydate%_%mytime%
set WEBAPP_DIR=%PATCH_DIR%\webapp
set WEBINF_DIR=%WEBAPP_DIR%\WEB-INF
set CLASSES_DIR=%WEBINF_DIR%\classes

echo === 开始生成补丁包 ===
echo 起始日期: %START_DATE%
echo 输出目录: %PATCH_DIR%

:: 创建输出目录结构
mkdir "%WEBAPP_DIR%" 2>nul
mkdir "%CLASSES_DIR%" 2>nul
mkdir "%WEBINF_DIR%\lib" 2>nul

:: 获取变更文件列表
echo === 获取Git变更文件列表 ===
git log --name-only --pretty=format: --since="%START_DATE%" > temp_files.txt
sort temp_files.txt | uniq > changed_files.txt
del temp_files.txt

:: 检查是否有变更文件
for /f %%i in ('type changed_files.txt ^| find /c /v ""') do set file_count=%%i
if %file_count%==0 (
    echo 没有找到变更文件
    del changed_files.txt
    pause
    exit /b 1
)

echo 发现 %file_count% 个变更文件
echo.

:: 确保项目已编译
echo === 编译项目 ===
if exist "pom.xml" (
    call mvn clean compile -q
) else if exist "build.gradle" (
    call gradlew compileJava -q
) else (
    echo 警告: 未找到Maven或Gradle构建文件，请手动编译项目
)

:: 处理变更文件
echo === 处理变更文件 ===
for /f "usebackq delims=" %%f in ("changed_files.txt") do (
    set file=%%f
    if "!file!" neq "" (
        call :process_file "!file!"
    )
)

:: 生成部署说明
echo === 生成部署说明 ===
(
echo # 补丁包部署说明
echo.
echo ## 生成信息
echo - 生成时间: %date% %time%
echo - Git变更起始时间: %START_DATE%
for /f "delims=" %%i in ('git rev-parse HEAD') do echo - 当前Git提交: %%i
for /f "delims=" %%i in ('git branch --show-current') do echo - 当前分支: %%i
echo.
echo ## 部署步骤
echo.
echo ### 1. 备份服务器文件
echo 建议在部署前备份Tomcat webapps目录下的应用
echo.
echo ### 2. 停止Tomcat服务
echo 通过Tomcat管理界面或命令行停止服务
echo.
echo ### 3. 部署文件
echo 将 webapp 目录下的所有内容复制到Tomcat的webapps/你的应用名/目录下
echo.
echo ### 4. 重启Tomcat服务
echo.
echo ## 变更文件清单
) > "%PATCH_DIR%\README.md"

:: 添加变更文件列表到README
for /f "usebackq delims=" %%f in ("changed_files.txt") do (
    if "%%f" neq "" echo - %%f >> "%PATCH_DIR%\README.md"
)

:: 创建Windows部署脚本
(
echo @echo off
echo :: 自动部署脚本 ^(Windows版本^)
echo.
echo set TOMCAT_HOME=%%1
echo set APP_NAME=%%2
echo.
echo if "%%TOMCAT_HOME%%"=="" set TOMCAT_HOME=C:\apache-tomcat
echo if "%%APP_NAME%%"=="" set APP_NAME=your-app-name
echo.
echo set WEBAPP_PATH=%%TOMCAT_HOME%%\webapps\%%APP_NAME%%
echo.
echo if not exist "%%WEBAPP_PATH%%" ^(
echo     echo 错误: 未找到应用目录 %%WEBAPP_PATH%%
echo     echo 使用方法: deploy.bat [TOMCAT_HOME] [APP_NAME]
echo     pause
echo     exit /b 1
echo ^)
echo.
echo echo 开始部署到: %%WEBAPP_PATH%%
echo echo 按任意键继续，Ctrl+C取消...
echo pause ^>nul
echo.
echo :: 创建备份
echo for /f "tokens=1-4 delims=/ " %%%%a in ^('date /t'^) do set mydate=%%%%c%%%%a%%%%b
echo for /f "tokens=1-2 delims=: " %%%%a in ^('time /t'^) do set mytime=%%%%a%%%%b
echo set BACKUP_DIR=backup_%%mydate%%_%%mytime%%
echo echo 创建备份: %%BACKUP_DIR%%
echo mkdir "..\%%BACKUP_DIR%%" 2^>nul
echo xcopy "%%WEBAPP_PATH%%" "..\%%BACKUP_DIR%%\" /E /I /Q
echo.
echo :: 复制文件
echo echo 复制文件...
echo xcopy "webapp\*" "%%WEBAPP_PATH%%\" /E /Y /Q
echo.
echo echo 部署完成！
echo pause
) > "%PATCH_DIR%\deploy.bat"

:: 清理临时文件
del changed_files.txt

echo === 补丁包生成完成 ===
echo 输出目录: %PATCH_DIR%
echo.
echo 请检查 %PATCH_DIR%\README.md 获取详细的部署说明
pause
goto :eof

:: 处理单个文件的函数
:process_file
set "file_path=%~1"
echo 处理文件: %file_path%

:: 检查文件是否存在
if not exist "%file_path%" (
    echo   跳过已删除的文件: %file_path%
    goto :eof
)

:: 处理Java源文件
echo %file_path% | findstr /b "%SRC_MAIN_JAVA%" >nul
if !errorlevel!==0 (
    echo %file_path% | findstr /e ".java" >nul
    if !errorlevel!==0 (
        call :process_java_file "%file_path%"
        goto :eof
    )
)

:: 处理资源文件
echo %file_path% | findstr /b "%SRC_MAIN_RESOURCES%" >nul
if !errorlevel!==0 (
    call :process_resource_file "%file_path%"
    goto :eof
)

:: 处理webapp文件
echo %file_path% | findstr /b "%SRC_MAIN_WEBAPP%" >nul
if !errorlevel!==0 (
    call :process_webapp_file "%file_path%"
    goto :eof
)

:: 处理配置文件
echo %file_path% | findstr "web.xml" >nul
if !errorlevel!==0 (
    call :process_config_file "%file_path%"
    goto :eof
)

echo   跳过: %file_path% (未匹配的文件类型)
goto :eof

:process_java_file
set "java_file=%~1"
set "relative_path=%java_file:*%SRC_MAIN_JAVA%\=%"
set "class_path=%relative_path:.java=.class%"
set "class_file=%TARGET_CLASSES%\%class_path%"

if exist "%class_file%" (
    set "target_path=%CLASSES_DIR%\%class_path%"
    for %%i in ("!target_path!") do set "target_dir=%%~dpi"
    mkdir "!target_dir!" 2>nul
    copy "%class_file%" "!target_path!" >nul
    echo   -^> %class_path% (已编译)
) else (
    echo   -^> 警告: 未找到编译后的class文件: %class_file%
)
goto :eof

:process_resource_file
set "resource_file=%~1"
set "relative_path=%resource_file:*%SRC_MAIN_RESOURCES%\=%"
set "target_path=%CLASSES_DIR%\%relative_path%"
for %%i in ("%target_path%") do set "target_dir=%%~dpi"
mkdir "%target_dir%" 2>nul
copy "%resource_file%" "%target_path%" >nul
echo   -^> %relative_path% (资源文件)
goto :eof

:process_webapp_file
set "webapp_file=%~1"
set "relative_path=%webapp_file:*%SRC_MAIN_WEBAPP%\=%"
set "target_path=%WEBAPP_DIR%\%relative_path%"
for %%i in ("%target_path%") do set "target_dir=%%~dpi"
mkdir "%target_dir%" 2>nul
copy "%webapp_file%" "%target_path%" >nul
echo   -^> %relative_path% (webapp文件)
goto :eof

:process_config_file
set "config_file=%~1"
for %%i in ("%config_file%") do set "filename=%%~nxi"
set "target_path=%WEBINF_DIR%\%filename%"
copy "%config_file%" "%target_path%" >nul
echo   -^> WEB-INF\%filename% (配置文件)
goto :eof
