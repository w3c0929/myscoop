@echo off
set HF_ENDPOINT=https://hf-mirror.com
cd /d "D:\scoop\apps\comfyui\current\ComfyUI_windows_portable"
python_embeded\python.exe -s ComfyUI\main.py --windows-standalone-build --listen 0.0.0.0 --port 8188