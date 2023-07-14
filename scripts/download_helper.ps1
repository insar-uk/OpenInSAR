# Get the URL and destination path from the command line arguments
$url = $args[0]
$destination = $args[1]

# Get the username and password from the command line arguments
$username = $args[2]
$password = ConvertTo-SecureString -String $args[3] -AsPlainText -Force

$credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $password
Invoke-WebRequest -Uri $url -OutFile $destination -Credential $credentials