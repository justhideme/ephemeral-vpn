#!/bin/sh
#
# Docker purists will hate me for this, however, the idea here is
# to spin up a webserver from which the user can download the
# client config.
#

umask 0022
source /etc/openvpn/env.sh >/dev/null 2>&1

# Wait until OpenVPN has started
echo "Your ephemeral VPN is being created!"
echo "Relax, this is going to take a while."
while [ ! -f $VPN_PID ]
do
  echo -n .
  sleep 1
done
echo ""

DOCS=/var/www/localhost/htdocs
USER=client
PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
echo $PASS | mini_htpasswd -c $DOCS/.htpasswd $USER >/dev/null

mkdir -p $DOCS
chmod 0711 $DOCS
install -m 444 -o nobody -g nobody /etc/openvpn/client.conf $DOCS/${PKI_SERVER}.ovpn
cat <<EOF
*************************************************************************
      Congratulations, your ephemeral VPN server is now running!
*************************************************************************

Copy and paste this address in a web browser and double-click on the file
it downloads to configure your client:

 https://$USER:$PASS@${IPV4_ADDR}/${PKI_SERVER}.ovpn

And hurry up. This URL will self-destruct after two minutes.


*************************************************************************
  NOTE: Your web browser will display security warnings! Here's why:
*************************************************************************
First, a username and password are passed in the URL, and some browsers
don't like this. They think it's a phishing scam. In this case it's not.

Enter the url and credentials manually if you need to get around this:

  https://${IPV4_ADDR}/${PKI_SERVER}.ovpn
  Username:		$USER
  Password:		$PASS

Second, your VPN has created its own disposable certificate authority
that your browser does not implicitly trust. You can verify it as:

  Certificate Name:	$PKI_SERVER
  Issued by:		$PKI_SIGNER

This is the one of the ONLY times it is safe to ignore these messages.

EOF

# Spin up a webserver for the .ovpn, and kill it after two minutes
timeout -s KILL -t 120 mini_httpd -D -S -E $PKI_DIR/$PKI_SERVER -d $DOCS -h 0.0.0.0 -p 443 -u daemon >/dev/null 2>&1
rm -rf $DOCS

cat <<EOF

*************************************************************************
  Time's up.
*************************************************************************
The config download service has been shut down. The VPN itself will
remain active until the host VM is destroyed.

Re-run the same justhide.me command if you need to download the client
config file again.

Thanks for trusting your privacy needs to justhide.me, and don't
forget to destroy the host VM when you're done.

EOF

exit 0
