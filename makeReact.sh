#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to properly check if a package is installed
is_installed() {
    if dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "ok installed"; then
        return 0
    else
        return 1
    fi
}

# Function to print status messages
print_status() {
    if [ $2 -eq 0 ]; then
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    else
        echo -e "${RED}[FAILED]${NC} $1"
    fi
}

# Update and Upgrade the system
echo -e "${YELLOW}[INFO]${NC} Starting system update and upgrade..."
sudo apt-get update -y
update_result=$?
sudo apt-get upgrade -y
upgrade_result=$?

if [ $update_result -eq 0 ] && [ $upgrade_result -eq 0 ]; then
    print_status "System updated and upgraded successfully" 0
else
    print_status "System update/upgrade failed" 1
fi

# Install UFW if not exists and configure it
if ! is_installed "ufw"; then
    echo -e "${YELLOW}[INFO]${NC} Installing UFW..."
    sudo apt-get install ufw -y
    ufw_result=$?
    print_status "UFW installation" $ufw_result
    
    if [ $ufw_result -eq 0 ]; then
        echo -e "${YELLOW}[INFO]${NC} Configuring UFW..."
        sudo ufw allow ssh
        sudo ufw allow http
        sudo ufw allow https
        sudo ufw allow 3000  # Node.js/React
        sudo ufw allow 8000  # Python
        sudo ufw allow 8080  # Alternative port
        
        sudo ufw --force enable
        ufw_enable_result=$?
        print_status "UFW configuration" $ufw_enable_result
    fi
else
    echo -e "${YELLOW}[INFO]${NC} UFW is already installed"
fi

# Check and install Apache2 if not exists
if ! is_installed "apache2"; then
    echo -e "${YELLOW}[INFO]${NC} Installing Apache2..."
    sudo apt-get install apache2 -y
    apache_result=$?
    print_status "Apache2 installation" $apache_result
    
    if [ $apache_result -eq 0 ]; then
        sudo systemctl enable apache2
        sudo systemctl start apache2
        print_status "Apache2 service started" $?
    fi
else
    echo -e "${YELLOW}[INFO]${NC} Apache2 is already installed"
fi

# Install Node.js (for React) if not exists
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}[INFO]${NC} Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
    node_result=$?
    print_status "Node.js installation" $node_result
    
    if [ $node_result -eq 0 ]; then
        # Install build essentials for Node.js native addons
        sudo apt-get install -y build-essential
        print_status "Build essentials installation" $?
    fi
else
    echo -e "${YELLOW}[INFO]${NC} Node.js is already installed (version: $(node -v))"
fi

# Install npm if not exists (sometimes it's not installed with node)
if ! command -v npm &> /dev/null; then
    echo -e "${YELLOW}[INFO]${NC} Installing npm..."
    sudo apt-get install -y npm
    npm_result=$?
    print_status "npm installation" $npm_result
else
    echo -e "${YELLOW}[INFO]${NC} npm is already installed (version: $(npm -v))"
fi

# Install create-react-app globally if not exists
if ! npm list -g create-react-app &>/dev/null; then
    echo -e "${YELLOW}[INFO]${NC} Installing create-react-app..."
    sudo npm install -g create-react-app
    cra_result=$?
    print_status "create-react-app installation" $cra_result
else
    echo -e "${YELLOW}[INFO]${NC} create-react-app is already installed"
fi

# Install Python and pip if not exists
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}[INFO]${NC} Installing Python3..."
    sudo apt-get install -y python3 python3-pip
    python_result=$?
    print_status "Python3 installation" $python_result
else
    echo -e "${YELLOW}[INFO]${NC} Python3 is already installed (version: $(python3 --version | cut -d' ' -f2))"
fi

# Website management functions
list_websites() {
    echo -e "\n${YELLOW}[Configured Websites]${NC}"
    echo "Enabled websites:"
    ls /etc/apache2/sites-enabled/ 2>/dev/null | grep -v '^000-default.conf$' | grep -v '^default-ssl.conf$' | sed 's/.conf$//'
    
    echo -e "\nAvailable websites:"
    ls /etc/apache2/sites-available/ 2>/dev/null | grep -v '^000-default.conf$' | grep -v '^default-ssl.conf$' | sed 's/.conf$//'
}

toggle_website() {
    list_websites
    read -p "Enter website name to enable/disable: " site_name
    
    if [ -f "/etc/apache2/sites-available/${site_name}.conf" ]; then
        if [ -f "/etc/apache2/sites-enabled/${site_name}.conf" ]; then
            echo -e "${YELLOW}[INFO]${NC} Disabling website ${site_name}..."
            sudo a2dissite "${site_name}.conf"
            sudo systemctl reload apache2
            echo -e "${GREEN}[SUCCESS]${NC} Website ${site_name} disabled"
        else
            echo -e "${YELLOW}[INFO]${NC} Enabling website ${site_name}..."
            sudo a2ensite "${site_name}.conf"
            sudo systemctl reload apache2
            echo -e "${GREEN}[SUCCESS]${NC} Website ${site_name} enabled"
        fi
    else
        echo -e "${RED}[ERROR]${NC} Website ${site_name} not found"
    fi
}

