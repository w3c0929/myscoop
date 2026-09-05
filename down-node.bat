@echo off
chcp 65001 >nul
title ComfyUI插件批量安装 xget镜像版（增强代理）

:: ===================================================================
:: 1. 基础路径设置（请修改为您的 ComfyUI 实际路径）
:: ===================================================================
cd /d "D:\scoop\apps\comfyui\current\ComfyUI_windows_portable\ComfyUI\custom_nodes" || (
    echo 错误：无法进入目标目录，请检查路径！
    pause
    exit /b
)

:: 创建插件禁用目录（如有需要可放置 .disabled 文件）
if not exist ".disabled" mkdir ".disabled"
echo [√] .disabled 插件禁用目录就绪
echo.

:: ===================================================================
:: 2. 加速代理配置（您只需修改下面几个 set 变量）
:: ===================================================================
:: PL  = 代理列表（按优先级，空格分隔），可自由增删
set PL=hk.gh-proxy.org gh-proxy.com gh-proxy.org

:: TO  = 检测代理是否可用的超时（秒），网络慢时可调大
set TO=6

:: TU  = 用于测试代理的 URL（一般固定为 GitHub 首页）
set TU=https://github.com/

:: VB  = 是否显示代理检测详细信息（1=显示，0=静默）
set VB=1

:: 自动选择第一个可用代理，结果存入 GP（若全失败则 GP 为空）
call :sp
if "%GP%"=="" (
    echo [警告] 所有代理不可用，将使用直连（可能较慢）
    set "GP="
) else (
    echo [信息] 使用代理: %GP%
)
set "GH=https://github.com/"
echo.
:: ===================================================================
:: 3. 通用下载函数（按需调用，不会自动执行）
::    用法示例：
::       call :dr "owner/repo/path/file.ext" "local_file.ext"
::       call :drl "owner/repo" "v1.0" "release.zip"
::       call :dg "gist_id" "filename" "output"
::    它们都自动使用上面选中的代理 %GP%
:: ===================================================================
goto :plugin_start   :: 跳过函数定义，直接执行插件克隆

:sp   :: 自动选择代理（内部函数，无需手动调用）
set "GP="
for %%p in (%PL%) do (
    set "test_url=https://%%p/%TU%"
    if %VB%==1 echo 检测代理: %%p ...
    curl -s -o nul -w "%%{http_code}" --connect-timeout %TO% "!test_url!" | find "200" >nul
    if errorlevel 1 (
        if %VB%==1 echo 代理 %%p 不可用
    ) else (
        set "GP=https://%%p/"
        if %VB%==1 echo 代理 %%p 可用
        goto :pf
    )
)
:pf
set "test_url="
exit /b

:dr   :: 下载 raw 文件 (download raw)
set "url=%GP%https://raw.githubusercontent.com/%~1"
curl -L -o "%~2" "%url%" --connect-timeout %TO%
exit /b

:drl  :: 下载 Release 压缩包并自动解压 (download release)
set "url=%GP%https://github.com/%~1/archive/refs/tags/%~2.zip"
curl -L -o "%~3" "%url%" --connect-timeout %TO%
if exist "%~3" powershell -command "Expand-Archive -Path '%~3' -DestinationPath '.' -Force"
exit /b

:dg   :: 下载 Gist 内容 (download gist)
set "url=%GP%https://gist.githubusercontent.com/%~1/raw/%~2"
curl -L -o "%~3" "%url%" --connect-timeout %TO%
exit /b

:plugin_start
:: ===================================================================
:: 4. 插件安装列表（取消注释即安装，注释即跳过）
::    格式：if not exist 文件夹名 git clone %GP%%GH%用户名/仓库名.git 文件夹名
::    注意：文件夹名必须与仓库名一致（即最后一个斜杠后的部分）
:: ===================================================================
rem if not exist ComfyUI-DD-Translation git clone %GP%%GH%Dontdrunk/ComfyUI-DD-Translation.git ComfyUI-DD-Translation
rem if not exist ComfyUI-AutoModelDownloader git clone %GP%%GH%FNGarvin/ComfyUI-AutoModelDownloader.git ComfyUI-AutoModelDownloader

rem if not exist comfyui_controlnet_aux git clone %GP%%GH%Fannovel16/comfyui_controlnet_aux.git comfyui_controlnet_aux

rem if not exist ComfyUI-Easy-Use git clone %GP%%GH%yolain/ComfyUI-Easy-Use.git ComfyUI-Easy-Use

