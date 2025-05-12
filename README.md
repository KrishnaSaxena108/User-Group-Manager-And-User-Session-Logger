# Linux User Account Management TUI

A comprehensive Terminal User Interface (TUI) tool for managing Linux user accounts, groups, and monitoring session activities.

![image](https://github.com/user-attachments/assets/6875b1f5-f52f-44ae-99a7-7be602061e80)

## Features

### User Management
- **Create User**: Set up new user accounts with customizable settings
  - Username validation
  - Custom home directory
  - Shell selection
  - Primary group assignment
  - Supplementary group membership
- **Modify User**: Update existing user accounts
  - Change username
  - Update full name
  - Relocate home directory
  - Change login shell
  - Reset password
  - Modify group memberships
- **Delete User**: Remove user accounts with option to preserve or delete home directory
- **User Information**: Display detailed user information including UID, GID, groups

### Group Management
- **Create Group**: Create new groups with optional GID specification
- **Modify Group**: Update group properties
  - Rename groups
  - Add/remove group members
- **Delete Group**: Remove groups from the system
- **Group Information**: View detailed group information

### Session Logging and Monitoring
- **User Session Logs**: Review login history and session data
  - Login history tracking
  - Failed login attempt monitoring
  - Current active sessions
  - Last login information
  - Session duration statistics
- **User Activity Summary**: View consolidated user activity metrics
- **System-wide Session Statistics**: Review system-level login data and uptime

## Requirements

- Linux system with root/sudo privileges
- `dialog` package (for TUI interface)
- Standard Linux user management commands (`useradd`, `usermod`, etc.)

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/User-Group-Manager-And-User-Session-Logger.git/
   cd User-Group-Manager-And-User-Session-Logger
   ```

2. Make the script executable:
   ```bash
   chmod +x Project.sh
   ```

3. Ensure `dialog` is installed:
   ```bash
   # On Debian/Ubuntu
   sudo apt-get install dialog
   
   # On RHEL/CentOS
   sudo yum install dialog
   ```

## Usage

Run the script with root privileges:

```bash
sudo ./Project.sh
```

Navigate the interface using arrow keys, Tab key, and Enter to select options.

## Security Features

- Input validation for all user entries
- Confirmation dialogs for destructive operations
- Secure password management through standard Linux tools
- Detailed action logging with timestamps
- Permission checking to ensure root-only access

## Log File

All user and group management actions are logged to `/var/log/user_management.log` with the following information:
- Timestamp
- User/Group name
- Action performed
- Actor who performed the action

## Screenshots

![image](https://github.com/user-attachments/assets/da543252-eae7-4d74-a7b7-a5ebeb4a7d2f)

![image](https://github.com/user-attachments/assets/781d2019-1a8a-4fc4-a267-2d8d7235b583)

## Project Structure

```
Linux-User-Management-TUI/
├── Project.sh         # Main script
├── README.md          # This file
└── G19-PID-03.pdf     # Project documentation
```

## Author

Created by Tanishq Gupta (2310992384), Krishna Saxena (2310991705), Ansh Jolly (2310991694), Armaan Singh Thind (2310991704) as part of Linux System Administration course project.

## License

This project is available under the MIT License. See the LICENSE file for more details.

## Acknowledgements

- Inspired by the need for a user-friendly interface for Linux user management
- Based on standard Linux user and group management utilities
