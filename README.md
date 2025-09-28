# Linux SSH Monitor Service

Open-source Linux SSH Monitor Service 

## Features

- **Real-time Monitoring:** Watches the system's authentication log (`/var/log/auth.log` or `/var/log/secure`) for SSH login events.
- **Dual Alerting:** Sends notifications for both **successful** and **failed** login attempts.
- **Rich Notifications:** Alerts include:
    - User name (for both valid and invalid users).
    - Source IP address.
    - Geolocation data of the IP (City, Region, Country).
    - ISP information.
    - Authentication method (Password or Public Key).
    - Server name and IP.
- **Smart IP Type Detection:** Differentiates between `Local Network` and `External` IP addresses.
- **Easy Configuration:** Uses a `.env` file to securely store your Telegram credentials.
- **Robust & Self-Contained:** Includes helper functions to test your configuration, get your Chat ID, and debug log parsing.
- **Service Mode:** Can be run as a background service to ensure continuous monitoring.
- **Logging:** Keeps a record of its own activities in `/var/log/ssh-telegram-monitor.log`.

## Prerequisites

Before you begin, ensure you have the following installed on your server:

- `curl`: For making API requests to Telegram and IP geolocation services.
- `jq`: For parsing JSON responses. The script has a basic fallback, but `jq` is highly recommended for reliability.
- A Telegram account.

## Setup and Configuration

1.  **Create a Telegram Bot:**
    - Open Telegram and chat with the [@BotFather](https://t.me/BotFather).
    - Send `/newbot` and follow the instructions to create your bot.
    - BotFather will give you a **Bot Token**. Save it.

2.  **Get your Telegram Chat ID:**
    - After creating the bot, send a `/start` message to it.
    - You can then get your Chat ID by running the script: `./ssh-monitor.sh chatid`. This will provide instructions, including a link to check.

3.  **Clone the Repository (if you haven't already):**
    ```bash
    git clone <repository_url>
    cd ssh-monitor
    ```

4.  **Make the Script Executable:**

    ```bash
    chmod +x ssh-monitor.sh
    ```

5.  **Create the `.env` file:**
    Create a file named `.env` in the same directory as the script and add your credentials:
    ```env
    TELEGRAM_BOT_TOKEN="YOUR_TELEGRAM_BOT_TOKEN"
    TELEGRAM_CHAT_ID="YOUR_TELEGRAM_CHAT_ID"
    ```
    Replace the placeholder values with your actual bot token and chat ID.

## Usage

The script requires `root` privileges to read the system authentication logs.

- **Run in Foreground:**
  For testing or manual monitoring.
  ```bash
  sudo ./ssh-monitor.sh monitor
  ```

- **Run as a Background Service:**
  To start the monitor as a daemon process.
  ```bash
  sudo ./ssh-monitor.sh service
  ```

- **Test Your Configuration:**
  Send a test message to your Telegram chat to verify that the bot token and chat ID are correct.
  ```bash
  sudo ./ssh-monitor.sh test
  ```

- **Debug Log Parsing:**
  To check if the script can correctly parse your system's log files. This is useful if you are not receiving notifications.
  ```bash
  sudo ./ssh-monitor.sh debug
  ```

- **Get Chat ID Instructions:**
  ```bash
  ./ssh-monitor.sh chatid
  ```


## Installing as a Systemd Service (Recommended)

For the monitor to run automatically on boot, it's best to set it up as a `systemd` service.

1.  **Create a service file:**
    ```bash
    sudo nano /etc/systemd/system/ssh-monitor.service
    ```

2.  **Add the following content.** Make sure to replace `/path/to/ssh-monitor.sh` with the actual absolute path to the script.
    ```ini
    [Unit]
    Description=SSH Login Monitor with Telegram Notifications
    After=network.target

    [Service]
    ExecStart=/path/to/ssh-monitor.sh monitor
    WorkingDirectory=/path/to/
    Restart=always
    User=root

    [Install]
    WantedBy=multi-user.target
    ```

3.  **Enable and Start the Service:**
    ```bash
    sudo systemctl daemon-reload
    sudo systemctl enable ssh-monitor.service
    sudo systemctl start ssh-monitor.service
    ```

4.  **Check the Service Status:**
    ```bash
    sudo systemctl status ssh-monitor.service
    ```

## Log File

The script logs its actions, such as startup, shutdown, and notification status, to:
`/var/log/ssh-telegram-monitor.log`

You can check this log file for troubleshooting.
```bash
tail -f /var/log/ssh-telegram-monitor.log
```
