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

define CADDY_TEMPLATE=
localhost, $(SERVER_ADDRESS)
reverse_proxy vpn2go:5000
route /dnsmasq/* {
	uri strip_prefix /dnsmasq
	reverse_proxy dnsmasq:8080
}
route /admin/* {
	uri strip_prefix /admin
	reverse_proxy frontend:8989
}
endef
export CADDY_TEMPLATE

.PHONY:
build:
	docker build -t vpn2go .
	git clone $(REPOSITORY)
	sed -i '/ENV EASYRSA_VARS_FILE $$OPENVPN\/vars/d' docker-openvpn/Dockerfile
	cd docker-openvpn && docker build -t $(DOCKER_IMAGE) .
	rm -Rf docker-openvpn
	git clone https://github.com/wil92/vpn2go-frontend.git
	cd vpn2go-frontend && API_URL=$(SERVER_ADDRESS) docker-compose build
	rm -Rf vpn2go-frontend

.PHONY:
configure:
	docker-compose run --rm openvpn ovpn_genconfig -u $(PROTOCOL)://$(SERVER_ADDRESS):$(VPN_PORT) $(CLIENT_TO_CLIENT_FLAG) $(COMPRESSION_FLAG) -s $(SERVER_SUBNET) -n $(SERVER_IP_ADDRESS) -n $(DNS_SERVER) -e "topology subnet"
	docker-compose run --rm -e "EASYRSA_BATCH=1" -e "EASYRSA_REQ_CN=$(CA)" openvpn ovpn_initpki nopass
	echo "$$CADDY_TEMPLATE" > Caddyfile
	printf "log-queries\nno-resolv\nserver=$(DNS_SERVER)\nstrict-order\naddress=/$(SERVER_ADDRESS)/$(SERVER_IP_ADDRESS)" > dnsmasq.conf

.PHONY:
run:
	docker-compose up -d

.PHONY:
stop:
	docker-compose down

.PHONY:
clean: stop
	-rm -Rf docker-openvpn
	-sudo rm -Rf $(OVPN_DATA)
	-sudo rm -Rf caddy
	-rm -f $(EXAMPLE_USER).ovpn
	-rm -f Caddyfile
	-rm -f dnsmasq.conf
	-docker rmi $(DOCKER_IMAGE)
