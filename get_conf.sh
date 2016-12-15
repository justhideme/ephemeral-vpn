#!/bin/sh
#
# Just spit out the config file
#

umask 0022
source /etc/openvpn/env.sh

echo "Waiting for OpenVPN. This might take a while."
while [ ! -f $VPN_PID ]
do
  echo -n .
  sleep 1
done
echo ""

CONF=${PKI_SERVER}.ovpn

cat <<EOF
Copy and paste the config below into a text file and name it:
  $CONF

Double click on the file to configure your VPN client.

vvvvvvvvvvvvvvvvvvvvv COPY BELOW THIS LINE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
$(cat $CLIENT_CNF)
^^^^^^^^^^^^^^^^^^^^^ COPY ABOVE THIS LINE ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
EOF

exit 0
