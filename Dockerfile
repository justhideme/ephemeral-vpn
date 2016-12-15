FROM alpine:3.3
MAINTAINER CJ Niemira <siege@siege.org>
EXPOSE 1194/udp
EXPOSE 443/tcp

RUN echo "http://dl-4.alpinelinux.org/alpine/edge/community/" >> /etc/apk/repositories && \
    echo "http://dl-4.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories && \
    apk add --update drill libqrencode lighttpd openssl openvpn && \
    ln -s /usr/share/easy-rsa/easyrsa /usr/local/bin && \
    rm -rf /tmp/* /var/tmp/* /var/cache/apk/*

ENV updated 20160412-2244
ADD get_config.sh /get_config.sh
ADD run_vpn.sh /run_vpn.sh

CMD ["/run_vpn.sh"]
