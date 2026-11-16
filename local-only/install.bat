@echo off
rem local-only: Fragt Organisations_Name, Model_Name, Model_Url und Windows_Username ab, erzeugt opencode.jsonc aus
rem der Vorlage opencode.jsonc_template neben diesem Skript und kopiert sie nach
rem C:\Users\<Windows_Username>\.config\opencode\. Testfassung fuer macOS/Linux: install.sh (gleiche Ablaeufe).
rem Die Vorlage wird nie geaendert; eine vorhandene opencode.jsonc wird an beiden Orten vorher als
rem opencode.jsonc.bak gesichert (ueberschreibt die Sicherung des vorigen Laufs).
rem Benutzereingaben nie mit %...% expandieren (& | < > wuerden ausgefuehrt), nur ueber $env: in PowerShell lesen.
setlocal
cd /d "%~dp0"

if not exist "opencode.jsonc_template" (
  echo Error: opencode.jsonc_template not found next to install.bat.
  goto fail
)

:ask_org
set "Organisations_Name="
set /p "Organisations_Name=Organisations_Name: "
if not defined Organisations_Name goto ask_org

:ask_model
set "Model_Name="
set /p "Model_Name=Model_Name: "
if not defined Model_Name goto ask_model

:ask_url
set "Model_Url="
set /p "Model_Url=Model_Url: "
if not defined Model_Url goto ask_url

rem Enter = angemeldeter Benutzer
set "Windows_Username="
set /p "Windows_Username=Windows_Username [%USERNAME%]: "
if not defined Windows_Username set "Windows_Username=%USERNAME%"

rem Pruefen vor dem Backup, wie in install.sh. Werte landen in JSON-Strings: " und \ wuerden die Datei zerstoeren.
rem Benutzername: in Windows verbotene Zeichen ablehnen (verhindert auch Pfade wie ..\x); C:\Users\<Windows_Username>
rem muss existieren (wird nie angelegt, sonst entstuende bei Tippfehlern still ein falscher Ordner).
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$values = @($env:Organisations_Name, $env:Model_Name, $env:Model_Url);" ^
  "if ($values | Where-Object { $_.IndexOfAny([char[]](34, 92)) -ge 0 }) { [Console]::Error.WriteLine('Error: values must not contain double quotes or backslashes.'); exit 1 }" ^
  "if ($env:Model_Url -notmatch '^https?://') { [Console]::Error.WriteLine('Error: Model_Url must start with http:// or https://.'); exit 1 }" ^
  "if ($env:Windows_Username -match '[\\/:*?<>|\[\];=,+]' -or $env:Windows_Username.Contains([char]34) -or $env:Windows_Username.Trim('.') -eq '') { [Console]::Error.WriteLine('Error: invalid Windows_Username.'); exit 1 }" ^
  "if (-not (Test-Path -LiteralPath (Join-Path 'C:\Users' $env:Windows_Username) -PathType Container)) { [Console]::Error.WriteLine('Error: C:\Users\' + $env:Windows_Username + ' does not exist.'); exit 1 }"
if errorlevel 1 goto fail

if exist "opencode.jsonc" (
  copy /y "opencode.jsonc" "opencode.jsonc.bak" >nul || goto fail
  echo Backup: opencode.jsonc.bak
)

rem Woertlich ersetzen (String.Replace, keine Regex); UTF-8 ohne BOM lesen und schreiben, Zeilenenden bleiben erhalten
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop';" ^
  "$enc = New-Object System.Text.UTF8Encoding $false;" ^
  "$text = [IO.File]::ReadAllText((Join-Path (Get-Location) 'opencode.jsonc_template'), $enc);" ^
  "$text = $text.Replace('Organisation LLM', $env:Organisations_Name).Replace('model-id', $env:Model_Name).Replace('http://llm.intern:8000/v1', $env:Model_Url);" ^
  "[IO.File]::WriteAllText((Join-Path (Get-Location) 'opencode.jsonc'), $text, $enc)"
if errorlevel 1 goto fail
echo Written: opencode.jsonc

rem Nach C:\Users\<Windows_Username>\.config\opencode kopieren; nur .config\opencode wird bei Bedarf angelegt,
rem vorhandene Datei dort ebenfalls als .bak sichern
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop';" ^
  "$dir = Join-Path (Join-Path 'C:\Users' $env:Windows_Username) '.config\opencode';" ^
  "$target = Join-Path $dir 'opencode.jsonc';" ^
  "New-Item -ItemType Directory -Force -Path $dir | Out-Null;" ^
  "if (Test-Path -LiteralPath $target) { Copy-Item -LiteralPath $target -Destination ($target + '.bak') -Force; Write-Host ('Backup: ' + $target + '.bak') }" ^
  "Copy-Item -LiteralPath 'opencode.jsonc' -Destination $target -Force;" ^
  "Write-Host ('Copied to: ' + $target)"
if errorlevel 1 goto fail

pause
exit /b 0

:fail
pause
exit /b 1
