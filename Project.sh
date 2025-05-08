#!/bin/bash
#
# Linux User Account Management TUI
# 
# A Terminal User Interface (TUI) tool for managing Linux user and group accounts.
# This script provides an interactive interface for creating, modifying, and deleting
# users and groups, as well as managing passwords and group memberships.
# Now includes user login/logout logging functionality.
#
# Dependencies: dialog, standard Linux user management commands
#
# Usage: sudo ./user_management_tui.sh
#

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" 
    exit 1
fi

# Check if dialog is installed
if ! command -v dialog &> /dev/null; then
    echo "dialog is not installed. Please install it first."
    echo "On Debian/Ubuntu: sudo apt-get install dialog"
    echo "On RHEL/CentOS: sudo yum install dialog"
    exit 1
fi

# Set dialog settings
DIALOG_CANCEL=1
DIALOG_ESC=255
HEIGHT=20
WIDTH=70
CHOICE_HEIGHT=10

# Define log file location
LOG_DIR="/var/log/user_activity"
LOGIN_LOG_FILE="$LOG_DIR/user_login.log"
ACCOUNT_LOG_FILE="$LOG_DIR/account_changes.log"

# Create log directory if it doesn't exist
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
    chmod 750 "$LOG_DIR"
fi

# Create log files if they don't exist
if [ ! -f "$LOGIN_LOG_FILE" ]; then
    touch "$LOGIN_LOG_FILE"
    chmod 640 "$LOGIN_LOG_FILE"
fi

if [ ! -f "$ACCOUNT_LOG_FILE" ]; then
    touch "$ACCOUNT_LOG_FILE"
    chmod 640 "$ACCOUNT_LOG_FILE"
fi

# Function to log user activity
log_user_activity() {
    local action="$1"
    local username="$2"
    local details="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local admin_user=$(whoami)
    
    echo "[$timestamp] Admin: $admin_user, Action: $action, User: $username, Details: $details" >> "$ACCOUNT_LOG_FILE"
}

# Function to display a message box
show_message() {
    dialog --title "Message" --msgbox "$1" 8 50
}

# Function to display an error message
show_error() {
    dialog --title "Error" --msgbox "$1" 8 50
}

