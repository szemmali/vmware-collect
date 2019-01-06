##=================================================================================
##       Project:  vCollect Storage PATH per ESXi for each vCenter
##        AUTHOR:  SADDAM ZEMMALI
##         eMail:  saddam.zemmali@gmail.com
##       CREATED:  01.01.2019 02:03:01
##      REVISION:  --
##       Version:  0.0.3  ¯\_(ツ)_/¯
##    Repository:  https://github.com/szemmali/vmware-collect
##          Task:  vCollect Storage PATH per ESXi for each vCenter
##          FILE:  vCollect-StoragePATH-ByESXi-PervCenter.ps1
##   Description:  vCollect Storage PATH per ESXi for each vCenter
##   Requirement:  --
##          Note:  Connect With USERNAME/PASSWORD Credential 
##          BUGS:  Set-ExecutionPolicy -ExecutionPolicy Bypass
##=================================================================================
#################################
#  vCollect Targeting Variables # 
################################# 
$StartTime = Get-Date
if (-not (Test-Path '.\vCollect-Reports')) { New-Item -Path '.\vCollect-Reports' -ItemType Directory -Force | Out-Null }
$report= "..\vCollect-Reports"
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

vcollect-check-folder  "vCollect-Storage"
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
$ReportInfo="Storage PATH for each ESXi per vCenter Info Report"

#################################
#           LOG INFO            # 
################################# 
$PathH = "$report\vCollect-Storage\$dateF"
$DCReport = @()
# XLSX Reports
$ReportXlsVC = "_fileName_VM_" + (Get-Date -UFormat "%d-%b-%Y-%H-%M") +".xlsx"
$ReportXls = "vCollect_All_StoragePATH_Report_ByESXi_ByVC_" + (Get-Date -UFormat "%d-%b-%Y-%H-%M") +".xlsx"

# CVS Reports
$ReportCSV = "_vCollect_StoragePATH_Report_ByESXi_" + (Get-Date -UFormat "%d-%b-%Y-%H-%M") + ".csv"
$ReportCsvAll = "vCollect_All_StoragePATH_Report_ByESXi_ByVC_" + (Get-Date -UFormat "%d-%b-%Y-%H-%M") + ".csv"

