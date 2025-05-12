#!/bin/bash
#
# Linux User Account Management TUI
# 
# A Terminal User Interface (TUI) tool for managing Linux user and group accounts.
# This script provides an interactive interface for creating, modifying, and deleting
# users and groups, as well as managing passwords and group memberships.
# Includes comprehensive session logging and monitoring capabilities.
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
        # Set password
        set_password "$username"
        
        # Add to supplementary groups
        add_user_to_groups "$username"
        
        # Log user creation
        log_user_action "$username" "created"
        
        show_message "User '$username' created successfully."
    else
        show_error "Failed to create user '$username'."
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
    log_user_action "$username" "password changed"
    
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
            # Log group membership change
            log_user_action "$username" "group membership changed to: $selected_groups"
            show_message "User '$username' added to groups: $selected_groups"
        else
            show_error "Failed to add user '$username' to groups."
        fi
    else
        # Remove user from all supplementary groups
        usermod -G "" "$username"
        # Log group membership removal
        log_user_action "$username" "removed from all supplementary groups"
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
                    log_user_action "$username" "username changed to $new_username"
                    
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
                    # Log full name change
                    log_user_action "$username" "full name changed to '$new_fullname'"
                    
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
                    log_user_action "$username" "home directory changed from '$current_home' to '$new_home'"
                    
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
                    log_user_action "$username" "shell changed from '$current_shell' to '$new_shell'"
                    
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
        log_user_action "$username" "deleted" "system"
        
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
        log_group_action "$groupname" "created"
        
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
                    # Log group name change
                    log_group_action "$groupname" "renamed to '$new_groupname'"
                    
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
                    log_group_action "$groupname" "membership updated to: $selected_users"
                    
                    show_message "Members of group '$groupname' updated successfully."
                else
                    show_error "Failed to update members of group '$groupname'."
                fi
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
        log_group_action "$groupname" "deleted"
        
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

# Function to log user actions
log_user_action() {
    local username="$1"
    local action="$2"
    local actor="${3:-$(whoami)}"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local log_file="/var/log/user_management.log"
    
    # Create log file if it doesn't exist
    if [ ! -f "$log_file" ]; then
        touch "$log_file"
        chmod 640 "$log_file"
    fi
    
    # Log the action
    echo "[$timestamp] User '$username' $action by '$actor'" >> "$log_file"
}

# Function to log group actions
log_group_action() {
    local groupname="$1"
    local action="$2"
    local actor="${3:-$(whoami)}"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local log_file="/var/log/user_management.log"
    
    # Create log file if it doesn't exist
    if [ ! -f "$log_file" ]; then
        touch "$log_file"
        chmod 640 "$log_file"
    fi
    
    # Log the action
    echo "[$timestamp] Group '$groupname' $action by '$actor'" >> "$log_file"
}

# Function to display user session logs
display_user_session_logs() {
    # Get list of users
    users=$(getent passwd | grep -v "nologin\|false" | cut -d: -f1)
    
    # Create menu items
    menu_items=""
    for user in $users; do
        menu_items="$menu_items $user User"
    done
    
    # Add "All Users" option
    menu_items="all \"All Users\" $menu_items"
    
    # Show menu dialog
    username=$(dialog --title "User Session Logs" --menu "Select user to view session logs:" $HEIGHT $WIDTH $CHOICE_HEIGHT $menu_items 3>&1 1>&2 2>&3)
    
    # Check if canceled
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Show session log options
    while true; do
        option=$(dialog --title "Session Logs: ${username}" --menu "Select option:" $HEIGHT $WIDTH $CHOICE_HEIGHT \
            "1" "Login History" \
            "2" "Failed Login Attempts" \
            "3" "Current Active Sessions" \
            "4" "Last Login Information" \
            "5" "Session Duration Statistics" \
            "6" "Back to User Management" 3>&1 1>&2 2>&3)
        
        # Check if canceled
        if [ $? -ne 0 ] || [ "$option" = "6" ]; then
            break
        fi
        
        case $option in
            1)
                # Login History
                if [ "$username" = "all" ]; then
                    # Get login history for all users
                    login_history=$(last -a | head -n 20)
                else
                    # Get login history for specific user
                    login_history=$(last -a "$username" | head -n 20)
                fi
                
                # Display login history
                dialog --title "Login History: ${username}" --msgbox "$login_history" 20 80
                ;;
            
            2)
                # Failed Login Attempts
                if [ "$username" = "all" ]; then
                    # Get failed login attempts for all users
                    failed_logins=$(lastb -a | head -n 20 2>/dev/null || echo "No failed login attempts found or access denied.")
                else
                    # Get failed login attempts for specific user
                    failed_logins=$(lastb -a "$username" | head -n 20 2>/dev/null || echo "No failed login attempts found or access denied.")
                fi
                
                # Display failed login attempts
                dialog --title "Failed Login Attempts: ${username}" --msgbox "$failed_logins" 20 80
                ;;
            
            3)
                # Current Active Sessions
                if [ "$username" = "all" ]; then
                    # Get current active sessions for all users
                    active_sessions=$(who -a)
                else
                    # Get current active sessions for specific user
                    active_sessions=$(who -a | grep "^$username ")
                    
                    # Check if user has active sessions
                    if [ -z "$active_sessions" ]; then
                        active_sessions="No active sessions for user '$username'."
                    fi
                fi
                
                # Display current active sessions
                dialog --title "Current Active Sessions: ${username}" --msgbox "$active_sessions" 20 80
                ;;
            
            4)
                # Last Login Information
                if [ "$username" = "all" ]; then
                    # Get last login information for all users
                    last_login=$(lastlog)
                else
                    # Get last login information for specific user
                    last_login=$(lastlog -u "$username")
                fi
                
                # Display last login information
                dialog --title "Last Login Information: ${username}" --msgbox "$last_login" 20 80
                ;;
            
            5)
                # Session Duration Statistics
                if [ "$username" = "all" ]; then
                    # Get session duration statistics for all users
                    session_stats=$(ac -p)
                else
                    # Get session duration statistics for specific user
                    session_stats=$(ac -d "$username" 2>/dev/null || echo "No session statistics available for user '$username'.")
                fi
                
                # Display session duration statistics
                dialog --title "Session Duration Statistics: ${username}" --msgbox "$session_stats" 20 80
                ;;
        esac
    done
}

