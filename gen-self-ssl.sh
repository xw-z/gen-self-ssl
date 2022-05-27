#!/bin/bash
set -e

defaultPass="pass"
defaultSubject="/C=CN/ST=ST/L=L/O=O/OU=OU"
defaultDays="3650"
defaultBit="2048"
defaultExtfileData="extendedKeyUsage = serverAuth\nsubjectAltName = DNS.1:example.com,IP.1:127.0.0.1"

HOST=${HOST}
PASS=${PASS:-$defaultPass}
SUBJECT=${SUBJECT}
DAYS=${DAYS:-$defaultDays}
BIT=${BIT:-$defaultBit}
EXTFILE=${EXTFILE}
CA=${CA}
PKCS12=${PKCS12}

rebuild_subject() {
    if [ -z "$SUBJECT" ]; then
        SUBJECT=${SUBJECT:-$defaultSubject}"/CN="$HOST
    fi
}

help() {
    echo "Usage: "
    echo "  --host, -h: hostname, domain name or ip, required."
    echo "  --ca: create ca cert."
    echo "  --pass, -p: the password of cert, default '$defaultPass'."
    echo "  --days, -d: days, default '$defaultDays'."
    echo "  --subj: subject, default '$defaultSubject/CN=\{host}'."
    echo "  --bit: numbits, default '$defaultBit'."
    echo "  --exfile: exfile, default '', example --exfile=exfile.cnf."
    echo "  --help: help"
    echo "Example:"
    echo "  gen-self-ssl.sh --host=localhost --days=3650"
    echo "Note exfile.cnf data:"
    echo -e "$defaultExtfileData"
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

clean() {
    rm -f server-csr.pem client-csr.pem ca-key.pem ca.srl
    rm -f ca.pem client-cert.pem client-key.pem ca.pem server-cert.pem server-key.pem server.p12 client.p12
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
        "--extfile" | "-extfile") EXTFILE=$v ;;
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
    rebuild_subject
}

build() {
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

    v_path_extfile="$EXTFILE"
    v_autoremove=0
    if [ -z $v_path_extfile ]; then
        v_autoremove=1
        v_path_extfile="server-extfile.cnf"
        echo -e "extendedKeyUsage = serverAuth\nsubjectAltName = DNS.1:$HOST,IP.1:127.0.0.1" >"$v_path_extfile"
        log_warn "create template file $v_path_extfile."
    fi

    log "..."
    cat "$v_path_extfile"
    log "..."

    CMD_PARAMS=" -signkey server-key.pem"
    if [ -n "$CA" ]; then
        CMD_PARAMS=" -CAcreateserial -CA ca.pem -CAkey ca-key.pem"
    fi

    command_openssl x509 -req -days $DAYS -in server-csr.pem $CMD_PARAMS -out server-cert.pem -extfile "$v_path_extfile"
    check_file server-cert.pem
    log "server-cert.pem created."

    if [ -n "$PKCS12" ]; then
        command_openssl pkcs12 -export -in server-cert.pem -inkey server-key.pem -out server.p12 -passin pass:$PASS -passout pass:$PASS
        check_file server.p12
        log "server.p12 created."
    fi

    if [ $v_autoremove = 1 ]; then
        log_warn "remove template file $v_path_extfile."
        rm -f "$v_path_extfile"
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

    rm -f server-csr.pem client-csr.pem ca-key.pem ca.srl

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
    parse_flags $*

    if [ -z "$HOST" ]; then
        help
        exit
    fi

    if ! command_exists openssl; then
        echo "OpenSSL isn't installed. You need that to generate SSL certificates."
        exit
    fi

    clean

    build

}

main $*
