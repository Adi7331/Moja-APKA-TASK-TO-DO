@echo off
set "APP=%~dp0build\windows\x64\runner\Release\dzien_po_dniu.exe"
if not exist "%APP%" set "APP=%~dp0build\windows\x64\runner\Debug\dzien_po_dniu.exe"
if not exist "%APP%" (
  echo Nie znaleziono zbudowanej aplikacji Windows.
  echo Uruchom: flutter build windows
  pause
  exit /b 1
)
start "Dzien po dniu" "%APP%"
