@echo off

:start

cls

echo,

echo 修改右键菜单模式

echo,

echo 1 穿越到Windows 10默认模式

echo,

echo 2 恢复为Windows 11默认模式

echo,

echo 0 什么也不做，退出

echo,

echo,

choice /c:120 /n /m:"请选择要进行的操作（1/2/0）："

if %errorlevel%==0 exit

if %errorlevel%==2 goto cmd2

if %errorlevel%==1 goto cmd1

exit

:cmd1

reg.exe add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve

taskkill /f /im explorer.exe

start explorer.exe

exit

:cmd2

reg.exe delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f

taskkill /f /im explorer.exe

start explorer.exe

exit