# Function to display user activity summary
display_user_activity_summary() {
    # Get list of users
    users=$(getent passwd | grep -v "nologin\|false" | cut -d: -f1)
    
    # Create menu items
    menu_items=""
    for user in $users; do
        menu_items="$menu_items $user User"
    done
    
    # Show menu dialog
    username=$(dialog --title "User Activity Summary" --menu "Select user to view activity summary:" $HEIGHT $WIDTH $CHOICE_HEIGHT $menu_items 3>&1 1>&2 2>&3)
    
    # Check if canceled
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Get user activity summary
    
    # Last login time
    last_login=$(lastlog -u "$username" | tail -n 1)
    
    # Login count (last 30 days)
    login_count=$(last "$username" | grep -v "still logged in" | grep -v "^wtmp begins" | wc -l)
    
    # Failed login attempts (if accessible)
    failed_attempts=$(lastb "$username" 2>/dev/null | grep -v "^btmp begins" | wc -l || echo "N/A")
    
    # Total session time (if available)
    total_time=$(ac "$username" 2>/dev/null || echo "N/A")
    
    # Current status (logged in or not)
    if who | grep -q "^$username "; then
        current_status="Currently logged in"
    else
        current_status="Not currently logged in"
    fi
    
    # Get user management log entries
    if [ -f "/var/log/user_management.log" ]; then
        user_log=$(grep "User '$username'" /var/log/user_management.log | tail -n 10)
    else
        user_log="No user management logs available."
    fi
    
    # Display user activity summary
    dialog --title "User Activity Summary: $username" --msgbox "User: $username\n\nLast Login: $last_login\n\nLogin Count (recent): $login_count\n\nFailed Login Attempts: $failed_attempts\n\nTotal Session Time: $total_time\n\nCurrent Status: $current_status\n\nRecent Account Changes:\n$user_log" 20 80
}

# Function to display system-wide session statistics
display_system_session_statistics() {
    # Get system-wide statistics
    
    # Current logged in users
    current_users=$(who | wc -l)
    
    # Total login count today
    today=$(date "+%b %d")
    logins_today=$(last | grep "$today" | wc -l)
    
    # Most active user
    most_active=$(ac -p | sort -nrk 2 | head -n 1)
    
    # Failed login attempts today
    failed_today=$(lastb | grep "$today" 2>/dev/null | wc -l || echo "N/A")
    
    # System uptime
    uptime_info=$(uptime)
    
    # Display system-wide session statistics
    dialog --title "System-wide Session Statistics" --msgbox "Current Logged In Users: $current_users\n\nTotal Logins Today: $logins_today\n\nMost Active User: $most_active\n\nFailed Login Attempts Today: $failed_today\n\nSystem Uptime: $uptime_info" 15 70
}

# Function to display help
show_help() {
    dialog --title "Help" --msgbox "Linux User Account Management TUI\n\nThis tool provides an interactive interface for managing Linux user and group accounts. It allows you to create, modify, and delete users and groups, as well as manage passwords and group memberships.\n\nUser Management:\n- Create User: Create a new user account with customizable settings\n- Modify User: Change username, full name, home directory, shell, password, or group membership\n- Delete User: Remove a user account with option to keep or delete home directory\n- Set Password: Change a user's password\n- Add User to Groups: Modify a user's group memberships\n- Display User Info: Show detailed information about a user\n\nGroup Management:\n- Create Group: Create a new group\n- Modify Group: Change group name or modify group members\n- Delete Group: Remove a group\n- Display Group Info: Show detailed information about a group\n\nSession Logging:\n- User Session Logs: View login history, failed attempts, and active sessions\n- User Activity Summary: View comprehensive user activity statistics\n- System-wide Session Statistics: View system-wide login and session information\n\nFor more information about Linux user and group management, refer to the man pages:\n- man useradd\n- man usermod\n- man userdel\n- man passwd\n- man groupadd\n- man groupmod\n- man groupdel\n- man last\n- man lastb\n- man who\n- man w\n- man ac" 25 75
}