######################################################################
######################################################################
$TotalVcCount = $vCenterList.count
Write-Host "There are $TotalVcCount vCenter"  -Foregroundcolor "Cyan"
$h=0
#################################
#   Start vCollect By vCenter   # 
################################# 
Disconnect-VIServer  -Force -confirm:$false  -ErrorAction SilentlyContinue -WarningAction 0 | Out-Null
foreach ($vCenter in $vCenterList){
	$h++
	Write-Host "Connecting to $vCenter..." -Foregroundcolor "Yellow" -NoNewLine
	$connection = Connect-VIServer -Server $vCenter -Cred $vccredential -ErrorAction SilentlyContinue -WarningAction 0 | Out-Null
	If($? -Eq $True){
		Write-Host "Connected" -Foregroundcolor "Green" 		
        Write-Progress -Activity "vCollecting vCenter" -Status ("vCenter: {0}" -f $vCenter) -PercentComplete ($h/$TotalVcCount*100) -Id 0
        ##############################
        #    Gathering information   #
        ##############################
        Write-Host "Gathering ESXi Storage PATH Informations From vCenter: $vCenter"
        $esxihosts = Get-VMHost
        $allhosts=$esxihosts.count
        Write-Host "# There are $allhosts ESXi in vCenter: $vCenter" -Foregroundcolor "Yellow"

        ################################
        # Gathering Hosts informations #
        ################################
        Write-Host "Gathering Hosts Informations"   -Foregroundcolor "Cyan"
        $i=0
        $Report = @() 
        ForEach ($esxi in $esxihosts) {            
            $i++
            Write-Progress -Activity "vCollecting hosts" -Status ("Host: {0}" -f $esxi.Name) -PercentComplete ($i/$allhosts*100) -Id 1  -ParentId 0
            $hbas = $esxi | Get-VMHostHba
            $allhbas=$hbas.count
            Write-Host "## There are $allhbas HBAs in ESXi: $esxi" -Foregroundcolor "Yellow"
            
            #Datacenter info  
            $datacenter = $esxi | Get-Datacenter | Select-Object -ExpandProperty name  
            #Cluster info  
            $cluster = $esxi | Get-Cluster | Select-Object -ExpandProperty name  
            #vCenter Server  
            $vCenter = $esxi.ExtensionData.Client.ServiceUrl.Split('/')[2].trimend(":443") 


            ###############################
            # Gathering HBAs informations #
            ###############################
            Write-Host "Gathering HBAs Informations from ESXi: $esxi"    -Foregroundcolor "Cyan"
            $j=0
            ForEach ($hba in $hbas) {
                $j++                
                Write-Progress -Activity "vCollecting HBAs" -Status ("HBA: {0}" -f $hba.Device) -PercentComplete ($j/$allhbas*100) -Id 2  -ParentId 1
                $scsiluns = $hba | Get-ScsiLun
                $allluns=$scsiluns.count
                Write-Host "### There are $allluns LUNs in HBA: $hba" -Foregroundcolor "Yellow"

                ###############################
                # Gathering Luns informations #
                ###############################
                Write-Host "Gathering Luns Informations from HBA: $hba"    -Foregroundcolor "Cyan"
                $k=0
                ForEach ($scsilun in $scsiluns) {
                    $k++
                    Write-Progress -Activity "vCollecting Luns" -Status ("Lun: {0}" -f $scsilun.CanonicalName) -PercentComplete ($k/$allluns*100) -Id 3  -ParentId 2
                    $scsipaths = $scsilun | Get-Scsilunpath
                    $allpaths=$scsipaths.count
                    Write-Host "#### There are $allpaths Paths in LUN: $scsilun" -Foregroundcolor "Yellow"

                    ################################
                    # Gathering Paths informations #
                    ################################
                    Write-Host "Gathering Paths Informations from LUN: $scsilun"   -Foregroundcolor "Cyan"
                    $l=0
                    ForEach ($scsipath in $scsipaths) {
                        $l++                        
                        Write-Progress -Activity "vCollecting Paths" -Status ("Path: {0}" -f $scsipath.Name) -PercentComplete ($l/$allpaths*100) -Id 4  -ParentId 3

                        $SPATHInfo = New-Object PSObject  
                        $SPATHInfo | add-member -MemberType NoteProperty -Name "Data Center"            -Value $datacenter
                        $SPATHInfo | add-member -MemberType NoteProperty -Name "vCenter"                -Value $vCenter 
                        $SPATHInfo | add-member -MemberType NoteProperty -Name "Cluster"                -Value $cluster
                        $SPATHInfo | add-member -MemberType NoteProperty -Name "Host"                   -Value $esxi.name
                        $SPATHInfo | add-member -MemberType NoteProperty -Name "HBA Name"               -Value $scsilun.RuntimeName
                        $SPATHInfo | add-member -MemberType NoteProperty -Name "Path Selection Policy"  -Value $scsilun.MultiPathPolicy
                        $SPATHInfo | add-member -MemberType NoteProperty -Name "Status"                 -Value $scsipath.state
                        #$SPATHInfo | add-member -MemberType NoteProperty -Name "Source"                 -Value "{0}" -f ((("{0:x}" -f $hba.PortWorldWideName) -split '([a-f0-9]{2})' | where {$_}) -Join ":")
                        $SPATHInfo | add-member -MemberType NoteProperty -Name "Target"                 -Value $scsipath.SanId
                        $SPATHInfo | add-member -MemberType NoteProperty -Name "LUN"                    -Value (($scsilun.RunTimeName -Split "L")[1] -as [Int])
                        $SPATHInfo | add-member -MemberType NoteProperty -Name "Path"                   -Value $scsipath.LunPath 
                    }
                $Report += $SPATHInfo                 
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
	}
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
Write-Host "vCollect Storage PATH per ESXi for each vCenter Completed!"
Write-Host "StartTime: $StartTime"
Write-Host "  EndTime: $EndTime"
Write-Host "  Duration: $duration minutes"
Write-Host "================================"