# Function to validate username
validate_username() {
    local username="$1"
    
    # Check if username is empty
    if [ -z "$username" ]; then
        return 1
    fi
    
    # Check if username contains only allowed characters
    if ! [[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        return 2
    fi
    
    # Check if username length is valid
    if [ ${#username} -gt 32 ]; then
        return 3
    fi
    
    return 0
}

# Function to check if user exists
user_exists() {
    id "$1" &>/dev/null
    return $?
}

# Function to check if group exists
group_exists() {
    getent group "$1" &>/dev/null
    return $?
}

# Function to create a new user
create_user() {
    # Get username
    username=$(dialog --title "Create User" --inputbox "Enter username:" 8 40 3>&1 1>&2 2>&3)
    
    # Check if canceled
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Validate username
    validate_username "$username"
    case $? in
        1)
            show_error "Username cannot be empty."
            return
            ;;
        2)
            show_error "Username can only contain lowercase letters, digits, underscores, and hyphens, and must start with a letter or underscore."
            return
            ;;
        3)
            show_error "Username is too long (maximum 32 characters)."
            return
            ;;
    esac
    
    # Check if user already exists
    if user_exists "$username"; then
        show_error "User '$username' already exists."
        return
    fi
    
    # Get full name
    fullname=$(dialog --title "Create User" --inputbox "Enter full name (optional):" 8 40 3>&1 1>&2 2>&3)
    
    # Check if canceled
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Get home directory
    homedir=$(dialog --title "Create User" --inputbox "Enter home directory (leave empty for default):" 8 60 "/home/$username" 3>&1 1>&2 2>&3)
    
    # Check if canceled
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Get shell
    shell=$(dialog --title "Create User" --menu "Select default shell:" $HEIGHT $WIDTH $CHOICE_HEIGHT \
        "/bin/bash" "Bash shell" \
        "/bin/sh" "Bourne shell" \
        "/bin/zsh" "Z shell" \
        "/bin/dash" "Debian Almquist shell" \
        "/usr/bin/fish" "Friendly Interactive Shell" \
        "/sbin/nologin" "No login" 3>&1 1>&2 2>&3)
    
    # Check if canceled
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Get primary group
    create_primary_group=$(dialog --title "Create User" --yesno "Create a primary group with the same name as the user?" 8 60 3>&1 1>&2 2>&3)
    primary_group_option=""
    
    if [ $? -eq 0 ]; then
        primary_group_option="-U"
    else
        # List existing groups
        groups=$(getent group | cut -d: -f1)
        primary_group=$(dialog --title "Create User" --menu "Select primary group:" $HEIGHT $WIDTH $CHOICE_HEIGHT $(echo "$groups" | awk '{print $1 " Group" }') 3>&1 1>&2 2>&3)
        
        # Check if canceled
        if [ $? -ne 0 ]; then
            return
        fi
        
        primary_group_option="-g $primary_group"
    fi
    
    # Build useradd command
    cmd="useradd"
    
    # Add options
    if [ -n "$homedir" ]; then
        cmd="$cmd -d $homedir"
    fi
    
    if [ -n "$shell" ]; then
        cmd="$cmd -s $shell"
    fi
    
    if [ -n "$fullname" ]; then
        cmd="$cmd -c \"$fullname\""
    fi
    
    cmd="$cmd $primary_group_option -m $username"
    
    # Execute command
    eval $cmd
    
    if [ $? -eq 0 ]; then
        # Log user creation
        log_user_activity "CREATE" "$username" "Shell: $shell, Home: $homedir"
        
        # Set password
        set_password "$username"
        
        # Add to supplementary groups
        add_user_to_groups "$username"
        
        # Setup login logging for this user by adding to PAM configuration
        setup_login_logging "$username"
        
        show_message "User '$username' created successfully."
    else
        show_error "Failed to create user '$username'."
    fi
}

# Function to setup login logging for a user
setup_login_logging() {
    local username="$1"
    local pam_login_file="/etc/pam.d/login"
    local pam_sshd_file="/etc/pam.d/sshd"
    
    # Check if the login hook is already installed
    if ! grep -q "pam_exec.so /etc/security/log_login.sh" "$pam_login_file" 2>/dev/null; then
        # Create the login logging script if it doesn't exist
        if [ ! -f "/etc/security/log_login.sh" ]; then
            mkdir -p /etc/security
            cat > /etc/security/log_login.sh << 'EOF'
#!/bin/bash
# Log user logins and logouts
LOG_FILE="/var/log/user_activity/user_login.log"
USER=$PAM_USER
RHOST=$PAM_RHOST
TTY=$PAM_TTY
SERVICE=$PAM_SERVICE
TYPE=$PAM_TYPE
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Ensure log directory exists
if [ ! -d "$(dirname "$LOG_FILE")" ]; then
    mkdir -p "$(dirname "$LOG_FILE")"
    chmod 750 "$(dirname "$LOG_FILE")"
fi

# Create log file if it doesn't exist
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    chmod 640 "$LOG_FILE"
fi

# Log the event
if [ "$TYPE" = "open_session" ]; then
    echo "[$DATE] LOGIN: User: $USER, Remote: $RHOST, TTY: $TTY, Service: $SERVICE" >> "$LOG_FILE"
elif [ "$TYPE" = "close_session" ]; then
    echo "[$DATE] LOGOUT: User: $USER, Remote: $RHOST, TTY: $TTY, Service: $SERVICE" >> "$LOG_FILE"
fi
EOF
            chmod +x /etc/security/log_login.sh
        fi
        
        # Add to PAM configuration
        echo "session optional pam_exec.so /etc/security/log_login.sh" >> "$pam_login_file"
        
        # Also add to sshd PAM if it exists
        if [ -f "$pam_sshd_file" ]; then
            echo "session optional pam_exec.so /etc/security/log_login.sh" >> "$pam_sshd_file"
        fi
    fi
    
    # Hook into /etc/profile to catch all login sessions
    if ! grep -q "log_login.sh" /etc/profile 2>/dev/null; then
        echo '# Log user login' >> /etc/profile
        echo 'if [ -x /etc/security/log_login.sh ]; then' >> /etc/profile
        echo '    PAM_TYPE=open_session PAM_USER=$USER PAM_TTY=$(tty) PAM_SERVICE=login /etc/security/log_login.sh' >> /etc/profile
        echo 'fi' >> /etc/profile
        
        # Add logout trap to /etc/bash.bash_logout
        if [ ! -f /etc/bash.bash_logout ]; then
            echo '# Log user logout' > /etc/bash.bash_logout
            echo 'if [ -x /etc/security/log_login.sh ]; then' >> /etc/bash.bash_logout
            echo '    PAM_TYPE=close_session PAM_USER=$USER PAM_TTY=$(tty) PAM_SERVICE=login /etc/security/log_login.sh' >> /etc/bash.bash_logout
            echo 'fi' >> /etc/bash.bash_logout
        elif ! grep -q "log_login.sh" /etc/bash.bash_logout; then
            echo '# Log user logout' >> /etc/bash.bash_logout
            echo 'if [ -x /etc/security/log_login.sh ]; then' >> /etc/bash.bash_logout
            echo '    PAM_TYPE=close_session PAM_USER=$USER PAM_TTY=$(tty) PAM_SERVICE=login /etc/security/log_login.sh' >> /etc/bash.bash_logout
            echo 'fi' >> /etc/bash.bash_logout
        fi
    fi
}

# Function to set password
set_password() {
    local username="$1"
    
    # Check if user exists
    if ! user_exists "$username"; then
        show_error "User '$username' does not exist."
        return
    fi
    
    # Inform user about password entry
    dialog --title "Set Password" --msgbox "You will now be prompted to enter a password for user '$username'.\n\nThe password entry will happen in the terminal, not in a dialog box." 10 60
    
    # Use passwd command directly
    clear
    echo "Setting password for user '$username':"
    passwd "$username"
    
    # Log password change
    log_user_activity "PASSWORD_CHANGE" "$username" "Password modified"
    
    # Wait for user to press a key before returning to the TUI
    read -p "Press Enter to continue..."
}

# Function to add user to supplementary groups
add_user_to_groups() {
    local username="$1"
    
    # Check if user exists
    if ! user_exists "$username"; then
        show_error "User '$username' does not exist."
        return
    fi
    
    # Get list of all groups
    all_groups=$(getent group | cut -d: -f1)
    
    # Get current groups for the user
    current_groups=$(groups "$username" | cut -d: -f2 | sed 's/^ //')
    
    # Create checklist items
    checklist_items=""
    for group in $all_groups; do
        # Check if user is already in this group
        if echo "$current_groups" | grep -q -w "$group"; then
            checklist_items="$checklist_items $group Group on"
        else
            checklist_items="$checklist_items $group Group off"
        fi
    done
    
    # Show checklist dialog
    selected_groups=$(dialog --title "Add User to Groups" --checklist "Select groups for user '$username':" $HEIGHT $WIDTH $CHOICE_HEIGHT $checklist_items 3>&1 1>&2 2>&3)
    
    # Check if canceled
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Add user to selected groups
    if [ -n "$selected_groups" ]; then
        usermod -G $(echo $selected_groups | tr -d '"') "$username"
        
        if [ $? -eq 0 ]; then
            # Log group modification
            log_user_activity "GROUP_MEMBERSHIP" "$username" "Added to groups: $selected_groups"
            show_message "User '$username' added to groups: $selected_groups"
        else
            show_error "Failed to add user '$username' to groups."
        fi
    else
        # Remove user from all supplementary groups
        usermod -G "" "$username"
        # Log group modification
        log_user_activity "GROUP_MEMBERSHIP" "$username" "Removed from all supplementary groups"
        show_message "User '$username' removed from all supplementary groups."
    fi
}

# Function to modify user
modify_user() {
    # Get list of users
    users=$(getent passwd | grep -v "nologin\|false" | cut -d: -f1)
    
    # Create menu items
    menu_items=""
    for user in $users; do
        menu_items="$menu_items $user User"
    done
    
    # Show menu dialog
    username=$(dialog --title "Modify User" --menu "Select user to modify:" $HEIGHT $WIDTH $CHOICE_HEIGHT $menu_items 3>&1 1>&2 2>&3)
    
    # Check if canceled
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Get user info
    user_info=$(getent passwd "$username")
    current_shell=$(echo "$user_info" | cut -d: -f7)
    current_home=$(echo "$user_info" | cut -d: -f6)
    current_fullname=$(echo "$user_info" | cut -d: -f5)
    
    # Show modification options
    while true; do
        option=$(dialog --title "Modify User: $username" --menu "Select option:" $HEIGHT $WIDTH $CHOICE_HEIGHT \
            "1" "Change username" \
            "2" "Change full name" \
            "3" "Change home directory" \
            "4" "Change shell" \
            "5" "Change password" \
            "6" "Modify group membership" \
            "7" "Back to user management" 3>&1 1>&2 2>&3)
        
        # Check if canceled
        if [ $? -ne 0 ] || [ "$option" = "7" ]; then
            break
        fi
        
        case $option in
            1)
                # Change username
                new_username=$(dialog --title "Change Username" --inputbox "Enter new username:" 8 40 "$username" 3>&1 1>&2 2>&3)
                
                # Check if canceled
                if [ $? -ne 0 ]; then
                    continue
                fi
                
                # Validate username
                validate_username "$new_username"
                case $? in
                    1)
                        show_error "Username cannot be empty."
                        continue
                        ;;
                    2)
                        show_error "Username can only contain lowercase letters, digits, underscores, and hyphens, and must start with a letter or underscore."
                        continue
                        ;;
                    3)
                        show_error "Username is too long (maximum 32 characters)."
                        continue
                        ;;
                esac
                
                # Check if new username already exists
                if [ "$new_username" != "$username" ] && user_exists "$new_username"; then
                    show_error "User '$new_username' already exists."
                    continue
                fi
                
                # Change username
                usermod -l "$new_username" "$username"
                
                if [ $? -eq 0 ]; then
                    # Also update home directory if it follows the default pattern
                    if [ "$current_home" = "/home/$username" ]; then
                        usermod -d "/home/$new_username" -m "$new_username"
                    fi
                    
                    # Log username change
                    log_user_activity "RENAME" "$username" "New username: $new_username"
                    
                    show_message "Username changed from '$username' to '$new_username'."
                    username="$new_username"
                else
                    show_error "Failed to change username."
                fi
                ;;
            
            2)
                # Change full name
                new_fullname=$(dialog --title "Change Full Name" --inputbox "Enter new full name:" 8 40 "$current_fullname" 3>&1 1>&2 2>&3)
                
                # Check if canceled
                if [ $? -ne 0 ]; then
                    continue
                fi
                
                # Change full name
                usermod -c "$new_fullname" "$username"
                
                if [ $? -eq 0 ]; then
                    # Log fullname change
                    log_user_activity "MODIFY" "$username" "Full name changed from '$current_fullname' to '$new_fullname'"
                    
                    show_message "Full name changed for user '$username'."
                    current_fullname="$new_fullname"
                else
                    show_error "Failed to change full name."
                fi
                ;;
            
            3)
                # Change home directory
                new_home=$(dialog --title "Change Home Directory" --inputbox "Enter new home directory:" 8 60 "$current_home" 3>&1 1>&2 2>&3)
                
                # Check if canceled
                if [ $? -ne 0 ]; then
                    continue
                fi
                
                # Ask if files should be moved
                dialog --title "Move Files" --yesno "Do you want to move the contents of the old home directory to the new one?" 8 60
                move_files=$?
                
                # Change home directory
                if [ $move_files -eq 0 ]; then
                    usermod -d "$new_home" -m "$username"
                else
                    usermod -d "$new_home" "$username"
                fi
                
                if [ $? -eq 0 ]; then
                    # Log home directory change
                    log_user_activity "MODIFY" "$username" "Home changed from '$current_home' to '$new_home', files moved: $([ $move_files -eq 0 ] && echo 'yes' || echo 'no')"
                    
                    show_message "Home directory changed for user '$username'."
                    current_home="$new_home"
                else
                    show_error "Failed to change home directory."
                fi
                ;;
            
            4)
                # Change shell
                new_shell=$(dialog --title "Change Shell" --menu "Select new shell:" $HEIGHT $WIDTH $CHOICE_HEIGHT \
                    "/bin/bash" "Bash shell" \
                    "/bin/sh" "Bourne shell" \
                    "/bin/zsh" "Z shell" \
                    "/bin/dash" "Debian Almquist shell" \
                    "/usr/bin/fish" "Friendly Interactive Shell" \
                    "/sbin/nologin" "No login" 3>&1 1>&2 2>&3)
                
                # Check if canceled
                if [ $? -ne 0 ]; then
                    continue
                fi
                
                # Change shell
                usermod -s "$new_shell" "$username"
                
                if [ $? -eq 0 ]; then
                    # Log shell change
                    log_user_activity "MODIFY" "$username" "Shell changed from '$current_shell' to '$new_shell'"
                    
                    show_message "Shell changed for user '$username'."
                    current_shell="$new_shell"
                else
                    show_error "Failed to change shell."
                fi
                ;;
            
            5)
                # Change password
                set_password "$username"
                ;;
            
            6)
                # Modify group membership
                add_user_to_groups "$username"
                ;;
        esac
    done
}

