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
if (-not (Test-Path '.\vCollect-Reports')) { New-Item -Path '.\vCollect-Reports' -ItemType Directory -Force | Out-Null }
$report= ".\vCollect-Reports"
$dateF = Get-Date -UFormat "%d-%b-%Y_%H-%M-%S" 
##############################
# Check the required modules #
############################## 
function vcollect-check-module ($m) {
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

vcollect-check-module "CredentialManager"
vcollect-check-module "VMware.PowerCLI"

#####################################
#  vCollect Targeting Report Folder # 
#####################################
function vcollect-check-folder ($dir) {
    if(!(Test-Path -Path $report\$dir )){
        New-Item -ItemType directory -Path $report\$dir
        Write-Host "New Storage folder created" -f Magenta
        New-Item -Path $report\$dir -Name $dateF -ItemType "directory"
        Write-Host "New Work folder created"   -f Magenta
    }
    else{
      Write-Host "Storage Folder already exists" -f Green
      New-Item -Path $report\$dir -Name $dateF -ItemType "directory"
      Write-Host "New Work folder created"  -f Magenta
    }    
}

vcollect-check-folder "vCollect-Storage"

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
$ReportInfo="Storage Parition Info Report"
$countvc = 0
$CountHosts = 0
$TotalVcCount = $vCenterList.count
Write-Host "There are $TotalVcCount vCenter"  -Foregroundcolor "Cyan"

#################################
#           LOG INFO            # 
################################# 
$PathH = "$report\vCollect-Storage\$dateF"
$DCReport = @()
$DCLowReport = @()
# XLSX Reports
$ReportXlsVC = "_fileName_VM_" + (Get-Date -UFormat "%d-%b-%Y-%H-%M") +".xlsx"
$ReportXls = "vCollect-StoragePartition-AllVMs-AllvCenter_" + (Get-Date -UFormat "%d-%b-%Y-%H-%M") +".xlsx"

# CVS Reports vCollect-StoragePartition-AllVMs-AllvCenter
$ReportCSV = "_vCollect_StoragePartition_Info_ByVM_" + (Get-Date -UFormat "%d-%b-%Y-%H-%M") + ".csv"
$ReportCsvAll = "vCollect-StoragePartition-AllVMs-AllvCenter_" + (Get-Date -UFormat "%d-%b-%Y-%H-%M") + ".csv"

#################################
#   Start vCollect By vCenter   # 
################################# 
#Disconnect-VIServer -Server * -Force -confirm:$false  
disconnect-viserver -confirm:$false
foreach ($vCenter in $vCenterList){
  $countvc++
  Write-Host "Connecting to $vCenter..." -Foregroundcolor "Yellow" -NoNewLine
  $connection = Connect-VIServer -Server $vCenter -Cred $vccredential -ErrorAction SilentlyContinue -WarningAction 0 | Out-Null
  If($? -Eq $True){
    Write-Host "Connected" -Foregroundcolor "Green" 
    Write-Progress -Activity "vCollecting vCenter" -Status ("vCenter: {0}" -f $vCenter) -PercentComplete ($countvc/$TotalVcCount*100) -Id 0
      #################################
      #   vCheck Targeting Variables  # 
      ################################# 
      # Total number of hosts
      $TotalVMHosts = Get-VMHost
      $TotalVMHostsCount = $TotalVMHosts.count
      $CountHosts = $CountHosts + $TotalVMHostsCount
      Write-Host "There are $TotalVMHostsCount Hosts in $DefaultVIServer" -Foregroundcolor "Cyan"
      
      # Total number of VMs
      $TotalVMs = Get-VM
      $TotalVMsCount = $TotalVMs.count
      $CountVMs=$CountVMs + $TotalVMsCount
      Write-Host "There are $TotalVMsCount Virtual Machines in $DefaultVIServer" -Foregroundcolor "Cyan"

      ##############################
      # Gathering ESXi information #
      ##############################
      Write-Host "Gathering Disk Partition Storage Information"
      $Report = @() 
      $DisksLowReport = @() 

      $i=0
      ForEach ($VM in $TotalVMs){ 
        $i++
        Write-Progress -Activity "vCollecting VMs" -Status ("VM: {0}" -f $VM.Name) -PercentComplete ($i/$TotalVMsCount*100) -Id 1  -ParentId 0
        #Datacenter info  
        $datacenter = $vm | Get-Datacenter | Select-Object -ExpandProperty name 
        #vCenter Server  
        $vCenter = $vm.ExtensionData.Client.ServiceUrl.Split('/')[2].trimend(":443") 
        #Cluster info  
        $cluster = $vm | Get-Cluster | Select-Object -ExpandProperty name 
        
        # Total Drives
        $TotalDrives = $VM.ExtensionData.Guest.Disk
        $TotalDrivesCount = $TotalDrives.count
        $j=0
        ForEach ($Drive in $VM.ExtensionData.Guest.Disk){
            $j++
            Write-Progress -Activity "vCollecting Drives" -Status ("Drive: {0}" -f $Drive.DiskPath) -PercentComplete ($j/$TotalDrivesCount*100) -Id 2  -ParentId 1
            $Path = $Drive.DiskPath
            $Capacity   =   [math]::Round($Drive.Capacity/ 1GB)
            $Freespace  =   [math]::Round($Drive.FreeSpace / 1GB)
            $PercentFree=   [math]::Round(((100* ($Drive.FreeSpace))/ ($Drive.Capacity)),0)

            $Vmresult = New-Object PSObject   
            $Vmresult | add-member -MemberType NoteProperty -Name "datacenter"      -Value $datacenter  
            $Vmresult | add-member -MemberType NoteProperty -Name "vCenter Server"  -Value $vCenter  
            $Vmresult | add-member -MemberType NoteProperty -Name "Cluster"         -Value $cluster 
            $Vmresult | add-member -MemberType NoteProperty -Name "Host"            -Value $VM.VMHost 
            $Vmresult | add-member -MemberType NoteProperty -Name "VM Name"         -Value $VM.Name
            $Vmresult | add-member -MemberType NoteProperty -Name "Disk PATH"       -Value $Path
            $Vmresult | add-member -MemberType NoteProperty -Name "Capacity(GB)"    -Value $Capacity
            $Vmresult | add-member -MemberType NoteProperty -Name "Free Space(GB)"  -Value $Freespace
            $Vmresult | add-member -MemberType NoteProperty -Name "Free Space %"    -Value $PercentFree
            $report += $Vmresult                         
            
            if ($PercentFree -lt 10) {     
                $DisksLowresult = New-Object PSObject   
                $DisksLowresult | add-member -MemberType NoteProperty -Name "datacenter"      -Value $datacenter  
                $DisksLowresult | add-member -MemberType NoteProperty -Name "vCenter Server"  -Value $vCenter  
                $DisksLowresult | add-member -MemberType NoteProperty -Name "Cluster"         -Value $cluster 
                $DisksLowresult | add-member -MemberType NoteProperty -Name "Host"            -Value $VM.VMHost 
                $DisksLowresult | add-member -MemberType NoteProperty -Name "VM Name"         -Value $VM.Name
                $DisksLowresult | add-member -MemberType NoteProperty -Name "Disk PATH"       -Value $Path
                $DisksLowresult | add-member -MemberType NoteProperty -Name "Capacity(GB)"    -Value $Capacity
                $DisksLowresult | add-member -MemberType NoteProperty -Name "Free Space(GB)"  -Value $Freespace
                $DisksLowresult | add-member -MemberType NoteProperty -Name "Free Space %"    -Value $PercentFree
                $DisksLowReport += $DisksLowresult
            }
         }
      }            
    ########################################
    #   END Collect HW Info by vCenter     #
    ######################################## 
    Write-Host "Export $ReportInfo from vcenter: $vCenter" -Foregroundcolor "Green"  
    $Report | Export-Csv $PathH\$vCenter$ReportCSV -NoTypeInformation -UseCulture 
    $Report | Export-Excel -Path $PathH\$ReportXls -WorkSheetname "$vCenter" 
    #Invoke-Item    $PathS\$vCenter$ReportCSV
    $DCReport +=$Report
    $DCLowReport += $DisksLowReport
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
  $DCLowReport | Export-Excel -Path $PathH\$ReportXls -WorkSheetname "Disks-Low-Space"
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
