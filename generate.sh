#/bin/bash

CURDIR=`dirname "$0"`
DOMAIN=$1
EMAIL=$2
CONTAINER_NAME=$3
COPYPATH=$4
CERTNAME=${5:-wildcard}

USAGE="Usage: generate.sh \"*.example.com\" \"me@example.com\" [container name: \"nginx-web\"] [copy path: \"/path/to/proxy/folder\"] [certname: \"wildcard\"]"

TERMINAL=$(tty)
CONFIG=$CURDIR/do.ini

if [ ! -e $CONFIG ]
then
    read -s -p "Enter your Digitalocean API token:" TOKEN <$TERMINAL

    if [ ! -z $TOKEN ]
    then
        cp $CONFIG.example $CONFIG
        chmod 0600 $CONFIG
        sed -i.bak "s/TOKEN/$TOKEN/" $CONFIG && rm $CONFIG.bak
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
    -v $CURDIR/letsencrypt:/etc/letsencrypt \
    -v $CURDIR/do.ini:/do.ini \
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
    cp $CURDIR/letsencrypt/live/$FOLDER/cert.pem $COPYPATH$CERTNAME.crt
    cp $CURDIR/letsencrypt/live/$FOLDER/privkey.pem $COPYPATH$CERTNAME.key
fi

if [ ! -z $CONTAINER_NAME ]
then
    docker start $CONTAINER_NAME
fi
