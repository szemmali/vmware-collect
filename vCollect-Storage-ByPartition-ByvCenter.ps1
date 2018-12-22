##=================================================================================
##       Project:  Collect Storage By Partition for each vCenter
##        AUTHOR:  SADDAM ZEMMALI
##         eMail:  saddam.zemmali@gmail.com
##       CREATED:  14.07.2018 02:03:01
##      REVISION:  --
##       Version:  1.0  ¯\_(ツ)_/¯
##    Repository:  https://github.com/szemmali/vmware-collect
##          Task:  Collect Storage By Partition for each vCenter
##          FILE:  vCollect-Storage-ByPartition-ByvCenter.ps1
##   Description:  Collect Storage By Partition for each vCenter
##   Requirement:  --
##          Note:  Connect With USERNAME/PASSWORD Credential 
##          BUGS:  Set-ExecutionPolicy -ExecutionPolicy Bypass
##=================================================================================
#################################
#  vCollect Targeting Variables # 
################################# 
$StartTime = Get-Date
$report= "reports\"
$dateF = Get-Date -UFormat "%d-%b-%Y_%H-%M-%S" 
##############################
# Check the required modules #
############################## 
function check-Module ($m) {
    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $m}) {
        write-host "Module $m "  -f Magenta -NoNewLine  
        write-host "is already imported." -f Green
    } else {
        # If module is not imported, but available on disk then import
        Write-Warning "Module $m is NOT imported (must be installed before starting)."
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $m}) {
            Import-Module $m -Verbose
        } else {
            # If module is not imported, not available on disk, but is in online gallery then install and import
            if (Find-Module -Name $m | Where-Object {$_.Name -eq $m}) {
                Install-Module -Name $m -Force -Verbose -Scope CurrentUser
                Import-Module $m -Verbose
            } else {
                # If module is not imported, not available and not in online gallery then abort
                Write-Warning "Module $m not imported, not available and not in online gallery, exiting."
                EXIT 1
            }
        }
    }
}

check-Module "CredentialManager"
check-Module "VMware.PowerCLI"

#####################################
#  vCollect Targeting Report Folder # 
#####################################
function check-ReportFolder ($dir) {
    if(!(Test-Path -Path $report$dir )){
        New-Item -ItemType directory -Path $report$dir
        Write-Host "New Storage folder created" -f Magenta
        New-Item -Path $report$dir -Name $dateF -ItemType "directory"
        Write-Host "New Work folder created"   -f Magenta
    }
    else{
      Write-Host "Storage Folder already exists" -f Green
      New-Item -Path $report$dir -Name $dateF -ItemType "directory"
      Write-Host "New Work folder created"  -f Magenta
    }    
}

check-ReportFolder "Storage"

#################################
#   vSphere Targeting Variables # 
#################################  
$vCenterList = Get-Content "vCenter.txt"
$username = Read-Host 'Enter The vCenter Username'
$password = Read-Host 'Enter The vCenter Password' -AsSecureString    
$vccredential = New-Object System.Management.Automation.PSCredential ($username, $password)

#################################
#   vCheck Targeting Variables  # 
################################# 
# Total number of vCenter
$countvc = 0
$TotalVcCount = $vCenterList.count
Write-Host "There are $TotalVcCount vCenter"  -Foregroundcolor "Cyan"

