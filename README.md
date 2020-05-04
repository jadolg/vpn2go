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
3. Export the security related variables to your environment with save values
- SERVICE_USER
- SERVICE_PASSWORD
4. Export the customization variables to your environment
- SERVER_ADDRESS
- CA
5. Execute `make configure` to generate the base OpenVPN configuration
6. Execute `make run` to start the services
7. Open ports 5000/tcp and 1194/udp in your firewall

## How to use the API

### List all created certificates (including server certificate)

`curl -u SERVICE_USER:SERVICE_PASSWORD SERVER_ADDRESS:5000`

output: a list of certificates

### Create a new certificate

`curl -X POST -u SERVICE_USER:SERVICE_PASSWORD SERVER_ADDRESS:5000 -d '{"user":"username"}'`

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
