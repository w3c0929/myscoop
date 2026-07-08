@echo off
cd /d "D:\scoop\apps\comfyui\current\ComfyUI_windows_portable\ComfyUI\custom_nodes"
chcp 65001 >nul
title ComfyUI插件批量安装 xget镜像版


if not exist ".disabled" mkdir ".disabled"
echo [√] .disabled 插件禁用目录就绪
echo.

set "GH=https://github.com/"
rem set "GH=https://xget.xi-xu.me/gh/"
rem set "GH=https://xget.xi-xu.me/gl/"
rem set "GH=https://xget.xi-xu.me/gl/"
rem set "GH=https://xget.xi-xu.me/gitea/"
rem set "GH=https://xget.xi-xu.me/codeberg/"
rem set "GH=https://xget.xi-xu.me/sf/"
rem set "GH=https://xget.xi-xu.me/aosp/"



if not exist ComfyUI-DD-Translation git clone %GH%Dontdrunk/ComfyUI-DD-Translation.git ComfyUI-DD-Translation
if not exist ComfyUI-AutoModelDownloader git clone %GH%FNGarvin/ComfyUI-AutoModelDownloader.git ComfyUI-AutoModelDownloader

rem if not exist comfyui_controlnet_aux git clone %GH%Fannovel16/comfyui_controlnet_aux.git comfyui_controlnet_aux

if not exist ComfyUI-Easy-Use git clone %GH%yolain/ComfyUI-Easy-Use.git ComfyUI-Easy-Use

rem if not exist ComfyUI-Img_Tag git clone %GH%fancyfeast/ComfyUI-Img_Tag.git ComfyUI-Img_Tag

rem if not exist stepaudiotts_mw git clone %GH%stepfun-ai/ComfyUI-StepAudioTTS.git stepaudiotts_mw

rem if not exist comfyui-edgetts git clone %GH%zzz40500/ComfyUI-EdgeTTS.git comfyui-edgetts

rem if not exist ComfyUI-FreeVC_wrapper git clone %GH%voicepaw/ComfyUI-FreeVC_wrapper.git ComfyUI-FreeVC_wrapper

rem if not exist ComfyUI-Manager git clone %GH%ltdrdata/ComfyUI-Manager.git ComfyUI-Manager

rem if not exist ComfyUI-WanVideoWrapper git clone %GH%Kijai/ComfyUI-WanVideoWrapper.git ComfyUI-WanVideoWrapper

rem if not exist Comfyui_StartPatch git clone %GH%fancyfeast/ComfyUI-StartPatch.git Comfyui_StartPatch

rem if not exist ComfyUI-HunyuanLoom git clone %GH%Tencent/HunyuanLoom-ComfyUI.git ComfyUI-HunyuanLoom

rem if not exist ComfyUI-GGUF git clone %GH%city96/ComfyUI-GGUF.git ComfyUI-GGUF

rem if not exist ComfyUI-Fluxtapoz git clone %GH%fancyfeast/ComfyUI-Fluxtapoz.git ComfyUI-Fluxtapoz

rem if not exist ComfyUI-Florence2 git clone %GH%fancyfeast/ComfyUI-Florence2.git ComfyUI-Florence2

rem if not exist ComfyUI-Custom-Scripts git clone %GH%pythongosssss/ComfyUI-Custom-Scripts.git ComfyUI-Custom-Scripts

rem if not exist ComfyUI-Crystools git clone %GH%crystian/ComfyUI-Crystools.git ComfyUI-Crystools

rem if not exist ComfyUI-AdvancedLivePortrait git clone %GH%PowerHouseMan/ComfyUI-AdvancedLivePortrait.git ComfyUI-AdvancedLivePortrait

rem if not exist comfyui_ultimatesdupscale git clone %GH%ssitu/ComfyUI_UltimateSDUpscale.git comfyui_ultimatesdupscale

rem if not exist Comfyui_TTP_Toolset git clone %GH%TinyTerra/ComfyUI_TTP_Toolset.git Comfyui_TTP_Toolset

rem if not exist ComfyUI_Sonic git clone %GH%ksm26/ComfyUI_Sonic.git ComfyUI_Sonic

rem if not exist ComfyUI_SLK_joy_caption_two git clone %GH%fancyfeast/ComfyUI-SLK-Joy-Caption.git ComfyUI_SLK_joy_caption_two

rem if not exist ComfyUI_RyanOnTheInside git clone %GH%RyanOnTheInside/ComfyUI-RyanOnTheInside.git ComfyUI_RyanOnTheInside

rem if not exist ComfyUI-PuLID-Flux-Enhanced git clone %GH%guoyww/ComfyUI-PuLID-Flux-Enhanced.git ComfyUI-PuLID-Flux-Enhanced

rem if not exist ComfyUI_LayerStyle git clone %GH%chflame163/ComfyUI_LayerStyle.git ComfyUI_LayerStyle

