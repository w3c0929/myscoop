@echo off
set HF_ENDPOINT=https://aifasthub.com
cd /d "D:\scoop\apps\comfyui\current\"
python_embeded\python.exe -s ComfyUI\main.py --windows-standalone-build --enable-manager --listen 0.0.0.0 --port 8188