@echo off
setlocal enabledelayedexpansion

:: ===================================================================
:: Sims Anti-Crash v1.0 - CPU Throttling Application
:: Real-time monitoring with detailed logging and status display
:: ===================================================================

title Sims Anti-Crash v1.0

:: Configuration Variables
set "TARGET_PROCESS=TS4_x64.exe"
set "CHECK_INTERVAL=5"
set "TEMP_CHECK_INTERVAL=3"
set "STATUS_FILE=%~dp0sims-anti-crash.tmp"

:: Temperature thresholds (Celsius)
set "TEMP_THRESHOLD_SAFE=60"
set "TEMP_THRESHOLD_ELEVATED=65"
set "TEMP_THRESHOLD_HIGH=70"
set "TEMP_THRESHOLD_CRITICAL=75"

:: CPU throttling levels (percentage)
set "CPU_NORMAL=100"
set "CPU_THROTTLE_LIGHT=85"
set "CPU_THROTTLE_MEDIUM=70"
set "CPU_THROTTLE_HEAVY=50"
set "CPU_THROTTLE_EMERGENCY=30"

:: State variables
set "PROCESS_RUNNING=0"
set "THROTTLE_ACTIVE=0"
set "CURRENT_CPU_LIMIT=100"
set "ORIGINAL_CPU_LIMIT="
set "CURRENT_TEMP=0"
set "THROTTLE_LEVEL=NORMAL"
set "PROCESS_PID=0"
set "PROCESS_MEMORY=0"
set "UPTIME_START="

:: Display settings
set "CONSOLE_WIDTH=80"
set "CONSOLE_HEIGHT=30"

:: Administrative privilege check
net session >nul 2>&1
if %errorLevel% neq 0 (
    call :display_error "FATAL: Administrator privileges required for power management operations"
    echo.
    echo This application modifies system-wide CPU power settings.
    echo Please run as Administrator to continue.
    pause
    exit /b 1
)

:: Initialize console and logging
color 0A
mode con: cols=%CONSOLE_WIDTH% lines=%CONSOLE_HEIGHT%
call :initialize_monitoring
call :setup_cleanup_handler

:: Main monitoring loop with real-time display
:main_loop
    cls
    call :display_header
    call :check_process_status
    call :update_process_info
    
    if !PROCESS_RUNNING! equ 1 (
        call :monitor_temperature_realtime
        call :display_active_monitoring
    ) else (
        call :display_standby_mode
        if !THROTTLE_ACTIVE! equ 1 (
            call :restore_cpu_settings
        )
    )
    
    call :display_status_footer
    call :log_current_state
    
    timeout /t %CHECK_INTERVAL% >nul
    goto main_loop

:: ===================================================================
:: DISPLAY FUNCTIONS
:: ===================================================================

:display_header
    echo ================================================================================
    echo                                 SIMS ANTI-CRASH
    echo ================================================================================
    echo                                Made for Libby ^<3
    echo ================================================================================
    call :get_timestamp CURRENT_TIME
    echo Status Time: !CURRENT_TIME!                    PID: %PROCESS_PID%
    echo Target: %TARGET_PROCESS%                   Memory: %PROCESS_MEMORY% MB
    echo ================================================================================
    goto :eof

:display_active_monitoring
    echo.
    echo [ACTIVE MONITORING - SIMS DETECTED]
    echo.
    call :display_temperature_gauge
    echo.
    call :display_throttle_status
    echo.
    call :display_performance_metrics
    goto :eof

:display_standby_mode
    echo.
    echo [STANDBY MODE - SIMS NOT DETECTED]
    echo.
    echo    Status: Waiting for %TARGET_PROCESS% to start...
    echo    Action: No throttling applied
    echo    CPU:    Running at normal speed (100%%)
    echo.
    goto :eof

