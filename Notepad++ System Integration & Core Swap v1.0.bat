@echo off
if not "%~1"=="__wrapped__" (
    cmd /k call "%~f0" __wrapped__
    exit /b
)

setlocal
title Notepad++ System Integration ^& Core Swap v1.0
color 0A
echo ========================================================
echo  Notepad++ System Integration ^& Core Swap v1.0
echo ========================================================
echo.

:: --------------------------------------------------------
:: Ensure Administrator privileges
:: --------------------------------------------------------
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Administrative privileges required.
    echo Right-click this script and select "Run as administrator".
    goto :end
)

:: --------------------------------------------------------
:: Verify winget availability
:: --------------------------------------------------------
echo [PRE-CHECK] Verifying winget availability...
winget --version >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] winget is not available on this system.
    echo Install App Installer from the Microsoft Store.
    goto :end
)
echo [OK] winget found.
echo.

:: ========================================================
:: STEP 1: Install Notepad++ via winget (skip if found)
:: ========================================================
set "NP_FOUND="
for /f "delims=" %%i in ('where notepad++ 2^>nul') do set "NP_FOUND=1"
if defined NP_FOUND goto :skip_winget
if exist "%ProgramFiles%\Notepad++\notepad++.exe" goto :skip_winget
if exist "%ProgramFiles(x86)%\Notepad++\notepad++.exe" goto :skip_winget
for /f "tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Notepad++" /v "InstallLocation" 2^>nul ^| findstr /i "InstallLocation"') do (
    if exist "%%b\notepad++.exe" goto :skip_winget
)

echo [1/8] Installing Notepad++ via winget...
winget install --id Notepad++.Notepad++ --exact --silent --accept-package-agreements --accept-source-agreements
if %errorLevel% neq 0 (
    echo [WARN] winget returned an error. Continuing anyway...
)
goto :after_winget

:skip_winget
echo [1/8] Notepad++ already installed -- skipping winget.

:after_winget
echo.

:: ========================================================
:: STEP 2: Resolve Notepad++ install path
:: ========================================================
echo [2/8] Resolving Notepad++ install path...
set "NP_PATH="
for /f "delims=" %%i in ('where notepad++ 2^>nul') do (
    if not defined NP_PATH set "NP_PATH=%%i"
)
if not defined NP_PATH (
    if exist "%ProgramFiles%\Notepad++\notepad++.exe" (
        set "NP_PATH=%ProgramFiles%\Notepad++\notepad++.exe"
    )
)
if not defined NP_PATH (
    if exist "%ProgramFiles(x86)%\Notepad++\notepad++.exe" (
        set "NP_PATH=%ProgramFiles(x86)%\Notepad++\notepad++.exe"
    )
)
if not defined NP_PATH (
    for /f "tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Notepad++" /v "InstallLocation" 2^>nul ^| findstr /i "InstallLocation"') do (
        if exist "%%b\notepad++.exe" set "NP_PATH=%%b\notepad++.exe"
    )
)
if not defined NP_PATH (
    echo [ERROR] Could not locate notepad++.exe.
    goto :end
)
echo [OK] Found: %NP_PATH%

echo --- Setting Notepad++ txt icon ---
reg add "HKEY_LOCAL_MACHINE\Software\Classes\Notepad++_txt\DefaultIcon" /ve /t REG_EXPAND_SZ /d "%%SystemRoot%%\System32\imageres.dll,-102" /f /reg:64
echo.
echo.

:: ========================================================
:: STEP 3: Remove UWP Windows Notepad
:: ========================================================
echo [3/8] Removing UWP Windows Notepad...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p=Get-AppxPackage '*Microsoft.WindowsNotepad*' -AllUsers -EA 0; if($p){$p|Remove-AppxPackage -AllUsers -EA 0; Write-Host '[OK] UWP Notepad removed.'}else{Write-Host '[INFO] UWP Notepad not found.'}"
echo.

:: ========================================================
:: STEP 4: Remove provisioned package
:: ========================================================
echo [4/8] Removing provisioned Notepad package...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p=Get-AppxProvisionedPackage -Online -EA 0|Where-Object{$_.DisplayName -like '*WindowsNotepad*'}; if($p){Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -EA 0|Out-Null; Write-Host '[OK] Provisioned package removed.'}else{Write-Host '[INFO] No provisioned package.'}"
echo.

:: ========================================================
:: STEP 5: Remove Notepad capability (Feature on Demand)
:: ========================================================
echo [5/8] Removing Notepad Windows capability, might take some time...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$c=Get-WindowsCapability -Online -EA 0|Where-Object{$_.Name -like '*Notepad*' -and $_.State -eq 'Installed'}; if($c){$c|Remove-WindowsCapability -Online -EA 0|Out-Null; Write-Host '[OK] Capability removed.'}else{Write-Host '[INFO] Capability not found.'}"
echo.

