function Repair-TransientErrors {
    <#
    .SYNOPSIS
        This function will remove a capacity disk from an active storage pool and clear any data including meta data that can lead to transient errors
    .EXAMPLE
        Repair-TransientErrors -ClearData $true

        In this example, any disks with a ststus of 'Transient Error' will be removed from the S2D pool and reset.
    .PARAMETER ClearData
        With this parameter set to true, the disk will be reset and all data will be earsed.  The default is false.

    #>
    [CmdletBinding()]
    param(

        [Parameter()]
        [ValidateSet($True,$False)]
        [string]$ClearData = $false
    
    )
    process {

            #Set varibles
            $S2DStoragePool = Get-StoragePool | Where-Object {$_.FriendlyName -like "S2D *"}          
            $disks = Get-PhysicalDisk | Where-Object {$_.operationalstatus -eq 'Transient Error'}

            ## Remove the faulty disk from the pool
            if (!($disks -eq $null)){
                foreach ($disk in $disks){
                    Set-PhysicalDisk -UniqueId $disk.UniqueId -Usage Retired
                    Remove-PhysicalDisk -PhysicalDisks $disk.UniqueId -StoragePoolFriendlyName $S2DStoragePool.FriendlyName -Confirm:$false
                }
            }
            else {
                break
                throw 'No disks found with a status of Transient Error.'
            }

            ## Clear any data on the physical disk
            if ($ClearData -eq $True){
                foreach ($disk in $disks){
                    Reset-PhysicalDisk -FriendlyName $disk.FriendlyName
                    Set-PhysicalDisk -UniqueId $disk.UniqueId -Usage AutoSelect
                }
            }
            else {
                continue
            }

            ## Add the disk back into the storage pool
            $FixedDisk = Get-PhysicalDisk -CanPool $True
            if ($FixedDisk -ne $null){
                Add-PhysicalDisk -StoragePoolFriendlyName $S2DStoragePool.FriendlyName -PhysicalDisks $FixedDisk.UniqueID
                if ($FixedDisk.BusType -eq "NVMe"){
                    Set-PhysicalDisk -UniqueId $FixedDisk.UniqueId -Usage Journal
                }
                else {
                    Set-PhysicalDisk -UniqueId $FixedDisk.UniqueId -Usage AutoSelect
                }
            }                
        try {
        }
        catch {
            Write-Error "$($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
        }
    }
}
