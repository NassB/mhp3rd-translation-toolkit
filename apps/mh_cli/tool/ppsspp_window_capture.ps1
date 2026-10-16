# T44 — capture la zone de jeu de la fenêtre PPSSPP en PNG (docs/QA_PPSSPP.md §10).
#
# Utilise PrintWindow (PW_RENDERFULLCONTENT) : la capture fonctionne même si la
# fenêtre est cachée derrière d'autres. La taille est celle de la zone cliente
# (960x544 = rendu x2 d'un écran de 480x272).
#
#   powershell -File apps/mh_cli/tool/ppsspp_window_capture.ps1 -Out out/ppsspp_shots/a.png
#
# Les captures sont des images du jeu : les garder dans out/ (ignoré par git).
param(
  [Parameter(Mandatory = $true)][string]$Out,
  [string]$ProcessName = 'PPSSPPWindows64'
)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class PpssppWin {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
[PpssppWin]::SetProcessDPIAware() | Out-Null
$p = Get-Process $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $p -or $p.MainWindowHandle -eq 0) { Write-Error "window of $ProcessName not found"; exit 2 }
$r = New-Object PpssppWin+RECT
[PpssppWin]::GetClientRect($p.MainWindowHandle, [ref]$r) | Out-Null
$bmp = New-Object System.Drawing.Bitmap $r.R, $r.B
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
$ok = [PpssppWin]::PrintWindow($p.MainWindowHandle, $hdc, 0x3)
$g.ReleaseHdc($hdc)
if (-not $ok) { Write-Error 'PrintWindow failed'; exit 3 }
New-Item -ItemType Directory -Force (Split-Path -Parent $Out) | Out-Null
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Output "saved $Out $($r.R)x$($r.B)"
