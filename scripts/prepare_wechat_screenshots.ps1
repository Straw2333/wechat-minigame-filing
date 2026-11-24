<#
.SYNOPSIS
    生成符合微信小游戏备案 / 前置资质审核规范的截图物料。
.DESCRIPTION
    为原始游戏截图叠加顶部微信小游戏官方胶囊按钮与当前小游戏正式名称气泡，
    支持为“设置系统”自动合成标准设置弹窗遮罩，并强制校验输出文件为 PNG 且大小处于 60KB~5MB 区间。
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File prepare_wechat_screenshots.ps1 -GameName "愚公移山之这山我移定了" -OutDir ".\out" -ManifestJson ".\manifest.json"
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File prepare_wechat_screenshots.ps1 -GameName "我的小游戏" -OutDir ".\out" -InputFiles ".\s1.png,.\s2.png" -Prefix "scene"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$GameName,

    [Parameter(Mandatory = $true)]
    [string]$OutDir,

    [string]$ManifestJson = "",

    [string]$InputFiles = "",

    [ValidateSet("none", "settings")]
    [string]$OverlayMode = "none",

    [string]$Prefix = "shot",

    [int]$MinWidth = 1280,

    [int]$MinSizeKB = 60,

    [int]$MaxSizeKB = 5120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

if ([string]::IsNullOrWhiteSpace($ManifestJson) -and [string]::IsNullOrWhiteSpace($InputFiles)) {
    Write-Error "必须提供 -ManifestJson 或 -InputFiles 参数。"
    exit 1
}

if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

function Draw-WechatHeader([System.Drawing.Graphics]$g, [int]$W, [int]$H, [string]$TitleText) {
    $scale = [math]::Max(1.0, $W / 1688.0)
    $headerH = [math]::Max([int](50 * $scale), [int]($H * 0.09))

    # 1. 顶部半透明渐变遮罩，确保白色文字与胶囊在亮色场景下清晰可读
    $rectHeader = [System.Drawing.Rectangle]::new(0, 0, $W, $headerH)
    $brushHeader = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        $rectHeader,
        [System.Drawing.Color]::FromArgb(180, 0, 0, 0),
        [System.Drawing.Color]::FromArgb(0, 0, 0, 0),
        [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
    )
    $g.FillRectangle($brushHeader, $rectHeader)
    $brushHeader.Dispose()

    # 2. 左上角小游戏正式名称气泡
    $fontSize = [float](20.0 * $scale)
    $fontTitle = [System.Drawing.Font]::new("Microsoft YaHei", $fontSize, [System.Drawing.FontStyle]::Bold)
    $titleSize = $g.MeasureString($TitleText, $fontTitle)

    $badgeX = [int](24 * $scale)
    $badgeY = [int](12 * $scale)
    $badgeW = [int]$titleSize.Width + [int](36 * $scale)
    $badgeH = [int]$titleSize.Height + [int](10 * $scale)

    $pathTitle = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $radius = [int](12 * $scale)
    $rTitle = [System.Drawing.Rectangle]::new($badgeX, $badgeY, $badgeW, $badgeH)
    $pathTitle.AddArc($rTitle.X, $rTitle.Y, $radius, $radius, 180, 90)
    $pathTitle.AddArc($rTitle.Right - $radius, $rTitle.Y, $radius, $radius, 270, 90)
    $pathTitle.AddArc($rTitle.Right - $radius, $rTitle.Bottom - $radius, $radius, $radius, 0, 90)
    $pathTitle.AddArc($rTitle.X, $rTitle.Bottom - $radius, $radius, $radius, 90, 90)
    $pathTitle.CloseFigure()

    $brushBadge = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(210, 20, 16, 12))
    $penBadge = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(160, 212, 175, 55), [float](1.5 * $scale))
    $g.FillPath($brushBadge, $pathTitle)
    $g.DrawPath($penBadge, $pathTitle)
    $brushBadge.Dispose()
    $penBadge.Dispose()
    $pathTitle.Dispose()

    $brushText = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 245, 215))
    $g.DrawString($TitleText, $fontTitle, $brushText, [float]($badgeX + [int](18 * $scale)), [float]($badgeY + [int](5 * $scale)))
    $brushText.Dispose()
    $fontTitle.Dispose()

    # 3. 右上角微信标准胶囊按钮（... | ◎）
    $capsuleW = [int](160 * $scale)
    $capsuleH = [int](54 * $scale)
    $capsuleX = $W - $capsuleW - [int](24 * $scale)
    $capsuleY = [int](12 * $scale)
    $capRadius = [int]($capsuleH / 2)

    $pathCap = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $rCap = [System.Drawing.Rectangle]::new($capsuleX, $capsuleY, $capsuleW, $capsuleH)
    $pathCap.AddArc($rCap.X, $rCap.Y, $capRadius * 2, $capRadius * 2, 90, 180)
    $pathCap.AddArc($rCap.Right - $capRadius * 2, $rCap.Y, $capRadius * 2, $capRadius * 2, 270, 180)
    $pathCap.CloseFigure()

    $brushCap = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(100, 0, 0, 0))
    $penCap = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(110, 255, 255, 255), [float](1.2 * $scale))
    $g.FillPath($brushCap, $pathCap)
    $g.DrawPath($penCap, $pathCap)
    $brushCap.Dispose()
    $penCap.Dispose()
    $pathCap.Dispose()

    $midX = $capsuleX + [int]($capsuleW / 2)
    $penDiv = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(80, 255, 255, 255), [float](1.0 * $scale))
    $g.DrawLine($penDiv, $midX, ($capsuleY + [int](12 * $scale)), $midX, ($capsuleY + $capsuleH - [int](12 * $scale)))
    $penDiv.Dispose()

    $brushWhite = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
    $dotSize = [float](6 * $scale)
    $dotY = [float]($capsuleY + ($capsuleH / 2.0) - ($dotSize / 2.0))
    $leftCenter = [float]($capsuleX + ($capsuleW / 4.0))
    $g.FillEllipse($brushWhite, [float]($leftCenter - (14.0 * $scale)), $dotY, $dotSize, $dotSize)
    $g.FillEllipse($brushWhite, [float]($leftCenter - ($dotSize / 2.0)), $dotY, $dotSize, $dotSize)
    $g.FillEllipse($brushWhite, [float]($leftCenter + (8.0 * $scale)), $dotY, $dotSize, $dotSize)

    $rightCenter = [float]($midX + ($capsuleW / 4.0))
    $circleY = [float]($capsuleY + ($capsuleH / 2.0))
    $penOuter = [System.Drawing.Pen]::new([System.Drawing.Color]::White, [float](1.8 * $scale))
    $rOut = [float](9 * $scale)
    $rIn = [float](4 * $scale)
    $g.DrawEllipse($penOuter, [float]($rightCenter - $rOut), [float]($circleY - $rOut), [float]($rOut * 2), [float]($rOut * 2))
    $g.FillEllipse($brushWhite, [float]($rightCenter - $rIn), [float]($circleY - $rIn), [float]($rIn * 2), [float]($rIn * 2))
    $penOuter.Dispose()
    $brushWhite.Dispose()
}

