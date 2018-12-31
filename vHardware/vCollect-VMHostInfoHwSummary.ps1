##=================================================================================
##       Project:  vCollect Hardware Info  By ESXi for each vCenter
##        AUTHOR:  SADDAM ZEMMALI
##         eMail:  saddam.zemmali@gmail.com
##       CREATED:  14.07.2018 02:03:01
##      REVISION:  --
##       Version:  1.0  ¯\_(ツ)_/¯
##    Repository:  https://github.com/szemmali/vmware-collect
##          Task:   vCollect Hardware Info  By ESXi for each vCenter
##          FILE:  vCollect-Storage-ByPartition-ByvCenter.ps1
##   Description:  vCollect Hardware Info  By ESXi for each vCenter
##   Requirement:  --
##          Note:  Connect With USERNAME/PASSWORD Credential 
##          BUGS:  Set-ExecutionPolicy -ExecutionPolicy Bypass
##=================================================================================
#################################
#  vCollect Targeting Variables # 
################################# 
$StartTime = Get-Date
$report= "..\reports\"
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

check-ReportFolder "vHardware"

#################################
#   vSphere Targeting Variables # 
#################################  
$vCenterList = Get-Content "..\vCenter.txt"
$username = Read-Host 'Enter The vCenter Username'
$password = Read-Host 'Enter The vCenter Password' -AsSecureString    
$vccredential = New-Object System.Management.Automation.PSCredential ($username, $password)

#################################
#   vCheck Targeting Variables  # 
################################# 
$ReportInfo="Hardware Info Report"
$countvc = 0
$CountHosts = 0
$TotalVcCount = $vCenterList.count
Write-Host "There are $TotalVcCount vCenter"  -Foregroundcolor "Cyan"

#################################
#           LOG INFO            # 
################################# 
$PathH = "..\reports\Hardware\$dateF"
$DCReport = @()
# XLSX Reports
$ReportXlsVC = "_fileName_VM_" + (Get-Date -UFormat "%d-%b-%Y-%H-%M") +".xlsx"
$ReportXls = "vCollect_All_ESXi_Hardware_Report_ByVC_" + (Get-Date -UFormat "%d-%b-%Y-%H-%M") +".xlsx"

