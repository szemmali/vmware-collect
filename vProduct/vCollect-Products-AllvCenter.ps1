##=================================================================================
##       Project:  vCollect Products for All vCenter
##        AUTHOR:  SADDAM ZEMMALI
##         eMail:  saddam.zemmali@gmail.com
##       CREATED:  14.07.2018 02:03:01
##      REVISION:  --
##       Version:  1.0  ¯\_(ツ)_/¯
##    Repository:  https://github.com/szemmali/vCollect-SDDC-SZ
##          Task:  vCollect Products for All vCenter
##          FILE:  vCollect-Products-AllvCenter.ps1
##   Description:  vCollect Products for All vCenter
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
$export="vCollect-Products"
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
$ReportInfo="All Products per vCenter Info Report"

#################################
#           LOG INFO            # 
################################# 
$PathH = "$report\$export\$dateF"
$DCReport = @()
# XLSX Reports
$ReportXls = "vCollect_All_Products_Report_All-vCenter_" + (Get-Date -UFormat "%d-%b-%Y-%H-%M") +".xlsx"

# CVS Reports
$ReportCSV = "_vCollect_All_Products_Report_By-vCenter_" + (Get-Date -UFormat "%d-%b-%Y-%H-%M") + ".csv"
$ReportCsvAll = "vCollect_All_Products_Report_All-vCenter_" + (Get-Date -UFormat "%d-%b-%Y-%H-%M") + ".csv"

######################################################################
######################################################################
$TotalVcCount = $vCenterList.count
Write-Host "There are $TotalVcCount vCenter"  -Foregroundcolor "Cyan"
$h=0
#################################
#   Start vCollect By vCenter   # 
################################# 
$AllDCProducts=0
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
        Write-Host "Gathering Products Informations From vCenter: $vCenter"
        $VMs = Get-VM * | where { $_.ExtensionData.Summary.Config.Product.Name -ne $null }
        $AllvProducts=$VMs.count
        $AllDCProducts=$AllDCProducts+$AllvProducts
        Write-Host "# There are $AllProducts Products in vCenter: $vCenter" -Foregroundcolor "Yellow"

        ###################################
        # Gathering Products informations #
        ###################################
        Write-Host "Gathering Products Informations"   -Foregroundcolor "Cyan"
        $i=0
        $Report = @()         
        foreach ($VM in $VMs) {
            $i++
            Write-Progress -Activity "vCollecting Products" -Status ("VM: {0}" -f $VM.Name) -PercentComplete ($i/$AllvProducts*100) -Id 1  -ParentId 0
            #Datacenter info  
            $datacenter = $VM | Get-Datacenter | Select-Object -ExpandProperty name  
            #Cluster info  
            $cluster = $VM | Get-Cluster | Select-Object -ExpandProperty name  
            #vCenter Server  
            $vCenter = $VM.ExtensionData.Client.ServiceUrl.Split('/')[2].trimend(":443") 

            $Product = New-Object PSObject 
            $Product | add-member -MemberType NoteProperty -Name "Data Center"         -Value $datacenter
            $Product | add-member -MemberType NoteProperty -Name "vCenter"             -Value $vCenter 
            $Product | add-member -MemberType NoteProperty -Name "Cluster"             -Value $cluster
            $Product | add-member -MemberType NoteProperty -Name "Host"                -Value $VM.VMHost 
            $Product | add-member -MemberType NoteProperty -Name "VM Name"              -Value $VM.name;
            $Product | add-member -MemberType NoteProperty -Name "Product Name"         -Value $VM.extensiondata.summary.config.product.name;
            $Product | add-member -MemberType NoteProperty -Name "Version"             -Value $VM.extensiondata.summary.config.product.version;
            $Product | add-member -MemberType NoteProperty -Name "Full Version"         -Value $VM.extensiondata.summary.config.product.fullversion;
            $Product | add-member -MemberType NoteProperty -Name "Product URL"          -Value $VM.extensiondata.summary.config.product.producturl;
            $Product | add-member -MemberType NoteProperty -Name "App URL"              -Value $VM.extensiondata.summary.config.product.appurl
            $report += $Product 
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
Write-Host "vCollect All Products for each vCenter Completed!"
Write-Host "There are $AllDCProducts VM Products in $TotalVcCount vCenter" -Foregroundcolor "Cyan"
Write-Host "StartTime: $StartTime"
Write-Host "  EndTime: $EndTime"
Write-Host "  Duration: $duration minutes"
Write-Host "================================"