function Draw-SettingsModal([System.Drawing.Graphics]$g, [int]$W, [int]$H) {
    $scale = [math]::Max(0.75, [math]::Min($W / 1688.0, $H / 780.0))

    $brushDim = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(150, 0, 0, 0))
    $g.FillRectangle($brushDim, 0, 0, $W, $H)
    $brushDim.Dispose()

    $modalW = [int](620 * $scale)
    $modalH = [int](460 * $scale)
    $modalX = [int](($W - $modalW) / 2)
    $modalY = [int](($H - $modalH) / 2)

    $rectModal = [System.Drawing.Rectangle]::new($modalX, $modalY, $modalW, $modalH)
    $brushModal = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(245, 28, 22, 18))
    $penGold = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 212, 175, 55), [float](2.5 * $scale))
    $penInner = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(100, 212, 175, 55), [float](1.0 * $scale))

    $g.FillRectangle($brushModal, $rectModal)
    $g.DrawRectangle($penGold, $rectModal)
    $pad = [int](6 * $scale)
    $g.DrawRectangle($penInner, ($modalX + $pad), ($modalY + $pad), ($modalW - $pad * 2), ($modalH - $pad * 2))

    $brushModal.Dispose()
    $penGold.Dispose()
    $penInner.Dispose()

    $fontHeader = [System.Drawing.Font]::new("Microsoft YaHei", [float](22.0 * $scale), [System.Drawing.FontStyle]::Bold)
    $brushGold = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 240, 180))
    $g.DrawString("【 ⚙️ 游戏设置系统 】", $fontHeader, $brushGold, [float]($modalX + [int](160 * $scale)), [float]($modalY + [int](28 * $scale)))
    $fontHeader.Dispose()
    $brushGold.Dispose()

    $penSep = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(80, 255, 255, 255), [float]1.0)
    $g.DrawLine($penSep, ($modalX + [int](30 * $scale)), ($modalY + [int](75 * $scale)), ($modalX + $modalW - [int](30 * $scale)), ($modalY + [int](75 * $scale)))
    $penSep.Dispose()

    $fontItem = [System.Drawing.Font]::new("Microsoft YaHei", [float](16.0 * $scale), [System.Drawing.FontStyle]::Bold)
    $brushWhite = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(240, 240, 240))
    $brushSub = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(180, 180, 180))
    $brushBtnOn = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 46, 125, 50))

    $rows = @(
        @{ Label = "🎵 背景音乐 (BGM)"; State = "已开启 🔊"; Y = 105 },
        @{ Label = "💥 动作音效 (SFX)"; State = "已开启 🔔"; Y = 175 },
        @{ Label = "📳 触觉振动反馈"; State = "强(默认) 📳"; Y = 245 }
    )
    foreach ($r in $rows) {
        $ry = $modalY + [int]($r.Y * $scale)
        $g.DrawString($r.Label, $fontItem, $brushWhite, [float]($modalX + [int](50 * $scale)), [float]$ry)
        $btnRect = [System.Drawing.Rectangle]::new(($modalX + [int](410 * $scale)), ($ry - [int](4 * $scale)), [int](140 * $scale), [int](40 * $scale))
        $g.FillRectangle($brushBtnOn, $btnRect)
        $g.DrawString($r.State, $fontItem, $brushWhite, [float]($modalX + [int](424 * $scale)), [float]$ry)
    }

    $fontNote = [System.Drawing.Font]::new("Microsoft YaHei", [float](12.0 * $scale), [System.Drawing.FontStyle]::Regular)
    $g.DrawString("※ 设置自动即时保存至本地缓存，保障纯净流畅的单机游玩体验", $fontNote, $brushSub, [float]($modalX + [int](60 * $scale)), [float]($modalY + [int](315 * $scale)))

    $btnConfirm = [System.Drawing.Rectangle]::new(($modalX + [int](180 * $scale)), ($modalY + [int](365 * $scale)), [int](260 * $scale), [int](50 * $scale))
    $brushConfirm = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 184, 134, 11))
    $penConfirm = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 255, 215, 0), [float](1.5 * $scale))
    $g.FillRectangle($brushConfirm, $btnConfirm)
    $g.DrawRectangle($penConfirm, $btnConfirm)

    $fontBtn = [System.Drawing.Font]::new("Microsoft YaHei", [float](16.0 * $scale), [System.Drawing.FontStyle]::Bold)
    $g.DrawString("保存并返回游戏", $fontBtn, $brushWhite, [float]($modalX + [int](235 * $scale)), [float]($modalY + [int](375 * $scale)))

    $fontItem.Dispose()
    $brushWhite.Dispose()
    $brushSub.Dispose()
    $brushBtnOn.Dispose()
    $fontNote.Dispose()
    $brushConfirm.Dispose()
    $penConfirm.Dispose()
    $fontBtn.Dispose()
}

