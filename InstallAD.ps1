# Instalar Active Directory
function InstalarActiveDirectory {

   Import-Module ADDSDeployment
   Install-ADDSForest `
   -CreateDnsDelegation:$false `
   -DatabasePath "C:\Windows\NTDS" `
   -DomainMode "WinThreshold" `
   -DomainName "lilsdomain.local" `
   -DomainNetbiosName "LILSDOMAIN" `
   -ForestMode "WinThreshold" `
   -InstallDns:$true `
   -LogPath "C:\Windows\NTDS" `
   -NoRebootOnCompletion:$false `
   -SysvolPath "C:\Windows\SYSVOL" `
   -Force:$true
}
