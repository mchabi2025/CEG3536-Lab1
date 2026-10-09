param([string]$ToolchainBin = '')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $ToolchainBin) {
    $found = Get-Command arm-none-eabi-gcc.exe -ErrorAction SilentlyContinue
    if ($found) { $ToolchainBin = Split-Path $found.Source }
    else { throw 'Fournir -ToolchainBin avec le dossier bin de GNU Arm (CubeIDE ou CubeCLT).' }
}
$ToolchainBin = (Resolve-Path -LiteralPath $ToolchainBin).Path
$gcc = Join-Path $ToolchainBin 'arm-none-eabi-gcc.exe'
$objcopy = Join-Path $ToolchainBin 'arm-none-eabi-objcopy.exe'
$size = Join-Path $ToolchainBin 'arm-none-eabi-size.exe'
function Run-Checked([string]$Exe, [string[]]$Arguments) {
    & $Exe @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Echec de $Exe (code $LASTEXITCODE)." }
}
Push-Location $PSScriptRoot
try {
    New-Item -ItemType Directory -Force build | Out-Null
    $cpu = @('-mcpu=cortex-m33', '-mthumb', '-mfpu=fpv5-sp-d16', '-mfloat-abi=hard')
    $objects = @()
    $assembly = @(Get-ChildItem Core/Src -Filter '*.s') + @(Get-ChildItem Core/Startup -Filter '*.s')
    foreach ($source in $assembly) {
        $object = "build/$($source.BaseName).o"
        Run-Checked $gcc ($cpu + @('-x','assembler-with-cpp','-g3','-DDEBUG','-Wall','-Werror','-c',$source.FullName,'-o',$object))
        $objects += $object
    }
    foreach ($source in Get-ChildItem Core/Src -Filter '*.c') {
        $object = "build/$($source.BaseName).o"
        Run-Checked $gcc ($cpu + @('-std=gnu11','-O0','-g3','-DDEBUG','-DSTM32L552xx','-Wall','-Werror','-ICore/Inc','-ffunction-sections','-fdata-sections','-fstack-usage','-c',$source.FullName,'-o',$object))
        $objects += $object
    }
    $elf = 'build/CEG3536_Lab1_Complet.elf'
    Run-Checked $gcc ($cpu + $objects + @('-T','STM32L552ZETXQ_FLASH.ld','-Wl,--gc-sections','-static','-Wl,-Map=build/CEG3536_Lab1_Complet.map','--specs=nano.specs','--specs=nosys.specs','-Wl,--start-group','-lc','-lm','-Wl,--end-group','-o',$elf))
    Run-Checked $size @($elf)
    Run-Checked $objcopy @('-O','binary',$elf,'build/CEG3536_Lab1_Complet.bin')
    Run-Checked $objcopy @('-O','ihex',$elf,'build/CEG3536_Lab1_Complet.hex')
    Write-Output 'Construction terminee. Ce script ne programme pas la carte.'
}
finally { Pop-Location }
