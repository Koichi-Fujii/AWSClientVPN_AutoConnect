
#----------------------------------------------------------------------------------------------------
$DNSAddressArray = @("*.*.*.*","*.*.*.*.")	#�`�F�b�NDNS�A�h���X
$InterfaceArray1 = @("Wi-Fi","�C�[�T�l�b�g")	#�Г��ڑ��C���^�[�t�F�C�X
$InterfaceArray2 = @("���[�J�� �G���A�ڑ�")	#VPN�C���^�[�t�F�C�X

$CertTemplateName = "CertTemplateName"		#�ؖ����e���v���[�g
$CertTemplateId = "1.3.6.1.4.1.311.21.8"	#�ؖ����e���v���[�g
$CAServer = "CAServer"				#�ؖ������s��

$ConfigName = "downloaded-client-config.ovpn"					#�R���t�B�O��
$ConfigOrg = "C:\Program Files\Tools\Tools\aws_client_vpn\$ConfigName"		#�R���t�B�O�I���W�i���t�@�C��
$ConfigPath = Join-Path $env:USERPROFILE OpenVPN\config\			#�R���t�B�O�ۑ���
$DisableFlag = "disable.flg"							#�����ڑ��������t���O

$KeyPhrase = "SHA1"				#SHA1�n�b�V��

$LoopMSec = 2000				#��ԃ`�F�b�N���[�v�E�F�C�g(�~���b)

#----------------------------------------------------------------------------------------------------
function Get-ThumbPrint($certs){
    $cert = $certs | ?{$_.Issuer -match "$CAServer"}
    $extension = $cert.Extensions | ?{$_.OID.FriendlyName -match "�ؖ����e���v���[�g���"}
    if($extension){
        if(($extension.Format($false) -match $CertTemplateId) -or ($extension.Format($false) -match $CertTemplateName)){
            return $cert.Thumbprint
        }
    }
    $extension = $cert.Extensions | ?{$_.OID.FriendlyName -match "�ؖ����e���v���[�g��"}
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
    $ExitMenuItem.Text = "�I��(&X)"
    $ExitMenuItem.Add_Click({
	$TempPhrase = ""
	$strKey = [Microsoft.VisualBasic.Interaction]::InputBox("�p�X���[�h����͂��Ă�������", "�p�X���[�h����", "")
	$byteKey = [System.Text.Encoding]::ASCII.GetBytes($strKey)
	$sha1 = [System.Security.Cryptography.SHA1]::Create()
	$sha1.ComputeHash($byteKey) | %{$TempPhrase += $_.ToString("x2")}
	if($TempPhrase -ne $KeyPhrase){return}
        $objForm.Close()
        $objNotifyIcon.Visible = $False
    })
    $DisableMenuItem.Index = 1
    if(Test-Path $ConfigPath$DisableFlag){
        $DisableMenuItem.Text = "�L����(&E)"
    }else{
        $DisableMenuItem.Text = "������(&D)"
    }
    $DisableMenuItem.Add_Click({
        if(-not(Test-Path $ConfigPath$DisableFlag)){
            $DisableMenuItem.Text = "�L����(&E)"
            Write-Output "`n" | Out-File -FilePath $ConfigPath$DisableFlag
        }else{
            $DisableMenuItem.Text = "������(&D)"
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

$UserThumb = Get-ChildItem Cert:\CurrentUser\My | %{Get-ThumbPrint($_)}		#�d��

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
