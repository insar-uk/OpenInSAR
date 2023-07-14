# Call an exe and print the output to the console
# Pass arguments to the exe
# Use this to automatically run test suites using Windows Powershell


# time between retries
$retryInterval = 300.0 # seconds
# exit after this many minutes
$timeout = 60 # minutes
# script to call
$Script = "octave"

$startTime = Get-Date
$endTime = $startTime.AddMinutes($timeout)

while ($true) {
    # Echo starting directory
    Write-Host "Starting directory: $pwd"

    # call the exe
    #$result = & $Script --eval "OI.Test('Database');"
    $result = & $Script --eval "OI.Test();"
    # print datetime
    Write-Host (Get-Date)
    Write-Host "Will run until $($endTime)"
    Write-Host "----------------------------------"
    # print the output
    Write-Output $result
    # exit after a while
    $timeNow = Get-Date
    if ($timeNow -gt $endTime) {
        Write-Host "Timeout reached. Exiting loop."
        break
    }

    # sleep the entire retry interval, but check every frameTime for a keypress and skip the sleep if a key is pressed
    $frameTime = 1 # seconds
    $sleepTime = $retryInterval
    Write-Host "Sleeping for $sleepTime seconds."
    while ($sleepTime -gt 0) {
        # round up
        # Write-Host -NoNewLine "`rSleeping for $sleepTime seconds."
        Start-Sleep -Milliseconds ($frameTime * 1000)
        $sleepTime -= $frameTime

        
        # Check for user input
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            # Exit loop
            Write-Host "Key: $($key.VirtualKeyCode), exiting loop."
            # Add extra time to the end time
            $endTime = $endTime.AddSeconds($retryInterval)
            # clear screen
            Clear-Host
            break
        }
    }
    Clear-Host
}

# $frameTime = 1 # seconds
# $sleepTime = $retryInterval
# Write-Host "Sleeping for $sleepTime seconds."
# while ($sleepTime -gt 0) {
#     Start-Sleep -Seconds $frameTime
#     $sleepTime  $frameTime
#     # clear last line of output
    
#     # print remaining time
#     Write-Host "Sleeping for $sleepTime seconds."
#     # Check for user input
#     if ($Host.UI.RawUI.KeyAvailable) {
#         $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
#         # Exit loop
#         Write-Host "Key: $($key.VirtualKeyCode), exiting loop."
#         # clear screen
#         Clear-Host
#         break
#     }
    
# }
