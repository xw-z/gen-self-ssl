#!/bin/bash
set -e

defaultPass="pass"
defaultSubject="/C=CN/ST=ST/L=L/O=O/OU=OU/CN="
defaultDays="3650"
defaultBit="2048"

HOST=${HOST}
PASS=${PASS:-$defaultPass}
SUBJECT=${SUBJECT}
DAYS=${DAYS:-$defaultDays}
BIT=${BIT:-$defaultBit}
SERVER_EXTFILE=${SERVER_EXTFILE}
IS_SERVER_EXTFILE_CREATED=0
CA=${CA}
PKCS12=${PKCS12}

help() {
    echo "Usage: "
    echo "  --host, -h: hostname, domain name or ip, required."
    echo "  --ca: create ca cert."
    echo "  --pass, -p: the password of cert, default $defaultPass."
    echo "  --days, -d: days, default $defaultDays."
    echo "  --subj: subject, default /C=CN/ST=ST/L=L/O=O/OU=OU/CN={host}."
    echo "  --bit: numbits, default '$defaultBit'."
    echo "  --server-exfile: default '', example --server-exfile=server-exfile.cnf."
    echo "  --help: help"
    echo "Example:"
    echo "  gen-self-ssl.sh --host=localhost --days=3650"
    echo "Note exfile.cnf data:"
    echo "  extendedKeyUsage = serverAuth"
    echo "  subjectAltName = DNS.1:example.com,IP.1:127.0.0.1"
}

log() {
    echo -e ">> "$*
}

log_warn() {
    echo -e ">> \e[1;33m[Waring] "$*"\e[0m"
}

log_err() {
    echo -e ">> \e[1;31m[Error] "$*"\e[0m"
}

log_suc() {
    echo -e ">> \e[1;32m"$*"\e[0m"
}

command_exists() {
    type "$1" &>/dev/null
}

command_openssl() {
    log "\e[1;34mopenssl "$*"\e[0m"
    case $OSTYPE in
    msys | win32)
        # git-bash
        MSYS_NO_PATHCONV=1 openssl $*
        ;;
    *)
        openssl $*
        ;;
    esac
}

check_file() {
    if [ ! -f "$1" ]; then
        log_err "[$1] no found."
        exit
    fi
}

parse_flags() {
    k=""
    v=""
    for flag in $*; do
        eval $(echo $flag | awk -F '=' '{printf("k=%s;v=%s",$1,$2)}')
        case $k in
        "--host" | "-host" | "-h") HOST=$v ;;
        "--ca" | "-ca") CA=1 ;;
        "--p12" | "-p12" | "--pkcs12") PKCS12=1 ;;
        "--bit" | "-bit") BIT=$v ;;
        "--subj" | "-subj") SUBJECT=$v ;;
        "--pass" | "-pass" | "-p") PASS=$v ;;
        "--days" | "-days" | "-d") DAYS=$v ;;
        "--server-extfile") SERVER_EXTFILE=$v ;;
        "--clean" | "-clean")
            clean
            exit
            ;;
        "--help" | "-help")
            help
            exit
            ;;
        *)
            log_err "unknown $k"
            help
            exit
            ;;
        esac
    done
}