rem if not exist ComfyUI-Img_Tag git clone %GP%%GH%fancyfeast/ComfyUI-Img_Tag.git ComfyUI-Img_Tag

rem if not exist stepaudiotts_mw git clone %GP%%GH%stepfun-ai/ComfyUI-StepAudioTTS.git stepaudiotts_mw

rem if not exist comfyui-edgetts git clone %GP%%GH%zzz40500/ComfyUI-EdgeTTS.git comfyui-edgetts

rem if not exist ComfyUI-FreeVC_wrapper git clone %GP%%GH%voicepaw/ComfyUI-FreeVC_wrapper.git ComfyUI-FreeVC_wrapper

rem if not exist ComfyUI-Manager git clone %GP%%GH%ltdrdata/ComfyUI-Manager.git ComfyUI-Manager

rem if not exist ComfyUI-WanVideoWrapper git clone %GP%%GH%Kijai/ComfyUI-WanVideoWrapper.git ComfyUI-WanVideoWrapper

rem if not exist Comfyui_StartPatch git clone %GP%%GH%fancyfeast/ComfyUI-StartPatch.git Comfyui_StartPatch

rem if not exist ComfyUI-HunyuanLoom git clone %GP%%GH%Tencent/HunyuanLoom-ComfyUI.git ComfyUI-HunyuanLoom

rem if not exist ComfyUI-GGUF git clone %GP%%GH%city96/ComfyUI-GGUF.git ComfyUI-GGUF

rem if not exist ComfyUI-Fluxtapoz git clone %GP%%GH%fancyfeast/ComfyUI-Fluxtapoz.git ComfyUI-Fluxtapoz

rem if not exist ComfyUI-Florence2 git clone %GP%%GH%fancyfeast/ComfyUI-Florence2.git ComfyUI-Florence2

rem if not exist ComfyUI-Custom-Scripts git clone %GP%%GH%pythongosssss/ComfyUI-Custom-Scripts.git ComfyUI-Custom-Scripts

rem if not exist ComfyUI-Crystools git clone %GP%%GH%crystian/ComfyUI-Crystools.git ComfyUI-Crystools

rem if not exist ComfyUI-AdvancedLivePortrait git clone %GP%%GH%PowerHouseMan/ComfyUI-AdvancedLivePortrait.git ComfyUI-AdvancedLivePortrait

rem if not exist comfyui_ultimatesdupscale git clone %GP%%GH%ssitu/ComfyUI_UltimateSDUpscale.git comfyui_ultimatesdupscale

rem if not exist Comfyui_TTP_Toolset git clone %GP%%GH%TinyTerra/ComfyUI_TTP_Toolset.git Comfyui_TTP_Toolset

rem if not exist ComfyUI_Sonic git clone %GP%%GH%ksm26/ComfyUI_Sonic.git ComfyUI_Sonic

rem if not exist ComfyUI_SLK_joy_caption_two git clone %GP%%GH%fancyfeast/ComfyUI-SLK-Joy-Caption.git ComfyUI_SLK_joy_caption_two

rem if not exist ComfyUI_RyanOnTheInside git clone %GP%%GH%RyanOnTheInside/ComfyUI-RyanOnTheInside.git ComfyUI_RyanOnTheInside

rem if not exist ComfyUI-PuLID-Flux-Enhanced git clone %GP%%GH%guoyww/ComfyUI-PuLID-Flux-Enhanced.git ComfyUI-PuLID-Flux-Enhanced

rem if not exist ComfyUI_LayerStyle git clone %GP%%GH%chflame163/ComfyUI_LayerStyle.git ComfyUI_LayerStyle

rem if not exist ComfyUI_LayerStyle_Advance git clone %GP%%GH%chflame163/ComfyUI_LayerStyle.git ComfyUI_LayerStyle_Advance

rem if not exist ComfyUI_IPAdapter_plus git clone %GP%%GH%cubiq/ComfyUI_IPAdapter_plus.git ComfyUI_IPAdapter_plus

rem if not exist ComfyUI_essentials git clone %GP%%GH%cubiq/ComfyUI_essentials.git ComfyUI_essentials

rem if not exist ComfyUI_Comfyroll_CustomNodes git clone %GP%%GH%Suzie1/ComfyUI_Comfyroll_CustomNodes.git ComfyUI_Comfyroll_CustomNodes

