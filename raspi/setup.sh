#!/bin/bash

# Default options
COMPOSE_PROFILES=""

# Parse arguments
for arg in "$@"; do
    case $arg in
        --with-mailer)
            COMPOSE_PROFILES="--profile mailer"
            ;;
        *)
            print_error "Unknown argument: $arg"
            echo "Usage: $0 [--with-mailer]"
            exit 1
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

print_info "🚀 Starting Home Network Certificate Setup..."
echo ""

# Check if docker-compose is running
if ! docker ps >/dev/null 2>&1; then
    print_error "Docker is not running or you don't have permission to access it."
    exit 1
fi

# Step 1: Create www directory for HTML files
print_info "📁 Creating www directory for web pages..."
mkdir -p ./www
print_success "Directory created"

# Step 2: Copy HTML files
print_info "📄 You need to create the following files in ./www/:"
print_warning "  - qr.html (QR code page for mobile)"
print_warning "  - setup.html (Setup instructions page)"
echo ""

# Step 3: Start/restart services
print_info "🐳 Starting Docker containers..."
docker-compose $COMPOSE_PROFILES up -d
sleep 5
print_success "Containers started"

# Step 4: Wait for Caddy to generate certificate
print_info "⏳ Waiting for Caddy to generate certificates (30 seconds)..."
sleep 30

# Step 5: Extract certificate
print_info "🔐 Extracting root certificate from Caddy..."
docker exec caddy cat /data/caddy/pki/authorities/local/root.crt > ./www/root.crt 2>/dev/null

if [ ! -f "./www/root.crt" ]; then
    print_warning "Certificate not found yet. Trying alternative path..."
    sleep 10
    docker exec caddy cat /data/caddy/pki/authorities/local/root.crt > ./www/root.crt 2>/dev/null
fi

if [ -f "./www/root.crt" ]; then
    print_success "Certificate extracted successfully"
else
    print_error "Failed to extract certificate. Check if Caddy is running correctly."
    print_info "You can manually check with: docker logs caddy"
    exit 1
fi

# Step 6: Generate QR code
print_info "📱 Generating QR code..."
if command_exists qrencode; then
    qrencode -t PNG -o ./www/qr-code.png -s 10 "http://cert.home.arpa"
    print_success "QR code generated at ./www/qr-code.png"
else
    print_warning "qrencode not found. Installing..."
    if command_exists apt-get; then
        sudo apt-get update && sudo apt-get install -y qrencode
    elif command_exists yum; then
        sudo yum install -y qrencode
    elif command_exists brew; then
        brew install qrencode
    else
        print_error "Cannot install qrencode automatically. Please install it manually:"
        print_info "  Ubuntu/Debian: sudo apt-get install qrencode"
        print_info "  Fedora/RHEL: sudo yum install qrencode"
        print_info "  macOS: brew install qrencode"
        exit 1
    fi
    qrencode -t PNG -o ./www/qr-code.png -s 10 "http://cert.home.arpa"
    print_success "QR code generated"
fi

# Step 7: Update docker-compose to mount www directory
print_info "📝 Checking docker-compose configuration..."
if grep -q "./www:/config/www:ro" docker-compose.yml; then
    print_success "docker-compose.yml already configured"
else
    print_warning "You need to add the www volume mount to Caddy service:"
    print_info "Add this line under caddy volumes:"
    print_info "      - ./www:/config/www:ro"
    echo ""
    read -p "Press Enter after you've updated docker-compose.yml..."
    docker-compose restart caddy
fi

# Step 8: Get server IP
print_info "🌐 Detecting server IP address..."
SERVER_IP=$(hostname -I | awk '{print $1}')
print_success "Server IP: $SERVER_IP"
echo ""

# Step 9: Pi-hole DNS configuration reminder
echo ""
print_info "⚙️  IMPORTANT: Configure Pi-hole DNS records"
print_warning "Access Pi-hole at: http://$SERVER_IP:8000/admin"
print_info "Add these Local DNS Records (Local DNS → DNS Records):"
echo ""
echo "    Domain                    →  IP Address"
echo "    ─────────────────────────────────────────"
echo "    cert.home.arpa           →  $SERVER_IP"
echo "    qr.home.arpa             →  $SERVER_IP"
echo "    setup.home.arpa          →  $SERVER_IP"
echo "    vaultwarden.home.arpa    →  $SERVER_IP"
echo "    octoprint.home.arpa      →  $SERVER_IP"
echo "    pihole.home.arpa         →  $SERVER_IP"
echo ""

# Step 10: Final instructions
echo ""
print_success "✅ Setup complete!"
echo ""
print_info "📋 Next steps:"
echo ""
echo "1. Configure Pi-hole DNS records (see above)"
echo "2. Ensure devices use Pi-hole as DNS server ($SERVER_IP)"
echo "3. Visit setup pages:"
echo "   • Desktop: http://setup.home.arpa"
echo "   • Mobile:  http://qr.home.arpa"
echo "4. Download and install the certificate on each device"
echo ""
print_info "💡 Once configured, access your services at:"
echo "   • https://vaultwarden.home.arpa"
echo "   • https://octoprint.home.arpa"
echo "   • https://pihole.home.arpa"
echo ""
print_success "Enjoy your secure home network! 🎉"