# Main function
main() {
    while true; do
        # Show main menu
        main_option=$(dialog --title "Linux User Account Management" --menu "Select an option:" $HEIGHT $WIDTH $CHOICE_HEIGHT \
            "1" "User Management" \
            "2" "Group Management" \
            "3" "Session Logging" \
            "4" "Help" \
            "5" "Exit" 3>&1 1>&2 2>&3)
        
        # Check if canceled or exit selected
        if [ $? -ne 0 ] || [ "$main_option" = "5" ]; then
            clear
            echo "Exiting..."
            exit 0
        fi
        
        case $main_option in
            1)
                # User Management submenu
                while true; do
                    user_option=$(dialog --title "User Management" --menu "Select an option:" $HEIGHT $WIDTH $CHOICE_HEIGHT \
                        "1" "Create User" \
                        "2" "Modify User" \
                        "3" "Delete User" \
                        "4" "Set Password" \
                        "5" "Add User to Groups" \
                        "6" "Display User Info" \
                        "7" "Back to Main Menu" 3>&1 1>&2 2>&3)
                    
                    # Check if canceled or back selected
                    if [ $? -ne 0 ] || [ "$user_option" = "7" ]; then
                        break
                    fi
                    
                    case $user_option in
                        1) create_user ;;
                        2) modify_user ;;
                        3) delete_user ;;
                        4)
                            # Get list of users
                            users=$(getent passwd | grep -v "nologin\|false" | cut -d: -f1)
                            
                            # Create menu items
                            menu_items=""
                            for user in $users; do
                                menu_items="$menu_items $user User"
                            done
                            
                            # Show menu dialog
                            username=$(dialog --title "Set Password" --menu "Select user to set password:" $HEIGHT $WIDTH $CHOICE_HEIGHT $menu_items 3>&1 1>&2 2>&3)
                            
                            # Check if canceled
                            if [ $? -ne 0 ]; then
                                continue
                            fi
                            
                            set_password "$username"
                            ;;
                        5)
                            # Get list of users
                            users=$(getent passwd | grep -v "nologin\|false" | cut -d: -f1)
                            
                            # Create menu items
                            menu_items=""
                            for user in $users; do
                                menu_items="$menu_items $user User"
                            done
                            
                            # Show menu dialog
                            username=$(dialog --title "Add User to Groups" --menu "Select user to modify groups:" $HEIGHT $WIDTH $CHOICE_HEIGHT $menu_items 3>&1 1>&2 2>&3)
                            
                            # Check if canceled
                            if [ $? -ne 0 ]; then
                                continue
                            fi
                            
                            add_user_to_groups "$username"
                            ;;
                        6) display_user_info ;;
                    esac
                done
                ;;
            
            2)
                # Group Management submenu
                while true; do
                    group_option=$(dialog --title "Group Management" --menu "Select an option:" $HEIGHT $WIDTH $CHOICE_HEIGHT \
                        "1" "Create Group" \
                        "2" "Modify Group" \
                        "3" "Delete Group" \
                        "4" "Display Group Info" \
                        "5" "Back to Main Menu" 3>&1 1>&2 2>&3)
                    
                    # Check if canceled or back selected
                    if [ $? -ne 0 ] || [ "$group_option" = "5" ]; then
                        break
                    fi
                    
                    case $group_option in
                        1) create_group ;;
                        2) modify_group ;;
                        3) delete_group ;;
                        4) display_group_info ;;
                    esac
                done
                ;;
            
            3)
                # Session Logging submenu
                while true; do
                    session_option=$(dialog --title "Session Logging" --menu "Select an option:" $HEIGHT $WIDTH $CHOICE_HEIGHT \
                        "1" "User Session Logs" \
                        "2" "User Activity Summary" \
                        "3" "System-wide Session Statistics" \
                        "4" "Back to Main Menu" 3>&1 1>&2 2>&3)
                    
                    # Check if canceled or back selected
                    if [ $? -ne 0 ] || [ "$session_option" = "4" ]; then
                        break
                    fi
                    
                    case $session_option in
                        1) display_user_session_logs ;;
                        2) display_user_activity_summary ;;
                        3) display_system_session_statistics ;;
                    esac
                done
                ;;
            
            4)
                # Help
                show_help
                ;;
        esac
    done
}

# Start the main function
main