initial() {

    parse_flags $*

    if [ -z "$HOST" ]; then
        help
        exit
    fi

    if ! command_exists openssl; then
        echo "OpenSSL isn't installed. You need that to generate SSL certificates."
        exit
    fi

    if [ -z "$SUBJECT" ]; then
        SUBJECT=${SUBJECT:-"/C=CN/ST=ST/L=L/O=O/OU=OU/CN=$HOST"}
    fi

    if [ -z "$SERVER_EXTFILE" ]; then
        SERVER_EXTFILE="server-extfile.cnf"
        if [ ! -f "$SERVER_EXTFILE" ]; then
            IPs="IP.1:127.0.0.1"
            IP=$( (echo $HOST | grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$") || echo "")
            if [ ! -z $IP ]; then
                IPs="$IPs,IP.2:$IP"
            fi
            echo -e "extendedKeyUsage = serverAuth\nsubjectAltName = DNS.1:$HOST,$IPs" >"$SERVER_EXTFILE"
            IS_SERVER_EXTFILE_CREATED=1
            log_warn "create template file $SERVER_EXTFILE."
        fi
    fi

    log "..."
    cat "$SERVER_EXTFILE"
    log "..."

    rm -f server-csr.pem client-csr.pem ca-key.pem ca.srl
    rm -f ca.pem client-cert.pem client-key.pem ca.pem server-cert.pem server-key.pem server.p12 client.p12
}

service() {
    if [ -n "$CA" ]; then
        # build ca
        command_openssl genrsa -passout pass:$PASS -out ca-key.pem $BIT
        check_file ca-key.pem
        log "ca-key.pem created."

        command_openssl req -new -x509 -subj $SUBJECT -sha256 -key ca-key.pem -passin pass:$PASS -out ca.pem -days $DAYS
        check_file ca.pem
        log "ca.pem created."
    fi

    # build server cert
    command_openssl genrsa -passout pass:$PASS -out server-key.pem $BIT
    check_file server-key.pem
    log "server-key.pem created."

    command_openssl req -new -subj $SUBJECT -key server-key.pem -passin pass:$PASS -out server-csr.pem
    check_file server-csr.pem
    log "server-csr.pem created."

    CMD_PARAMS=" -signkey server-key.pem"
    if [ -n "$CA" ]; then
        CMD_PARAMS=" -CAcreateserial -CA ca.pem -CAkey ca-key.pem"
    fi

    command_openssl x509 -req -days $DAYS -in server-csr.pem $CMD_PARAMS -out server-cert.pem -extfile "$SERVER_EXTFILE"
    check_file server-cert.pem
    log "server-cert.pem created."

    if [ -n "$PKCS12" ]; then
        command_openssl pkcs12 -export -in server-cert.pem -inkey server-key.pem -out server.p12 -passin pass:$PASS -passout pass:$PASS
        check_file server.p12
        log "server.p12 created."
    fi

    # build client cert
    command_openssl genrsa -out client-key.pem $BIT
    check_file client-key.pem
    log "client-key.pem created."

    command_openssl req -subj $SUBJECT -new -key client-key.pem -out client-csr.pem
    check_file client-csr.pem
    log "client-csr.pem created."

    CMD_PARAMS=" -signkey client-key.pem"
    if [ -n "$CA" ]; then
        CMD_PARAMS=" -CAcreateserial -CA ca.pem -CAkey ca-key.pem"
    fi
    command_openssl x509 -req -days $DAYS -in client-csr.pem $CMD_PARAMS -out client-cert.pem
    check_file client-cert.pem
    log "client-cert.pem created"

    if [ -n "$PKCS12" ]; then
        command_openssl pkcs12 -export -in client-cert.pem -inkey client-key.pem -out client.p12 -passin pass:$PASS -passout pass:$PASS
        check_file client.p12
        log "client.p12 created."
    fi

}

finish() {
    rm -f server-csr.pem client-csr.pem ca-key.pem ca.srl
    if [ $IS_SERVER_EXTFILE_CREATED = 1 ]; then
        log_warn "remove template file $SERVER_EXTFILE."
        rm -f "$SERVER_EXTFILE"
    fi

    log ""
    log "Output:"

    CMD_PARAMS=""
    if [ -n "$CA" ]; then
        CMD_PARAMS="$CMD_PARAMS ca.pem"
    fi
    if [ -n "$PKCS12" ]; then
        CMD_PARAMS="$CMD_PARAMS server.p12"
    fi
    log "server side: server-cert.pem server-key.pem $CMD_PARAMS"

    CMD_PARAMS=""
    if [ -n "$CA" ]; then
        CMD_PARAMS="$CMD_PARAMS ca.pem"
    fi
    if [ -n "$PKCS12" ]; then
        CMD_PARAMS="$CMD_PARAMS client.p12"
    fi
    log "client side: client-cert.pem client-key.pem $CMD_PARAMS"
    log_suc "---------Sucessfuly----------"
}

main() {
    initial $*

    service

    finish
}

main $*
