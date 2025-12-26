# Docker Project
This project contains Docker configurations for deploying various services including Vaultwarden with PostgreSQL, WireGuard VPN server, and OctoPrint for 3D printing management.


## Prerequisites
- Docker and Docker Compose installed on your system.


## Environment Variables
The project uses a `.env` file to manage environment variables. Below are the key variables used
in the project:
- `TZ`: Timezone for the containers.

- `PG_PASSWORD`: Password for the PostgreSQL database.
- `VAULTWARDEN_ADMIN_TOKEN`: Admin token for Vaultwarden.
- `VAULTWARDEN_JWT_SECRET`: JWT secret for Vaultwarden.

- `WG_SERVERURL`: URL for the WireGuard VPN server.
- `WG_SERVERPORT`: Port for the WireGuard VPN server.
- `WG_PEERS`: Comma-separated list of WireGuard peer names.

- `OCTOPRINT_USER`: Admin username for OctoPrint.
- `OCTOPRINT_PASS`: Admin password for OctoPrint.


## Vaultwarden
Generate a strong ADMIN_TOKEN
```bash
echo -n "<VAULTWARDEN_ADMIN_PASSWORD>" | argon2 "$(openssl rand -base64 32)" -e -id -k 65540 -t 3 -p 4
# Note: add an extra `$` to every `$` in the output before adding it to the .env file
```

## Setup Instructions
1. Clone the repository to your local machine.
    ```bash
    git clone <repository-url>
    ```
2. Navigate to the project directory.
    ```bash
    cd <project-directory>
    ```
3. Create a `.env` file based on the `.env.example` file.
    ```bash
    cp .env.example .env
    ```
4. Update the `.env` file with your specific configuration values.
5. Start the services using Docker Compose.
    ```bash
    docker-compose up -d
    ```
6. Verify that the services are running.
    ```bash
    docker-compose ps
    ```


## Accessing Services
- Vaultwarden: Access the Vaultwarden web interface at `http://<your-server-ip>:
    8080` using the admin token specified in the `.env` file.
- WireGuard: Configure your WireGuard clients using the server URL specified in the
    `.env` file.


## Troubleshooting
If you encounter any issues, check the logs of the respective containers:
```bash
docker-compose logs <service-name>
```

## License
This project is licensed under the MIT License. See the LICENSE file for details.
