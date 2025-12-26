import os

from time import sleep
from base64 import b64decode
from yagmail import SMTP
from dotenv import load_dotenv

load_dotenv()

# Get environment variables
peers = os.getenv("WG_PEERS", "").split(",")
emails = os.getenv("WG_PEERS_EMAILS", "").split(",")
smtp_server = os.getenv("SMTP_SERVER")
smtp_port = int(os.getenv("SMTP_PORT", "587"))
smtp_user = os.getenv("SMTP_USER")
smtp_pass = b64decode(os.getenv("SMTP_PASS", "").encode("utf-8")).decode("utf-8").strip()

# Wait for WireGuard configs
config_dir = "/config"
for _ in range(30):
    if os.path.exists(config_dir) and any(os.listdir(config_dir)):
        break
    sleep(5)

print(f"📨 Starting WireGuard mailer...")
# Initialize mailer
yag = SMTP(user=smtp_user, password=smtp_pass, host=smtp_server, port=smtp_port, smtp_starttls=False)
print(f"✅ Connected to SMTP server {smtp_server}\n")

# Iterate over peers
for peer, email in zip(peers, emails):
    peer = peer.strip()
    email = email.strip()
    conf_folder = f"{config_dir}/peer_{peer}"
    if not os.path.exists(conf_folder):
        print(f"⚠️ Config folder not found for {peer}")
        continue

    qr_path = f"{conf_folder}/peer_{peer}.png"
    conf_path = f"{conf_folder}/peer_{peer}.conf"
    conf_data = open(conf_path, "r").read()

    # Compose email
    subject = f"Your WireGuard VPN Configuration ({peer})"
    body = f"""
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; color: #333;">
        <h2 style="color: #2c3e50; margin-bottom: 20px;">WireGuard VPN Configuration</h2>
        
        <p style="font-size: 16px; line-height: 1.5;">
            A VPN configuration has been generated for your device: <strong>{peer}</strong>
        </p>

        <div style="background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <h3 style="color: #2c3e50; margin-top: 0;">📱 Setup Instructions</h3>
            <ol style="margin-left: 20px; line-height: 1.6;">
                <li>Install the WireGuard app from the App Store or Google Play</li>
                <li>Open the app and tap "+"</li>
                <li>Choose "Scan from QR Code"</li>
                <li>Scan the attached QR image</li>
                <li>That's it — your secure VPN is ready!</li>
            </ol>
        </div>

        <div style="background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <h3 style="color: #2c3e50; margin-top: 0;">Manual Configuration</h3>
            <p style="margin-bottom: 10px;">If you prefer manual setup, here's your config file content:</p>
            <pre style="background-color: #fff; padding: 15px; border-radius: 4px; overflow-x: auto; font-size: 14px;">{conf_data}</pre>
        </div>

        <p style="font-size: 16px; color: #2c3e50; text-align: center; margin-top: 30px;">
            Stay secure! 🛡️
        </p>
    </div>
    """

    # Send email
    print(f"""📤 Sending config for {peer} to {email}...
      - Config path: {conf_path}
      - QR path: {qr_path}""")
    yag.send(to=email, subject=subject, contents=[body, qr_path])
    print(f"✅ Sent")