# Function to delete group
delete_group() {
    # Get list of groups
    groups=$(getent group | cut -d: -f1)
    
    # Create menu items
    menu_items=""
    for group in $groups; do
        menu_items="$menu_items $group Group"
    done
    
    # Show menu dialog
    groupname=$(dialog --title "Delete Group" --menu "Select group to delete:" $HEIGHT $WIDTH $CHOICE_HEIGHT $menu_items 3>&1 1>&2 2>&3)
    
    # Check if canceled
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Confirm deletion
    dialog --title "Confirm Deletion" --yesno "Are you sure you want to delete group '$groupname'?" 8 60
    
    # Check if canceled
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Delete group
    groupdel "$groupname"
    
    if [ $? -eq 0 ]; then
        # Log group deletion
        log_user_activity "DELETE_GROUP" "$groupname" "Group deleted"
        
        show_message "Group '$groupname' deleted successfully."
    else
        show_error "Failed to delete group '$groupname'."
    fi
}

# Function to display group information
display_group_info() {
    # Get list of groups
    groups=$(getent group | cut -d: -f1)
    
    # Create menu items
    menu_items=""
    for group in $groups; do
        menu_items="$menu_items $group Group"
    done
    
    # Show menu dialog
    groupname=$(dialog --title "Group Information" --menu "Select group to display information:" $HEIGHT $WIDTH $CHOICE_HEIGHT $menu_items 3>&1 1>&2 2>&3)
    
    # Check if canceled
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Get group info
    group_info=$(getent group "$groupname")
    gid=$(echo "$group_info" | cut -d: -f3)
    members=$(echo "$group_info" | cut -d: -f4 | tr ',' ' ')
    
    # Display group info
    dialog --title "Group Information: $groupname" --msgbox "Group Name: $groupname\nGroup ID: $gid\nMembers: $members" 10 70
}

