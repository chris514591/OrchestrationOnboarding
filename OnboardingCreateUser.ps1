# Import the Active Directory module
Import-Module ActiveDirectory

# Define the path to the CSV file containing user information
$csvPath = "S:\Fileshare\HR\NewHires.csv"

# Check if the CSV file exists
if (Test-Path $csvPath) {
    # Read the CSV file
    $userList = Import-Csv $csvPath

    # Loop through each user in the CSV
    foreach ($user in $userList) {
        $firstName = $user.Firstname
        $lastName = $user.Surname
        $function = $user.Function
        $department = $user.Department
        $location = $user.Location
        $password = $user.Password
        $jobTitle = $user.Function 

        # Generate the user logon name as first letter of first name + entire last name without symbols or spaces
        $logonName = ($firstName.Substring(0, 1) + $lastName) -replace '\W'

        # Define the target OU based on the location
        $ouPath = "OU=Employees Eindhoven,OU=Employees,DC=CDB,DC=lan"
        if ($location -eq "Tilburg") {
            $ouPath = "OU=Employees Tilburg,OU=Employees,DC=CDB,DC=lan"
        }

        # Check if the user already exists
        $existingUser = Get-ADUser -Filter { (SamAccountName -eq $logonName) } -ErrorAction SilentlyContinue

        if ($existingUser -eq $null) {
            # Create a new user in Active Directory in the specified OU with a temporary password
            try {
                New-ADUser -Name "$firstName $lastName" -GivenName $firstName -Surname $lastName -UserPrincipalName "$logonName@CDB.lan" -SamAccountName $logonName -Enabled $true -Path $ouPath -AccountPassword (ConvertTo-SecureString -AsPlainText $password -Force) -ErrorAction Stop

                # Set additional user attributes
                Set-ADUser -Identity $logonName -Description $function -Department $department -Office $location -Title $jobTitle -ErrorAction Stop
            } catch {
                # Handle errors as needed
            }

            # Enable the account using SamAccountName
            Enable-ADAccount -Identity $logonName

            # Set the pre-Windows 2000 logon name to match the user logon name
            Set-ADUser -Identity $logonName -SamAccountName $logonName -ErrorAction Stop

            # Set the "User must change password upon next logon" option
            Set-ADUser -Identity $logonName -ChangePasswordAtLogon $true -ErrorAction Stop
        }
    }
}