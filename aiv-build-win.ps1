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

# ── aiv.bat launcher ─────────────────────────────────────────────────────────
@"
@echo off
java --add-opens=java.base/java.nio=ALL-UNNAMED ^
     --add-exports=java.base/sun.nio.ch=ALL-UNNAMED ^
     --add-opens=java.base/sun.nio.ch=ALL-UNNAMED ^
     --add-opens=java.base/sun.util.calendar=ALL-UNNAMED ^
     -Dspring.config.location=$InstallBase\repository\econfig\application.yml ^
     -Dloader.path=$InstallBase\config\drivers ^
     -cp "$InstallBase\repository\econfig\;$InstallBase\aiv.jar" ^
     org.springframework.boot.loader.launch.PropertiesLauncher
"@ | Set-Content "$BuildDir\bin\aiv.bat"

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

    <!-- Java 17+ prerequisite check -->
    <Property Id="JAVACURRENTVERSION">
      <RegistrySearch Id="JavaVersionSearch"
                      Root="HKLM"
                      Key="SOFTWARE\JavaSoft\JDK"
                      Name="CurrentVersion"
                      Type="raw" />
    </Property>
    <Launch Condition="JAVACURRENTVERSION" Message="Java 17 (or later) must be installed before AIV." />

    <Feature Id="MainFeature" Title="AIV Application" Level="1">
      <ComponentGroupRef Id="AIVFiles" />
      <ComponentRef Id="AIVService" />
      <ComponentRef Id="AIVEnvPath" />
    </Feature>

    <StandardDirectory Id="ProgramFiles64Folder">
      <Directory Id="INSTALLFOLDER" Name="AIV" />
    </StandardDirectory>

    <ComponentGroup Id="AIVFiles" Directory="INSTALLFOLDER">
      <!-- Files are harvested at CI time via 'wix harvest' and merged here.  -->
      <!-- Placeholder component keeps the WXS valid for manual builds.       -->
      <Component Id="AivJar" Guid="*">
        <File Source="$BuildDir\aiv.jar" KeyPath="yes" />
      </Component>
      <Component Id="AivBat" Guid="*">
        <File Source="$BuildDir\bin\aiv.bat" />
      </Component>
    </ComponentGroup>

    <!-- Windows Service registration via WiX ServiceInstall -->
    <Component Id="AIVService" Directory="INSTALLFOLDER" Guid="D1E2F3A4-B5C6-7890-DEFA-234567890123">
      <RegistryValue Root="HKLM"
                     Key="SOFTWARE\AIVHub\AIV"
                     Name="ServiceInstalled"
                     Type="integer"
                     Value="1"
                     KeyPath="yes" />
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
                   Value="[INSTALLFOLDER]bin"
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