# CVS Reports
$ReportCSV = "_vCollect_Hardware_Info_ByESXi_" + (Get-Date -UFormat "%d-%b-%Y-%H-%M") + ".csv"
$ReportCsvAll = "vCollect_All_ESXi_Hardware_Report_ByVC_" + (Get-Date -UFormat "%d-%b-%Y-%H-%M") + ".csv"

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
      # Total number of hosts
      $TotalVMHosts = Get-VMHost
      $TotalVMHostsCount = $TotalVMHosts.count
      $CountHosts = $CountHosts + $TotalVMHostsCount
      Write-Host "There are $TotalVMHostsCount Hosts in $DefaultVIServer" -Foregroundcolor "Cyan"

      ##############################
      # Gathering ESXi information #
      ##############################
      Write-Host "Gathering ESXi Hardware Information"
      $Report = @() 
      $vmHosts = get-vmhost | select Name,ConnectionState,PowerState,NumCpu,MemoryUsageGB,MemoryTotalGB,Version,Build,MaxEVCMode,@{N="BiosVersion";E={$_.ExtensionData.Hardware.BiosInfo.BiosVersion}}, @{N="BiosReleaseDate";E={$_.ExtensionData.Hardware.BiosInfo.ReleaseDate}},@{N="Cluster";E={ $_.Parent}},@{N="vCenter";E={ ($_.uid).split("@")[1].split(":")[0]}} 
      foreach ($vmHost in $vmHosts) {       
          
            $ConnectionState = $vmHost.ConnectionState
            if ($ConnectionState -eq 'NotResponding'){
                $ESXiInfo = New-Object PSObject  
                $ESXiInfo | add-member -MemberType NoteProperty -Name "vCenter"                 -Value $vmHost.vcenter 
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Cluster"                 -Value $vmHost.Cluster 
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Name"                    -Value $vmHost.name
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Version"                 -Value $vmHost.Version   
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Hardware Vendor"         -Value "Unknown" 
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Hardware Model"          -Value "Unknown" 
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Serial Number"           -Value "Unknown"
                $ESXiInfo | add-member -MemberType NoteProperty -Name "BIOS Version"            -Value $vmHost.BiosVersion 
                $ESXiInfo | add-member -MemberType NoteProperty -Name "BIOS Release Date"       -Value $vmHost.BiosReleaseDate
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Build"                   -Value $vmHost.Build
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Max EVC Mode"            -Value $vmHost.MaxEVCMode 
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Num CPU"                 -Value $vmHost.NumCpu 
                $ESXiInfo | add-member -MemberType NoteProperty -Name "CPU Model"               -Value "Unknown" 
                $ESXiInfo | add-member -MemberType NoteProperty -Name "CPU Core Count Total"    -Value "Unknown"
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Memory Usage (GB)"       -Value "Unknown"            
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Memory Total (GB)"       -Value $vmHost.MemoryTotalGB 
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Connection State"        -Value $vmHost.ConnectionState
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Power State"             -Value $vmHost.PowerState 
            }
            else {
                $VMHardwareInfo = get-vmhosthardware -vmhost $vmHost.name |select Manufacturer, Model, SerialNumber,CpuModel, CpuCoreCountTotal
                $ESXiInfo = New-Object PSObject  
                $ESXiInfo | add-member -MemberType NoteProperty -Name "vCenter"                 -Value $vmHost.vcenter 
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Cluster"                 -Value $vmHost.Cluster 
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Name"                    -Value $vmHost.name
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Version"                 -Value $vmHost.Version   
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Hardware Vendor"         -Value $VMHardwareInfo.Manufacturer 
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Hardware Model"          -Value $VMHardwareInfo.Model 
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Serial Number"           -Value $VMHardwareInfo.SerialNumber
                $ESXiInfo | add-member -MemberType NoteProperty -Name "BIOS Version"            -Value $vmHost.BiosVersion 
                $ESXiInfo | add-member -MemberType NoteProperty -Name "BIOS Release Date"       -Value $vmHost.BiosReleaseDate
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Build"                   -Value $vmHost.Build
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Max EVC Mode"            -Value $vmHost.MaxEVCMode 
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Num CPU"                 -Value $vmHost.NumCpu 
                $ESXiInfo | add-member -MemberType NoteProperty -Name "CPU Model"               -Value $VMHardwareInfo.CpuModel 
                $ESXiInfo | add-member -MemberType NoteProperty -Name "CPU Core Count Total"    -Value $VMHardwareInfo.CpuCoreCountTotal
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Memory Usage (GB)"       -Value $vmHost.MemoryUsageGB            
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Memory Total (GB)"       -Value $vmHost.MemoryTotalGB 
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Connection State"        -Value $vmHost.ConnectionState
                $ESXiInfo | add-member -MemberType NoteProperty -Name "Power State"             -Value $vmHost.PowerState 
            }
            $report += $ESXiInfo
      } # END foreach 
    ########################################
    #   END Collect HW Info by vCenter     #
    ######################################## 
    Write-Host "Export $ReportInfo from vcenter: $vCenter" -Foregroundcolor "Green"  
    $Report | Export-Csv $PathH\$vCenter$ReportCSV -NoTypeInformation -UseCulture 
    $Report | Export-Excel -Path $PathH\$ReportXls -WorkSheetname "$vCenter" 
    #Invoke-Item    $PathS\$vCenter$ReportCSV
    $DCReport +=$Report
    
  } # END If 

  Else{
    Write-Host "Error in Connecting to $vCenter; Try Again with correct user name & password!" -Foregroundcolor "Red" 
  }
  ########################################
  # END Collect HW Info from All vCenter #
  ######################################## 
  Write-Host "Export All $ReportInfo from All vCenter" -Foregroundcolor "Green" 
  $DCReport | Export-Csv $PathH\$ReportCsvAll -NoTypeInformation -UseCulture 
  $DCReport | Export-Excel -Path $PathH\$ReportXls -WorkSheetname "All vCenter" 

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
#Invoke-Item $PathH \$ReportXls

##############################
#       End of Script        #
############################## 
$EndTime = Get-Date
$duration = [math]::Round((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes,2)
Write-Host "================================"
Write-Host "vCollect Harware Info By ESXi By vCenter Completed!"
Write-Host "There are $CountHosts Hosts in $TotalVcCount vCenter" -Foregroundcolor "Cyan"
Write-Host "StartTime: $StartTime"
Write-Host "  EndTime: $EndTime"
Write-Host "  Duration: $duration minutes"
Write-Host "================================"
