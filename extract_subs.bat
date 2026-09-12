@echo off
setlocal enabledelayedexpansion

for %%F in (*.mkv *.mp4) do (
	echo Extracting subtitle from %%F
	ffmpeg -i "%%F" -map 0:s:0? -map_metadata 0 -c:s copy "%%~nF.srt"
)

pause
