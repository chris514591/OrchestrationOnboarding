# Import the Active Directory module
Import-Module ActiveDirectory

# Define the path to the CSV file containing user information
$csvPath = "S:\Fileshare\HR\NewHires.csv"

# Kasm Workspaces API credentials
$apiKey = "7fUH9ZV9HvWv"
$apiSecret = "Zb7iiChJVyFWNSuQwYdcAGHypV2oCU7g"
$apiEndpoint = "https://172.16.1.21/api/public/create_user"  # Updated API endpoint URL

# Bypass SSL/TLS certificate checks (for debugging/testing purposes)
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

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

                # Add users to their department group (HR_Department or IT_Department)
                if ($department -eq "HR") {
                    Add-ADGroupMember -Identity "HR_Department" -Members $logonName
                }
                elseif ($department -eq "IT") {
                    Add-ADGroupMember -Identity "IT_Department" -Members $logonName
                }

                # Add users to groups based on their function
                if ($function -eq "IT Employee") {
                    Add-ADGroupMember -Identity "IT_Support" -Members $logonName
                }
                elseif ($function -eq "IT Infrastructure") {
                    Add-ADGroupMember -Identity "IT_Infrastructure" -Members $logonName
                }
                elseif ($function -eq "IT Cybersecurity") {
                    Add-ADGroupMember -Identity "IT_Security" -Members $logonName
                }
                elseif ($function -eq "HR Employee") {
                    Add-ADGroupMember -Identity "HR_Employee" -Members $logonName
                }
                elseif ($function -eq "HR Advisor") {
                    Add-ADGroupMember -Identity "HR_Advisor" -Members $logonName
                }
                elseif ($function -eq "HR Trainee") {
                    Add-ADGroupMember -Identity "HR_Trainee" -Members $logonName
                }
                elseif ($function -eq "IT Trainee") {
                    Add-ADGroupMember -Identity "IT_SupportTrainee" -Members $logonName
                }

                # Enable the account using SamAccountName
                Enable-ADAccount -Identity $logonName

                # Set the pre-Windows 2000 logon name to match the user logon name
                Set-ADUser -Identity $logonName -SamAccountName $logonName -ErrorAction Stop

                # Set the "User must change password upon next logon" option
                Set-ADUser -Identity $logonName -ChangePasswordAtLogon $true -ErrorAction Stop

                # Create the user in Kasm Workspaces
                $kasmUserParams = @{
                    "api_key" = $apiKey
                    "api_key_secret" = $apiSecret
                    "target_user" = @{
                        "username" = $logonName
                        "first_name" = $firstName
                        "last_name" = $lastName
                        "locked" = $false
                        "disabled" = $false
                        "organization" = "CDB"  # You can modify this as needed
                        "phone" = ""  # Provide the phone number if needed
                        "password" = $password
                    }
                }

                # Convert the user data to JSON format
                $kasmUserParamsJson = $kasmUserParams | ConvertTo-Json

                # Make the API request to create the user in Kasm Workspaces
                $kasmHeaders = @{
                    "Content-Type" = "application/json"
                }
                $kasmResponse = Invoke-RestMethod -Uri $apiEndpoint -Method Post -Headers $kasmHeaders -Body $kasmUserParamsJson

                # Check the Kasm Workspaces API response
                if ($kasmResponse.user -ne $null) {
                    Write-Host "User $($logonName) successfully created in Active Directory and Kasm Workspaces."
                }
                else {
                    # Print the API response for debugging purposes
                    Write-Host "Kasm Workspaces API Response: $kasmResponse"

                    # Handle the error
                    Write-Host "Failed to create user $($logonName) in Kasm Workspaces."
                }
            }
            catch {
                Write-Host "Error creating user $($logonName): $_"
            }
        }
        else {
            Write-Host "User $($logonName) already exists in Active Directory. Skipping."
        }
    }
}
else {
    Write-Host "CSV file not found at $csvPath."
}
