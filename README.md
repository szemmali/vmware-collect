# :+1: vCollect VMware Informations for each vCenter
## Overview: 
Many of the customer projects I work on involve collecting an inventory of basic and advanced infrastructure information about the environment: that produce infrastructure audit and reports of VMware SDDC (vSphere, NSX, vCloud DIrector, vRealize Automation) environments in CSV or Excel file format.


:shipit:	VMware Code: https://code.vmware.com/user/szemmali

:shipit:	GitHub Repository: https://github.com/szemmali/vmware-collect


## Description:

To make this inventory process less time consuming I began using #PowerShell scripts to collect the information I was interested. Over time these scripts got less messy and more useful, so now I want to share my current script.

The following PowerShell scripts are included as part of the vCollect vSphere:

####	:+1: [vCollect Hardware Information for each ESXi per vCenter](https://github.com/szemmali/vmware-collect/tree/master/vHardware)
####	:+1: [vCollect All Storage Partitions for each VMs in DC per vCenter](https://github.com/szemmali/vmware-collect/blob/master/vCollect-Storage-ByPartition-ByvCenter.ps1)
####	:+1: [vCollect Storage PATH for each  ESXi per vCenter](https://github.com/szemmali/vmware-collect/blob/master/vStorage/vCollect-StoragePATH-ByESXi-PervCenter.ps1)
####	:+1: [Listed of all VMs with all fields With vCenter Credential](https://github.com/szemmali/vmware-collect/blob/master/Collect-vm-info-By-vCenter.ps1)	


## Output:

The information is output to a CSV file per server and XLXS/CSV file for all vCenter.

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to update tests as appropriate.

## Authors

•	Saddam ZEMMALI — Initial work — My Project
