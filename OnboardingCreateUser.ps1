# Import the Active Directory module
Import-Module ActiveDirectory

# Define the path to the CSV file containing user information
$csvPath = "S:\Fileshare\HR\NewHires.csv"

# Check if the CSV file exists
if (Test-Path $csvPath) {
    # Read the CSV file
    $userList = Import-Csv $csvPath

    # Create an array to store users that were successfully created
    $createdUsers = @()

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

                # Add the user to the list of successfully created users
                $createdUsers += $user
            } catch {
                # Handle errors as needed
            }
        }
    }

    # Remove the successfully created users from the CSV
    $userList = $userList | Where-Object { $createdUsers -notcontains $_ }

    # Export the updated CSV without the successfully created users
    $userList | Export-Csv $csvPath -NoTypeInformation
}