#!/bin/sh

# https://tunnelblick.net

export DO_TOR=0

##########################
# Variable Initialization
##########################
#export IPV4_ADDR=$(dig +short myip.opendns.com @208.67.222.222)
# people really like drill better?
export IPV4_ADDR=$(drill myip.opendns.com @208.67.222.222 | grep -v \;\; | grep . | cut -f 5)

export OPENVPN="/etc/openvpn"
export ENV_CNF="${OPENVPN}/env.sh"

export CLIENT_CNF="${OPENVPN}/client.conf"
export PKI_DIR="${OPENVPN}/pki"
export PKI_CNF="${PKI_DIR}/pki.cnf"
export VPN_CNF="${OPENVPN}/openvpn.conf"
export VPN_PID="/var/run/openvpn.pid"

export PKI_DAYS=365
export PKI_KEY_SIZE=2048
export PKI_MD="sha512"

export VPN_ID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
export PKI_CLIENT=client.${VPN_ID}.justhide.me
export PKI_SERVER=vpn.${VPN_ID}.justhide.me
export PKI_SIGNER=ca.${VPN_ID}.justhide.me
export PKI_WEBSRV=web.${VPN_ID}.justhide.me
export VPN_AUTH_ALGO="SHA256"
export VPN_CIPHER="AES-128-CBC"
export VPN_DNS=1
export VPN_DNS_SERVERS="208.67.222.222,208.67.220.220"
export VPN_SUBNET="192.168.255.0/24"
export VPN_TLS_AUTH="${PKI_DIR}/key/tls-auth"
export VPN_TLS_CIPHER="TLS-DHE-RSA-WITH-AES-128-CBC-SHA256"

export WEB_PEM="${PKI_DIR}/${PKI_WEBSRV}"

##############################
# Create the environment file
##############################
set -o posix ; set > ${ENV_CNF}


############
# Functions
############
cidr2mask() {
    eval $(ipcalc -m ${1})
    echo ${NETMASK}
}

getnetdevice() {
    echo "eth0"
}

