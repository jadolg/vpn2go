# You should REALLY change the credentials for production environments
SERVICE_USER ?= admin
SERVICE_PASSWORD ?= JY9yZhXuKhNfGwfu+OrKfkBMFiHVwg0ehlP1NLthCIs
SERVER_ADDRESS ?= 192.168.178.26
SERVER_IP_ADDRESS ?= 192.168.178.26
CA ?= myvpn

PROTOCOL ?= udp
VPN_PORT ?= 1194
SERVER_SUBNET ?= 192.168.253.0/24
DNS_SERVER ?= 1.1.1.1
CLIENT_TO_CLIENT ?= no
COMPRESSION ?= yes

ifeq ($(CLIENT_TO_CLIENT), yes)
	CLIENT_TO_CLIENT_FLAG := -c
else
	CLIENT_TO_CLIENT_FLAG :=
endif

ifeq ($(COMPRESSION), yes)
	COMPRESSION_FLAG := -z
else
	COMPRESSION_FLAG :=
endif

OVPN_DATA ?= $(PWD)/ovpn-data
DOCKER_IMAGE ?= kylemanna/openvpn
REPOSITORY ?= https://github.com/kylemanna/docker-openvpn.git

DOCKER_COMPOSE= OVPN_DATA=$(OVPN_DATA) \
				VPN_PORT=$(VPN_PORT) \
				PROTOCOL=$(PROTOCOL) \
				DOCKER_IMAGE=$(DOCKER_IMAGE) \
				SERVER_ADDRESS=$(SERVER_ADDRESS) \
				SERVICE_USER=$(SERVICE_USER) \
				SERVICE_PASSWORD=$(SERVICE_PASSWORD) \
				docker-compose

.PHONY:
build:
	docker build -t vpn2go .
	git clone $(REPOSITORY)
	cd docker-openvpn && docker build -t $(DOCKER_IMAGE) .
	rm -Rf docker-openvpn

.PHONY:
configure:
	docker run --rm -v $(OVPN_DATA):/etc/openvpn $(DOCKER_IMAGE) ovpn_genconfig -u $(PROTOCOL)://$(SERVER_ADDRESS):$(VPN_PORT) $(CLIENT_TO_CLIENT_FLAG) $(COMPRESSION_FLAG) -s $(SERVER_SUBNET) -n $(SERVER_IP_ADDRESS) -n $(DNS_SERVER) -e "topology subnet"
	docker run --rm -v $(OVPN_DATA):/etc/openvpn -i -e "EASYRSA_BATCH=1" -e "EASYRSA_REQ_CN="$(CA) $(DOCKER_IMAGE) ovpn_initpki nopass
	printf "localhost, $(SERVER_ADDRESS)\nreverse_proxy vpn2go:5000\nroute /dnsmasq/* {\n\turi strip_prefix /dnsmasq\n\treverse_proxy dnsmasq:8080\n}" > Caddyfile
	printf "log-queries\nno-resolv\nserver=$(DNS_SERVER)\nstrict-order\naddress=/$(SERVER_ADDRESS)/$(SERVER_IP_ADDRESS)" > dnsmasq.conf

.PHONY:
run:
	$(DOCKER_COMPOSE) up -d

.PHONY:
logs:
	$(DOCKER_COMPOSE) logs -f --tail =100

.PHONY:
ps:
	$(DOCKER_COMPOSE) ps

.PHONY:
stop:
	$(DOCKER_COMPOSE) down

.PHONY:
clean:
	rm -Rf docker-openvpn
	sudo rm -Rf $(OVPN_DATA)
	sudo rm -Rf caddy
	rm -f $(EXAMPLE_USER).ovpn
	rm -f Caddyfile
	rm -f dnsmasq.conf
	docker rmi $(DOCKER_IMAGE)
