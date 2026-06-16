param([string]$e = "")

# ============================================================================
#  1. ПОЛУЧЕНИЕ ЭНТРОПИИ
# ============================================================================
function Get-Entropy {
    Write-Host "`nChoose entropy length:" -ForegroundColor DarkYellow
    Write-Host "  1) 128 bits (12 words)" -ForegroundColor White
    Write-Host "  2) 256 bits (24 words)" -ForegroundColor White
    $choice = Read-Host "Select (1/2)"
    $targetLen = if ($choice -eq '2') { 256 } else { 128 }
    
    Write-Host "`nType binary entropy (0/1). Enter to finish." -ForegroundColor DarkYellow
    
    $sb = New-Object System.Text.StringBuilder
    $line = 0
    
    function Show-Status {
        $len = $sb.Length
        $str = $sb.ToString()
        
        if ($len -lt $targetLen) {
            $cursor = $len
        } else {
            $cursor = $targetLen - 1
        }
        
        [Console]::SetCursorPosition(0, $line + 1)
        Write-Host (" " * 100) -NoNewline
        [Console]::SetCursorPosition(0, $line + 1)
        Write-Host "[$len/$targetLen] " -NoNewline -ForegroundColor Gray
        Write-Host $str -NoNewline -ForegroundColor DarkYellow
    }
    
    $line = [Console]::CursorTop
    Show-Status
    
    while ($true) {
        $key = [Console]::ReadKey($true)
        
        if ($key.Key -eq [ConsoleKey]::Enter) { break }
        
        if ($key.Key -eq [ConsoleKey]::Backspace -and $sb.Length -gt 0) {
            $sb.Remove($sb.Length - 1, 1) | Out-Null
            Show-Status
            continue
        }
        
        if (($key.KeyChar -eq '0' -or $key.KeyChar -eq '1') -and $sb.Length -lt $targetLen) {
            $sb.Append($key.KeyChar) | Out-Null
            Show-Status
        }
    }
    
    Write-Host "`n"
    return $sb.ToString()
}

# ============================================================================
#  2. ВАЛИДАЦИЯ ЭНТРОПИИ
# ============================================================================
function Validate-Entropy {
    param([string]$entropy)
    
    if ($entropy.Length -notin @(128, 256)) {
        Write-Host "ERROR: Length must be 128 or 256 bits. Got: $($entropy.Length)" -ForegroundColor Red
        exit 1
    }
    if ($entropy -notmatch '^[01]+$') {
        Write-Host "ERROR: String must contain only 0 and 1." -ForegroundColor Red
        exit 1
    }
    
    $wordlistPath = Join-Path $PSScriptRoot "wordlist.txt"
    if (-not (Test-Path $wordlistPath)) {
        Write-Host "ERROR: wordlist.txt not found" -ForegroundColor Red
        exit 1
    }
    
    return $wordlistPath
}

# ============================================================================
#  3. ГЕНЕРАЦИЯ МНЕМОНИКИ
# ============================================================================
function Generate-Mnemonic {
    param([string]$entropy, [string]$wordlistPath)
    
    $bytes = for ($i = 0; $i -lt $entropy.Length; $i += 8) {
        [Convert]::ToByte($entropy.Substring($i, 8), 2)
    }
    
    $sha = [Security.Cryptography.SHA256]::Create()
    $hash = $sha.ComputeHash($bytes)
    
    $csBits = $entropy.Length / 32
    $cs = [Convert]::ToString($hash[0], 2).PadLeft(8, '0').Substring(0, $csBits)
    
    $bits = $entropy + $cs
    $words = Get-Content $wordlistPath
    $wordCount = ($entropy.Length + $csBits) / 11
    
    $result = 0..($wordCount - 1) | ForEach-Object {
        $idx = [Convert]::ToInt32($bits.Substring($_ * 11, 11), 2)
        $words[$idx]
    }
    
    return @{
        Mnemonic = $result -join ' '
        WordCount = $wordCount
    }
}

# ============================================================================
#  4. ВЫВОД РЕЗУЛЬТАТА
# ============================================================================
function Show-Mnemonic {
    param([string]$mnemonic, [int]$wordCount)
    
    Write-Host "`n============================================" -ForegroundColor DarkYellow
    Write-Host " MNEMONIC PHRASE ($wordCount words):" -ForegroundColor DarkYellow
    Write-Host "============================================" -ForegroundColor DarkYellow
    Write-Host "`n$mnemonic`n" -ForegroundColor White
}

# ============================================================================
#  5. MAIN
# ============================================================================
$entropy = if ($e -eq "") { Get-Entropy } else { $e }
$wordlistPath = Validate-Entropy $entropy
$result = Generate-Mnemonic $entropy $wordlistPath
Show-Mnemonic $result.Mnemonic $result.WordCount
