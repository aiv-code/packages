## Windows MSI package build script for AIV application
## Requires: WiX Toolset v4 (dotnet tool), Java 17+, envsubst (via Git for Windows)

param(
    [string]$Version = $env:VERSION,
    [string]$Release = $env:RELEASE
)

if (-not $Version) { $Version = "1.0.0" }
if (-not $Release) { $Release = "0" }

$ErrorActionPreference = "Stop"
$BuildDir = "aiv-win-$Version"
$InstallBase = "C:\AIV"

Write-Host "Building Windows MSI for AIV $Version-$Release"

# ── Directory layout ──────────────────────────────────────────────────────────
Remove-Item -Recurse -Force $BuildDir -ErrorAction SilentlyContinue
$dirs = @(
    "$BuildDir\bin",
    "$BuildDir\config\drivers",
    "$BuildDir\repository\econfig",
    "$BuildDir\repository\Config",
    "$BuildDir\repository\images",
    "$BuildDir\repository\Default",
    "$BuildDir\logs"
)
foreach ($d in $dirs) { New-Item -ItemType Directory -Force $d | Out-Null }

# ── Copy application files ────────────────────────────────────────────────────
Copy-Item aiv.jar                          "$BuildDir\"
Copy-Item -Recurse config\drivers\*       "$BuildDir\config\drivers\"
Copy-Item -Recurse repository\econfig\*   "$BuildDir\repository\econfig\"
Copy-Item -Recurse repository\Config\*    "$BuildDir\repository\Config\"
Copy-Item -Recurse repository\images\*    "$BuildDir\repository\images\"
Copy-Item -Recurse repository\Default\*   "$BuildDir\repository\Default\"