#################################
#           LOG INFO            # 
#################################  
$PathS = "reports\storage\$dateF"
$vC_VM_Storage_Export = "_vCollect_Storage_Info_By-VM_" + (Get-Date -UFormat "%d-%b-%Y-%H-%M") + ".csv"
$All_VM_Storage_Export = "vCollect_All_Storage_Info_By-VM_By-vC_" + (Get-Date -UFormat "%d-%b-%Y-%H-%M") + ".csv"
$Snap_INFO = "All_Snap_Export_" + (Get-Date -UFormat "%d-%b-%Y-%H-%M") + ".csv"
$DCStorageReportVM = @() 
$CountVMs  = @()
$CountHosts  = @()
$CountDS  = 0
$CountCluster  = 0
$countvc =0
#################################
#   Start vCollect By vCenter   # 
################################# 
Disconnect-VIServer  -Force -confirm:$false  -ErrorAction SilentlyContinue -WarningAction 0 | Out-Null
foreach ($vCenter in $vCenterList){
  $countvc++
  Write-Host "Connecting to $vCenter..." -Foregroundcolor "Yellow" -NoNewLine
  $connection = Connect-VIServer -Server $vCenter -Cred $vccredential -ErrorAction SilentlyContinue -WarningAction 0 | Out-Null
  If($? -Eq $True){
      Write-Host "Connected" -Foregroundcolor "Green" 
      Write-Progress -Id 0 -Activity 'Checking vCenter' -Status "Processing $($countvc) of $($TotalVcCount):  $($vCenter)" -CurrentOperation $countvc -PercentComplete (($countvc/$TotalVcCount) * 100)

      #################################
      #   vCheck Targeting Variables  # 
      ################################# 
      $StorageReportVMs = @() 
      # Total number of hosts
      $TotalVMHosts = Get-VMHost
      $TotalVMHostsCount = $TotalVMHosts.count
      $CountHosts = $CountHosts + $TotalVMHosts
      Write-Host "There are $TotalVMHostsCount Hosts in $DefaultVIServer" -Foregroundcolor "Cyan"

      # Total number of guests
      $TotalVMs = Get-VM
      $TotalVMsCount = $TotalVMs.count
      $CountVMs=$CountVMs + $TotalVMsCount
      Write-Host "There are $TotalVMsCount Virtual Machines in $DefaultVIServer" -Foregroundcolor "Cyan"
        
      ####################################
      # Start Collect Storage Info by VM #
      #################################### 
      $countvms = 0
      $StorageReportVMs=ForEach ($VM in Get-VM ){ 
          $countvms++

          Write-Progress -Id 1 -ParentId 0 -Activity 'Checking All VMs in vCenter' -Status "Processing $($countvms) of $($TotalVMsCount) VMs" -CurrentOperation $countvms -PercentComplete (($countvms/$TotalVMsCount) * 100)

              ($VM.Extensiondata.Guest.Disk | Select @{N="Data Center";E={$vm | Get-Datacenter | Select-Object -ExpandProperty name }}, 
              @{N="vCenter Server";E={$vm.ExtensionData.Client.ServiceUrl.Split('/')[2].trimend(":443")}}, 
              @{N="Cluster";E={$vm | Get-Cluster | Select-Object -ExpandProperty name}}, 
              @{N="Host";E={$VM.VMHost}}, 
              @{N="Name";E={$VM.Name}},DiskPath, 
              @{N="Capacity(GB)";E={[math]::Round($_.Capacity/ 1GB)}}, 
              @{N="Free Space(GB)";E={[math]::Round($_.FreeSpace / 1GB)}}, 
              @{N="Free Space %";E={[math]::Round(((100* ($_.FreeSpace))/ ($_.Capacity)),0)}})

          Write-Progress -Id 2 -ParentId 1 -Activity 'Gathering Storage Information'   -Status "Processing VM: $($VM)" -CurrentOperation $VM.DisplayName -PercentComplete (100)
      }  
     ####################################
     # END Collect Storage Info by VMs  #
     #################################### 
     Write-Host "Create CSV File with VM Information from $vCenter" 
     $StorageReportVMs | Export-Csv $PathS\$vCenter$vC_VM_Storage_Export -NoTypeInformation -UseCulture  
     Invoke-Item    $PathS$vCenter$vC_VM_Storage_Export
     $DCStorageReportVM +=$StorageReportVMs

   }

  Else{
        Write-Host "Error in Connecting to $vCenter; Try Again with correct user name & password!" -Foregroundcolor "Red" 
    }    

  Write-Host "Export All Storage Information By VM All vCenter" 
  $DCStorageReportVM | Export-Csv $PathS\$All_VM_Storage_Export -NoTypeInformation -UseCulture 

  ##############################
  # Disconnect session from VC #
  ##############################  
  Write-Host "Disconnect to $vCenter..." -Foregroundcolor "Yellow" -NoNewLine 
  $disconnection =Disconnect-VIServer -Server $vCenter  -Force -confirm:$false  -ErrorAction SilentlyContinue -WarningAction 0 | Out-Null

  If($? -Eq $True){
      Write-Host "Disconnected" -Foregroundcolor "Green" 
      Write-Host "#####################################" -Foregroundcolor "Blue" 
   }

  Else{
      Write-Host "Error in Disconnecting to $vCenter" -Foregroundcolor "Red" 
   }
}
#################################
#     End vCollect By vCenter   # 
################################# 

##############################
#       End of Script        #
############################## 
$EndTime = Get-Date
$duration = [math]::Round((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes,2)
Write-Host "================================"
Write-Host "vCollect Storage Info By VM By vCenter Completed!"
Write-Host "There are $SumHosts Hosts in $TotalVcCount vCenter" -Foregroundcolor "Cyan"
Write-Host "There are $SumVMs   Virtual Machines   in $TotalVcCount vCenter" -Foregroundcolor "Cyan"
Write-Host "StartTime: $StartTime"
Write-Host "  EndTime: $EndTime"
Write-Host "  Duration: $duration minutes"
Write-Host "================================"