# Function to show the user login log viewer
view_login_logs() {
    # Check if login log file exists
    if [ ! -f "$LOGIN_LOG_FILE" ]; then
        show_error "Login log file does not exist."
        return
    fi
    
    # Get list of users to filter by
    users=$(getent passwd | grep -v "nologin\|false" | cut -d: -f1)
    
    # Add "All Users" option at the beginning
    menu_items="all_users \"All Users\""
    for user in $users; do
        menu_items="$menu_items $user \"$user\""
    done
    
    # Show menu dialog for selecting user
    filter_user=$(dialog --title "Login Logs" --menu "Select user to view login logs:" $HEIGHT $WIDTH $CHOICE_HEIGHT $menu_items 3>&1 1>&2 2>&3)
    
    # Check if canceled
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Filter logs by user or show all
    if [ "$filter_user" = "all_users" ]; then
        log_content=$(cat "$LOGIN_LOG_FILE")
        title="Login Logs - All Users"
    else
        log_content=$(grep "User: $filter_user" "$LOGIN_LOG_FILE")
        title="Login Logs - User: $filter_user"
    fi
    
    # Check if there are any logs
    if [ -z "$log_content" ]; then
        show_message "No login logs found for the selected user."
        return
    fi
    
    # Show logs in a scrollable textbox
    dialog --title "$title" --backtitle "User Login Logs" --scrollbar --exit-label "Back" \
        --textbox <(echo "$log_content") $((HEIGHT*2)) $((WIDTH*2))
}

