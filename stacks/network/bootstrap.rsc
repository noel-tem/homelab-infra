# Run once on the hAP ax3 after `/system reset-configuration no-defaults=yes`, pasted into WinBox's terminal.
# It sets up just enough for Tofu to connect, on ether5, which Tofu keeps out of the bridge as
# the management port. Everything else is stacks/network. The tofu user is added by hand afterwards, so its password
# isn't in this file.

/ip address add address=192.168.88.1/24 interface=ether5 comment=mgmt

# For the REST API Tofu uses; valid for both addresses it's reached on. Signed by a local CA because RouterOS
# 7.25 won't self-sign a certificate that isn't a CA ("CA not found")
/certificate add name=router-ca common-name=live-laugh-router-ca key-size=2048 days-valid=3650 \
    key-usage=key-cert-sign,crl-sign
/certificate sign router-ca
/certificate add name=router common-name=live-laugh-router subject-alt-name=IP:192.168.0.1,IP:192.168.88.1 \
    key-size=2048 days-valid=3650 key-usage=digital-signature,key-encipherment,tls-server
/certificate sign router ca=router-ca

/ip service set www-ssl certificate=router disabled=no address=192.168.0.0/24,192.168.88.0/24
