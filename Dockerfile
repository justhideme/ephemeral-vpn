FROM alpine:3.3
MAINTAINER CJ Niemira <siege@siege.org>
EXPOSE 1194/udp
EXPOSE 443/tcp

RUN echo "http://dl-4.alpinelinux.org/alpine/edge/community/" >> /etc/apk/repositories && \
    echo "http://dl-4.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories && \
    apk add --update openssl openvpn mini_httpd drill && \
    ln -s /usr/share/easy-rsa/easyrsa /usr/local/bin && \
    rm -rf /tmp/* /var/tmp/* /var/cache/apk/*

ENV updated 20160411-2308
ADD vpn.sh /vpn.sh
ADD web.sh /web.sh

CMD ["/vpn.sh"]