# Deploy React app from GitHub
deploy_react_app() {
    echo -e "\n${YELLOW}[React App Deployment]${NC}"
    
    # Get GitHub repository URL
    read -p "Enter GitHub repository URL (e.g., https://github.com/user/repo.git): " repo_url
    read -p "Enter branch name (leave empty for main/master): " branch
    branch=${branch:-"main"}
    
    # Get domain details
    read -p "Enter domain name for this app (e.g., app.example.com): " domain
    read -p "Enter server admin email: " email
    
    # Set webroot
    webroot="/var/www/$domain"
    
    # Check if directory exists
    if [ -d "$webroot" ]; then
        echo -e "${YELLOW}[WARNING]${NC} Directory $webroot already exists."
        read -p "Do you want to overwrite it? (y/n): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            echo -e "${RED}[ABORTED]${NC} Deployment cancelled."
            return 1
        fi
        echo -e "${YELLOW}[INFO]${NC} Removing existing directory..."
        sudo rm -rf "$webroot"
    fi
    
    # Create directory structure
    echo -e "${YELLOW}[INFO]${NC} Creating website directory..."
    sudo mkdir -p "$webroot"
    sudo chown -R $USER:$USER "$webroot"
    sudo chmod -R 755 "$webroot"
    
    # Clone repository
    echo -e "${YELLOW}[INFO]${NC} Cloning repository..."
    git clone -b "$branch" "$repo_url" "$webroot"
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ERROR]${NC} Failed to clone repository."
        return 1
    fi
    
    # Install dependencies
    echo -e "${YELLOW}[INFO]${NC} Installing dependencies..."
    cd "$webroot" || return 1
    npm install
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ERROR]${NC} Failed to install dependencies."
        return 1
    fi
    
    # Build the app
    echo -e "${YELLOW}[INFO]${NC} Building the React app..."
    npm run build
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ERROR]${NC} Failed to build the app."
        return 1
    fi
    
    # Create Apache configuration
    echo -e "${YELLOW}[INFO]${NC} Creating Apache configuration..."
    config_file="/etc/apache2/sites-available/$domain.conf"
    
    sudo tee "$config_file" > /dev/null <<EOL
<VirtualHost *:80>
    ServerAdmin $email
    ServerName $domain
    ServerAlias www.$domain
    DocumentRoot $webroot/build
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
    
    <Directory $webroot/build>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
        
        RewriteEngine On
        RewriteBase /
        RewriteRule ^index\.html$ - [L]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . /index.html [L]
    </Directory>
</VirtualHost>
EOL

    # Enable the site
    sudo a2ensite "$domain.conf"
    sudo a2enmod rewrite
    sudo systemctl restart apache2
    
    # Verify website is accessible
    echo -e "${YELLOW}[INFO]${NC} Verifying website deployment..."
    if curl -s -o /dev/null -w "%{http_code}" "http://$domain" | grep -q "200"; then
        echo -e "${GREEN}[SUCCESS]${NC} React app is properly deployed and accessible"
    else
        echo -e "${YELLOW}[WARNING]${NC} React app created but not accessible yet (DNS may need to propagate)"
    fi
    
    # SSL certificate option
    read -p "Would you like to install an SSL certificate with Let's Encrypt? (y/n): " ssl_choice
    if [[ "$ssl_choice" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}[INFO]${NC} Installing SSL certificate..."
        
        # Check if certbot is installed
        if ! command -v certbot &> /dev/null; then
            sudo apt-get install certbot python3-certbot-apache -y
        fi
        
        sudo certbot --apache -d "$domain" -d "www.$domain" --non-interactive --agree-tos -m "$email"
        cert_result=$?
        
        if [ $cert_result -eq 0 ]; then
            # Auto-renewal
            (crontab -l 2>/dev/null; echo "0 24 * * * /usr/bin/certbot renew --quiet") | crontab -
            echo -e "${GREEN}[SUCCESS]${NC} SSL certificate installed and auto-renewal configured!"
        else
            echo -e "${RED}[ERROR]${NC} SSL certificate installation failed"
        fi
    fi
    
    echo -e "\n${GREEN}[SUCCESS]${NC} React app has been deployed!"
    echo -e "App directory: $webroot"
    echo -e "Build directory: $webroot/build"
    echo -e "Apache config: $config_file"
    if [[ "$ssl_choice" =~ ^[Yy]$ ]]; then
        echo -e "Access your app: https://$domain"
    else
        echo -e "Access your app: http://$domain"
    fi
}

