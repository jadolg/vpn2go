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
	reverse_proxy frontend:80
}
endef
export CADDY_TEMPLATE

.PHONY:
build:
	docker-compose build

push:
	docker push guamulo/vpn2go

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
	-sudo rm -Rf $(OVPN_DATA)
	-sudo rm -Rf caddy
	-rm -f Caddyfile
	-rm -f dnsmasq.conf
