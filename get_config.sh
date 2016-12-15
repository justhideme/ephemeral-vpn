#!/bin/sh
#
# Docker purists will hate this, however, the idea here is to spin up
# a webserver from which the user can download the client config.
#

umask 0022
source /etc/openvpn/env.sh
CONF=${PKI_SERVER}.ovpn
# TODO: sanity check the config

boldtext=$(printf '%b\n' '\033[1m')
normtext=$(printf '%b\n' '\033[0m')
default=$(printf '%b\n' '\033[39m\033[49m')
hilight=$(printf '%b\n' '\033[31m\033[40m')


cat <<EOF
*************************************************************************
 ${boldtext}Waiting for VPN server to start. This can take up to 5 minutes.${normtext}
*************************************************************************
EOF
while [ ! -f ${VPN_PID} ]
do
  echo -n .
  sleep 1
done
echo ""


prompt_for_config_method() {
  read -p "Your choice: " opt
  echo ${opt}
}


do_showconf() {
  cat <<EOF
Copy and paste the config below into a text file and name it:
  ${CONF}

Double click on the file to configure your VPN client.

${boldtext}vvvvvvvvvvvvvvvvvvvvv COPY BELOW THIS LINE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvv${normtext}
$(cat ${CLIENT_CNF})
${boldtext}^^^^^^^^^^^^^^^^^^^^^ COPY ABOVE THIS LINE ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^${normtext}
EOF
}


do_webserver() {
  DOCS=/var/www/localhost/htdocs
  HTTPD_CNF=/tmp/httpd.conf
  URL="https://${IPV4_ADDR}/${CONF}"

  mkdir -p ${DOCS}
  chmod 0711 ${DOCS}
  install -m 444 -o nobody -g nobody ${CLIENT_CNF} ${DOCS}/${CONF}

  cat <<EOF
*************************************************************************
 ${boldtext}Scan to download the client config file:${normtext}
*************************************************************************
EOF

  # This should work on any modern terminal
  qrencode -t ANSIUTF8 --foreground=ffffff --background=000000 "${URL}"

  cat <<EOF

Or paste the following into a web browser:
  ${boldtext}${URL}${normtext}

${hilight}CONFIRM BEFORE IGNORING ANY SECURITY WARNINGS:${default}
  Cert Name:	${boldtext}${PKI_WEBSRV}${normtext}
  Issued by:	${boldtext}${PKI_SIGNER}${normtext}
  VPN Profile:  ${IPV4_ADDR}/autologin
  More info:    ${boldtext}https://justhideme.github.io/warnings.html${normtext}

Hurry, this URL will self-destruct after two minutes.

EOF

  # Spin up a webserver for the .ovpn, and kill it after two minutes
  # lighttpd has the features we need to force the download this way
  cat > ${HTTPD_CNF} <<EOF
\$HTTP["url"] =~ "\.ovpn\$" {
  setenv.add-response-header = ("Content-Disposition" => "attachment; filename=vpn.${VPN_ID}.justhide.me.ovpn")
  mimetype.assign = ("" => "application/x-openvpn-profile")
}
server.document-root = "${DOCS}"
server.modules = ("mod_setenv")
server.port = 443
ssl.engine = "enable" 
ssl.pemfile = "${WEB_PEM}"
EOF

  timeout -s TERM -t 120 lighttpd -D -f ${HTTPD_CNF} >/dev/null 2>&1
  rm -rf ${DOCS}
  rm ${HTTPD_CNF}

  cat <<EOF
*************************************************************************
 ${boldtext}Time's up.${normtext}
*************************************************************************
The config download webserver has been shut down. The VPN itself will
remain active until the host VM is destroyed.

EOF
}


# The VPN should be running at this point
# Print a message, and ask how the user wants to get the config
cat <<EOF
*************************************************************************
              ${boldtext}Your ephemeral VPN server is running!${normtext}
*************************************************************************
How should I deliver the client config?

  1. Show it here (copy and paste into a file)
  2. Start a webserver and download it
  0. Don't show the client config

EOF


while [ 1 ]; do
    opt=$(prompt_for_config_method)
    case "${opt}" in
        1 ) do_showconf ; break ;;
        2 ) do_webserver ; break ;;
        0 ) break ;;
    esac
    echo "? Pick one of: [1] [2] [0]"
done


# Exit message
cat <<EOF
Simply run the JustHideMe command again to re-download the client config.

Thanks for trusting your privacy needs to JustHideMe.

${boldtext}${hilight}!!! DO NOT FORGET TO DESTROY THE HOST VM WHEN YOU ARE DONE !!!${default}${normtext}
EOF


exit 0
