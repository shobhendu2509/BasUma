#ValidationTags#Messaging,FlowControl,Pipeline,CodeStyle#
function New-DbaDbMasterKey {
    <#
    .SYNOPSIS
        Creates a new database master key

    .DESCRIPTION
        Creates a new database master key. If no database is specified, the master key will be created in master.

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER SqlCredential
        Allows you to login to SQL Server using alternative credentials.

    .PARAMETER Credential
        Enables easy creation of a secure password.
    
    .PARAMETER Database
        The database where the master key will be created. Defaults to master.

    .PARAMETER Password
        Secure string used to create the key.
    
    .PARAMETER InputObject
        Database object piped in from Get-DbaDatabase.
    
    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Certificate
        Author: Chrissy LeMaire (@cl), netnerds.net

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .EXAMPLE
        PS C:\> New-DbaDbMasterKey -SqlInstance Server1

        You will be prompted to securely enter your password, then a master key will be created in the master database on server1 if it does not exist.

    
    .EXAMPLE
        PS C:\> New-DbaDbMasterKey -SqlInstance Server1 -Credential usernamedoesntmatter

        You will be prompted by a credential interface to securely enter your password, then a master key will be created in the master database on server1 if it does not exist.
    
    .EXAMPLE
        PS C:\> New-DbaDbMasterKey -SqlInstance Server1 -Database db1 -Confirm:$false

        Suppresses all prompts to install but prompts in th console to securely enter your password and creates a master key in the 'db1' database

#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param (
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [PSCredential]$Credential,
        [string[]]$Database = "master",
        [Security.SecureString]$Password,
        [parameter(ValueFromPipeline)]
        [Microsoft.SqlServer.Management.Smo.Database[]]$InputObject,
        [switch]$EnableException
    )
    begin {
        if ($Credential) {
            $Password = $Credential.Password
        } else {
            if (-not $Password) {
                $Password = Read-Host "Password" -AsSecureString
            }
        }
    }
    process {
        if ($SqlInstance) {
            $InputObject += Get-DbaDatabase -SqlInstance $SqlInstance -Database $Database -ExcludeDatabase $ExcludeDatabase
        }
        
        foreach ($db in $InputObject) {
            if ($null -ne $db.MasterKey) {
                Stop-Function -Message "Master key already exists in the $db database on $($db.Parent.Name)" -Target $db -Continue
            }
            
            if ($Pscmdlet.ShouldProcess($db.Parent.Name, "Creating master key for database '$($db.Name)'")) {
                try {
                    $masterkey = New-Object Microsoft.SqlServer.Management.Smo.MasterKey $db
                    $masterkey.Create(([System.Runtime.InteropServices.marshal]::PtrToStringAuto([System.Runtime.InteropServices.marshal]::SecureStringToBSTR($password))))
                    
                    Add-Member -Force -InputObject $masterkey -MemberType NoteProperty -Name ComputerName -value $db.Parent.ComputerName
                    Add-Member -Force -InputObject $masterkey -MemberType NoteProperty -Name InstanceName -value $db.Parent.ServiceName
                    Add-Member -Force -InputObject $masterkey -MemberType NoteProperty -Name SqlInstance -value $db.Parent.DomainInstanceName
                    Add-Member -Force -InputObject $masterkey -MemberType NoteProperty -Name Database -value $db.Name
                    
                    Select-DefaultView -InputObject $masterkey -Property ComputerName, InstanceName, SqlInstance, Database, CreateDate, DateLastModified, IsEncryptedByServer
                } catch {
                    Stop-Function -Message "Failed to create master key in $db on $instance. Exception: $($_.Exception.InnerException)" -Target $masterkey -ErrorRecord $_ -Continue
                }
            }
        }
    }
    end {
        Test-DbaDeprecation -DeprecatedOn "1.0.0" -EnableException:$false -Alias New-DbaDatabaseMasterKey
    }
}