$tasks = @()
if (-not [string]::IsNullOrWhiteSpace($ManifestJson)) {
    if (-not (Test-Path $ManifestJson)) {
        Write-Error "找不到 Manifest 文件: $ManifestJson"
        exit 1
    }
    $rawItems = Get-Content -Path $ManifestJson -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($item in $rawItems) {
        $overlay = "none"
        if ($item.PSObject.Properties.Match("overlay").Count -gt 0 -and $item.overlay) {
            $overlay = [string]$item.overlay
        }
        $destName = if ($item.PSObject.Properties.Match("dest").Count -gt 0 -and $item.dest) {
            [string]$item.dest
        } else {
            $base = [System.IO.Path]::GetFileNameWithoutExtension([string]$item.src)
            "${base}_${GameName}.png"
        }
        $tasks += @{ Src = [string]$item.src; Dest = $destName; Overlay = $overlay }
    }
} else {
    $idx = 1
    $fileItems = $InputFiles -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
    foreach ($f in $fileItems) {
        $num = $idx.ToString("D2")
        $destName = "${Prefix}_${num}_${GameName}.png"
        $tasks += @{ Src = $f; Dest = $destName; Overlay = $OverlayMode }
        $idx++
    }
}

$failedCount = 0
foreach ($t in $tasks) {
    if (-not (Test-Path $t.Src)) {
        Write-Error "源文件不存在: $($t.Src)"
        $failedCount++
        continue
    }

    $srcImg = [System.Drawing.Image]::FromFile((Resolve-Path $t.Src).Path)
    $W = $srcImg.Width
    $H = $srcImg.Height
    if ($W -lt $MinWidth) {
        $ratio = $MinWidth / [double]$W
        $W = $MinWidth
        $H = [int][math]::Round($H * $ratio)
    }

    $bmp = [System.Drawing.Bitmap]::new($W, $H)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    $g.DrawImage($srcImg, 0, 0, $W, $H)
    if ($t.Overlay -eq "settings") {
        Draw-SettingsModal $g $W $H
    }
    Draw-WechatHeader $g $W $H $GameName

    $g.Dispose()
    $srcImg.Dispose()

    $destPath = Join-Path $OutDir $t.Dest
    $bmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()

    $sizeKB = [math]::Round((Get-Item $destPath).Length / 1024.0, 1)
    if ($sizeKB -lt $MinSizeKB -or $sizeKB -gt $MaxSizeKB) {
        Write-Warning "❌ 尺寸超限: $($t.Dest) (${sizeKB} KB，不在 ${MinSizeKB}~${MaxSizeKB} KB 区间)"
        $failedCount++
    } else {
        Write-Host "✅ 已生成: $($t.Dest) (${W}x${H}, ${sizeKB} KB)"
    }
}

if ($failedCount -gt 0) {
    Write-Error "有 $failedCount 张截图生成或大小校验失败。"
    exit 1
}
Write-Host "🎉 全部 $($tasks.Count) 张微信小游戏合规截图生成并校验通过！"
