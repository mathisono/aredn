include $(TOPDIR)/rules.mk

PKG_NAME:=aredn-multiwan
PKG_VERSION:=0.1.0
PKG_RELEASE:=1
PKG_LICENSE:=GPL-3.0-only
PKG_MAINTAINER:=AREDN contributors
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/aredn-multiwan
  SECTION:=net
  CATEGORY:=Network
  TITLE:=AREDN experimental multi-WAN and USB tethering
  URL:=https://github.com/mathisono/aredn
  DEPENDS:=@(TARGET_ath79_mikrotik||TARGET_ipq40xx_mikrotik) \
    +ca-bundle +curl +ip +jshn +jsonfilter +nftables-json +redsocks \
    +kmod-nft-nat +kmod-usb-net-rndis +kmod-usb-net-cdc-ether \
    +kmod-usb-net-cdc-ncm
endef

define Package/aredn-multiwan/description
 Experimental AREDN multi-WAN package for the MikroTik hAP ac lite,
 hAP ac2, and hAP ac3. It provides an optional USB WAN, PdaNet HTTP
 CONNECT proxy support, manual route selection, and bounded link calibration.
 The package is not installed in the base firmware image.
endef

define Package/aredn-multiwan/preinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
board="$$(cat /tmp/sysinfo/board_name 2>/dev/null)"
[ -z "$$board" ] && exit 0
case "$$board" in
  mikrotik,routerboard-952ui-5ac2nd|mikrotik,hap-ac2|mikrotik,hap-ac3)
    exit 0
    ;;
  *)
    echo "aredn-multiwan is supported only on the MikroTik hAP ac lite, hAP ac2, and hAP ac3" >&2
    exit 1
    ;;
esac
endef

define Package/aredn-multiwan/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
if [ -x /etc/uci-defaults/95-aredn-multiwan ]; then
  /etc/uci-defaults/95-aredn-multiwan && rm -f /etc/uci-defaults/95-aredn-multiwan
fi
if [ -x /etc/uci-defaults/98_wan3_redsocks ]; then
  /etc/uci-defaults/98_wan3_redsocks && rm -f /etc/uci-defaults/98_wan3_redsocks
fi
/etc/init.d/wan3-manager enable >/dev/null 2>&1 || true
/etc/init.d/wan3-manager restart >/dev/null 2>&1 || true
exit 0
endef

define Package/aredn-multiwan/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
/usr/local/bin/wan3-manager select wan >/dev/null 2>&1 || true
/etc/init.d/wan3-manager stop >/dev/null 2>&1 || true
/etc/init.d/wan3-manager disable >/dev/null 2>&1 || true
exit 0
endef

define Package/aredn-multiwan/install
	$(INSTALL_DIR) $(1)/usr/local/bin
	$(INSTALL_BIN) ./files/usr/local/bin/wan3-manager $(1)/usr/local/bin/
	$(INSTALL_BIN) ./files/usr/local/bin/wan-route-cache $(1)/usr/local/bin/
	$(INSTALL_BIN) ./files/usr/local/bin/wan-calibrate $(1)/usr/local/bin/

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/wan3-manager $(1)/etc/init.d/

	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_BIN) ./files/etc/hotplug.d/iface/95-wan3-manager $(1)/etc/hotplug.d/iface/
	$(INSTALL_DIR) $(1)/etc/hotplug.d/net
	$(INSTALL_BIN) ./files/etc/hotplug.d/net/95-wan3-manager $(1)/etc/hotplug.d/net/

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/95-aredn-multiwan $(1)/etc/uci-defaults/
	$(INSTALL_BIN) ./files/etc/uci-defaults/98_wan3_redsocks $(1)/etc/uci-defaults/

	$(INSTALL_DIR) $(1)/app/main/status/e
	$(INSTALL_DATA) ./files/app/main/status/e/usb-wan.ut $(1)/app/main/status/e/
	$(INSTALL_DATA) ./files/app/main/status/e/link-calibration.ut $(1)/app/main/status/e/
	$(INSTALL_DIR) $(1)/app/main
	$(INSTALL_DATA) ./files/app/main/multiwan.ut $(1)/app/main/
	$(INSTALL_DATA) ./files/app/main/u-multiwan.ut $(1)/app/main/
	$(INSTALL_DATA) ./files/app/main/u-usb-wan.ut $(1)/app/main/
	$(INSTALL_DATA) ./files/app/main/u-link-calibration.ut $(1)/app/main/
	$(INSTALL_DIR) $(1)/app/partial
	$(INSTALL_DATA) ./files/app/partial/multiwan-page.ut $(1)/app/partial/
	$(INSTALL_DATA) ./files/app/partial/usb-wan.ut $(1)/app/partial/
	$(INSTALL_DATA) ./files/app/partial/link-calibration.ut $(1)/app/partial/

	$(INSTALL_DIR) $(1)/www/cgi-bin/apps/aredn-multiwan
	$(INSTALL_BIN) ./files/www/cgi-bin/apps/aredn-multiwan/admin $(1)/www/cgi-bin/apps/aredn-multiwan/
	$(INSTALL_DIR) $(1)/www/apps/aredn-multiwan
	$(INSTALL_DATA) ./files/www/apps/aredn-multiwan/icon.svg $(1)/www/apps/aredn-multiwan/
	$(INSTALL_DATA) ./files/www/apps/aredn-multiwan/help.html $(1)/www/apps/aredn-multiwan/

	$(INSTALL_DIR) $(1)/usr/share/doc/aredn-multiwan
	$(INSTALL_DATA) ./files/usr/share/doc/aredn-multiwan/multiwan-usb-wan.md $(1)/usr/share/doc/aredn-multiwan/
	$(INSTALL_DATA) ./files/usr/share/doc/aredn-multiwan/multiwan-link-calibration.md $(1)/usr/share/doc/aredn-multiwan/
	$(INSTALL_DATA) ./files/usr/share/doc/aredn-multiwan/multiwan-verification.md $(1)/usr/share/doc/aredn-multiwan/
endef

$(eval $(call BuildPackage,aredn-multiwan))
