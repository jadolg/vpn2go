#!make
include .env
export $(shell sed 's/=.*//' .env)

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

.PHONY:
build:
	docker build -t vpn2go .
	git clone $(REPOSITORY)
	cd docker-openvpn && docker build -t $(DOCKER_IMAGE) .
	rm -Rf docker-openvpn

.PHONY:
configure:
	docker-compose run openvpn ovpn_genconfig -u $(PROTOCOL)://$(SERVER_ADDRESS):$(VPN_PORT) $(CLIENT_TO_CLIENT_FLAG) $(COMPRESSION_FLAG) -s $(SERVER_SUBNET) -n $(SERVER_IP_ADDRESS) -n $(DNS_SERVER) -e "topology subnet"
	docker-compose run -e "EASYRSA_BATCH=1" -e "EASYRSA_REQ_CN="$(CA) openvpn ovpn_initpki nopass
	printf "localhost, $(SERVER_ADDRESS)\nreverse_proxy vpn2go:5000\nroute /dnsmasq/* {\n\turi strip_prefix /dnsmasq\n\treverse_proxy dnsmasq:8080\n}" > Caddyfile
	printf "log-queries\nno-resolv\nserver=$(DNS_SERVER)\nstrict-order\naddress=/$(SERVER_ADDRESS)/$(SERVER_IP_ADDRESS)" > dnsmasq.conf

.PHONY:
run:
	docker-compose up -d

.PHONY:
stop:
	docker-compose down

.PHONY:
clean:
	-rm -Rf docker-openvpn
	-sudo rm -Rf $(OVPN_DATA)
	-sudo rm -Rf caddy
	-rm -f $(EXAMPLE_USER).ovpn
	-rm -f Caddyfile
	-rm -f dnsmasq.conf
	-docker rmi $(DOCKER_IMAGE)
