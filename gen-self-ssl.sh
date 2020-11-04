#!/bin/bash

set -e

defaultPass="pass"
defaultSubCN="self"
defaultDays="3650"
defaultBit="2048"

HOST=${HOST}
PASS=${PASS:-$defaultPass}
DAYS=${DAYS:-$defaultDays}
BIT=${BIT:-$defaultBit}
SUB_CN=${SUB_CN:-$defaultSubCN}
ALLOW_FILE=${ALLOW_FILE}

Help(){
    echo "Usage: "
    echo "  --host: hostname or ip, required."
    echo "  --pass: the password of cert, default '$defaultPass'."
    echo "  --days: days, default '$defaultDays'."
    echo "  --bit: numbits, default '$defaultBit'."
    echo "  --sub_cn: subject CN."
    echo "  --allow: allow file."
    echo "  --clean: clean files."
    echo "  --help: help"
    echo "Example:"
    echo "  gen-self-ssl.sh --host=localhost --days=36500"
}

Clean(){
    rm -f server-csr.pem client-csr.pem options.list ca-key.pem ca.srl
    rm -f ca.pem client-cert.pem client-key.pem ca.pem server-cert.pem server-key.pem
}

ParseFlags(){
    k=""
    v=""
    for flag in $*
    do
        eval $(echo $flag | awk -F '=' '{printf("k=%s;v=%s",$1,$2)}')
        case $k in
        "--host")
            HOST=$v
            ;;
        "--pass")
            PASS=$v
            ;;
        "--days")
            DAYS=$v
            ;;
        "--sub_cn")
            SUB_CN=$v
            ;;
        "--allow")
            ALLOW_FILE=$v
            if [ -z "$ALLOW_FILE" ]; then
                Help
                exit
            fi
            ;;
        "--clean")
            Clean
            exit
            ;;
        "--help")
            Help
            exit
            ;;
        *)
            ;;
        esac
    done
}

ParseFlags $*

if [ -z "$HOST" ]; then
    Help
    exit
fi

if [ -z "$PASS" ]; then
    Help
    exit
fi

command_exists(){
    type "$1" &> /dev/null ;
}

if ! command_exists openssl ; then
        echo "OpenSSL isn't installed. You need that to generate SSL certificates."
    exit
fi

echo HOST = $HOST

Clean

openssl genrsa -passout pass:$PASS -out ca-key.pem $BIT
echo ">> ca-key.pem created."

SUBJECT="/C=CN/ST=/L=/O=/OU=/=$HOST"
openssl req -new -x509 -subj $SUBJECT -days $DAYS -sha256 -key ca-key.pem -passin pass:$PASS -out ca.pem
echo ">> ca.pem created."

openssl genrsa -aes256 -passout pass:$PASS -out server-key.pem $BIT
echo ">> server-key.pem created."

openssl req -new -subj "/CN=$SUB_CN" -sha256  -key server-key.pem -passin pass:$PASS -out server-csr.pem

echo ">> server-csr.pem created."


if [ -z "$ALLOW_FILE" ]; then
    openssl x509 -req -days $DAYS -sha256 -in server-csr.pem -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem
else
    openssl x509 -req -days $DAYS -sha256 -in server-csr.pem -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem -extfile $ALLOW_FILE    
fi
echo ">> server-cert.pem created."

openssl genrsa -out client-key.pem $BIT
openssl req -subj "/CN=$SUB_CN" -new -key client-key.pem -out client-csr.pem
echo ">> client-csr.pem created."

echo "extendedKeyUsage = clientAuth" > options.list
openssl x509 -req -days $DAYS -sha256 -in client-csr.pem -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out client-cert.pem -extfile options.list
echo ">> client-cert.pem created."

rm -f server-csr.pem client-csr.pem options.list ca-key.pem ca.srl

echo "---------------"
echo "Sucessfuly."
echo "client side: ca.pem client-cert.pem client-key.pem"
echo "server side: ca.pem server-cert.pem server-key.pem"