rem if not exist ComfyUI_LayerStyle_Advance git clone %GH%chflame163/ComfyUI_LayerStyle.git ComfyUI_LayerStyle_Advance

rem if not exist ComfyUI_IPAdapter_plus git clone %GH%cubiq/ComfyUI_IPAdapter_plus.git ComfyUI_IPAdapter_plus

rem if not exist ComfyUI_essentials git clone %GH%cubiq/ComfyUI_essentials.git ComfyUI_essentials

rem if not exist ComfyUI_Comfyroll_CustomNodes git clone %GH%Suzie1/ComfyUI_Comfyroll_CustomNodes.git ComfyUI_Comfyroll_CustomNodes

rem if not exist ComfyUI_bnb_nf4_fp4_Loaders git clone %GH%fancyfeast/ComfyUI-bnb-nf4-fp4-Loaders.git ComfyUI_bnb_nf4_fp4_Loaders

rem if not exist ComfyUI-AdvancedRefluxControl git clone %GH%fancyfeast/ComfyUI-AdvancedRefluxControl.git ComfyUI-AdvancedRefluxControl

if not exist comfy_mtb git clone %GH%melMass/comfy_mtb.git comfy_mtb

rem if not exist x-flux-comfyui git clone %GH%XLabs-AI/x-flux-comfyui.git x-flux-comfyui

rem if not exist was-node-suite-comfyui git clone %GH%WASasquatch/was-node-suite-comfyui.git was-node-suite-comfyui

rem if not exist rgthree-comfy git clone %GH%rgthree/rgthree-comfy.git rgthree-comfy

rem if not exist efficiency-nodes-comfyui git clone %GH%jmchilton/efficiency-nodes-comfyui.git efficiency-nodes-comfyui

rem if not exist ComfyUI-VideoHelperSuite git clone %GH%Kosinkadink/ComfyUI-VideoHelperSuite.git ComfyUI-VideoHelperSuite

rem if not exist comfyui-tooling-nodes git clone %GH%fancyfeast/comfyui-tooling-nodes.git comfyui-tooling-nodes

rem if not exist comfyui-supir git clone %GH%kijai/ComfyUI-SUPIR.git comfyui-supir

if not exist comfyui-sixgod_prompt git clone %GH%thisjam/comfyui-sixgod_prompt.git comfyui-sixgod_prompt

rem if not exist comfyui-ollama git clone %GH%benjiamin104/comfyui-ollama.git comfyui-ollama

rem if not exist comfyui-nettools git clone %GH%fancyfeast/comfyui-nettools.git comfyui-nettools

rem if not exist ComfyUI-MVAdapter git clone %GH%Kijai/ComfyUI-MVAdapter.git ComfyUI-MVAdapter

rem if not exist ComfyUI-MMAudio git clone %GH%Kijai/ComfyUI-MMAudio.git ComfyUI-MMAudio

rem if not exist ComfyUI-MingNodes git clone %GH%ming007/ComfyUI-MingNodes.git ComfyUI-MingNodes

rem if not exist ComfyUI-LTXTricks git clone %GH%Lightricks/ComfyUI-LTXTricks.git ComfyUI-LTXTricks

rem if not exist comfyui-liveportraitkj git clone %GH%kjhuanhao/comfyui-liveportraitkj.git comfyui-liveportraitkj

rem if not exist ComfyUI-KJNodes git clone %GH%kjhuanhao/KJNodes.git ComfyUI-KJNodes

rem if not exist ComfyUI-IPAdapter-Flux git clone %GH%cubiq/ComfyUI-IPAdapter-Flux.git ComfyUI-IPAdapter-Flux

rem if not exist comfyui-inpaint-nodes git clone %GH%ltdrdata/comfyui-inpaint-nodes.git comfyui-inpaint-nodes

rem if not exist ComfyUI-Inpaint-CropAndStitch git clone %GH%fancyfeast/ComfyUI-Inpaint-CropAndStitch.git ComfyUI-Inpaint-CropAndStitch

rem if not exist ComfyUI-Impact-Pack git clone %GH%ltdrdata/ComfyUI-Impact-Pack.git ComfyUI-Impact-Pack

rem if not exist comfyui-impact-subpack git clone %GH%ltdrdata/comfyui-impact-subpack.git comfyui-impact-subpack

rem if not exist ComfyUI-IC-Light git clone %GH%fancyfeast/ComfyUI-IC-Light.git ComfyUI-IC-Light

rem if not exist comfyui-workspace-manager git clone %GH%11cafe/comfyui-workspace-manager.git comfyui-workspace-manager

rem if not exist quick-connections git clone %GH%fancyfeast/quick-connections.git quick-connections

rem if not exist ComfyUI-NodeAligner git clone %GH%fancyfeast/ComfyUI-NodeAligner.git ComfyUI-NodeAligner

echo.
echo ==============================================
echo 全部克隆执行完毕！
echo ==============================================
pause