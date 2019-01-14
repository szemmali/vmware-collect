##=================================================================================
##       Project:  vCollect All VMs details + Hosts Info for All vCenter
##        AUTHOR:  SADDAM ZEMMALI
##         eMail:  saddam.zemmali@gmail.com
##       CREATED:  14.07.2018 02:03:01
##      REVISION:  --
##       Version:  1.0  ¯\_(ツ)_/¯
##    Repository:  https://github.com/szemmali/vCollect-SDDC-SZ
##          Task:  Collect All VMs details + Hosts Info for All vCenter
##          FILE:  vCollect-AllVMs-details-HostInfo-AllvCenter.ps1
##   Description:  Collect All VMs details + Hosts Info for All vCenter
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
$export="vCollect-Inventory"
$dateF = Get-Date -UFormat "%d-%b-%Y_%H-%M-%S" 
##############################
# Check the required modules #
############################## 
function vcollect-check-Module ($m) {
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

vcollect-check-Module "CredentialManager"
vcollect-check-Module "VMware.PowerCLI"
#####################################
#  vCollect Targeting Report Folder # 
#####################################
function vcollect-check-folder ($dir) {
    if(!(Test-Path -Path $report\$dir )){
        New-Item -ItemType directory -Path $report\$dir
        Write-Host "New $dir folder created" -f Magenta
        New-Item -Path $report\$dir -Name $dateF -ItemType "directory"
        Write-Host "New Work folder created"   -f Magenta
    }
    else{
      Write-Host "$dir Folder already exists" -f Green
      New-Item -Path $report\$dir -Name $dateF -ItemType "directory"
      Write-Host "New Work folder created"  -f Magenta
    }    
}

vcollect-check-folder  $export
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
$ReportInfo="All VMs with host details per vCenter Info Report"
$DCReport = @()
$AllvCenter = $vCenterList.count
$AllDCVMs=0
$h=0

#################################
#       Reports INFO            # 
################################# 
$PathH = "$report\$export\$dateF"
# XLSX Reports
$ReportXls = "vCollect_All_VMs_Report_All-vCenter_" + (Get-Date -UFormat "%d-%b-%Y-%H-%M") +".xlsx"

# CVS Reports
$ReportCSV = "_vCollect_All_VMs_Report_By-vCenter_" + (Get-Date -UFormat "%d-%b-%Y-%H-%M") + ".csv"
$ReportCsvAll = "vCollect_All_VMs_Report_All-vCenter_" + (Get-Date -UFormat "%d-%b-%Y-%H-%M") + ".csv"

#################################
#   Start vCollect By vCenter   # 
################################# 
Write-Host "There are $AllvCenter vCenter"  -Foregroundcolor "Cyan"
Disconnect-VIServer  -Force -confirm:$false  -ErrorAction SilentlyContinue -WarningAction 0 | Out-Null
foreach ($vCenter in $vCenterList){
	$h++
	Write-Host "Connecting to $vCenter..." -Foregroundcolor "Yellow" -NoNewLine
	$connection = Connect-VIServer -Server $vCenter -Cred $vccredential -ErrorAction SilentlyContinue -WarningAction 0 | Out-Null
	If($? -Eq $True){
		Write-Host "Connected" -Foregroundcolor "Green" 		
        Write-Progress -Activity "vCollecting vCenter" -Status ("vCenter: {0}" -f $vCenter) -PercentComplete ($h/$AllvCenter*100) -Id 0
        ##############################
        #    Gathering information   #
        ##############################
        Write-Host "Gathering VMs Informations From vCenter: $vCenter"
        $VMs = Get-VM | Sort-Object -Property Name
        $AllVMs=$VMs.count
        $AllDCVMs=$AllDCVMs+$AllVMs
        Write-Host "# There are $AllVMs VMs in vCenter: $vCenter" -Foregroundcolor "Yellow"

        ###################################
        #   Gathering VMs informations    #
        ###################################
        Write-Host "Gathering VMs Informations"   -Foregroundcolor "Cyan"
        $i=0
        $Report = @()         
        foreach ($VM in $VMs) {
            $i++
            Write-Progress -Activity "vCollecting All VMs Details" -Status ("VM: {0}" -f $VM.Name) -PercentComplete ($i/$AllVMs*100) -Id 1  -ParentId 0
            #Datacenter info  
            $datacenter = $VM | Get-Datacenter | Select-Object -ExpandProperty name  
            #Cluster info  
            $cluster = $VM | Get-Cluster | Select-Object -ExpandProperty name  
            #vCenter Server  
            $vCenter = $VM.ExtensionData.Client.ServiceUrl.Split('/')[2].trimend(":443") 

            ##### VMCPUCount
            $VNumCPU=$vm.ExtensionData.Config.Hardware.NumCPU
            $VNumCoresPerSocket=$vm.ExtensionData.Config.Hardware.NumCoresPerSocket
            $VMCPUCount=$VNumCPU/$VNumCoresPerSocket
            
            ##### HostCPUCoreCount
            $HNumCpuCores=$vm.VMHost.ExtensionData.Summary.Hardware.NumCpuCores
            $HNumCpuPkgs=$vm.VMHost.ExtensionData.Summary.Hardware.NumCpuPkgs
            $HostCPUCoreCount=$HNumCpuCores/$HNumCpuPkgs

            # Network Configuration
            $IPAddresses = "";
            $MACAddresses = "";
            $NetworkNames = "";
            foreach ($NIC in $VM.Guest.Nics) {
                $IPAddresses += $NIC.IPAddress -join ','
                $MACAddresses += $NIC.MacAddress
                $NetworkNames += $NIC.NetworkName
            
                $IPAddresses += ','
                $MACAddresses += ','
                $NetworkNames += ','
            }

            # Get the VM Data
            $Vmresult = New-Object PSObject  
            $Vmresult | add-member -MemberType NoteProperty -Name "Data Center"                     -Value  $datacenter
            $Vmresult | add-member -MemberType NoteProperty -Name "vCenter Server"                  -Value  $vCenter
            $Vmresult | add-member -MemberType NoteProperty -Name "vCluster"                        -Value  $cluster
            $Vmresult | add-member -MemberType NoteProperty -Name "VM"                              -Value  $VM.Name
            $Vmresult | add-member -MemberType NoteProperty -Name "VM CPU Count"                    -Value  $VMCPUCount
            $Vmresult | add-member -MemberType NoteProperty -Name "VM CPU Core Count"               -Value  $vm.NumCPU
            $Vmresult | add-member -MemberType NoteProperty -Name "Power State"                     -Value  $VM.PowerState
            $Vmresult | add-member -MemberType NoteProperty -Name "Fault Tolerance State"           -Value  $VM.ExtensionData.Summary.Runtime.FaultToleranceState
            $Vmresult | add-member -MemberType NoteProperty -Name "Online Standby"                  -Value  $VM.ExtensionData.Summary.Runtime.OnlineStandby
            $Vmresult | add-member -MemberType NoteProperty -Name "Version"                         -Value  $VM.Version
            $Vmresult | add-member -MemberType NoteProperty -Name "Description"                     -Value  $VM.Description
            $Vmresult | add-member -MemberType NoteProperty -Name "Notes"                           -Value  $VM.Notes
            $Vmresult | add-member -MemberType NoteProperty -Name "Memory MB"                       -Value  $VM.MemoryMB
            $Vmresult | add-member -MemberType NoteProperty -Name "Resource Pool"                   -Value  $VM.ResourcePool
            $Vmresult | add-member -MemberType NoteProperty -Name "Resource Pool ID"                -Value  $VM.ResourcePoolId
            $Vmresult | add-member -MemberType NoteProperty -Name "Persistent ID"                   -Value  $VM.PersistentId
            $Vmresult | add-member -MemberType NoteProperty -Name "ID"                              -Value  $VM.Id
            $Vmresult | add-member -MemberType NoteProperty -Name "UID"                             -Value  $VM.Uid
            $Vmresult | add-member -MemberType NoteProperty -Name "UUID"                            -Value  $VM.ExtensionData.Config.Uuid
            $Vmresult | add-member -MemberType NoteProperty -Name "IPs"                             -Value  $IPAddresses
            $Vmresult | add-member -MemberType NoteProperty -Name "MACs"                            -Value  $MACAddresses
            $Vmresult | add-member -MemberType NoteProperty -Name "Network Names"                   -Value  $NetworkNames
            $Vmresult | add-member -MemberType NoteProperty -Name "OS"                              -Value  $VM.Guest.OSFullName
            $Vmresult | add-member -MemberType NoteProperty -Name "FQDN"                            -Value  $VM.Guest.HostName
            $Vmresult | add-member -MemberType NoteProperty -Name "Screen Dimensions"               -Value  $VM.Guest.ScreenDimensions
            $Vmresult | add-member -MemberType NoteProperty -Name "OS2"                             -Value  $VM.ExtensionData.Guest.OSFullName
            $Vmresult | add-member -MemberType NoteProperty -Name "FQDN2"                           -Value  $VM.ExtensionData.Guest.HostName
            $Vmresult | add-member -MemberType NoteProperty -Name "Guest Host name"                 -Value  $VM.ExtensionData.Summary.Guest.HostName
            $Vmresult | add-member -MemberType NoteProperty -Name "Guest Id"                        -Value  $VM.ExtensionData.Summary.Guest.GuestId
            $Vmresult | add-member -MemberType NoteProperty -Name "Guest Full Name"                 -Value  $VM.ExtensionData.Summary.Guest.GuestFullName
            $Vmresult | add-member -MemberType NoteProperty -Name "Guest IP"                        -Value  $VM.ExtensionData.Summary.Guest.IpAddress
            $Vmresult | add-member -MemberType NoteProperty -Name "Cluster"                         -Value  $vm.VMHost.Parent.Name
            $Vmresult | add-member -MemberType NoteProperty -Name "Host Name1"                      -Value  $vm.VMHost.Name
            $Vmresult | add-member -MemberType NoteProperty -Name "Host Name2"                      -Value  $vm.VMHost.ExtensionData.Summary.Config.Name
            $Vmresult | add-member -MemberType NoteProperty -Name "Host Name3"                      -Value  $VM.VMHost.NetworkInfo.HostName
            $Vmresult | add-member -MemberType NoteProperty -Name "Host Domain Name"                -Value  $VM.VMHost.NetworkInfo.DomainName
            $Vmresult | add-member -MemberType NoteProperty -Name "Host CPU Count"                  -Value  $vm.VMHost.ExtensionData.Summary.Hardware.NumCpuPkgs
            $Vmresult | add-member -MemberType NoteProperty -Name "Host CPU Core Count"             -Value  $HostCPUCoreCount
            $Vmresult | add-member -MemberType NoteProperty -Name "Hyperthreading Active"           -Value  $vm.VMHost.HyperthreadingActive
            $Vmresult | add-member -MemberType NoteProperty -Name "Host Manufacturer"               -Value  $VM.VMHost.Manufacturer
            $Vmresult | add-member -MemberType NoteProperty -Name "Host ID"                         -Value  $VM.VMHost.Id
            $Vmresult | add-member -MemberType NoteProperty -Name "Host UID"                        -Value  $VM.VMHost.Uid
            $Vmresult | add-member -MemberType NoteProperty -Name "Host Power State"                -Value  $VM.VMHost.PowerState
            $Vmresult | add-member -MemberType NoteProperty -Name "Host Hyper Threading"            -Value  $VM.VMHost.HyperthreadingActive
            $Vmresult | add-member -MemberType NoteProperty -Name "Host vMotion Enabled"            -Value  $vm.VMHost.ExtensionData.Summary.Config.VmotionEnabled
            $Vmresult | add-member -MemberType NoteProperty -Name "Host Vendor"                     -Value  $VM.VMHost.ExtensionData.Hardware.SystemInfo.Vendor
            $Vmresult | add-member -MemberType NoteProperty -Name "Host Model"                      -Value  $VM.VMHost.ExtensionData.Hardware.SystemInfo.Model
            $Vmresult | add-member -MemberType NoteProperty -Name "Host RAM"                        -Value  $VM.VMHost.ExtensionData.Summary.Hardware.MemorySize
            $Vmresult | add-member -MemberType NoteProperty -Name "Host CPU Model"                  -Value  $VM.VMHost.ExtensionData.Summary.Hardware.CpuModel
            $Vmresult | add-member -MemberType NoteProperty -Name "Host Thread Count"               -Value  $VM.VMHost.ExtensionData.Summary.Hardware.NumCpuThreads
            $Vmresult | add-member -MemberType NoteProperty -Name "Host CPU Speed"                  -Value  $VM.VMHost.ExtensionData.Summary.Hardware.CpuMhz
            $Vmresult | add-member -MemberType NoteProperty -Name "Host Vmresult Name"              -Value  $VM.VMHost.ExtensionData.Summary.Config.Product.Name
            $Vmresult | add-member -MemberType NoteProperty -Name "Host Vmresult Version"           -Value  $VM.VMHost.ExtensionData.Summary.Config.Product.Version
            $Vmresult | add-member -MemberType NoteProperty -Name "Host Vmresult Build"             -Value  $VM.VMHost.ExtensionData.Summary.Config.Product.Build
            $Vmresult | add-member -MemberType NoteProperty -Name "Host Vmresult OS"                -Value  $VM.VMHost.ExtensionData.Summary.Config.Product.OsType
            $Vmresult | add-member -MemberType NoteProperty -Name "Host Vmresult License Key"       -Value  $VM.VMHost.LicenseKey
            $Vmresult | add-member -MemberType NoteProperty -Name "Host Vmresult License Name"      -Value  $VM.VMHost.ExtensionData.Summary.Config.Product.LicenseVmresultName
            $Vmresult | add-member -MemberType NoteProperty -Name "Host Vmresult License Version"   -Value  $VM.VMHost.ExtensionData.Summary.Config.Product.LicenseVmresultVersion
            $Vmresult | add-member -MemberType NoteProperty -Name "Host vMotion IP Address"         -Value  $VM.VMHost.ExtensionData.Config.vMotion.IPConfig.IpAddress
            $Vmresult | add-member -MemberType NoteProperty -Name "Host vMotion Subnet Mask"        -Value  $VM.VMHost.ExtensionData.Config.vMotion.IPConfig.SubnetMask 
            $report += $Vmresult 
        } # END For VM

        ########################################
        #   END Collect HW Info by vCenter     #
        ######################################## 
        Write-Host "Export $ReportInfo from vcenter: $vCenter" -Foregroundcolor "Green"  
        $Report | Export-Csv $PathH\$vCenter$ReportCSV -NoTypeInformation -UseCulture 
        $Report | Export-Excel -Path $PathH\$ReportXls -WorkSheetname "$vCenter" 

        #Invoke-Item    $PathS\$vCenter$ReportCSV
        $DCReport +=$Report
	} # END If Connection OK
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
Write-Host "vCollect All VMs for each vCenter Completed!"
Write-Host "There are $AllDCVMs VMs in $AllvCenter vCenter" -Foregroundcolor "Cyan"
Write-Host "StartTime: $StartTime"
Write-Host "  EndTime: $EndTime"
Write-Host "  Duration: $duration minutes"
Write-Host "================================"
