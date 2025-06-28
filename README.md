🚀 Web Server Deployment Automation Tool
A comprehensive Bash script to automate web server setup, deployment, and management for React apps and static websites on Ubuntu/Apache environments.

📝 Table of Contents
Features

Prerequisites

Installation

Usage

Script Functions

Screenshots

Contributing

License

✨ Features
Automated System Setup

System updates & upgrades

Firewall (UFW) configuration

Apache2 web server installation

Development Environment

Node.js & npm installation

Python 3 & pip installation

create-react-app global setup

Website Management

Static website deployment

React app deployment from GitHub

Apache virtual host configuration

SSL certificate installation (Let's Encrypt)

Website enable/disable toggling

User-Friendly Interface

Color-coded output

Status indicators

Interactive menus

Error handling

📋 Prerequisites
Ubuntu/Debian-based system

sudo privileges

Internet connection

(Optional) Domain name for production deployments

⚙️ Installation
Download the script:

bash
wget [https://raw.githubusercontent.com/yourusername/web-deploy-tool/main/](https://raw.githubusercontent.com/IRamadi/Web-Server-Deployment-Automation-Tool/refs/heads/main/makeReact.sh
Make it executable:

bash
chmod +x makeReact.sh
Run the script:

bash
sudo ./makeReact.sh
🖥️ Usage
The script provides an interactive menu after initial setup:

Install a new website - Sets up a static website with Apache

Deploy a React app - Clones from GitHub and configures production build

List all websites - Shows available/enabled websites

Enable/Disable website - Toggles website status

Exit - Quits the program

🔧 Script Functions
Core Setup
System updates & package installations

UFW firewall configuration

Apache2 web server setup

Deployment Options
Static Websites:

Creates directory structure

Sets up Apache virtual host

Optional Let's Encrypt SSL

React Apps:

Clones GitHub repository

Installs dependencies

Builds production version

Configures Apache for SPA routing

Management Features
Website listing

Toggle enable/disable

SSL certificate management

Auto-renewal setup