getroute() {
    echo ${1%/*} $(cidr2mask $1)
}


################
# Setup the PKI
################
umask 0077
mkdir -p -m 700 ${PKI_DIR}
mkdir -m 700 ${PKI_DIR}/csr
mkdir -m 700 ${PKI_DIR}/crt
mkdir -m 700 ${PKI_DIR}/key
touch ${PKI_DIR}/db
echo 01 > ${PKI_DIR}/serial

cat > "${PKI_CNF}" <<EOF
RANDFILE		= \$ENV::PKI_DIR/.rnd

[ ca ]
default_ca		= ephemeral_ca

[ req ]
default_bits            = \$ENV::PKI_KEY_SIZE    # RSA key size
encrypt_key             = no                    # Protect private key
default_md              = \$ENV::PKI_MD          # MD to use
utf8                    = yes                   # Input is UTF-8
string_mask             = utf8only              # Emit UTF-8 strings
prompt                  = no                    # Don't prompt for DN
distinguished_name      = ephemeral_dn          # DN section
req_extensions          = ephemeral_signer      # Desired extensions

[ ephemeral_ca ]
dir			= \$ENV::PKI_DIR
certs			= \$dir
database		= \$dir/db
new_certs_dir		= \$dir
certificate		= \$dir/crt/\$ENV::PKI_SIGNER
private_key		= \$dir/key/\$ENV::PKI_SIGNER
serial			= \$dir/serial

default_days		= \$ENV::PKI_DAYS
default_md 		= \$ENV::PKI_MD
email_in_dn		= no
policy 			= ephemeral_policy
preserve		= no
x509_extensions		= basic_exts

[ ephemeral_policy ]
countryName		= optional
stateOrProvinceName	= optional
localityName		= optional
organizationName	= supplied
organizationalUnitName	= supplied
commonName		= supplied
name			= optional
emailAddress		= optional

[ ephemeral_dn ]
0.domainComponent       = "me"
1.domainComponent       = "justhide"
organizationName        = "JustHideMe"
organizationalUnitName  = "Ephemeral VPN"
commonName              = \$ENV::REQ_CN

[ ephemeral_client ]
keyUsage                = critical,digitalSignature,keyEncipherment
extendedKeyUsage        = clientAuth
subjectKeyIdentifier    = hash

[ephemeral_server]
keyUsage                = critical,digitalSignature,keyEncipherment
extendedKeyUsage        = serverAuth,clientAuth
subjectKeyIdentifier    = hash
subjectAltName          = \$ENV::SAN

[ ephemeral_signer ]
keyUsage                = critical,keyCertSign,cRLSign
basicConstraints        = critical,CA:true
subjectKeyIdentifier    = hash
EOF

# The server certs need a SAN
export SAN="IP:${IPV4_ADDR}"

# Create the signing certificate
export REQ_CN=${PKI_SIGNER}
openssl req -new -config ${PKI_CNF} -out ${PKI_DIR}/crt/${REQ_CN} -keyout ${PKI_DIR}/key/${REQ_CN} -x509

# Create the client certificate
export REQ_CN=${PKI_CLIENT}
openssl req -new -config ${PKI_CNF} -out ${PKI_DIR}/csr/${REQ_CN} -keyout ${PKI_DIR}/key/${REQ_CN}
openssl ca -config ${PKI_CNF} -in ${PKI_DIR}/csr/${REQ_CN} -out ${PKI_DIR}/crt/${REQ_CN} -extensions ephemeral_client -batch

# Create the vpn server certificate
export REQ_CN=${PKI_SERVER}
openssl req -new -config ${PKI_CNF} -out ${PKI_DIR}/csr/${REQ_CN} -keyout ${PKI_DIR}/key/${REQ_CN}
openssl ca -config ${PKI_CNF} -in ${PKI_DIR}/csr/${REQ_CN} -out ${PKI_DIR}/crt/${REQ_CN} -extensions ephemeral_server -batch

# Create the web server certificate
export REQ_CN=${PKI_WEBSRV}
openssl req -new -config ${PKI_CNF} -out ${PKI_DIR}/csr/${REQ_CN} -keyout ${PKI_DIR}/key/${REQ_CN}
openssl ca -config ${PKI_CNF} -in ${PKI_DIR}/csr/${REQ_CN} -out ${PKI_DIR}/crt/${REQ_CN} -extensions ephemeral_server -batch


############################################
# Build a certkey bundle for the web server
############################################
openssl pkey -in ${PKI_DIR}/key/${PKI_WEBSRV} -outform pem  > ${WEB_PEM}
openssl x509 -in ${PKI_DIR}/crt/${PKI_WEBSRV} -outform pem >> ${WEB_PEM}
openssl x509 -in ${PKI_DIR}/crt/${PKI_SIGNER} -outform pem >> ${WEB_PEM}


#####################################
# Generate Diffie-Hellman parameters
#####################################
openssl dhparam -out ${PKI_DIR}/dh.pem ${PKI_KEY_SIZE}
openvpn --genkey --secret ${VPN_TLS_AUTH}


####################
# Configure OpenVPN
####################
cat > "${VPN_CNF}" <<EOF
server $(getroute ${VPN_SUBNET})
verb 3
key ${PKI_DIR}/key/${PKI_SERVER}
ca ${PKI_DIR}/crt/${PKI_SIGNER}
cert ${PKI_DIR}/crt/${PKI_SERVER}
dh ${PKI_DIR}/dh.pem
tls-auth ${VPN_TLS_AUTH}
key-direction 0
keepalive 10 60
persist-key
persist-tun

proto udp
port 1194
dev tun0
status /tmp/openvpn-status.log

user nobody
group nogroup
auth ${VPN_AUTH_ALGO}
cipher ${VPN_CIPHER}
tls-cipher ${VPN_TLS_CIPHER}
EOF


# Append DNS servers
[ "${VPN_DNS}" == "1" ] && for i in $(echo ${VPN_DNS_SERVERS} | tr ',' ' '); do
  echo "push dhcp-option DNS ${i}" >> "${VPN_CNF}"
done


###################################
# Prepare the client configuration
###################################
umask 0022

cat > "${CLIENT_CNF}" <<EOF
client
nobind
auth ${VPN_AUTH_ALGO}
cipher ${VPN_CIPHER}
tls-cipher ${VPN_TLS_CIPHER}
dev tun
key-direction 1
redirect-gateway def1
remote-cert-tls server
remote ${IPV4_ADDR} 1194 udp
<key>
$(openssl pkey -in ${PKI_DIR}/key/${PKI_CLIENT} -outform pem)
</key>
<cert>
$(openssl x509 -in ${PKI_DIR}/crt/${PKI_CLIENT} -outform pem)
</cert>
<ca>
$(openssl x509 -in ${PKI_DIR}/crt/${PKI_SIGNER} -outform pem)
</ca>
<dh>
$(cat ${PKI_DIR}/dh.pem)
</dh>
<tls-auth>
$(cat ${VPN_TLS_AUTH})
</tls-auth>
EOF

################
# Start OpenVPN
################
mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200
fi

# NAT client traffic
iptables -t nat -A POSTROUTING -s ${VPN_SUBNET} -o $(getnetdevice) -j MASQUERADE

# Once the VPN process is up, we can delete the key files
nohup sh -c "while [ ! -f ${VPN_PID} ]; do sleep 1; done && rm -rf $PKI_DIR/key" > /dev/null 2>&1 &

# Start the OpenVPN process
openvpn --config ${VPN_CNF} --writepid ${VPN_PID}
