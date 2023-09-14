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

        # Check if the user already exists
        $existingUser = Get-ADUser -Filter { (GivenName -eq $firstName) -and (Surname -eq $lastName) } -ErrorAction SilentlyContinue

        if ($existingUser -eq $null) {
            # Create a new user in Active Directory in the specified OU with a temporary password
            try {
                New-ADUser -Name "$firstName $lastName" -GivenName $firstName -Surname $lastName -UserPrincipalName "$firstName.$lastName@CDB.lan" -SamAccountName $firstName -Enabled $false -Path $ouPath -AccountPassword (ConvertTo-SecureString -AsPlainText $password -Force) -ErrorAction Stop

                # Set additional user attributes
                Set-ADUser -Identity "$firstName $lastName" -Description $function -Department $department -Office $location -ErrorAction Stop
            } catch {
                Write-Host "Error creating user '$firstName $lastName': $_"
            }

            # Enable the account
            Enable-ADAccount -Identity "$firstName $lastName"
        } else {
            Write-Host "User '$firstName $lastName' already exists. Skipping creation."
        }
    }

