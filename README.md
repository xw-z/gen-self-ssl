# self-signed certificates

## Usage:
```
  --host: hostname or ip, required.
  --pass: the password of cert, default 'pass'.
  --days: days, default '3650'.
  --bit: numbits, default '2048'.
  --allow: allow file.
  --clean: clean files.
  --help: help
```

## Example:
```
./gen-self-ssl.sh --host=localhost --days=36500
```

## Client Side
- ca.pem
- client-cert.pem
- client-key.pem

## Server Side
- ca.pem
- server-cert.pem
- server-key.pem


## Related
```
go run $GOROOT/src/crypto/tls/generate_cert.go --host="localhost" --duration="8760h0m0s"
# duration: 8760h0m0s (a year).
```