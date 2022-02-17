# self-signed certificates

## Usage:
```
  ./gen-self-ssl.sh --help
```

## Example:
```
# 
./gen-self-ssl.sh --host=localhost --days=36500

HOST=localhost DAYS=36500 ./gen-self-ssl.sh

./gen-self-ssl.sh --host=localhost --days=36500 --ca=1

HOST=localhost DAYS=36500 CA=1 ./gen-self-ssl.sh
```

```
curl -sSL https://raw.githubusercontent.com/xw-z/gen-self-ssl/master/gen-self-ssl.sh | HOST=localhost DAYS=36500 bash -s 

curl -sSL https://raw.githubusercontent.com/xw-z/gen-self-ssl/master/gen-self-ssl.sh | HOST=localhost DAYS=36500 CA=1 bash -s 

curl -sSL https://gitee.com/xwzhou/gen-self-ssl/raw/master/gen-self-ssl.sh | HOST=localhost DAYS=36500 bash -s 

curl -sSL https://gitee.com/xwzhou/gen-self-ssl/raw/master/gen-self-ssl.sh | HOST=localhost DAYS=36500 CA=1 bash -s 
```