:: ========================================================
:: STEP 6: Delete legacy notepad.exe
:: ========================================================
echo [6/8] Deleting legacy notepad.exe files...
call :delete_notepad "%SystemRoot%\notepad.exe"
call :delete_notepad "%SystemRoot%\System32\notepad.exe"
call :delete_notepad "%SystemRoot%\SysWOW64\notepad.exe"
echo.

:: ========================================================
:: STEP 7: Registry -- IFEO hook + .txt file association
:: ========================================================
echo [7/8] Configuring registry...
echo.

echo   --- IFEO redirect ---
REG ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe" /v "Debugger" /t REG_SZ /d "\"%NP_PATH%\" -notepadStyleCmdline" /f
echo.

echo   --- Notepad++ ProgId ---
REG ADD "HKLM\Software\Classes\Notepad++_txt" /ve /t REG_SZ /d "Text Document" /f
REG ADD "HKLM\Software\Classes\Notepad++_txt\shell\open\command" /ve /t REG_SZ /d "\"%NP_PATH%\" \"%%1\"" /f
echo.

echo   --- .txt association ---
REG ADD "HKLM\Software\Classes\.txt" /ve /t REG_SZ /d "Notepad++_txt" /f
REG ADD "HKLM\Software\Classes\.txt\OpenWithProgids" /v "Notepad++_txt" /t REG_NONE /f
echo.

echo   --- UserChoice ---
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.txt\UserChoice'; if(Test-Path $key){$acl=Get-Acl $key; $acl.SetOwner([System.Security.Principal.NTAccount]$env:USERNAME); Set-Acl $key $acl; $acl=Get-Acl $key; $acl.SetAccessRuleProtection($true,$false); $rule=New-Object System.Security.AccessControl.RegistryAccessRule($env:USERNAME,'FullControl','Allow'); $acl.SetAccessRule($rule); Set-Acl $key $acl; Remove-Item $key -Force -EA 0; if(-not(Test-Path $key)){Write-Host '[OK] UserChoice deleted.'}else{Write-Host '[WARN] UserChoice still exists.'}}else{Write-Host '[INFO] UserChoice not found.'}"
echo.

echo   --- ShellNew ---
REG ADD "HKLM\Software\Classes\.txt\ShellNew" /v "NullFile" /t REG_SZ /d "" /f
echo.

:: ========================================================
:: STEP 8: Guard scheduled task for update resilience
:: ========================================================
echo [8/8] Setting up update-resilience guard...

set "GUARD_DIR=%ProgramData%\NotepadPPGuard"
set "GUARD_FILE=%GUARD_DIR%\guard.ps1"
if not exist "%GUARD_DIR%" mkdir "%GUARD_DIR%"

echo   Writing guard script to: %GUARD_FILE%
> "%GUARD_FILE%" echo # Notepad++ Guard - re-applies hijack on boot
>> "%GUARD_FILE%" echo $npExe = '%NP_PATH%'
>> "%GUARD_FILE%" echo $paths = 'notepad.exe','System32\notepad.exe','SysWOW64\notepad.exe'
>> "%GUARD_FILE%" echo foreach ^($rel in $paths^) {
>> "%GUARD_FILE%" echo     $p = Join-Path $env:SystemRoot $rel
>> "%GUARD_FILE%" echo     if ^(Test-Path $p^) {
>> "%GUARD_FILE%" echo         Start-Process takeown -ArgumentList '/f',$p,'/a' -NoNewWindow -Wait -EA 0
>> "%GUARD_FILE%" echo         Start-Process icacls -ArgumentList $p,'/grant','Administrators:F' -NoNewWindow -Wait -EA 0
>> "%GUARD_FILE%" echo         Remove-Item -Force $p -EA 0
>> "%GUARD_FILE%" echo     }
>> "%GUARD_FILE%" echo }
>> "%GUARD_FILE%" echo $k = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe'
>> "%GUARD_FILE%" echo if ^(-not ^(Test-Path $k^)^) { New-Item -Path $k -Force ^| Out-Null }
>> "%GUARD_FILE%" echo Set-ItemProperty $k 'Debugger' ^('"' + $npExe + '" -notepadStyleCmdline'^) -Force
>> "%GUARD_FILE%" echo Set-ItemProperty 'HKLM:\Software\Classes\.txt' '^(Default^)' 'Notepad++_txt' -Force -EA 0
>> "%GUARD_FILE%" echo $ucKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.txt\UserChoice'
>> "%GUARD_FILE%" echo if ^(Test-Path $ucKey^) {
>> "%GUARD_FILE%" echo     $a = Get-Acl $ucKey
>> "%GUARD_FILE%" echo     $a.SetOwner^([System.Security.Principal.NTAccount]$env:USERNAME^)
>> "%GUARD_FILE%" echo     Set-Acl $ucKey $a
>> "%GUARD_FILE%" echo     $a = Get-Acl $ucKey
>> "%GUARD_FILE%" echo     $a.SetAccessRuleProtection^($true,$false^)
>> "%GUARD_FILE%" echo     $r = New-Object System.Security.AccessControl.RegistryAccessRule^($env:USERNAME,'FullControl','Allow'^)
>> "%GUARD_FILE%" echo     $a.SetAccessRule^($r^)
>> "%GUARD_FILE%" echo     Set-Acl $ucKey $a
>> "%GUARD_FILE%" echo     Remove-Item $ucKey -Force -EA 0
>> "%GUARD_FILE%" echo }
>> "%GUARD_FILE%" echo Get-WindowsCapability -Online -EA 0 ^| Where-Object { $_.Name -like '*Notepad*' -and $_.State -eq 'Installed' } ^| Remove-WindowsCapability -Online -EA 0 ^| Out-Null
>> "%GUARD_FILE%" echo $pkg = Get-AppxPackage '*Microsoft.WindowsNotepad*' -AllUsers -EA 0
>> "%GUARD_FILE%" echo if ^($pkg^) { $pkg ^| Remove-AppxPackage -AllUsers -EA 0 }
echo   [OK] Guard script written.

