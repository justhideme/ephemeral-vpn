#!/bin/sh
#
# Docker purists will hate this, however, the idea here is to spin up
# a webserver from which the user can download the client config.
#

umask 0022
source /etc/openvpn/env.sh

# TODO: sanity check the config

echo "Waiting for OpenVPN. This might take a while."
while [ ! -f $VPN_PID ]
do
  echo -n .
  sleep 1
done
echo ""


CONF=${PKI_SERVER}.ovpn
DOCS=/var/www/localhost/htdocs
HTTPD_CNF=/tmp/httpd.conf
URL="https://${IPV4_ADDR}/$CONF"

mkdir -p $DOCS
chmod 0711 $DOCS
install -m 444 -o nobody -g nobody $CLIENT_CNF $DOCS/$CONF


cat <<EOF
*************************************************************************
 Scan to download the client config file:
*************************************************************************
EOF

# This should work on any modern terminal
qrencode -t ANSIUTF8 --foreground=ffffff --background=000000 "$URL"

cat <<EOF

Or paste the following into a web browser:
  URL:		$URL
  Cert Name:	$PKI_WEBSRV
  Issued by:	$PKI_SIGNER

ABOUT THE SECURITY WARNINGS:   https://justhideme.github.io/warnings.html

Hurry, this URL will self-destruct after two minutes.

EOF

# Spin up a webserver for the .ovpn, and kill it after two minutes
#  mini_httpd doesn't support new mime_types and defaults to text/plain
#  darkhttpd doesn't do tls
#  so, lighttpd it is...
cat > ${HTTPD_CNF} <<EOF
mimetype.assign = (".ovpn" => "application/octet-stream")
server.document-root = "${DOCS}"
server.port = 443
ssl.engine = "enable" 
ssl.pemfile = "$WEB_PEM"
EOF

timeout -s TERM -t 120 lighttpd -D -f ${HTTPD_CNF}
rm -rf ${DOCS}
rm ${HTTPD_CNF}


cat <<EOF
*************************************************************************
  Time's up.
*************************************************************************
The config download service has been shut down. The VPN itself will
remain active until the host VM is destroyed.

EOF

exit 0
