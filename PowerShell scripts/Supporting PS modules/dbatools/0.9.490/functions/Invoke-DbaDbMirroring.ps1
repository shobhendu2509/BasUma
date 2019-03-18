#ValidationTags#Messaging,FlowControl,Pipeline,CodeStyle#
function Invoke-DbaDbMirroring {
    <#
    .SYNOPSIS
        Automates the creation of database mirrors.

    .DESCRIPTION
        Automates the creation of database mirrors.

        * Verifies that a mirror is possible
        * Sets the recovery model to Full if needed
        * If the database does not exist on mirror or witness, a backup/restore is performed
        * Sets up endpoints if necessary
        * Creates a login and grants permissions to service accounts if needed
        * Starts endpoints if needed
        * Sets up partner for mirror
        * Sets up partner for primary
        * Sets up witness if one is specified

        NOTE: If a backup / restore is performed, the backups will be left in tact on the network share.

    .PARAMETER Primary
        SQL Server name or SMO object representing the primary SQL Server.

    .PARAMETER PrimarySqlCredential
        Login to the primary instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER Mirror
        SQL Server name or SMO object representing the mirror SQL Server.

    .PARAMETER MirrorSqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER Witness
        SQL Server name or SMO object representing the witness SQL Server.

    .PARAMETER WitnessSqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER Database
        The database or databases to mirror.

    .PARAMETER NetworkShare
        The network share where the backups will be backed up and restored from.

        Each SQL Server service account must have access to this share.

        NOTE: If a backup / restore is performed, the backups will be left in tact on the network share.

    .PARAMETER InputObject
        Enables piping from Get-DbaDatabase.

    .PARAMETER UseLastBackups
        Use the last full backup of database.

    .PARAMETER Force
        Drop and recreate the database on remote servers using fresh backup.

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Mirror, HA
        Author: Chrissy LeMaire (@cl), netnerds.net

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Invoke-DbaDbMirroring

    .EXAMPLE
        PS C:\> $params = @{
        >> Primary = 'sql2017a'
        >> Mirror = 'sql2017b'
        >> MirrorSqlCredential = 'sqladmin'
        >> Witness = 'sql2019'
        >> Database = 'pubs'
        >> NetworkShare = '\\nas\sql\share'
        >> }
        >>
        PS C:\> Invoke-DbaDbMirror @params

        Performs a bunch of checks to ensure the pubs database on sql2017a
        can be mirrored from sql2017a to sql2017b. Logs in to sql2019 and sql2017a
        using Windows credentials and sql2017b using a SQL credential.

        Prompts for confirmation for most changes. To avoid confirmation, use -Confirm:$false or
        use the syntax in the second example.

    .EXAMPLE
        PS C:\> $params = @{
        >> Primary = 'sql2017a'
        >> Mirror = 'sql2017b'
        >> MirrorSqlCredential = 'sqladmin'
        >> Witness = 'sql2019'
        >> Database = 'pubs'
        >> NetworkShare = '\\nas\sql\share'
        >> Force = $true
        >> Confirm = $false
        >> }
        >>
        PS C:\> Invoke-DbaDbMirror @params

        Performs a bunch of checks to ensure the pubs database on sql2017a
        can be mirrored from sql2017a to sql2017b. Logs in to sql2019 and sql2017a
        using Windows credentials and sql2017b using a SQL credential.

        Drops existing pubs database on Mirror and Witness and restores them with
        a fresh backup.

        Does all the things in the decription, does not prompt for confirmation.

    .EXAMPLE
        PS C:\> $map = @{ 'database_data' = 'M:\Data\database_data.mdf' 'database_log' = 'L:\Log\database_log.ldf' }
        PS C:\> Get-ChildItem \\nas\seed | Restore-DbaDatabase -SqlInstance sql2017b -FileMapping $map -NoRecovery
        PS C:\> Get-DbaDatabase -SqlInstance sql2017a -Database pubs | Invoke-DbaDbMirroring -Mirror sql2017b -Confirm:$false

        Restores backups from sql2017a to a specific file struture on sql2017b then creates mirror with no prompts for confirmation.

    .EXAMPLE
        PS C:\> Get-DbaDatabase -SqlInstance sql2017a -Database pubs |
        >> Invoke-DbaDbMirroring -Mirror sql2017b -UseLastBackups -Confirm:$false

        Mirrors pubs on sql2017a to sql2017b and uses the last full and logs from sql2017a to seed.

#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        [DbaInstanceParameter]$Primary,
        [PSCredential]$PrimarySqlCredential,
        [parameter(Mandatory)]
        [DbaInstanceParameter[]]$Mirror,
        [PSCredential]$MirrorSqlCredential,
        [DbaInstanceParameter]$Witness,
        [PSCredential]$WitnessSqlCredential,
        [string[]]$Database,
        [string]$NetworkShare,
        [parameter(ValueFromPipeline)]
        [Microsoft.SqlServer.Management.Smo.Database[]]$InputObject,
        [switch]$UseLastBackups,
        [switch]$Force,
        [switch]$EnableException
    )
    begin {
        $params = $PSBoundParameters
        $null = $params.Remove('UseLastBackups')
        $null = $params.Remove('Force')
        $null = $params.Remove('Confirm')
        $null = $params.Remove('Whatif')
        $totalSteps = 12
        $Activity = "Setting up mirroring"
    }
    process {
        if ((Test-Bound -ParameterName Primary) -and (Test-Bound -Not -ParameterName Database)) {
            Stop-Function -Message "Database is required when SqlInstance is specified"
            return
        }

        if ($Force -and (-not $NetworkShare -and -not $UseLastBackups)) {
            Stop-Function -Message "NetworkShare or UseLastBackups is required when Force is used"
            return
        }

        $InputObject += Get-DbaDatabase -SqlInstance $Primary -SqlCredential $PrimarySqlCredential -Database $Database

        foreach ($primarydb in $InputObject) {
            $stepCounter = 0
            $source = $primarydb.Parent

            try {
                $dest = Connect-SqlInstance -SqlInstance $Mirror -SqlCredential $MirrorSqlCredential

                if ($Witness) {
                    $witserver = Connect-SqlInstance -SqlInstance $Witness -SqlCredential $WitnessSqlCredential
                }
            } catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }

            $dbName = $primarydb.Name

            Write-ProgressHelper -TotalSteps $totalSteps -Activity $activity -StepNumber ($stepCounter++) -Message "Validating mirror setup"
            # Thanks to https://github.com/mmessano/PowerShell/blob/master/SQL-ConfigureDatabaseMirroring.ps1 for the tips

            $validation = Invoke-DbMirrorValidation @params

            if ((Test-Bound -ParameterName NetworkShare) -and -not $validation.AccessibleShare) {
                Stop-Function -Continue -Message "Cannot access $NetworkShare from $($dest.Name)"
            }

            if (-not $validation.EditionMatch) {
                Stop-Function -Continue -Message "This mirroring configuration is not supported. Because the principal server instance, $source, is $($source.EngineEdition) Edition, the mirror server instance must also be $($source.EngineEdition) Edition."
            }

            if ($validation.MirroringStatus -ne "None") {
                Stop-Function -Continue -Message "Cannot setup mirroring on database ($dbname) due to its current mirroring state: $($primarydb.MirroringStatus)"
            }

            if ($primarydb.Status -ne "Normal") {
                Stop-Function -Continue -Message "Cannot setup mirroring on database ($dbname) due to its current state: $($primarydb.Status)"
            }

            Write-ProgressHelper -TotalSteps $totalSteps -Activity $activity -StepNumber ($stepCounter++) -Message "Setting recovery model for $dbName on $($source.Name) to Full"

            if ($primarydb.RecoveryModel -ne "Full") {
                if ((Test-Bound -ParameterName UseLastBackups)) {
                    Stop-Function -Continue -Message "$dbName not set to full recovery. UseLastBackups cannot be used."
                } else {
                    Set-DbaDbRecoveryModel -SqlInstance $source -Database $primarydb.Name -RecoveryModel Full
                }
            }

            Write-ProgressHelper -TotalSteps $totalSteps -Activity $activity -StepNumber ($stepCounter++) -Message "Copying $dbName from primary to mirror"

            if (-not $validation.DatabaseExistsOnMirror -or $Force) {
                if ($UseLastBackups) {
                    $allbackups = Get-DbaBackupHistory -SqlInstance $primarydb.Parent -Database $primarydb.Name -IncludeCopyOnly -Last
                } else {
                    $fullbackup = $primarydb | Backup-DbaDatabase -BackupDirectory $NetworkShare -Type Full
                    $logbackup = $primarydb | Backup-DbaDatabase -BackupDirectory $NetworkShare -Type Log
                    $allbackups = $fullbackup, $logbackup
                }
                Write-Message -Level Verbose -Message "Backups still exist on $NetworkShare"
                if ($Pscmdlet.ShouldProcess("$Mirror", "restoring full and log backups of $primarydb from $Primary")) {
                    try {
                        $null = $allbackups | Restore-DbaDatabase -SqlInstance $Mirror -SqlCredential $MirrorSqlCredential -WithReplace -NoRecovery -TrustDbBackupHistory -EnableException
                    } catch {
                        $msg = $_.Exception.InnerException.InnerException.InnerException.InnerException.Message
                        if (-not $msg) {
                            $msg = $_.Exception.InnerException.InnerException.InnerException.Message
                        }
                        if (-not $msg) {
                            $msg = $_
                        }
                        Stop-Function -Message $msg -ErrorRecord $_ -Target $dest -Continue
                    }
                }
            }

            $mirrordb = Get-DbaDatabase -SqlInstance $dest -Database $dbName

            Write-ProgressHelper -TotalSteps $totalSteps -Activity $activity -StepNumber ($stepCounter++) -Message "Copying $dbName from primary to witness"

            if ($Witness -and (-not $validation.DatabaseExistsOnWitness -or $Force)) {
                if (-not $allbackups) {
                    if ($UseLastBackups) {
                        $allbackups = Get-DbaBackupHistory -SqlInstance $primarydb.Parent -Database $primarydb.Name -IncludeCopyOnly -Last
                    } else {
                        $fullbackup = $primarydb | Backup-DbaDatabase -BackupDirectory $NetworkShare -Type Full
                        $logbackup = $primarydb | Backup-DbaDatabase -BackupDirectory $NetworkShare -Type Log
                        $allbackups = $fullbackup, $logbackup
                    }
                }
                if ($Pscmdlet.ShouldProcess("$Witness", "restoring full and log backups of $primarydb from $Primary")) {
                    try {
                        $null = $allbackups | Restore-DbaDatabase -SqlInstance $Witness -SqlCredential $WitnessSqlCredential -WithReplace -NoRecovery -TrustDbBackupHistory -EnableException
                    } catch {
                        $msg = $_.Exception.InnerException.InnerException.InnerException.InnerException.Message
                        Stop-Function -Message $msg -ErrorRecord $_ -Target $witserver -Continue
                    }
                }
            }

            if ($Witness) {
                $witnessdb = Get-DbaDatabase -SqlInstance $witserver -Database $dbName
            }

            $primaryendpoint = Get-DbaEndpoint -SqlInstance $source | Where-Object EndpointType -eq DatabaseMirroring
            $mirrorendpoint = Get-DbaEndpoint -SqlInstance $dest | Where-Object EndpointType -eq DatabaseMirroring

            if (-not $primaryendpoint) {
                Write-ProgressHelper -TotalSteps $totalSteps -Activity $activity -StepNumber ($stepCounter++) -Message "Setting up endpoint for primary"
                $primaryendpoint = New-DbaEndpoint -SqlInstance $source -Type DatabaseMirroring -Role Partner -Name Mirroring -EncryptionAlgorithm RC4
                $null = $primaryendpoint | Stop-DbaEndpoint
                $null = $primaryendpoint | Start-DbaEndpoint
            }

            if (-not $mirrorendpoint) {
                Write-ProgressHelper -TotalSteps $totalSteps -Activity $activity -StepNumber ($stepCounter++) -Message "Setting up endpoint for mirror"
                $mirrorendpoint = New-DbaEndpoint -SqlInstance $dest -Type DatabaseMirroring -Role Partner -Name Mirroring -EncryptionAlgorithm RC4
                $null = $mirrorendpoint | Stop-DbaEndpoint
                $null = $mirrorendpoint | Start-DbaEndpoint
            }

            if ($witserver) {
                Write-ProgressHelper -TotalSteps $totalSteps -Activity $activity -StepNumber ($stepCounter++) -Message "Setting up endpoint for witness"
                $witnessendpoint = Get-DbaEndpoint -SqlInstance $witserver | Where-Object EndpointType -eq DatabaseMirroring
                if (-not $witnessendpoint) {
                    $witnessendpoint = New-DbaEndpoint -SqlInstance $witserver -Type DatabaseMirroring -Role Witness -Name Mirroring -EncryptionAlgorithm RC4
                    $null = $witnessendpoint | Stop-DbaEndpoint
                    $null = $witnessendpoint | Start-DbaEndpoint
                }
            }

            Write-ProgressHelper -TotalSteps $totalSteps -Activity $activity -StepNumber ($stepCounter++) -Message "Granting permissions to service account"

            $serviceaccounts = $source.ServiceAccount, $dest.ServiceAccount, $witserver.ServiceAccount | Select-Object -Unique

            foreach ($account in $serviceaccounts) {
                if ($Pscmdlet.ShouldProcess("primary, mirror and witness (if specified)", "Creating login $account and granting CONNECT ON ENDPOINT")) {
                    $null = New-DbaLogin -SqlInstance $source -Login $account -WarningAction SilentlyContinue
                    $null = New-DbaLogin -SqlInstance $dest -Login $account -WarningAction SilentlyContinue
                    try {
                        $null = $source.Query("GRANT CONNECT ON ENDPOINT::$primaryendpoint TO [$account]")
                        $null = $dest.Query("GRANT CONNECT ON ENDPOINT::$mirrorendpoint TO [$account]")
                        if ($witserver) {
                            $null = New-DbaLogin -SqlInstance $witserver -Login $account -WarningAction SilentlyContinue
                            $witserver.Query("GRANT CONNECT ON ENDPOINT::$witnessendpoint TO [$account]")
                        }
                    } catch {
                        Stop-Function -Continue -Message "Failure" -ErrorRecord $_
                    }
                }
            }

            Write-ProgressHelper -TotalSteps $totalSteps -Activity $activity -StepNumber ($stepCounter++) -Message "Starting endpoints if necessary"
            try {
                $null = $primaryendpoint, $mirrorendpoint, $witnessendpoint | Start-DbaEndpoint -EnableException
            } catch {
                Stop-Function -Continue -Message "Failure" -ErrorRecord $_
            }

            try {
                Write-ProgressHelper -TotalSteps $totalSteps -Activity $activity -StepNumber ($stepCounter++) -Message "Setting up partner for mirror"
                $null = $mirrordb | Set-DbaDbMirror -Partner $primaryendpoint.Fqdn -EnableException
            } catch {
                Stop-Function -Continue -Message "Failure on mirror" -ErrorRecord $_
            }

            try {
                Write-ProgressHelper -TotalSteps $totalSteps -Activity $activity -StepNumber ($stepCounter++) -Message "Setting up partner for primary"
                $null = $primarydb | Set-DbaDbMirror -Partner $mirrorendpoint.Fqdn -EnableException
            } catch {
                Stop-Function -Continue -Message "Failure on primary" -ErrorRecord $_
            }

            try {
                if ($witnessendpoint) {
                    $null = $primarydb | Set-DbaDbMirror -Witness $witnessendpoint.Fqdn -EnableException
                }
            } catch {
                Stop-Function -Continue -Message "Failure with the new last part" -ErrorRecord $_
            }

            if ($Pscmdlet.ShouldProcess("console", "Showing results")) {
                $results = [pscustomobject]@{
                    Primary  = $Primary
                    Mirror   = $Mirror
                    Witness  = $Witness
                    Database = $primarydb.Name
                    Status   = "Success"
                }
                if ($Witness) {
                    $results | Select-DefaultView -Property Primary, Mirror, Witness, Database, Status
                } else {
                    $results | Select-DefaultView -Property Primary, Mirror, Database, Status
                }
            }
        }
    }
}

