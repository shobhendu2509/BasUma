function Get-DbaDBMailAccount {
    <#
    .SYNOPSIS
        Gets database mail accounts from SQL Server

    .DESCRIPTION
        Gets database mail accounts from SQL Server

    .PARAMETER SqlInstance
        TThe target SQL Server instance or instances.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER Account
        Specifies one or more account(s) to get. If unspecified, all accounts will be returned.

    .PARAMETER ExcludeAccount
        Specifies one or more account(s) to exclude.

    .PARAMETER InputObject
        Accepts pipeline input from Get-DbaDBMail

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: DatabaseMail, DBMail, Mail
        Author: Chrissy LeMaire (@cl), netnerds.net

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MITIT

    .LINK
        https://dbatools.io/Get-DbaDbMailAccount

    .EXAMPLE
        PS C:\> Get-DbaDBMailAccount -SqlInstance sql01\sharepoint

        Returns DBMail accounts on sql01\sharepoint

    .EXAMPLE
        PS C:\> Get-DbaDBMailAccount -SqlInstance sql01\sharepoint -Account 'The DBA Team'

        Returns The DBA Team DBMail account from sql01\sharepoint

    .EXAMPLE
        PS C:\> Get-DbaDBMailAccount -SqlInstance sql01\sharepoint | Select *

        Returns the DBMail accounts on sql01\sharepoint then return a bunch more columns

    .EXAMPLE
        PS C:\> $servers = "sql2014","sql2016", "sqlcluster\sharepoint"
        PS C:\> $servers | Get-DbaDBMail | Get-DbaDBMailAccount

        Returns the db DBMail accounts for "sql2014","sql2016" and "sqlcluster\sharepoint"

#>
    [CmdletBinding()]
    param (
        [Alias("ServerInstance", "SqlServer")]
        [DbaInstanceParameter[]]$SqlInstance,
        [Alias("Credential")]
        [PSCredential]$SqlCredential,
        [string[]]$Account,
        [string[]]$ExcludeAccount,
        [Parameter(ValueFromPipeline)]
        [Microsoft.SqlServer.Management.Smo.Mail.SqlMail[]]$InputObject,
        [switch]$EnableException
    )
    process {
        foreach ($instance in $SqlInstance) {
            $InputObject += Get-DbaDBMail -SqlInstance $SqlInstance -SqlCredential $SqlCredential
        }

        if (-not $InputObject) {
            Stop-Function -Message "No servers to process"
            return
        }

        foreach ($mailserver in $InputObject) {
            try {
                $accounts = $mailserver.Accounts

                if ($Account) {
                    $accounts = $accounts | Where-Object Name -in $Account
                }

                If ($ExcludeAccount) {
                    $accounts = $accounts | Where-Object Name -notin $ExcludeAccount

                }

                $accounts | Add-Member -Force -MemberType NoteProperty -Name ComputerName -value $mailserver.ComputerName
                $accounts | Add-Member -Force -MemberType NoteProperty -Name InstanceName -value $mailserver.InstanceName
                $accounts | Add-Member -Force -MemberType NoteProperty -Name SqlInstance -value $mailserver.SqlInstance
                $accounts | Select-DefaultView -Property ComputerName, InstanceName, SqlInstance, ID, Name, DisplayName, Description, EmailAddress, ReplyToAddress, IsBusyAccount, MailServers
            } catch {
                Stop-Function -Message "Failure" -ErrorRecord $_ -Continue
            }
        }
    }
}

