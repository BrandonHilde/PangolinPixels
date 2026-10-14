@echo off
rem Builds PangolinPixels.exe (requires the Odin compiler on PATH; raylib ships with Odin's vendor: collection)
odin build src -out:PangolinPixels.exe -o:speed
if errorlevel 1 exit /b 1
echo Built PangolinPixels.exe