# Function to show account activity logs
view_account_logs() {
    # Check if account log file exists
    if [ ! -f "$ACCOUNT_LOG_FILE" ]; then
        show_error "Account log file does not exist."
        return
    fi
    
    # Options for filtering
    option=$(dialog --title "Account Activity Logs" --menu "Select filter option:" $HEIGHT $WIDTH $CHOICE_HEIGHT \
        "1" "All activities" \
        "2" "Filter by user" \
        "3" "Filter by action" \
        "4" "Back to logs menu" 3>&1 1>&2 2>&3)
    
    # Check if canceled or back selected
    if [ $? -ne 0 ] || [ "$option" = "4" ]; then
        return
    fi
    
    case $option in
        1)
            # Show all logs
            log_content=$(cat "$ACCOUNT_LOG_FILE")
            title="Account Activity Logs - All Activities"
            ;;
        2)
            # Filter by user
            users=$(getent passwd | grep -v "nologin\|false" | cut -d: -f1)
            
            # Create menu items
            menu_items=""
            for user in $users; do
                menu_items="$menu_items $user User"
            done
            
            # Show menu dialog
            username=$(dialog --title "Filter by User" --menu "Select user:" $HEIGHT $WIDTH $CHOICE_HEIGHT $menu_items 3>&1 1>&2 2>&3)
            
            # Check if canceled
            if [ $? -ne 0 ]; then
                return
            fi
            
            log_content=$(grep "User: $username" "$ACCOUNT_LOG_FILE")
            title="Account Activity Logs - User: $username"
            ;;
        3)
            # Filter by action
            action=$(dialog --title "Filter by Action" --menu "Select action:" $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "CREATE" "User creation" \
                "DELETE" "User deletion" \
                "MODIFY" "User modification" \
                "PASSWORD_CHANGE" "Password changes" \
                "GROUP_MEMBERSHIP" "Group membership changes" \
                "RENAME" "Username changes" \
                "CREATE_GROUP" "Group creation" \
                "DELETE_GROUP" "Group deletion" \
                "MODIFY_GROUP" "Group modification" \
                "RENAME_GROUP" "Group name changes" 3>&1 1>&2 2>&3)
            
            # Check if canceled
            if [ $? -ne 0 ]; then
                return
            fi
            
            log_content=$(grep "Action: $action" "$ACCOUNT_LOG_FILE")
            title="Account Activity Logs - Action: $action"
            ;;
    esac
    
    # Check if there are any logs
    if [ -z "$log_content" ]; then
        show_message "No account logs found for the selected filter."
        return
    fi
    
    # Show logs in a scrollable textbox
    dialog --title "$title" --backtitle "Account Activity Logs" --scrollbar --exit-label "Back" \
        --textbox <(echo "$log_content") $((HEIGHT*2)) $((WIDTH*2))
}