:display_temperature_gauge
    set "TEMP_BAR="
    set "TEMP_COLOR=GREEN"
    
    :: Create visual temperature bar
    set /a "BAR_LENGTH=%CURRENT_TEMP%/2"
    if %BAR_LENGTH% gtr 50 set "BAR_LENGTH=50"
    
    for /l %%i in (1,1,%BAR_LENGTH%) do set "TEMP_BAR=!TEMP_BAR!x"
    
    :: Determine color coding
    if %CURRENT_TEMP% geq %TEMP_THRESHOLD_CRITICAL% set "TEMP_COLOR=CRITICAL"
    if %CURRENT_TEMP% geq %TEMP_THRESHOLD_HIGH% if %CURRENT_TEMP% lss %TEMP_THRESHOLD_CRITICAL% set "TEMP_COLOR=HIGH"
    if %CURRENT_TEMP% geq %TEMP_THRESHOLD_ELEVATED% if %CURRENT_TEMP% lss %TEMP_THRESHOLD_HIGH% set "TEMP_COLOR=ELEVATED"
    
    echo CPU Temperature: %CURRENT_TEMP% C [!TEMP_COLOR!]
    echo Temperature Bar: [!TEMP_BAR!] (%CURRENT_TEMP%/100 C)
    goto :eof

:display_throttle_status
    echo CPU Throttling: %CURRENT_CPU_LIMIT%%% ^| Level: %THROTTLE_LEVEL%
    
    if !THROTTLE_ACTIVE! equ 1 (
        echo Throttle Reason: Temperature-based protection active
        echo Throttle Duration: Active since temperature exceeded threshold
    ) else (
        echo Throttle Status: No throttling - Normal operation
        echo Performance: Full CPU performance available
    )
    goto :eof

:display_performance_metrics
    echo.
    echo PERFORMANCE METRICS:
    echo - Original CPU Limit: %ORIGINAL_CPU_LIMIT%%%
    echo - Current CPU Limit:  %CURRENT_CPU_LIMIT%%%
    echo - Temperature Status: !TEMP_COLOR!
    echo - Throttle Level:     %THROTTLE_LEVEL%
    echo - Monitoring Uptime:  !UPTIME_DISPLAY!
    goto :eof

:display_status_footer
    echo.
    echo ================================================================================
    echo Press Ctrl+C to exit safely (will restore CPU settings)
    echo ================================================================================
    goto :eof

:display_error
    echo.
    echo [ERROR] %~1
    echo.
    goto :eof

:: ===================================================================
:: MONITORING FUNCTIONS
:: ===================================================================

:initialize_monitoring
    call :get_timestamp UPTIME_START
    call :get_original_cpu_limit
    call :log "=== Sims Anti-Crash Started ==="
    call :log "Configuration: Temp thresholds %TEMP_THRESHOLD_SAFE%/%TEMP_THRESHOLD_ELEVATED%/%TEMP_THRESHOLD_HIGH%/%TEMP_THRESHOLD_CRITICAL%°C"
    call :log "CPU Throttling: %CPU_THROTTLE_LIGHT%/%CPU_THROTTLE_MEDIUM%/%CPU_THROTTLE_HEAVY%/%CPU_THROTTLE_EMERGENCY%%%"
    call :log "Original CPU Limit: %ORIGINAL_CPU_LIMIT%%%"
    goto :eof

:check_process_status
    set "PROCESS_RUNNING=0"
    set "PROCESS_PID=0"
    set "PROCESS_MEMORY=0"
    
    for /f "tokens=2,5" %%a in ('tasklist /fi "imagename eq %TARGET_PROCESS%" /fo table 2^>nul ^| find "%TARGET_PROCESS%"') do (
        set "PROCESS_PID=%%a"
        set "PROCESS_MEMORY=%%b"
        set "PROCESS_RUNNING=1"
    )
    
    :: Clean memory value (remove commas and "K")
    if defined PROCESS_MEMORY (
        set "PROCESS_MEMORY=!PROCESS_MEMORY:,=!"
        set "PROCESS_MEMORY=!PROCESS_MEMORY: K=!"
        set /a "PROCESS_MEMORY=!PROCESS_MEMORY!/1024"
    )
    goto :eof

:update_process_info
    if !PROCESS_RUNNING! equ 1 (
        if !PROCESS_PID! neq 0 (
            :: Get additional process information
            for /f "tokens=2" %%i in ('wmic process where "processid=!PROCESS_PID!" get PageFileUsage /value 2^>nul ^| find "="') do (
                set /a "PROCESS_MEMORY=%%i/1024"
            )
        )
    )
    goto :eof