echo   Registering scheduled task...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try{$a=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-EP Bypass -WindowStyle Hidden -File %GUARD_FILE%';$t=New-ScheduledTaskTrigger -AtStartup;$p=New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest;$s=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable;Register-ScheduledTask -TaskName 'Notepad++Guard' -Action $a -Trigger $t -Principal $p -Settings $s -Force|Out-Null;Write-Host '[OK] Guard task registered.'}catch{Write-Host '[WARN] Task registration failed:' $_.Exception.Message}"
echo.


:: ========================================================
:: Refresh Explorer
:: ========================================================
echo [INFO] Restarting Explorer...
echo   Killing explorer.exe...
taskkill /f /im explorer.exe
echo   Waiting 3 seconds...
timeout /t 3 /noq
echo   Starting explorer.exe...
start "" explorer.exe
echo   [OK] Explorer restarted.
echo.

:: ========================================================
:: Verification -- confirm everything actually worked
:: ========================================================
echo ========================================================
echo   VERIFICATION
echo ========================================================
echo.
echo   --- notepad.exe deletion ---
if exist "%SystemRoot%\notepad.exe" (echo   [FAIL] %SystemRoot%\notepad.exe STILL EXISTS) else (echo   [OK] %SystemRoot%\notepad.exe -- gone)
if exist "%SystemRoot%\System32\notepad.exe" (echo   [FAIL] %SystemRoot%\System32\notepad.exe STILL EXISTS) else (echo   [OK] %SystemRoot%\System32\notepad.exe -- gone)
if exist "%SystemRoot%\SysWOW64\notepad.exe" (echo   [FAIL] %SystemRoot%\SysWOW64\notepad.exe STILL EXISTS) else (echo   [OK] %SystemRoot%\SysWOW64\notepad.exe -- gone)
echo.
echo   --- .txt default class ---
REG QUERY "HKLM\Software\Classes\.txt" /ve 2>&1
echo.
echo   --- Notepad++ open command ---
REG QUERY "HKLM\Software\Classes\Notepad++_txt\shell\open\command" /ve 2>&1
echo.
echo   --- IFEO debugger ---
REG QUERY "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe" /v "Debugger" 2>&1
echo.
echo   --- UserChoice (should say ERROR / not found) ---
REG QUERY "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.txt\UserChoice" 2>&1
echo.
echo ========================================================
echo   Deployment Complete!
echo   Notepad++ path: %NP_PATH%
echo   A reboot is recommended to finalize all changes.
echo ========================================================

:: ========================================================
:: :end -- THE ONLY EXIT POINT
:: The "cmd /k" wrapper above guarantees the window stays
:: open even if the script never reaches this label.
:: ========================================================
:end
echo.
echo ========================================================
echo   Press ENTER to exit...
echo ========================================================
pause >nul
exit

:: ========================================================
:: SUBROUTINE: Take ownership and delete a notepad.exe
:: ========================================================
:delete_notepad
if exist %~1 (
    echo   [INFO] Taking ownership of %~1 ...
    takeown /f %~1 /a
    icacls %~1 /grant Administrators:F
    echo   [INFO] Deleting %~1 ...
    del /f /q %~1
    if not exist %~1 (
        echo   [OK] Deleted %~1
    ) else (
        echo   [WARN] Could not delete %~1 -- scheduling for reboot...
        powershell.exe -NoProfile -Command "Add-Type 'using System;using System.Runtime.InteropServices;public class MFE{[DllImport(\"kernel32.dll\",SetLastError=true,CharSet=CharSet.Unicode)]public static extern bool MoveFileEx(string s,string d,int f);}';if([MFE]::MoveFileEx('%~1',$null,4)){Write-Host '   [OK] Scheduled for deletion on reboot.'}else{Write-Host '   [FAIL] MoveFileEx failed.'}"
    )
) else (
    echo   [INFO] %~1 not found -- already gone.
)
goto :eof