# Function to display help
show_help() {
    dialog --title "Help" --msgbox "Linux User Account Management TUI\n\nThis tool provides an interactive interface for managing Linux user and group accounts. It allows you to create, modify, and delete users and groups, as well as manage passwords and group memberships.\n\nUser Management:\n- Create User: Create a new user account with customizable settings\n- Modify User: Change username, full name, home directory, shell, password, or group membership\n- Delete User: Remove a user account with option to keep or delete home directory\n- Set Password: Change a user's password\n- Add User to Groups: Modify a user's group memberships\n- Display User Info: Show detailed information about a user\n\nGroup Management:\n- Create Group: Create a new group\n- Modify Group: Change group name or modify group members\n- Delete Group: Remove a group\n- Display Group Info: Show detailed information about a group\n\nLog Management:\n- View Login Logs: View user login/logout history\n- View Account Logs: View account modification history\n\nFor more information about Linux user and group management, refer to the man pages:\n- man useradd\n- man usermod\n- man userdel\n- man passwd\n- man groupadd\n- man groupmod\n- man groupdel" 25 70
}
}

# Function to delete user
delete_user() {
    # Get list of users
    users=$(getent passwd | grep -v "nologin\|false" | cut -d: -f1)
    
    # Create menu items
    menu_items=""
    for user in $users; do
        menu_items="$menu_items $user User"
    done
    
    # Show menu dialog
    username=$(dialog --title "Delete User" --menu "Select user to delete:" $HEIGHT $WIDTH $CHOICE_HEIGHT $menu_items 3>&1 1>&2 2>&3)
    
    # Check if canceled
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Confirm deletion
    dialog --title "Confirm Deletion" --yesno "Are you sure you want to delete user '$username'?" 8 60
    
    # Check if canceled
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Ask if home directory should be removed
    dialog --title "Remove Home Directory" --yesno "Do you want to remove the home directory of user '$username'?" 8 60
    remove_home=$?
    
    # Delete user
    if [ $remove_home -eq 0 ]; then
        userdel -r "$username"
    else
        userdel "$username"
    fi
    
    if [ $? -eq 0 ]; then
        # Log user deletion
        log_user_activity "DELETE" "$username" "Home directory removed: $([ $remove_home -eq 0 ] && echo 'yes' || echo 'no')"
        
        show_message "User '$username' deleted successfully."
    else
        show_error "Failed to delete user '$username'."
    fi
}

