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
reverse_proxy frontend:80
route /api/v1* {
	uri strip_prefix /api/v1
	reverse_proxy vpn2go:5000
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
	docker-compose run --rm openvpn ovpn_genconfig -u $(PROTOCOL)://$(SERVER_ADDRESS):$(VPN_PORT) $(CLIENT_TO_CLIENT_FLAG) $(COMPRESSION_FLAG) -s $(SERVER_SUBNET) -n $(DNS_SERVER) -e "topology subnet"
	docker-compose run --rm -e "EASYRSA_BATCH=1" -e "EASYRSA_REQ_CN=$(CA)" openvpn ovpn_initpki nopass
	echo "$$CADDY_TEMPLATE" > Caddyfile

.PHONY:
run:
	docker-compose up -d

.PHONY:
stop:
	docker-compose down

.PHONY:
logs:
	docker-compose logs -f --tail=50

.PHONY:
status:
	docker-compose ps

.PHONY:
clean: stop
	-sudo rm -Rf $(OVPN_DATA)
	-sudo rm -Rf caddy
	-rm -f Caddyfile
