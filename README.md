# 🐧 Linux User Account Management TUI


![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Shell Script](https://img.shields.io/badge/shell_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Terminal](https://img.shields.io/badge/Terminal-%23054020?style=for-the-badge&logo=gnu-bash&logoColor=white)

**A comprehensive Terminal User Interface (TUI) tool for managing Linux user accounts, groups, and monitoring session activities.**

*Built with ❤️ for Linux System Administration*

---

## 📸 Preview

<div align="center">

![Main Interface](https://github.com/user-attachments/assets/6875b1f5-f52f-44ae-99a7-7be602061e80)

*Main TUI Interface*

</div>

## ✨ Features

### 👤 **User Management**
- **🆕 Create User**: Set up new user accounts with customizable settings
  - ✅ Username validation
  - 🏠 Custom home directory
  - 🐚 Shell selection
  - 👥 Primary group assignment
  - 🔗 Supplementary group membership

- **✏️ Modify User**: Update existing user accounts
  - 🏷️ Change username
  - 📝 Update full name
  - 📁 Relocate home directory
  - 🐚 Change login shell
  - 🔐 Reset password
  - 👥 Modify group memberships

- **🗑️ Delete User**: Remove user accounts with option to preserve or delete home directory
- **ℹ️ User Information**: Display detailed user information including UID, GID, groups

### 👥 **Group Management**
- **🆕 Create Group**: Create new groups with optional GID specification
- **✏️ Modify Group**: Update group properties
  - 🏷️ Rename groups
  - 👤 Add/remove group members
- **🗑️ Delete Group**: Remove groups from the system
- **ℹ️ Group Information**: View detailed group information

### 📊 **Session Logging and Monitoring**
- **📋 User Session Logs**: Review login history and session data
  - 🕐 Login history tracking
  - ❌ Failed login attempt monitoring
  - 🟢 Current active sessions
  - 🔍 Last login information
  - ⏱️ Session duration statistics
- **📈 User Activity Summary**: View consolidated user activity metrics
- **🌐 System-wide Session Statistics**: Review system-level login data and uptime

## 🛠️ Requirements

- 🐧 Linux system with root/sudo privileges
- 💬 `dialog` package (for TUI interface)
- ⚙️ Standard Linux user management commands (`useradd`, `usermod`, etc.)

## 🚀 Installation

### 1️⃣ Clone the repository
```bash
git clone https://github.com/KrishnaSaxena108/User-Group-Manager-And-User-Session-Logger.git
cd User-Group-Manager-And-User-Session-Logger
```

### 2️⃣ Make the script executable
```bash
chmod +x Project.sh
```

### 3️⃣ Install dependencies
```bash
# On Debian/Ubuntu
sudo apt-get install dialog

# On RHEL/CentOS/Fedora
sudo yum install dialog
# or
sudo dnf install dialog
```

## 🎯 Usage

Run the script with root privileges:

```bash
sudo ./Project.sh
```

### 🎮 Navigation
- Use **Arrow Keys** to navigate
- Use **Tab** to switch between elements
- Press **Enter** to select options
- Press **Esc** to go back or cancel

## 🔒 Security Features

- ✅ **Input validation** for all user entries
- ⚠️ **Confirmation dialogs** for destructive operations
- 🔐 **Secure password management** through standard Linux tools
- 📝 **Detailed action logging** with timestamps
- 👮 **Permission checking** to ensure root-only access

## 📄 Log File

All user and group management actions are logged to:
```
/var/log/user_management.log
```

**Log Information Includes:**
- 🕐 Timestamp
- 👤 User/Group name
- 🎯 Action performed
- 👨‍💻 Actor who performed the action

## 📱 Screenshots

<div align="center">

![User Management](https://github.com/user-attachments/assets/da543252-eae7-4d74-a7b7-a5ebeb4a7d2f)
<br>
*User Management Interface*

![Group Management](https://github.com/user-attachments/assets/781d2019-1a8a-4fc4-a267-2d8d7235b583)
<br>
*Group Management Interface*

</div>

## 📁 Project Structure

```
User-Group-Manager-And-User-Session-Logger/
├── 📜 Project.sh         # Main script
├── 📖 README.md          # This file
└── 📋 G19-PID-03.pdf     # Project documentation
```

## 👨‍💻 Team Members

<table align="center">
  <tr>
    <td align="center">
      <a href="https://github.com/Spydiecy">
        <img src="https://github.com/Spydiecy.png" width="100px;" alt="Tanishq Gupta"/><br />
        <sub><b>Tanishq Gupta</b></sub>
      </a><br />
      <sub>2310992384</sub>
    </td>
    <td align="center">
      <a href="https://github.com/KrishnaSaxena108">
        <img src="https://github.com/KrishnaSaxena108.png" width="100px;" alt="Krishna Saxena"/><br />
        <sub><b>Krishna Saxena</b></sub>
      </a><br />
      <sub>2310991705</sub>
    </td>
    <td align="center">
      <a href="https://github.com/JollyAnsh">
        <img src="https://github.com/JollyAnsh.png" width="100px;" alt="Ansh Jolly"/><br />
        <sub><b>Ansh Jolly</b></sub>
      </a><br />
      <sub>2310991694</sub>
    </td>
    <td align="center">
      <a href="https://github.com/Armaan25Thind">
        <img src="https://github.com/Armaan25Thind.png" width="100px;" alt="Armaan Singh Thind"/><br />
        <sub><b>Armaan Singh Thind</b></sub>
      </a><br />
      <sub>2310991704</sub>
    </td>
  </tr>
</table>

---

## 🎓 About This Project

This project was developed as part of the **Linux System Administration** course. Our team focused on creating a user-friendly interface that simplifies complex Linux user and group management tasks while maintaining security and providing comprehensive logging capabilities.

## 🙏 Acknowledgements

- 🎯 Inspired by the need for a user-friendly interface for Linux user management
- 🛠️ Based on standard Linux user and group management utilities
- 📚 Created for educational purposes as part of Linux System Administration coursework

---

<div align="center">

**Made with ❤️ by Our Team **

*Linux System Administration Course Project*

</div>