# Function to display user information
display_user_info() {
    # Get list of users
    users=$(getent passwd | grep -v "nologin\|false" | cut -d: -f1)
    
    # Create menu items
    menu_items=""
    for user in $users; do
        menu_items="$menu_items $user User"
    done
    
    # Show menu dialog
    username=$(dialog --title "User Information" --menu "Select user to display information:" $HEIGHT $WIDTH $CHOICE_HEIGHT $menu_items 3>&1 1>&2 2>&3)
    
    # Check if canceled
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Get user info
    user_info=$(getent passwd "$username")
    uid=$(echo "$user_info" | cut -d: -f3)
    gid=$(echo "$user_info" | cut -d: -f4)
    fullname=$(echo "$user_info" | cut -d: -f5)
    home=$(echo "$user_info" | cut -d: -f6)
    shell=$(echo "$user_info" | cut -d: -f7)
    
    # Get primary group name
    primary_group=$(getent group "$gid" | cut -d: -f1)
    
    # Get supplementary groups
    supplementary_groups=$(groups "$username" | cut -d: -f2 | sed 's/^ //')
    
    # Display user info
    dialog --title "User Information: $username" --msgbox "Username: $username\nUser ID: $uid\nFull Name: $fullname\nHome Directory: $home\nShell: $shell\nPrimary Group: $primary_group (GID: $gid)\nSupplementary Groups: $supplementary_groups" 15 70
}

