# Import the Active Directory module
Import-Module ActiveDirectory

# Define the path to the CSV file containing user information
$csvPath = "S:\Fileshare\HR\NewHires.csv"

# Define the target OU where you want to create users
$ouPath = "OU=TestOU,DC=CDB,DC=lan"

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
        $password = $user.Password  # Password from the CSV

        # Generate the user logon name as first letter of first name + entire last name without symbols or spaces
        $logonName = ($firstName.Substring(0, 1) + $lastName) -replace '\W'

        # Check if the user already exists
        $existingUser = Get-ADUser -Filter { (SamAccountName -eq $logonName) } -ErrorAction SilentlyContinue

        if ($existingUser -eq $null) {
            # Create a new user in Active Directory in the specified OU with a temporary password
            try {
                New-ADUser -Name "$firstName $lastName" -GivenName $firstName -Surname $lastName -UserPrincipalName "$logonName@CDB.lan" -SamAccountName $logonName -Enabled $true -Path $ouPath -AccountPassword (ConvertTo-SecureString -AsPlainText $password -Force) -ErrorAction Stop

                # Set additional user attributes
                Set-ADUser -Identity $logonName -Description $function -Department $department -Office $location -ErrorAction Stop
            } catch {
                # Handle errors as needed
            }

            # Enable the account using SamAccountName
            Enable-ADAccount -Identity $logonName

            # Set the pre-Windows 2000 logon name to match the user logon name
            Set-ADUser -Identity $logonName -SamAccountName $logonName -ErrorAction Stop
        }
    }
}