<#

.SYNOPSIS
    PowerShell script to remove stale VPN connections.

.PARAMETER MaxAge
    The value in seconds to remove VPN connections older than. The minimum accepted value is 3600 (1 hour). The default is 86400 (24 hours).

.EXAMPLE
    .\Remove-VpnConnections -MaxAge 28800

.DESCRIPTION
    It is not uncommon for Windows Server Routing and Remote Access Service (RRAS) servers to maintain VPN connections long after the user has disconnected. This PowerShell script can be used to remove those stale connections.

.LINK
    https://directaccess.richardhicks.com/

.NOTES
    Version:        1.0
    Creation Date:  April 14, 2020
    Last Updated:   April 14, 2020
    Author:         Richard Hicks
    Organization:   Richard M. Hicks Consulting, Inc.
    Contact:        rich@richardhicks.com
    Web Site:       https://directaccess.richardhicks.com/

#>

[CmdletBinding()]

Param(

    [ValidateRange(3600,86400)]
    [string]$MaxAge = '86400'

)

# Get Connections Older Than the Max Age
$Connections = Get-RemoteAccessConnectionStatistics | Where-Object ConnectionDuration -ge $MaxAge | Select-Object Username, ClientIPAddress | Sort-Object UserName

# If no Connections Exceed the Value of MaxAge, Exit the Script
If ($null -eq $Connections)
{
    Write-Warning "No connections exceeding $MaxAge seconds. Exiting script."
    Exit
}

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