# Function to create a new group
create_group() {
    # Get group name
    groupname=$(dialog --title "Create Group" --inputbox "Enter group name:" 8 40 3>&1 1>&2 2>&3)
    
    # Check if canceled
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Validate group name
    if [ -z "$groupname" ]; then
        show_error "Group name cannot be empty."
        return
    fi
    
    # Check if group already exists
    if group_exists "$groupname"; then
        show_error "Group '$groupname' already exists."
        return
    fi
    
    # Get GID (optional)
    gid=$(dialog --title "Create Group" --inputbox "Enter GID (optional, leave empty for automatic assignment):" 8 60 3>&1 1>&2 2>&3)
    
    # Check if canceled
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Build groupadd command
    cmd="groupadd"
    
    # Add options
    if [ -n "$gid" ]; then
        cmd="$cmd -g $gid"
    fi
    
    cmd="$cmd $groupname"
    
    # Execute command
    eval $cmd
    
    if [ $? -eq 0 ]; then
        # Log group creation
        log_user_activity "CREATE_GROUP" "$groupname" "GID: $(getent group "$groupname" | cut -d: -f3)"
        
        show_message "Group '$groupname' created successfully."
    else
        show_error "Failed to create group '$groupname'."
    fi
}

# Function to modify group
modify_group() {
    # Get list of groups
    groups=$(getent group | cut -d: -f1)
    
    # Create menu items
    menu_items=""
    for group in $groups; do
        menu_items="$menu_items $group Group"
    done
    
    # Show menu dialog
    groupname=$(dialog --title "Modify Group" --menu "Select group to modify:" $HEIGHT $WIDTH $CHOICE_HEIGHT $menu_items 3>&1 1>&2 2>&3)
    
    # Check if canceled
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Show modification options
    while true; do
        option=$(dialog --title "Modify Group: $groupname" --menu "Select option:" $HEIGHT $WIDTH $CHOICE_HEIGHT \
            "1" "Change group name" \
            "2" "Modify group members" \
            "3" "Back to group management" 3>&1 1>&2 2>&3)
        
        # Check if canceled
        if [ $? -ne 0 ] || [ "$option" = "3" ]; then
            break
        fi
        
        case $option in
            1)
                # Change group name
                new_groupname=$(dialog --title "Change Group Name" --inputbox "Enter new group name:" 8 40 "$groupname" 3>&1 1>&2 2>&3)
                
                # Check if canceled
                if [ $? -ne 0 ]; then
                    continue
                fi
                
                # Validate group name
                if [ -z "$new_groupname" ]; then
                    show_error "Group name cannot be empty."
                    continue
                fi
                
                # Check if new group name already exists
                if [ "$new_groupname" != "$groupname" ] && group_exists "$new_groupname"; then
                    show_error "Group '$new_groupname' already exists."
                    continue
                fi
                
                # Change group name
                groupmod -n "$new_groupname" "$groupname"
                
                if [ $? -eq 0 ]; then
                    # Log group rename
                    log_user_activity "RENAME_GROUP" "$groupname" "New name: $new_groupname"
                    
                    show_message "Group name changed from '$groupname' to '$new_groupname'."
                    groupname="$new_groupname"
                else
                    show_error "Failed to change group name."
                fi
                ;;
            
            2)
                # Modify group members
                # Get list of all users
                all_users=$(getent passwd | grep -v "nologin\|false" | cut -d: -f1)
                
                # Get current members of the group
                current_members=$(getent group "$groupname" | cut -d: -f4 | tr ',' ' ')
                
                # Create checklist items
                checklist_items=""
                for user in $all_users; do
                    # Check if user is already in this group
                    if echo "$current_members" | grep -q -w "$user"; then
                        checklist_items="$checklist_items $user User on"
                    else
                        checklist_items="$checklist_items $user User off"
                    fi
                done
                
                # Show checklist dialog
                selected_users=$(dialog --title "Modify Group Members" --checklist "Select members for group '$groupname':" $HEIGHT $WIDTH $CHOICE_HEIGHT $checklist_items 3>&1 1>&2 2>&3)
                
                # Check if canceled
                if [ $? -ne 0 ]; then
                    continue
                fi
                
                # Update group members
                gpasswd -M $(echo $selected_users | tr -d '"') "$groupname"
                
                if [ $? -eq 0 ]; then
                    # Log group membership change
                    log_user_activity "MODIFY_GROUP" "$groupname" "Members updated to: $(echo $selected_users | tr -d '\"')"
                    
                    show_message "Members of group '$groupname' updated successfully."
                else
                    show_error "Failed to update members of group '$groupname'."
                fi
                ;;
        esac
    done
}

# Start the main function
main