# Website installation function
install_new_website() {
    echo -e "\n${YELLOW}[Website Installation]${NC}"
    
    # Get website details
    read -p "Enter domain name (e.g., example.com): " domain
    read -p "Enter server admin email: " email
    read -p "Enter website root directory (default: /var/www/$domain): " webroot
    webroot=${webroot:-"/var/www/$domain"}
    
    # Create directory structure
    echo -e "${YELLOW}[INFO]${NC} Creating website directory..."
    sudo mkdir -p "$webroot"
    sudo chown -R $USER:$USER "$webroot"
    sudo chmod -R 755 "$webroot"
    
    # Create sample index page
    echo "<html><head><title>$domain</title></head><body><h1>Welcome to $domain</h1></body></html>" | sudo tee "$webroot/index.html" > /dev/null
    
    # Create Apache2 configuration
    echo -e "${YELLOW}[INFO]${NC} Creating Apache2 configuration..."
    config_file="/etc/apache2/sites-available/$domain.conf"
    
    sudo tee "$config_file" > /dev/null <<EOL
<VirtualHost *:80>
    ServerAdmin $email
    ServerName $domain
    ServerAlias www.$domain
    DocumentRoot $webroot
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
    
    <Directory $webroot>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOL

    # Enable the site
    sudo a2ensite "$domain.conf"
    sudo a2enmod rewrite
    sudo systemctl restart apache2
    
    # Verify website is accessible
    echo -e "${YELLOW}[INFO]${NC} Verifying website deployment..."
    if curl -s -o /dev/null -w "%{http_code}" "http://$domain" | grep -q "200"; then
        echo -e "${GREEN}[SUCCESS]${NC} Website is properly deployed and accessible"
    else
        echo -e "${YELLOW}[WARNING]${NC} Website created but not accessible yet (DNS may need to propagate)"
    fi
    
    # SSL certificate option
    read -p "Would you like to install an SSL certificate with Let's Encrypt? (y/n): " ssl_choice
    if [[ "$ssl_choice" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}[INFO]${NC} Installing SSL certificate..."
        
        # Check if certbot is installed
        if ! command -v certbot &> /dev/null; then
            sudo apt-get install certbot python3-certbot-apache -y
        fi
        
        sudo certbot --apache -d "$domain" -d "www.$domain" --non-interactive --agree-tos -m "$email"
        cert_result=$?
        
        if [ $cert_result -eq 0 ]; then
            # Auto-renewal
            (crontab -l 2>/dev/null; echo "0 24 * * * /usr/bin/certbot renew --quiet") | crontab -
            echo -e "${GREEN}[SUCCESS]${NC} SSL certificate installed and auto-renewal configured!"
            
            # Verify HTTPS access
            if curl -s -o /dev/null -w "%{http_code}" "https://$domain" | grep -q "200"; then
                echo -e "${GREEN}[SUCCESS]${NC} HTTPS is working properly"
            else
                echo -e "${YELLOW}[WARNING]${NC} HTTPS not working yet (may need a few minutes to activate)"
            fi
        else
            echo -e "${RED}[ERROR]${NC} SSL certificate installation failed"
        fi
    fi
    
    echo -e "\n${GREEN}[SUCCESS]${NC} Website $domain has been set up!"
    echo -e "Website root: $webroot"
    echo -e "Apache config: $config_file"
    if [[ "$ssl_choice" =~ ^[Yy]$ ]]; then
        echo -e "Access your site: https://$domain"
    else
        echo -e "Access your site: http://$domain"
    fi
}

# Main menu function
show_menu() {
    echo -e "\n${YELLOW}What would you like to do next?${NC}"
    echo "1 - Install a new website (Apache2)"
    echo "2 - Deploy a React app from GitHub"
    echo "3 - List all websites"
    echo "4 - Enable/Disable a website"
    echo "5 - Exit"
    read -p "Enter your choice [1-5]: " choice
}

# Main execution
echo -e "\n${GREEN}[INSTALLATION COMPLETE]${NC}"
echo -e "All requested packages have been installed/verified\n"

# Show the menu
while true; do
    show_menu
    case $choice in
        1)
            install_new_website
            ;;
        2)
            deploy_react_app
            ;;
        3)
            list_websites
            ;;
        4)
            toggle_website
            ;;
        5)
            echo -e "${GREEN}[INFO]${NC} Exiting..."
            exit 0
            ;;
        *)
            echo -e "${RED}[ERROR]${NC} Invalid option. Please try again."
            ;;
    esac
done