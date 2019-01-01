# :+1: vCollect Hardware Information By ESXi for each vCenter
## Overview: 
Many of the customer projects I work on involve collecting an inventory of basic information about the #VMware #ESXi in the environment, such as Host, Name, HBAName, Source, Target, LUN, Status, Path, PathSelectionPolicy, and so on.

:shipit:	VMware Code: https://code.vmware.com/samples/5175

:shipit:	GitHub Repository: https://github.com/szemmali/vmware-collect


## Description:

To make this inventory process less time consuming I began using #PowerShell scripts to collect the information I was interested. Over time these scripts got less messy and more useful, so now I want to share my current script.

This PowerShell script, #vCollect-VMHostInfoHwSummary.ps1, will collect Storage PATH Information from Hosts By #vCenter that includes:
```
* vCnetre
* Cluster
* Host 				
* HBAName 			
* Path Selection Policy 
* Status 				
* Source 				
* Target 				
* LUN 				
* Path 				
```

## Output:

The information is output to a CSV file per server and XLXS/CSV file for all vCenter.

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to update tests as appropriate.

## Authors

•	Saddam ZEMMALI — Initial work — My Project