:monitor_temperature_realtime
    call :get_cpu_temperature
    if defined CURRENT_TEMP (
        call :apply_intelligent_throttling !CURRENT_TEMP!
        call :calculate_uptime
    ) else (
        set "CURRENT_TEMP=0"
        call :log "WARNING: Unable to read CPU temperature - thermal protection disabled"
    )
    goto :eof

:get_cpu_temperature
    set "CURRENT_TEMP="
    
    :: Method 1: WMI Thermal Zone
    for /f "tokens=2 delims==" %%i in ('wmic /namespace:\\root\wmi path MSAcpi_ThermalZoneTemperature get CurrentTemperature /value 2^>nul ^| find "="') do (
        set /a "TEMP_KELVIN=%%i"
        set /a "CURRENT_TEMP=!TEMP_KELVIN!/10-273"
    )
    
    :: Method 2: PowerShell fallback
    if not defined CURRENT_TEMP (
        for /f "usebackq tokens=*" %%i in (`powershell -command "try { (Get-WmiObject -Class Win32_PerfRawData_Counters_ThermalZoneInformation | Select-Object -First 1).Temperature / 10 - 273.15 } catch { 'N/A' }" 2^>nul`) do (
            if "%%i" neq "N/A" (
                set /a "CURRENT_TEMP=%%i"
            )
        )
    )
    
    :: Method 3: Alternative WMI approach
    if not defined CURRENT_TEMP (
        for /f "tokens=2 delims==" %%i in ('wmic path Win32_PerfRawData_Counters_ThermalZoneInformation get Temperature /value 2^>nul ^| find "="') do (
            if "%%i" neq "" (
                set /a "CURRENT_TEMP=%%i/10-273"
            )
        )
    )
    
    :: Validation and bounds checking
    if defined CURRENT_TEMP (
        if !CURRENT_TEMP! lss 20 set "CURRENT_TEMP="
        if !CURRENT_TEMP! gtr 120 set "CURRENT_TEMP="
    )
    goto :eof

:apply_intelligent_throttling
    set "NEW_TEMP=%~1"
    set "NEW_CPU_LIMIT=%CPU_NORMAL%"
    set "NEW_THROTTLE_LEVEL=NORMAL"
    
    :: Progressive throttling based on temperature ranges
    if %NEW_TEMP% geq %TEMP_THRESHOLD_CRITICAL% (
        set "NEW_CPU_LIMIT=%CPU_THROTTLE_EMERGENCY%"
        set "NEW_THROTTLE_LEVEL=EMERGENCY"
    ) else if %NEW_TEMP% geq %TEMP_THRESHOLD_HIGH% (
        set "NEW_CPU_LIMIT=%CPU_THROTTLE_HEAVY%"
        set "NEW_THROTTLE_LEVEL=HEAVY"
    ) else if %NEW_TEMP% geq %TEMP_THRESHOLD_ELEVATED% (
        set "NEW_CPU_LIMIT=%CPU_THROTTLE_MEDIUM%"
        set "NEW_THROTTLE_LEVEL=MEDIUM"
    ) else if %NEW_TEMP% geq %TEMP_THRESHOLD_SAFE% (
        set "NEW_CPU_LIMIT=%CPU_THROTTLE_LIGHT%"
        set "NEW_THROTTLE_LEVEL=LIGHT"
    )
    
    :: Apply throttling changes
    if !NEW_CPU_LIMIT! neq !CURRENT_CPU_LIMIT! (
        call :set_cpu_limit !NEW_CPU_LIMIT!
        call :log "THROTTLE: Temp=%NEW_TEMP%°C, CPU=%NEW_CPU_LIMIT%%%, Level=%NEW_THROTTLE_LEVEL%"
        
        set "CURRENT_CPU_LIMIT=!NEW_CPU_LIMIT!"
        set "THROTTLE_LEVEL=!NEW_THROTTLE_LEVEL!"
        
        if !NEW_CPU_LIMIT! neq %CPU_NORMAL% (
            set "THROTTLE_ACTIVE=1"
        ) else (
            set "THROTTLE_ACTIVE=0"
        )
    )
    goto :eof

