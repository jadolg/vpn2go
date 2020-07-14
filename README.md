# Easy to deploy and manage OpenVPN server

OpenVPN server with an API for user management.
Using this amazing project https://github.com/kylemanna/docker-openvpn

## Objective

Using the docker-openvpn is simple and fun, but with time I wanted to automate my user management process and link it to other systems.
The goal of this project is creating a basic configuration for docker-openvpn and an web API to manage the users.  

## Requirements

- [Docker](https://www.docker.com/)
- [Make](https://www.gnu.org/software/make/manual/html_node/Introduction.html)
- [git](https://git-scm.com/)

## How to deploy
1. Clone the project and cd into it
2. Execute `make build` to build the docker images
3. Edit the .env file and adapt the security related variables to your environment with save values
- SERVICE_USER
- SERVICE_PASSWORD
4. Export the customization variables to your environment
- SERVER_ADDRESS
- SERVER_IP_ADDRESS
- CA
5. Customize your server with these extra variables (optional)
- PROTOCOL (default:udp)
- VPN_PORT (default:1194)
- SERVER_SUBNET (default:192.168.253.0/24)
- DNS_SERVER (default:1.1.1.1)
- CLIENT_TO_CLIENT (default:no) Set this to yes if you want the clients to communicate amongst themselves.
- COMPRESSION (default:yes)
6. Execute `make configure` to generate the base OpenVPN configuration
7. Execute `make run` to start the services
8. Open ports 5000/tcp and 1194/udp in your firewall

## How to use the API

### List all created certificates

`curl -u SERVICE_USER:SERVICE_PASSWORD SERVER_ADDRESS:5000`

output: a list of certificates

### Create a new certificate

`curl -X POST -u SERVICE_USER:SERVICE_PASSWORD SERVER_ADDRESS:5000 -d '{"user":"username"}'`

output: a text configuration for openvpn

### Create a new certificate with a fixed ip address

`curl -X POST -u SERVICE_USER:SERVICE_PASSWORD SERVER_ADDRESS:5000 -d '{"user":"username", "ip":"192.168.253.5"}'`

output: a text configuration for openvpn

*note:* duplicates for ip address are not being handled. Use this at your own risk.

### Create a new certificate with a specific duration in days (default is 1460)

`curl -X POST -u SERVICE_USER:SERVICE_PASSWORD SERVER_ADDRESS:5000 -d '{"user":"username", "duration":"5"}'`

output: a text configuration for openvpn

### Get user configuration

`curl -u SERVICE_USER:SERVICE_PASSWORD SERVER_ADDRESS:5000/username`

output: a text configuration for openvpn

### Revoke a certificate

`curl -X DELETE -u SERVICE_USER:SERVICE_PASSWORD SERVER_ADDRESS:5000/username`

output: ok

### Get current status log

`curl -u SERVICE_USER:SERVICE_PASSWORD SERVER_ADDRESS:5000/status`

output: an openvpn status log
