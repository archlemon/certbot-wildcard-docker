#/bin/bash

DOMAIN=$1
EMAIL=$2
CONTAINER_NAME=$3
COPYPATH=$4
CERTNAME=${5:-wildcard}

USAGE="Usage: generate.sh \"*.example.com\" \"me@example.com\" [container name: \"nginx-proxy\"] [copy path: \"/path/to/proxy/folder\"] [certname: \"wildcard\"]" 

TERMINAL=$(tty)

if [ ! -e do.ini ]
then
    read -s -p "Enter your Digitalocean API token:" TOKEN <$TERMINAL

    if [ ! -z $TOKEN ]
    then
        cp "do.ini.example" "do.ini"
        chmod 0600 "do.ini"
        sed -i.bak "s/TOKEN/$TOKEN/" "do.ini" && rm "do.ini.bak"
    else
        echo "No token given."
        exit 1
    fi
fi

if [ -z $DOMAIN ]
then
    echo "A domain is required." 1>&2
    echo $USAGE 1>&2
    exit 1
fi

FOLDER=$(echo "$DOMAIN" | sed -e 's/^*.//')

if [ -z $EMAIL ]
then
    echo "An email address is required." 1>&2
    echo $USAGE 1>&2
    exit 1
fi

if [ ! -z $CONTAINER_NAME ]
then
    docker stop $CONTAINER_NAME
fi

if [ ! -d letsencrypt ]
then
    mkdir letsencrypt
fi

docker run --rm \
    -p 80:80 \
    -v $(pwd)/letsencrypt:/etc/letsencrypt \
    -v $(pwd)/do.ini:/do.ini \
    certbot/dns-digitalocean \
    certonly \
    --non-interactive \
    --agree-tos \
    -m $EMAIL \
    --preferred-challenges dns-01 \
    --dns-digitalocean \
    --dns-digitalocean-credentials /do.ini \
    -d $DOMAIN;

if [ -n $COPYPATH ]
then
    cp $(pwd)/letsencrypt/live/$FOLDER/cert.pem $COPYPATH$CERTNAME.crt
    cp $(pwd)/letsencrypt/live/$FOLDER/privkey.pem $COPYPATH$CERTNAME.key
fi

if [ ! -z $CONTAINER_NAME ]
then
    docker start $CONTAINER_NAME
fi
