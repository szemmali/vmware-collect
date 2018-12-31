Many of the customer projects I work on involve collecting an inventory of basic information about the ESX in the environment, such as CPU/memory specs, OS versions, volume sizes, and so on.

To make this inventory process less time consuming I began using PowerShell scripts to collect the information I was interested. Over time these scripts got less messy and more useful, so now I want to share my current script.

This PowerShell script, vCollect-VMHostInfoHwSummary.ps1, will collect Hardware Information from Host By vCenter that includes:

"vCenter"             
"Cluster"             
"Name"                
"Version"             
"Hardware Vendor"     
"Hardware Model"      
"Serial Number"       
"BIOS"                
"Build"               
"Max EVC Mode"        
"Num CPU"             
"CPU Model"           
"CPU Core Count Total"
"Memory Usage (GB)"   
"Memory Total (GB)"   
"Connection State"    
"Power State"

The information is output to a CSV file per server and XLXS/CSV file for all vCenter.
