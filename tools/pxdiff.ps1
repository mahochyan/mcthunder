Add-Type -AssemblyName System.Drawing
$E = 'E:\AIprogram\mcthunder-art001-pilot\docs\evidence\t34'
$views = @(
  @{ ortho = "$E\t34_oside.png";  panel = "$E\pnl_side.png";  out = "$E\cmp_px_side.png";  thr = 175 },
  @{ ortho = "$E\t34_ofront.png"; panel = "$E\pnl_front.png"; out = "$E\cmp_px_front.png"; thr = 175 }
)
function Get-Bits($bmp) {
  $rect = New-Object System.Drawing.Rectangle 0,0,$bmp.Width,$bmp.Height
  $d = $bmp.LockBits($rect,'ReadOnly',[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $s = [Math]::Abs($d.Stride); $b = New-Object byte[] ($s * $bmp.Height)
  [System.Runtime.InteropServices.Marshal]::Copy($d.Scan0,$b,0,$b.Length)
  $bmp.UnlockBits($d); ,@($b,$s)
}
function Find-Bbox($b,$s,$w,$h,$thr,$mode) {
  $x0=99999;$y0=99999;$x1=-1;$y1=-1
  for($y=0;$y -lt $h;$y++){ for($x=0;$x -lt $w;$x++){
    $o=$y*$s+$x*4; $lum=([int]$b[$o+2]*299+[int]$b[$o+1]*587+[int]$b[$o]*114)/1000
    $hit = if($mode -eq 'ge'){ $lum -ge $thr } else { $lum -lt $thr }
    if($hit){ if($x -lt $x0){$x0=$x}; if($x -gt $x1){$x1=$x}; if($y -lt $y0){$y0=$y}; if($y -gt $y1){$y1=$y} }
  }}
  @($x0,$y0,$x1,$y1)
}
foreach ($v in $views) {
  $ob = New-Object System.Drawing.Bitmap $v.ortho
  $pb = New-Object System.Drawing.Bitmap $v.panel
  $p1 = Get-Bits $ob; $mb = Find-Bbox $p1[0] $p1[1] $ob.Width $ob.Height 235 'lt'
  $p2 = Get-Bits $pb; $tb = Find-Bbox $p2[0] $p2[1] $pb.Width $pb.Height $v.thr 'lt'
  $mw = $mb[2]-$mb[0]+1; $mh = $mb[3]-$mb[1]+1
  $tw = $tb[2]-$tb[0]+1; $th = $tb[3]-$tb[1]+1
  # 面板等比缩放（按宽度匹配模型 bbox）+ 地面行对齐 + 鼻端左缘对齐
  $sc = $mw / $tw
  $tw2 = [int]($tw * $sc); $th2 = [int]($th * $sc)
  $ps = New-Object System.Drawing.Bitmap $mw,$mh
  $gs = [System.Drawing.Graphics]::FromImage($ps)
  $gs.Clear([System.Drawing.Color]::White)
  $gs.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  # 面板 bbox 底=地面=模型 bbox 底；面板 bbox 左=最左特征（我的 bbox 左同为最左）
  $dx = 0; $dy = $mh - $th2
  $gs.DrawImage($pb, (New-Object System.Drawing.Rectangle $dx,$dy,$tw2,$th2), $tb[0],$tb[1],$tw,$th,[System.Drawing.GraphicsUnit]::Pixel)
  $gs.Dispose()
  $psb = Get-Bits $ps
  # 输出图：白底 rgba
  $ow2 = $mw; $oh2 = $mh
  $oB = New-Object System.Drawing.Bitmap $ow2,$oh2
  $rect = New-Object System.Drawing.Rectangle 0,0,$ow2,$oh2
  $dd = $oB.LockBits($rect,[System.Drawing.Imaging.ImageLockMode]::WriteOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $sd = [Math]::Abs($dd.Stride); $bd = New-Object byte[] ($sd*$oh2)
  for($i=0;$i -lt $bd.Count;$i+=4){ $bd[$i]=255;$bd[$i+1]=255;$bd[$i+2]=255;$bd[$i+3]=255 }
  for($y=0;$y -lt $oh2;$y++){
    $my = $mb[1]+$y
    for($x=0;$x -lt $ow2;$x++){
      $o1 = $my*$p1[1]+($mb[0]+$x)*4
      $gl = ([int]$p1[0][$o1+2]*299+[int]$p1[0][$o1+1]*587+[int]$p1[0][$o1]*114)/1000
      $o2 = $y*$psb[1]+$x*4
      $rl = ([int]$psb[0][$o2+2]*299+[int]$psb[0][$o2+1]*587+[int]$psb[0][$o2]*114)/1000
      $gd = 255-$gl; $rd = 255-$rl
      $R = 255 - $gd*0.475; $G = 255 - $rd*0.475; $B = 255 - ($gd+$rd)*0.475
      if($R -lt 0){$R=0}; if($G -lt 0){$G=0}; if($B -lt 0){$B=0}
      if($R -gt 255){$R=255}; if($G -gt 255){$G=255}; if($B -gt 255){$B=255}
      $o=$y*$sd+$x*4
      $bd[$o]=[byte]$B; $bd[$o+1]=[byte]$G; $bd[$o+2]=[byte]$R; $bd[$o+3]=255
    }
  }
  [System.Runtime.InteropServices.Marshal]::Copy($bd,0,$dd.Scan0,$bd.Length)
  $oB.UnlockBits($dd)
  $oB.Save($v.out)
  Write-Host ("OK " + $v.out + " model=" + ($mb -join ',') + " panel=" + ($tb -join ',') + " ar_model=" + [Math]::Round($mw/$mh,3) + " ar_panel=" + [Math]::Round($tw/$th,3))
  $oB.Dispose(); $ps.Dispose(); $ob.Dispose(); $pb.Dispose()
}
