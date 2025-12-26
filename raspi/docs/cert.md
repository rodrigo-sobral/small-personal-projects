# Certificate Installation Commands - Complete Reference

## 🪟 Windows

### Graphical Method (Recommended)
1. Download certificate from `http://cert.home.arpa`
2. Double-click `caddy-root-ca.crt`
3. Click **"Install Certificate"**
4. Select **"Local Machine"** → Next
5. Choose **"Place all certificates in the following store"**
6. Click **"Browse"** → Select **"Trusted Root Certification Authorities"**
7. Click **Next** → **Finish**
8. **Restart your browser**

### PowerShell Method (Admin)
```powershell
# Download certificate
Invoke-WebRequest -Uri "http://cert.home.arpa" -OutFile "$env:TEMP\caddy-root-ca.crt"

# Import certificate
Import-Certificate -FilePath "$env:TEMP\caddy-root-ca.crt" -CertStoreLocation Cert:\LocalMachine\Root

# Verify installation
Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*Caddy*" }
```

### Command Prompt Method (Admin)
```cmd
REM Download with PowerShell
powershell -Command "Invoke-WebRequest -Uri 'http://cert.home.arpa' -OutFile '%TEMP%\caddy-root-ca.crt'"

REM Import certificate
certutil -addstore -f "ROOT" "%TEMP%\caddy-root-ca.crt"

REM Verify
certutil -store ROOT | findstr /i "Caddy"
```

---

## 🍎 macOS

### Graphical Method (Recommended)
1. Download certificate from `http://cert.home.arpa` using Safari
2. Double-click the downloaded `caddy-root-ca.crt`
3. In Keychain Access, click **"Add"**
4. Open **Applications** → **Utilities** → **Keychain Access**
5. Search for **"Caddy Local Authority"**
6. Double-click the certificate
7. Expand the **"Trust"** section
8. Set **"When using this certificate"** to **"Always Trust"**
9. Close the window (enter your password when prompted)
10. **Restart your browser**

### Terminal Method
```bash
# Download certificate
curl -o ~/Downloads/caddy-root-ca.crt http://cert.home.arpa

# Add to System Keychain (requires password)
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ~/Downloads/caddy-root-ca.crt

# Verify installation
security find-certificate -c "Caddy Local Authority" -a
```

### Alternative: Add to Login Keychain
```bash
# Download
curl -o ~/Downloads/caddy-root-ca.crt http://cert.home.arpa

# Add to login keychain
security add-trusted-cert -d -r trustRoot -k ~/Library/Keychains/login.keychain-db ~/Downloads/caddy-root-ca.crt

# Verify
security find-certificate -c "Caddy Local Authority" ~/Library/Keychains/login.keychain-db
```

---

## 🐧 Linux

### Ubuntu / Debian / Mint
```bash
# Download certificate
wget http://cert.home.arpa -O caddy-root-ca.crt

# Copy to certificates directory
sudo cp caddy-root-ca.crt /usr/local/share/ca-certificates/

# Update certificate store
sudo update-ca-certificates

# Verify installation
ls -la /usr/local/share/ca-certificates/ | grep caddy

# For Firefox (if using Firefox)
certutil -A -n "Caddy Local Authority" -t "C,," -i caddy-root-ca.crt -d sql:$HOME/.mozilla/firefox/*.default-release

# For Chromium/Chrome (if needed)
certutil -A -n "Caddy Local Authority" -t "C,," -i caddy-root-ca.crt -d sql:$HOME/.pki/nssdb
```

### Fedora / RHEL / CentOS / Rocky Linux
```bash
# Download certificate
wget http://cert.home.arpa -O caddy-root-ca.crt

# Copy to CA trust directory
sudo cp caddy-root-ca.crt /etc/pki/ca-trust/source/anchors/

# Update CA trust
sudo update-ca-trust

# Verify installation
trust list | grep -i caddy

# For Firefox
certutil -A -n "Caddy Local Authority" -t "C,," -i caddy-root-ca.crt -d sql:$HOME/.mozilla/firefox/*.default-release
```

### Arch Linux / Manjaro
```bash
# Download certificate
wget http://cert.home.arpa -O caddy-root-ca.crt

# Copy to CA certificates
sudo cp caddy-root-ca.crt /etc/ca-certificates/trust-source/anchors/

# Update certificates
sudo trust extract-compat

# Verify
trust list | grep -i caddy
```

### openSUSE
```bash
# Download certificate
wget http://cert.home.arpa -O caddy-root-ca.crt

# Copy to certificates directory
sudo cp caddy-root-ca.crt /etc/pki/trust/anchors/

# Update certificates
sudo update-ca-certificates

# Verify
trust list | grep -i caddy
```

### Universal Linux (System-wide)
```bash
# Download
wget http://cert.home.arpa -O caddy-root-ca.crt

# For most distributions, try:
sudo mkdir -p /usr/local/share/ca-certificates
sudo cp caddy-root-ca.crt /usr/local/share/ca-certificates/

# Then run the appropriate update command for your distro:
# Debian/Ubuntu: sudo update-ca-certificates
# Fedora/RHEL:   sudo update-ca-trust
# Arch:          sudo trust extract-compat
```

---

## 📱 iOS