rem if not exist ComfyUI_bnb_nf4_fp4_Loaders git clone %GP%%GH%fancyfeast/ComfyUI-bnb-nf4-fp4-Loaders.git ComfyUI_bnb_nf4_fp4_Loaders

rem if not exist ComfyUI-AdvancedRefluxControl git clone %GP%%GH%fancyfeast/ComfyUI-AdvancedRefluxControl.git ComfyUI-AdvancedRefluxControl

rem if not exist comfy_mtb git clone %GP%%GH%melMass/comfy_mtb.git comfy_mtb

rem if not exist x-flux-comfyui git clone %GP%%GH%XLabs-AI/x-flux-comfyui.git x-flux-comfyui

rem if not exist was-node-suite-comfyui git clone %GP%%GH%WASasquatch/was-node-suite-comfyui.git was-node-suite-comfyui

rem if not exist rgthree-comfy git clone %GP%%GH%rgthree/rgthree-comfy.git rgthree-comfy

rem if not exist efficiency-nodes-comfyui git clone %GP%%GH%jmchilton/efficiency-nodes-comfyui.git efficiency-nodes-comfyui

rem if not exist ComfyUI-VideoHelperSuite git clone %GP%%GH%Kosinkadink/ComfyUI-VideoHelperSuite.git ComfyUI-VideoHelperSuite

rem if not exist comfyui-tooling-nodes git clone %GP%%GH%fancyfeast/comfyui-tooling-nodes.git comfyui-tooling-nodes

rem if not exist comfyui-supir git clone %GP%%GH%kijai/ComfyUI-SUPIR.git comfyui-supir

rem if not exist comfyui-sixgod_prompt git clone %GP%%GH%thisjam/comfyui-sixgod_prompt.git comfyui-sixgod_prompt

rem if not exist comfyui-ollama git clone %GP%%GH%benjiamin104/comfyui-ollama.git comfyui-ollama

rem if not exist comfyui-nettools git clone %GP%%GH%fancyfeast/comfyui-nettools.git comfyui-nettools

rem if not exist ComfyUI-MVAdapter git clone %GP%%GH%Kijai/ComfyUI-MVAdapter.git ComfyUI-MVAdapter

rem if not exist ComfyUI-MMAudio git clone %GP%%GH%Kijai/ComfyUI-MMAudio.git ComfyUI-MMAudio

rem if not exist ComfyUI-MingNodes git clone %GP%%GH%ming007/ComfyUI-MingNodes.git ComfyUI-MingNodes

rem if not exist ComfyUI-LTXTricks git clone %GP%%GH%Lightricks/ComfyUI-LTXTricks.git ComfyUI-LTXTricks

rem if not exist comfyui-liveportraitkj git clone %GP%%GH%kjhuanhao/comfyui-liveportraitkj.git comfyui-liveportraitkj

rem if not exist ComfyUI-KJNodes git clone %GP%%GH%kjhuanhao/KJNodes.git ComfyUI-KJNodes

rem if not exist ComfyUI-IPAdapter-Flux git clone %GP%%GH%cubiq/ComfyUI-IPAdapter-Flux.git ComfyUI-IPAdapter-Flux

rem if not exist comfyui-inpaint-nodes git clone %GP%%GH%ltdrdata/comfyui-inpaint-nodes.git comfyui-inpaint-nodes

rem if not exist ComfyUI-Inpaint-CropAndStitch git clone %GP%%GH%fancyfeast/ComfyUI-Inpaint-CropAndStitch.git ComfyUI-Inpaint-CropAndStitch

rem if not exist ComfyUI-Impact-Pack git clone %GP%%GH%ltdrdata/ComfyUI-Impact-Pack.git ComfyUI-Impact-Pack

rem if not exist comfyui-impact-subpack git clone %GP%%GH%ltdrdata/comfyui-impact-subpack.git comfyui-impact-subpack

rem if not exist ComfyUI-IC-Light git clone %GP%%GH%fancyfeast/ComfyUI-IC-Light.git ComfyUI-IC-Light

rem if not exist comfyui-workspace-manager git clone %GP%%GH%11cafe/comfyui-workspace-manager.git comfyui-workspace-manager

rem if not exist quick-connections git clone %GP%%GH%fancyfeast/quick-connections.git quick-connections

rem if not exist ComfyUI-NodeAligner git clone %GP%%GH%fancyfeast/ComfyUI-NodeAligner.git ComfyUI-NodeAligner

echo.
echo ==============================================
echo 全部克隆执行完毕！
echo ==============================================
pause
exit /b