# ── Shared java invocation args (used by both aiv.bat and the WinSW service config) ────
$JavaArgs = @(
    "--add-opens=java.base/java.nio=ALL-UNNAMED"
    "--add-exports=java.base/sun.nio.ch=ALL-UNNAMED"
    "--add-opens=java.base/sun.nio.ch=ALL-UNNAMED"
    "--add-opens=java.base/sun.util.calendar=ALL-UNNAMED"
    "-Dspring.config.location=$InstallBase\repository\econfig\application.yml"
    "-Dloader.path=$InstallBase\config\drivers"
    "-cp `"$InstallBase\repository\econfig\;$InstallBase\aiv.jar`""
    "org.springframework.boot.loader.launch.PropertiesLauncher"
) -join " "

# ── aiv.bat launcher (interactive/manual use) ──────────────────────────────────
@"
@echo off
where java >nul 2>nul
if errorlevel 1 (
    echo ERROR: Java was not found on PATH. Please install Java 17 or later before running AIV.
    exit /b 1
)
for /f "tokens=3" %%v in ('java -version 2^>^&1 ^| findstr /i "version"') do set JAVA_VER_RAW=%%v
set JAVA_VER_RAW=%JAVA_VER_RAW:"=%
for /f "tokens=1,2 delims=." %%a in ("%JAVA_VER_RAW%") do (
    set JAVA_MAJOR=%%a
    set JAVA_MINOR=%%b
)
if "%JAVA_MAJOR%"=="1" set JAVA_MAJOR=%JAVA_MINOR%
if %JAVA_MAJOR% LSS 17 (
    echo ERROR: AIV requires Java 17 or later. Detected version %JAVA_VER_RAW%.
    exit /b 1
)
java $JavaArgs
"@ | Set-Content "$BuildDir\bin\aiv.bat"

# ── AIVService.exe (WinSW) ──────────────────────────────────────────────────────
# The Windows Service Control Manager requires a service binary that implements the
# SCM control protocol (StartServiceCtrlDispatcher); a bare java.exe/aiv.bat process
# does not, so it can never be registered directly as an ownProcess service. WinSW is
# a small wrapper exe that does implement that protocol and proxies to a child process
# described by the paired <name>.xml config placed next to it.
$WinswUrl = "https://github.com/winsw/winsw/releases/download/v2.12.0/WinSW-x64.exe"
Invoke-WebRequest -Uri $WinswUrl -OutFile "$BuildDir\bin\AIVService.exe"

@"
<service>
  <id>AIVService</id>
  <name>AIV Application</name>
  <description>AIV Application Service</description>
  <executable>java</executable>
  <arguments>$JavaArgs</arguments>
  <workingdirectory>$InstallBase</workingdirectory>
  <log mode="roll-by-size">
    <logpath>$InstallBase\logs</logpath>
  </log>
  <onfailure action="restart" delay="10 sec" />
</service>
"@ | Set-Content "$BuildDir\bin\AIVService.xml"

# ── Substitute config defaults ────────────────────────────────────────────────
$env:aiv_base            = $InstallBase
$env:aiv_db_url          = "jdbc:postgresql://localhost:5432/postgres"
$env:aiv_db_user         = "postgres"
$env:aiv_db_password     = "postgres"
$env:security_db_url     = "jdbc:postgresql://localhost:5432/postgres?currentSchema=security"
$env:security_db_user    = "postgres"
$env:security_db_password= "postgres"
$env:aiv_port            = "8080"

# envsubst shipped with Git for Windows
$appYml = Get-Content "$BuildDir\repository\econfig\application.yml" -Raw
foreach ($key in @("aiv_base","aiv_db_url","aiv_db_user","aiv_db_password",
                    "security_db_url","security_db_user","security_db_password","aiv_port")) {
    $appYml = $appYml -replace "\`${$key}", (Get-Item "env:$key").Value
}
$appYml = $appYml -replace "logDir: /var/lib/aiv/logs", "logDir: $InstallBase\\logs"
$appYml = $appYml -replace "/opt/logs",                  "$InstallBase\\logs"
$appYml | Set-Content "$BuildDir\repository\econfig\application.yml"

(Get-Content "$BuildDir\repository\econfig\logback.xml" -Raw) `
    -replace "/opt/logs", "$InstallBase\\logs" |
    Set-Content "$BuildDir\repository\econfig\logback.xml"

# ── WiX 4 source (*.wxs) ─────────────────────────────────────────────────────
# Unique GUIDs are generated once per version; keep them stable across releases
# by seeding from version string.
$wxs = @"
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs">

  <Package Name="AIV"
           Manufacturer="AIVHub"
           Version="$Version"
           UpgradeCode="A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
           Language="1033"
           Codepage="1252"
           InstallerVersion="500">

    <MajorUpgrade DowngradeErrorMessage="A newer version of AIV is already installed." />
    <MediaTemplate EmbedCab="yes" />

    <!-- Java 17+ is required, but is checked at runtime by aiv.bat rather than as an
         MSI Launch Condition: registry-based detection is vendor-specific (Oracle's
         JavaSoft\JDK\CurrentVersion key is not set by default by Temurin/Adoptium and
         other vendors), which caused false "Java not installed" blocks on valid JDKs. -->

    <Feature Id="MainFeature" Title="AIV Application" Level="1">
      <ComponentGroupRef Id="AIVFiles" />
      <ComponentRef Id="AIVService" />
      <ComponentRef Id="AIVEnvPath" />
    </Feature>

    <StandardDirectory Id="ProgramFiles64Folder">
      <Directory Id="INSTALLFOLDER" Name="AIV">
        <Directory Id="INSTALLBIN" Name="bin" />
      </Directory>
    </StandardDirectory>

    <ComponentGroup Id="AIVFiles" Directory="INSTALLFOLDER">
      <!-- Files are harvested at CI time via 'wix harvest' and merged here.  -->
      <!-- Placeholder component keeps the WXS valid for manual builds.       -->
      <Component Id="AivJar" Guid="*">
        <File Source="$BuildDir\aiv.jar" KeyPath="yes" />
      </Component>
      <Component Id="AivBat" Directory="INSTALLBIN" Guid="*">
        <File Source="$BuildDir\bin\aiv.bat" KeyPath="yes" />
      </Component>
    </ComponentGroup>

    <!-- Windows Service registration. AIVService.exe is WinSW (see aiv-build-win.ps1),
         which is what actually implements the SCM control protocol; ServiceInstall's
         ImagePath is derived from this component's KeyPath File. -->
    <Component Id="AIVService" Directory="INSTALLBIN" Guid="D1E2F3A4-B5C6-7890-DEFA-234567890123">
      <File Id="AIVServiceExe" Source="$BuildDir\bin\AIVService.exe" KeyPath="yes" />
      <File Id="AIVServiceConfig" Source="$BuildDir\bin\AIVService.xml" />
      <ServiceInstall Id="InstallAIVService"
                      Name="AIVService"
                      DisplayName="AIV Application"
                      Description="AIV Application Service"
                      Start="auto"
                      Type="ownProcess"
                      ErrorControl="normal"
                      Account="LocalSystem" />
      <ServiceControl Id="StartAIVService"
                      Name="AIVService"
                      Start="install"
                      Stop="both"
                      Remove="uninstall"
                      Wait="yes" />
    </Component>

    <!-- Add INSTALLFOLDER\bin to system PATH -->
    <Component Id="AIVEnvPath" Directory="INSTALLFOLDER" Guid="C9D3E4F5-A6B7-8901-CDEF-123456789012">
      <RegistryValue Root="HKLM"
                     Key="SOFTWARE\AIVHub\AIV"
                     Name="PathConfigured"
                     Type="integer"
                     Value="1"
                     KeyPath="yes" />
      <Environment Id="AIVPath"
                   Name="PATH"
                   Value="[INSTALLBIN]"
                   Permanent="no"
                   Part="last"
                   Action="set"
                   System="yes" />
    </Component>

  </Package>
</Wix>
"@

$wxs | Set-Content "$BuildDir\aiv.wxs"

# ── Build MSI ─────────────────────────────────────────────────────────────────
Write-Host "Running WiX build..."
wix build "$BuildDir\aiv.wxs" `
    -o "aiv-$Version-$Release.msi"

Write-Host "MSI built successfully:"
Get-Item "aiv-$Version-$Release.msi"
