# In normal mode, captures memory usage for top 15 processes every $Interval seconds, and writes to $LogFile
# In FindMax mode, reads $LogFile and outputs the top 15 processes during the capture
# Successive runs will overwrite $LogFile

param(
  [string]$LogFile = ".\MemLogger.txt",
  [switch]$FindMax = $false,
  [int]$Interval = 5
)

$LogSeparator = "=========="

if ($FindMax) {
  $LogRaw = Get-Content -Path $LogFile

  $Procs = @{}

  foreach ($LogEntry in $LogRaw.split($LogSeparator, [System.StringSplitOptions]::RemoveEmptyEntries)) {
    foreach ($LogLine in $LogEntry.split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)) {
      $Data = $LogLine.split("|")
      $Key = [String]::Format("{1} (PID {0})", $Data[0].Trim(), $Data[1].Trim())
      $WorkingSetMB = [int]$Data[2]

      If ($Procs.$Key) {
        If ($WorkingSetMB -gt $Procs.$Key) {
          $Procs.$Key = $WorkingSetMB
        }
      } Else {
        $Procs.$Key = $WorkingSetMB
      }
    }
  }

  $Top15 = $Procs.GetEnumerator() | sort -Property Value -Descending | select -f 15
  Write-Output $Top15
} Else {
  Out-File -FilePath $LogFile -InputObject "" -Encoding ASCII

  While(1) {
    Out-File -FilePath $LogFile -InputObject $LogSeparator -Encoding ASCII -Append
    # Get top 15 processes by working set size
    $ProcList = Get-Process | Sort-Object -Descending WS | Select -f 15

    Write-Output ""
    foreach ($Proc in $ProcList) {
      $ProcId = If ($Proc.Id) { $Proc.Id } Else { 0 }
      $WorkingSetMB = [Math]::Floor($Proc.WS/(1024*1024))
      $PrintLine = [String]::Format("{1} (PID {0}) using {2} MB", $ProcId, $Proc.Name, $WorkingSetMB)
      $LogLine = [String]::Format("{0} | {1} | {2}", $ProcId, $Proc.Name, $WorkingSetMB)
      Write-Output $PrintLine
      Out-File -FilePath $LogFile -InputObject $LogLine -Encoding ASCII -Append
    }

    sleep $Interval
  }
}
