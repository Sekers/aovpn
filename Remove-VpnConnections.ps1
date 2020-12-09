<#
.SYNOPSIS
    PowerShell script to remove stale VPN connections.
.PARAMETER MaxAge
    The value in seconds to remove VPN connections older than. The minimum accepted value is 3600 (1 hour). The default is 86400 (24 hours).
.EXAMPLE
    .\Remove-VpnConnections -MaxAge 28800
.DESCRIPTION
    It is not uncommon for Windows Server Routing and Remote Access Service (RRAS) servers to maintain device tunnel VPN connections long after the device has disconnected. This PowerShell script can be used to remove those stale connections.
.LINK
    https://github.com/richardhicks/aovpn/blob/master/Remove-VpnConnections.ps1
.NOTES
    Modified by LFCDS to fix some issues (see https://github.com/richardhicks/aovpn/issues/9) and then also added in some code (https://github.com/Sekers/aovpn/blob/patch-1/Remove-VpnConnections.ps1) to remove duplicate entries no matter the age, keeping the newest connection.
#>

[CmdletBinding()]

Param(

    [ValidateRange(3600,86400)]
    [string]$MaxAge = '86400'

)

# Get Connections (Older Than the Max Age)
$Connections = Get-RemoteAccessConnectionStatistics | Where-Object ConnectionDuration -ge $MaxAge | Select-Object Username, ClientIPAddress | Sort-Object UserName

# Remove Users With Connections Exceeding the Value of MaxAge
Write-Verbose "Disconnecting VPN connections older than $MaxAge seconds..."
Foreach ($User in $Connections)
{
    Write-Verbose ("" + $User.Username + " (" + $User.ClientIPAddress.IPAddressToString + ")")
    Disconnect-VpnUser -HostIPAddress $User.ClientIPAddress.IPAddressToString
}

# Get Connections (All) and Unique Users in This List
$Connections = Get-RemoteAccessConnectionStatistics | Select-Object Username, ClientIPAddress, ConnectionDuration
$UniqueUsers = $Connections | Select-Object Username | Sort-Object -Unique Username 

# Disconnect Oldest Duplicate Device Names, Leaving Only the Newset One
Foreach ($User in $UniqueUsers)
{
    Write-Verbose "------------------------------------------"
    
    #Get Matching Connections Sorted by connectionduration Ascending
    $UserConnections = $Connections | Where-Object {$_.Username -eq $User.Username} | Sort-Object ConnectionDuration
    $Count = 0
    foreach ($UserConnection in $UserConnections)
    {
        if ($Count -eq 0) # Keep the Newest Item
        {
            Write-Verbose ("Keeping: " + $UserConnection.Username + " (" + $UserConnection.ClientIPAddress.IPAddressToString + ", " + $UserConnection.ConnectionDuration + ")")
        }
        else
        {   
            Write-Verbose ("Removing: " + $UserConnection.Username + " (" + $UserConnection.ClientIPAddress.IPAddressToString + ", " + $UserConnection.ConnectionDuration + ")")
            Disconnect-VpnUser -HostIPAddress $UserConnection.ClientIPAddress.IPAddressToString
        }
        $Count += 1
    }
}
