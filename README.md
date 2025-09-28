# SSH Login Monitor with Telegram Notifications

This script actively monitors SSH login activities on a server and sends instant, detailed notifications to a specified Telegram chat. It tracks both successful and failed login attempts, >

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
