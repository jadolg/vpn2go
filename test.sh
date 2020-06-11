#!/usr/bin/env bash
export SERVICE_USER=test
export SERVICE_PASSWORD=test

function get_http_code() {
    $1 2>/dev/null | head -n 1 | cut -d$' ' -f2
}

make build
make configure
make run

sleep 5

echo "++++++ TESTS ++++++"

if [[ $(get_http_code "curl -i http://localhost:5000") -ne 401 ]]; then
    echo "unauthorized access should not be allowed" $LINENO
    exit 1
fi

if [[ $(get_http_code "curl -i -u ${SERVICE_USER}:${SERVICE_PASSWORD} http://localhost:5000") -ne 200 ]]; then
    echo "authorized access should be allowed" $LINENO
    exit 1
fi

if [[ $(get_http_code "curl -i -u ${SERVICE_USER}:${SERVICE_PASSWORD} http://localhost:5000/user") -ne 404 ]]; then
    echo "user should not exist" $LINENO
    exit 1
fi

create_user_code=$(curl -i -u ${SERVICE_USER}:${SERVICE_PASSWORD} http://localhost:5000 -d '{"user":"user"}' 2>/dev/null | head -n 1 | cut -d$' ' -f2)

if [[ ${create_user_code} -ne 200 ]]; then
    echo "user creation failed" $LINENO
    exit 1
fi

create_user_code=$(curl -i -u ${SERVICE_USER}:${SERVICE_PASSWORD} http://localhost:5000 -d '{"user":"userip", "ip":"192.168.255.2"}' 2>/dev/null | head -n 1 | cut -d$' ' -f2)

if [[ ${create_user_code} -ne 200 ]]; then
    echo "user creation failed" $LINENO
    exit 1
fi

create_user_code=$(curl -i -u ${SERVICE_USER}:${SERVICE_PASSWORD} http://localhost:5000 -d '{"user":"userduration", "duration":"5"}' 2>/dev/null | head -n 1 | cut -d$' ' -f2)

if [[ ${create_user_code} -ne 200 ]]; then
    echo "user creation failed" $LINENO
    exit 1
fi

if [[ $(get_http_code "curl -i -u ${SERVICE_USER}:${SERVICE_PASSWORD} http://localhost:5000/user") -ne 200 ]]; then
    echo "should get the already created user" $LINENO
    exit 1
fi

if [[ $(get_http_code "curl -X DELETE -i -u ${SERVICE_USER}:${SERVICE_PASSWORD} http://localhost:5000/user") -ne 200 ]]; then
    echo "should delete the already created user" $LINENO
    exit 1
fi

if [[ $(get_http_code "curl -X DELETE -i -u ${SERVICE_USER}:${SERVICE_PASSWORD} http://localhost:5000/user") -ne 404 ]]; then
    echo "should not find already deleted user" $LINENO
    exit 1
fi
echo "++++++ TESTS ++++++"
make stop
make clean
