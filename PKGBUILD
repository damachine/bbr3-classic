# Maintainer: damachin3 (damachine3 at proton dot me)
# Website: https://github.com/damachine/bbr_classic-multi

pkgname=bbr-classic-dkms
pkgver=6.19
pkgrel=1
pkgdesc="BBRv1 TCP congestion control module (backport for BBRv3-patched kernels)"
arch=('x86_64')
license=('GPL-2.0-only')
url="https://github.com/damachine/bbr_classic-multi"
depends=('dkms')
source=("tcp_bbr.c::https://raw.githubusercontent.com/torvalds/linux/v${pkgver}/net/ipv4/tcp_bbr.c"
        "Makefile"
        "dkms.conf")
sha256sums=('5e468692502251ada233ce249eb5c98b155846903269d04e0505500eefd2e99f'
            'bd98bebb5ce99cf59f995df7d860448851b41c3d6c5f343780d5fb8dadbd4a5d'
            '7acc6421f5b2b131967279dd9bf85932565c70c16a565f1158d256667cd35c24')

package() {
    install -dm755 "${pkgdir}/usr/src/bbr-classic-${pkgver}"
    install -m644 "tcp_bbr.c" "${pkgdir}/usr/src/bbr-classic-${pkgver}/"
    install -m644 "Makefile" "${pkgdir}/usr/src/bbr-classic-${pkgver}/"
    sed "s/@VERSION@/${pkgver}/" "dkms.conf" > "${pkgdir}/usr/src/bbr-classic-${pkgver}/dkms.conf"
}