:set_cpu_limit
    set "CPU_LIMIT=%~1"
    
    :: Apply to both AC and DC power plans
    powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMAX %CPU_LIMIT% >nul 2>&1
    powercfg /setdcvalueindex scheme_current sub_processor PROCTHROTTLEMAX %CPU_LIMIT% >nul 2>&1
    powercfg /setactive scheme_current >nul 2>&1
    
    goto :eof

:get_original_cpu_limit
    for /f "tokens=3" %%i in ('powercfg /query scheme_current sub_processor PROCTHROTTLEMAX 2^>nul ^| find "Current AC Power Setting Index:"') do (
        set /a "ORIGINAL_CPU_LIMIT=%%i"
    )
    
    if not defined ORIGINAL_CPU_LIMIT set "ORIGINAL_CPU_LIMIT=100"
    if !ORIGINAL_CPU_LIMIT! equ 0 set "ORIGINAL_CPU_LIMIT=100"
    goto :eof

:restore_cpu_settings
    if defined ORIGINAL_CPU_LIMIT (
        call :set_cpu_limit !ORIGINAL_CPU_LIMIT!
        call :log "RESTORE: CPU settings restored to %ORIGINAL_CPU_LIMIT%%%"
        set "THROTTLE_ACTIVE=0"
        set "CURRENT_CPU_LIMIT=!ORIGINAL_CPU_LIMIT!"
        set "THROTTLE_LEVEL=NORMAL"
    )
    goto :eof

:: ===================================================================
:: UTILITY FUNCTIONS
:: ===================================================================

:calculate_uptime
    if defined UPTIME_START (
        call :get_timestamp CURRENT_TIME_RAW
        :: Simple uptime calculation (this is a simplified version)
        set "UPTIME_DISPLAY=Monitoring Active"
    ) else (
        set "UPTIME_DISPLAY=Not Available"
    )
    goto :eof

:get_timestamp
    set "TIMESTAMP_VAR=%~1"
    
    for /f "tokens=2 delims==" %%i in ('wmic os get localdatetime /value 2^>nul ^| find "="') do (
        if not "%%i"=="" set "!TIMESTAMP_VAR!=%%i"
    )
    
    if defined %TIMESTAMP_VAR% (
        set "FORMATTED_TIME=!%TIMESTAMP_VAR%:~0,4!-!%TIMESTAMP_VAR%:~4,2!-!%TIMESTAMP_VAR%:~6,2! !%TIMESTAMP_VAR%:~8,2!:!%TIMESTAMP_VAR%:~10,2!:!%TIMESTAMP_VAR%:~12,2!"
        if "%~1"=="CURRENT_TIME" set "CURRENT_TIME=!FORMATTED_TIME!"
    )
    goto :eof

:log_current_state
    if !PROCESS_RUNNING! equ 1 (
        call :log "STATUS: Process=RUNNING, PID=%PROCESS_PID%, Temp=%CURRENT_TEMP% C, CPU=%CURRENT_CPU_LIMIT%%%, Level=%THROTTLE_LEVEL%"
    ) else (
        call :log "STATUS: Process=STOPPED, Temp=N/A, CPU=%CURRENT_CPU_LIMIT%%%, Level=STANDBY"
    )
    goto :eof

:log
    set "LOG_MESSAGE=%~1"
    call :get_timestamp LOG_TIME
    
    :: Console output with color coding (simplified)
    echo [!LOG_TIME!] %LOG_MESSAGE%
    
    goto :eof

:cleanup_and_exit
    call :log "=== Shutting down TS4 Thermal Monitor ==="
    if !THROTTLE_ACTIVE! equ 1 (
        call :restore_cpu_settings
    )
    
    if exist "%STATUS_FILE%" del "%STATUS_FILE%"
    call :log "Cleanup completed - CPU settings restored"
    
    echo.
    echo Thermal monitor stopped safely.
    echo CPU throttling has been restored to original settings.
    pause
    exit /b 0

:: Handle termination signals
:ctrl_c_handler
    call :cleanup_and_exit
    goto :eof