#!/bin/bash

# SSH Login Monitor with Telegram Notifications
# This script monitors SSH logins and sends notifications to Telegram

# =============================================================================
# CONFIGURATION
# =============================================================================

# Source the .env file to get credentials
if [[ -f ".env" ]]; then
    source ".env"
else
    echo "❌ .env file not found. Please create one with TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID"
    exit 1
fi

# Check if the variables are set
if [[ -z "$TELEGRAM_BOT_TOKEN" ]] || [[ -z "$TELEGRAM_CHAT_ID" ]]; then
    echo "❌ TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID is not set in the .env file"
    exit 1
fi

# Telegram API URL
TELEGRAM_API_URL="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"


# Server identification (customize as needed)
SERVER_NAME="$(hostname)"
SERVER_IP="$(curl -s ifconfig.me 2>/dev/null || echo 'Unknown')"

# Log file for this monitor
MONITOR_LOG="/var/log/ssh-telegram-monitor.log"





# =============================================================================
# FUNCTIONS
# =============================================================================

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$MONITOR_LOG"
}

# Function to send Telegram notification
send_telegram_notification() {
    local username="$1"
    local source_ip="$2"
    local login_time="$3"
    local session_type="$4"
    
    # Get additional info about the IP
    local geo_info=$(curl -s "http://ip-api.com/json/$source_ip" 2>/dev/null)
    local country=$(echo "$geo_info" | jq -r '.country // "Unknown"' 2>/dev/null || echo "$geo_info" | grep -o '"country":"[^"]*' | cut -d'"' -f4)
    local city=$(echo "$geo_info" | jq -r '.city // "Unknown"' 2>/dev/null || echo "$geo_info" | grep -o '"city":"[^"]*' | cut -d'"' -f4)
    local region=$(echo "$geo_info" | jq -r '.regionName // "Unknown"' 2>/dev/null || echo "$geo_info" | grep -o '"regionName":"[^"]*' | cut -d'"' -f4)
    local isp=$(echo "$geo_info" | jq -r '.isp // "Unknown"' 2>/dev/null || echo "$geo_info" | grep -o '"isp":"[^"]*' | cut -d'"' -f4)
    
    # Determine if it's a local or external IP
    local ip_type="🌐 External"
    if [[ "$source_ip" =~ ^192\.168\. ]] || [[ "$source_ip" =~ ^10\. ]] || [[ "$source_ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || [[ "$source_ip" == "127.0.0.1" ]]; then
        ip_type="🏠 Local Network"
    fi
    
    # Create the message with emojis and formatting
    local message="🔑 *SSH Login Detected*

👤 *User:* \`$username\`
🌐 *Source IP:* \`$source_ip\` ($ip_type)
🕐 *Time:* $login_time
🔐 *Auth Method:* $session_type
🖥️ *Server:* $SERVER_NAME (\`$SERVER_IP\`)

📍 *Location:* $city, $region, $country
🏢 *ISP:* $isp

⏰ *Timestamp:* $(date '+%Y-%m-%d %H:%M:%S %Z')"
    
    # Send to Telegram with simpler encoding
    local response=$(curl -s -X POST "$TELEGRAM_API_URL" \
        -H "Content-Type: application/json" \
        -d "{
            \"chat_id\": \"$TELEGRAM_CHAT_ID\",
            \"text\": $(printf '%s' "$message" | jq -Rs .),
            \"parse_mode\": \"Markdown\"
        }")
    
    # Check if message was sent successfully
    if echo "$response" | grep -q '"ok":true'; then
        log_message "✅ Notification sent for user: $username from IP: $source_ip"
    else
        log_message "❌ Failed to send notification: $response"
    fi
}

# Function to send failed login notification
send_failed_login_notification() {
    local username="$1"
    local source_ip="$2"
    local login_time="$3"
    
    local geo_info=$(curl -s "http://ip-api.com/json/$source_ip" 2>/dev/null)
    local country=$(echo "$geo_info" | jq -r '.country // "Unknown"' 2>/dev/null || echo "$geo_info" | grep -o '"country":"[^"]*' | cut -d'"' -f4)
    local city=$(echo "$geo_info" | jq -r '.city // "Unknown"' 2>/dev/null || echo "$geo_info" | grep -o '"city":"[^"]*' | cut -d'"' -f4)
    
    local message="⚠️ *SSH Login Failed*

🚫 *Attempted User:* \`$username\`
🌐 *Source IP:* \`$source_ip\`
🕐 *Attempt Time:* $login_time
🖥️ *Server:* $SERVER_NAME
📍 *Location:* $city, $country

⏰ *Timestamp:* $(date '+%Y-%m-%d %H:%M:%S %Z')"
    
    local response=$(curl -s -X POST "$TELEGRAM_API_URL" \
        -H "Content-Type: application/json" \
        -d "{
            \"chat_id\": \"$TELEGRAM_CHAT_ID\",
            \"text\": $(printf '%s' "$message" | jq -Rs .),
            \"parse_mode\": \"Markdown\"
        }")
        
    if echo "$response" | grep -q '"ok":true'; then
        log_message "⚠️ Failed login notification sent for user: $username from IP: $source_ip"
    else
        log_message "❌ Failed to send failed login notification: $response"
    fi
}

# Function to monitor auth.log in real-time
monitor_ssh_logins() {
    log_message "🚀 Starting SSH login monitor..."
    
    # Send startup notification
    local startup_message="🟢 *SSH Monitor Started*

🖥️ *Server:* $SERVER_NAME
🌐 *IP:* $SERVER_IP  
🕐 *Started:* $(date '+%Y-%m-%d %H:%M:%S %Z')

Monitoring SSH logins..."
    
    curl -s -X POST "$TELEGRAM_API_URL" \
        -H "Content-Type: application/json" \
        -d "{
            \"chat_id\": \"$TELEGRAM_CHAT_ID\",
            \"text\": $(printf '%s' "$startup_message" | jq -Rs .),
            \"parse_mode\": \"Markdown\"
        }" > /dev/null
    
    # Check if auth.log exists and is readable
    if [[ ! -r /var/log/auth.log ]]; then
        log_message "❌ Cannot read /var/log/auth.log - check permissions"
        # Try alternative log locations
        if [[ -r /var/log/secure ]]; then
            AUTH_LOG="/var/log/secure"
            log_message "📋 Using /var/log/secure instead"
        else
            log_message "❌ No readable auth log found"
            exit 1
        fi
    else
        AUTH_LOG="/var/log/auth.log"
    fi
    
    # Monitor auth.log for SSH logins with better regex patterns
    tail -F "$AUTH_LOG" 2>/dev/null | while IFS= read -r line; do
        # Debug: log what we're processing
        log_message "Processing: $line"
        
        # Check for successful SSH logins - improved pattern matching
        if echo "$line" | grep -E "sshd\[[0-9]+\]: Accepted" > /dev/null; then
            log_message "✅ Detected successful login: $line"
            
            # Extract information from log line with better parsing
            username=$(echo "$line" | grep -oE "Accepted [a-zA-Z]+ for [^ ]+" | awk '{print $NF}')
            source_ip=$(echo "$line" | grep -oE "from [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | awk '{print $2}')
            login_time=$(echo "$line" | awk '{print $1, $2, $3}')
            
            # Determine session type
            if echo "$line" | grep -q "publickey"; then
                session_type="🔑 Public Key"
            elif echo "$line" | grep -q "password"; then
                session_type="🔒 Password"
            else
                session_type="❓ Unknown"
            fi
            
            # Only send notification if we have required info
            if [[ -n "$username" && -n "$source_ip" ]]; then
                log_message "📤 Sending notification for user: $username from IP: $source_ip"
                send_telegram_notification "$username" "$source_ip" "$login_time" "$session_type"
            else
                log_message "❌ Missing required info - username: '$username', IP: '$source_ip'"
            fi
        fi
        
        # Monitor for failed attempts with improved pattern
        if echo "$line" | grep -E "sshd\[[0-9]+\]: Failed" > /dev/null; then
            log_message "⚠️ Detected failed login: $line"
            
            # Extract failed login info with better parsing
            username=$(echo "$line" | grep -oE "Failed [a-zA-Z]+ for (invalid user )?[^ ]+" | awk '{print $NF}')
            source_ip=$(echo "$line" | grep -oE "from [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | awk '{print $2}')
            login_time=$(echo "$line" | awk '{print $1, $2, $3}')
            
            # Handle "invalid user" cases
            if echo "$line" | grep -q "invalid user"; then
                username="invalid_user_$username"
            fi
            
            if [[ -n "$username" && -n "$source_ip" ]]; then
                log_message "📤 Sending failed login notification for user: $username from IP: $source_ip"
                send_failed_login_notification "$username" "$source_ip" "$login_time"
            else
                log_message "❌ Missing required info for failed login - username: '$username', IP: '$source_ip'"
            fi
        fi
    done
}

# Function to get Telegram chat ID (helper function)
get_chat_id() {
    echo "To get your Telegram Chat ID:"
    echo "1. Message @userinfobot on Telegram"
    echo "2. Or visit https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getUpdates"
    echo "3. Look for 'chat':{'id': YOUR_CHAT_ID}"
    echo ""
    echo "For group chats, add the bot to the group and send a message, then check getUpdates"
}

# Function to test Telegram configuration
test_telegram_config() {
    echo "🧪 Testing Telegram configuration..."
    
    # Simple test without complex encoding
    local response=$(curl -s -X POST "$TELEGRAM_API_URL" \
        -d "chat_id=$TELEGRAM_CHAT_ID" \
        -d "text=🧪 SSH Monitor Test - Configuration Working!" \
        -d "parse_mode=HTML")
    
    if echo "$response" | grep -q '"ok":true'; then
        echo "✅ Test notification sent successfully!"
        return 0
    else
        echo "❌ Failed to send test notification"
        echo "Response: $response"
        echo ""
        echo "Troubleshooting:"
        echo "1. Check bot token format: should be like 123456789:ABCdef..."
        echo "2. Make sure you sent /start to your bot"
        echo "3. Verify chat ID is correct"
        return 1
    fi
}

# Function to test log parsing (new debugging function)
test_log_parsing() {
    echo "🔍 Testing log parsing with recent entries..."
    
    if [[ -r /var/log/auth.log ]]; then
        AUTH_LOG="/var/log/auth.log"
    elif [[ -r /var/log/secure ]]; then
        AUTH_LOG="/var/log/secure"
    else
        echo "❌ No readable auth log found"
        return 1
    fi
    
    echo "📋 Checking last 10 SSH-related entries in $AUTH_LOG:"
    tail -n 100 "$AUTH_LOG" | grep -i ssh | tail -n 10
    
    echo ""
    echo "🔍 Testing regex patterns:"
    
    # Test successful login pattern
    echo "✅ Successful login patterns:"
    tail -n 100 "$AUTH_LOG" | grep -E "sshd\[[0-9]+\]: Accepted" | tail -n 3
    
    echo ""
    echo "❌ Failed login patterns:"
    tail -n 100 "$AUTH_LOG" | grep -E "sshd\[[0-9]+\]: Failed" | tail -n 3
}

#======================================================================
# MAIN EXECUTION
# =============================================================================

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "❌ This script needs to be run as root to access auth.log"
    exit 1
fi

# Create log file if it doesn't exist
touch "$MONITOR_LOG"

# Handle script termination gracefully
trap 'log_message "🛑 SSH monitor stopped"; exit 0' SIGTERM SIGINT

# Start monitoring
case "${1:-monitor}" in
    "monitor")
        monitor_ssh_logins
        ;;
    "test")
        test_telegram_config
        ;;
    "chatid")
        get_chat_id
        ;;
    "debug")
        test_log_parsing
        ;;
    "service")
        # Run as daemon
        nohup $0 monitor > /dev/null 2>&1 &
        echo "🚀 SSH monitor started as background service"
        echo "PID: $!"
        ;;
    *)
        echo "Usage: $0 [monitor|test|chatid|debug|service]"
        echo "  monitor - Run in foreground (default)"
        echo "  test    - Send test notification and verify config"
        echo "  chatid  - Show instructions to get Telegram chat ID"
        echo "  debug   - Test log parsing and show recent entries"
        echo "  service - Run as background service"
        ;;
esac