### Using Safari
1. On your iOS device, visit `http://qr.home.arpa`
2. Scan the QR code or visit `http://cert.home.arpa`
3. Tap **"Allow"** to download the configuration profile
4. Go to **Settings** → **Profile Downloaded** (at the top)
5. Tap **"Install"** → Enter your passcode
6. Tap **"Install"** again → **"Install"** once more
7. Tap **"Done"**
8. Go to **Settings** → **General** → **About** → **Certificate Trust Settings**
9. Enable the toggle for **"Caddy Local Authority"**
10. Tap **"Continue"**

### Command Line (for developers with iOS device connected)
```bash
# This requires a Mac with the device connected
# Export certificate from Caddy
docker exec caddy cat /data/caddy/pki/authorities/local/root.crt > caddy-root-ca.crt

# Create a .mobileconfig file (requires additional steps)
# This is complex and the web method is much easier for iOS
```

---

## 🤖 Android

### Using Chrome or any browser
1. Visit `http://qr.home.arpa` on your Android device
2. Scan the QR code or visit `http://cert.home.arpa`
3. Download the certificate file
4. Go to **Settings** → **Security** (or **Biometrics and security**)
5. Scroll down to **"Encryption & credentials"**
6. Tap **"Install a certificate"** or **"Install from device storage"**
7. Select **"CA certificate"**
8. Tap **"Install anyway"** (warning message)
9. Navigate to **Downloads** and select `caddy-root-ca.crt`
10. Enter your PIN/password if prompted

### Using ADB (Android Debug Bridge)
```bash
# Download certificate on your computer
wget http://cert.home.arpa -O caddy-root-ca.crt

# Push to device
adb push caddy-root-ca.crt /sdcard/Download/

# Then install manually through Settings as described above
```

---

## 🌐 Verification Commands

### Windows (PowerShell)
```powershell
# Check if certificate is installed
Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*Caddy*" } | Format-List Subject, Thumbprint, NotAfter
```

### macOS
```bash
# Check system keychain
security find-certificate -c "Caddy Local Authority" -p /Library/Keychains/System.keychain

# Check login keychain
security find-certificate -c "Caddy Local Authority" ~/Library/Keychains/login.keychain-db
```

### Linux
```bash
# Ubuntu/Debian
awk -v cmd='openssl x509 -noout -subject' '/BEGIN/{close(cmd)};{print | cmd}' < /etc/ssl/certs/ca-certificates.crt | grep -i caddy

# Fedora/RHEL
trust list | grep -i caddy

# Test HTTPS connection
curl -v https://vaultwarden.home.arpa 2>&1 | grep -i "ssl certificate"
```

---

## 🧪 Testing Your Certificate Installation

### Using curl
```bash
# This should succeed without errors
curl -v https://vaultwarden.home.arpa

# This should show "SSL certificate verify ok"
curl -vI https://pihole.home.arpa 2>&1 | grep "SSL certificate"
```

### Using OpenSSL
```bash
# Check certificate chain
openssl s_client -connect vaultwarden.home.arpa:443 -showcerts

# Verify certificate
echo | openssl s_client -connect octoprint.home.arpa:443 2>/dev/null | openssl x509 -noout -text | grep -i caddy
```

### Using Browser
1. Visit `https://vaultwarden.home.arpa`
2. Click the padlock icon in the address bar
3. View certificate details
4. Verify it says **"Caddy Local Authority"**
5. Should show **"Connection is secure"** with no warnings

---

## 🔧 Troubleshooting

### Certificate not trusted
```bash
# Re-download and reinstall
wget http://cert.home.arpa -O caddy-root-ca.crt

# Linux: Force update
sudo update-ca-certificates --fresh

# macOS: Remove and re-add
sudo security delete-certificate -c "Caddy Local Authority" /Library/Keychains/System.keychain
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain caddy-root-ca.crt
```

### Browser still shows warning
1. Clear browser cache and cookies
2. Restart browser completely
3. Check DNS is resolving correctly: `nslookup vaultwarden.home.arpa`
4. Verify you're using HTTPS (not HTTP)

### DNS not resolving
```bash
# Check if Pi-hole is being used as DNS
cat /etc/resolv.conf  # Linux
ipconfig /all  # Windows
scutil --dns  # macOS

# Test DNS resolution
nslookup vaultwarden.home.arpa
dig vaultwarden.home.arpa
```

---

## 📋 Quick Reference Card

| Platform | Install Command |
|----------|----------------|
| Windows | `certutil -addstore -f "ROOT" caddy-root-ca.crt` |
| macOS | `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain caddy-root-ca.crt` |
| Ubuntu/Debian | `sudo cp caddy-root-ca.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates` |
| Fedora/RHEL | `sudo cp caddy-root-ca.crt /etc/pki/ca-trust/source/anchors/ && sudo update-ca-trust` |
| iOS | Download via Safari, install in Settings |
| Android | Download, install via Settings → Security |

---

## 🚀 Automated Installation Script (Linux only)

```bash
#!/bin/bash
# Save this as install-cert.sh and run with: bash install-cert.sh

wget http://cert.home.arpa -O caddy-root-ca.crt

if [ -f /etc/debian_version ]; then
    sudo cp caddy-root-ca.crt /usr/local/share/ca-certificates/
    sudo update-ca-certificates
elif [ -f /etc/redhat-release ]; then
    sudo cp caddy-root-ca.crt /etc/pki/ca-trust/source/anchors/
    sudo update-ca-trust
elif [ -f /etc/arch-release ]; then
    sudo cp caddy-root-ca.crt /etc/ca-certificates/trust-source/anchors/
    sudo trust extract-compat
fi

echo "Certificate installed! Restart your browser."
```