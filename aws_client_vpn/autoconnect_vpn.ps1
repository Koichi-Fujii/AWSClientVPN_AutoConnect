
#----------------------------------------------------------------------------------------------------
$DNSAddressArray = @("*.*.*.*","*.*.*.*.")	#チェックDNSアドレス
$InterfaceArray1 = @("Wi-Fi","イーサネット")	#社内接続インターフェイス
$InterfaceArray2 = @("ローカル エリア接続")	#VPNインターフェイス

$CertTemplateName = "CertTemplateName"		#証明書テンプレート
$CertTemplateId = "1.3.6.1.4.1.311.21.8"	#証明書テンプレート
$CAServer = "CAServer"				#証明書発行者

$ConfigName = "downloaded-client-config.ovpn"					#コンフィグ名
$ConfigOrg = "C:\Program Files\Tools\Tools\aws_client_vpn\$ConfigName"		#コンフィグオリジナルファイル
$ConfigPath = Join-Path $env:USERPROFILE OpenVPN\config\			#コンフィグ保存先
$DisableFlag = "disable.flg"							#自動接続無効化フラグ

$KeyPhrase = "SHA1"				#SHA1ハッシュ

$LoopMSec = 2000				#状態チェックループウェイト(ミリ秒)

#----------------------------------------------------------------------------------------------------
function Get-ThumbPrint($certs){
    $cert = $certs | ?{$_.Issuer -match "$CAServer"}
    $extension = $cert.Extensions | ?{$_.OID.FriendlyName -match "証明書テンプレート情報"}
    if($extension){
        if(($extension.Format($false) -match $CertTemplateId) -or ($extension.Format($false) -match $CertTemplateName)){
            return $cert.Thumbprint
        }
    }
    $extension = $cert.Extensions | ?{$_.OID.FriendlyName -match "証明書テンプレート名"}
    if($extension){
        if(($extension.Format($false) -match $CertTemplateId) -or ($extension.Format($false) -match $CertTemplateName)){
            return $cert.Thumbprint
        }
    }
}

#----------------------------------------------------------------------------------------------------
function Get-InterfaceDNS($InterfaceArray){
    $result = $False
    Get-NetIPInterface -AddressFamily "IPv4" -ConnectionState "Connected" | ?{
        $InterfaceArray -contains $_.InterfaceAlias} | %{
            (Get-DnsClientServerAddress -AddressFamily "IPv4" -InterfaceIndex $_.ifIndex).ServerAddresses | %{
                if($DNSAddressArray -contains $_){
                    $result = $True
                }
            }
        }
    return $result
}

#----------------------------------------------------------------------------------------------------
function Initialize-Form{
    $ExitMenuItem.Index = 0
    $ExitMenuItem.Text = "終了(&X)"
    $ExitMenuItem.Add_Click({
	$TempPhrase = ""
	$strKey = [Microsoft.VisualBasic.Interaction]::InputBox("パスワードを入力してください", "パスワード入力", "")
	$byteKey = [System.Text.Encoding]::ASCII.GetBytes($strKey)
	$sha1 = [System.Security.Cryptography.SHA1]::Create()
	$sha1.ComputeHash($byteKey) | %{$TempPhrase += $_.ToString("x2")}
	if($TempPhrase -ne $KeyPhrase){return}
        $objForm.Close()
        $objNotifyIcon.Visible = $False
    })
    $DisableMenuItem.Index = 1
    if(Test-Path $ConfigPath$DisableFlag){
        $DisableMenuItem.Text = "有効化(&E)"
    }else{
        $DisableMenuItem.Text = "無効化(&D)"
    }
    $DisableMenuItem.Add_Click({
        if(-not(Test-Path $ConfigPath$DisableFlag)){
            $DisableMenuItem.Text = "有効化(&E)"
            Write-Output "`n" | Out-File -FilePath $ConfigPath$DisableFlag
        }else{
            $DisableMenuItem.Text = "無効化(&D)"
            Remove-Item -Path $ConfigPath$DisableFlag -Force
        }
    })
    $objContextMenu.MenuItems.Clear()
    $objContextMenu.MenuItems.Add($ExitMenuItem)
    $objContextMenu.MenuItems.Add($DisableMenuItem)

    $objForm.ContextMenu = $objContextMenu
    $objNotifyIcon.ContextMenu = $objContextMenu
    $objNotifyIcon.Icon = [environment]::CurrentDirectory + "\logo.ico"

    $objForm.Visible = $False
    $objForm.WindowState = "Minimized"
    $objForm.ShowInTaskbar = $False
    $objForm.Add_Closing({$objForm.ShowInTaskBar = $False}) 
    $objNotifyIcon.Visible = $True
}

#----------------------------------------------------------------------------------------------------
function Initialize-Config{
    if(-not(Test-Path $ConfigPath$ConfigName)){
        if(-not(Test-Path $ConfigPath)){
            New-Item $ConfigPath -ItemType Directory | Out-Null
        }
        Copy-Item -Path $ConfigOrg -Destination $ConfigPath -Recurse -Force
    }
    if(-not(Select-String $ConfigPath$ConfigName -Pattern "cryptoapicert" -Encoding UTF8 -Quiet)){
        $AddConfig = $Null
        $UserThumb | %{$AddConfig += "`ncryptoapicert `"THUMB:"+$_+"`""}
        Write-Output $AddConfig | Add-Content $ConfigPath$ConfigName -Encoding UTF8
    }
}

#----------------------------------------------------------------------------------------------------
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void] [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic")

$objForm = New-Object System.Windows.Forms.Form
$objNotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$objContextMenu = New-Object System.Windows.Forms.ContextMenu
$ExitMenuItem = New-Object System.Windows.Forms.MenuItem
$DisableMenuItem = New-Object System.Windows.Forms.MenuItem

$UserThumb = Get-ChildItem Cert:\CurrentUser\My | %{Get-ThumbPrint($_)}		#拇印

Initialize-Form
Initialize-Config

Do{
    if(-not(Test-Path $ConfigPath$DisableFlag)){
        if(Get-InterfaceDNS($InterfaceArray1)){
            if(Get-InterfaceDNS($InterfaceArray2)){
                Start-Process -FilePath "C:\Program Files\OpenVPN\bin\openvpn-gui.exe" -ArgumentList "--command disconnect_all" -WindowStyle Normal        
            }
            $objNotifyIcon.BalloonTipText = "AWS Client VPN autoconnect is enable(stopped)."
        }else{
            if(-not(Get-InterfaceDNS($InterfaceArray2))){
                Start-Process -FilePath "C:\Program Files\OpenVPN\bin\openvpn-gui.exe" -ArgumentList "--command connect downloaded-client-config.ovpn" -WindowStyle Normal        
            }
            $objNotifyIcon.BalloonTipText = "AWS Client VPN autoconnect is enable(started)."
        }
    }else{
        $objNotifyIcon.BalloonTipText = "AWS Client VPN autoconnect is disable."
    }
    $objNotifyIcon.Text = $objNotifyIcon.BalloonTipText
    Sleep -Milliseconds $LoopMSec
    [System.Windows.Forms.Application]::DoEvents()
}While($objNotifyIcon.Visible)

if($objNotifyIcon.Visible){
	$objForm.ShowDialog()
}
