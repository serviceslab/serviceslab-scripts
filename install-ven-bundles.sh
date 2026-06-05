#install ven bundles
latest_illumio_ven_bundle=$(ls /tmp/illumio-ven-bundle-*|tail -n 1)
illumio_ven_bundles=($(ls /tmp/illumio-ven-bundle-*))
for illumio_ven_bundle in "${illumio_ven_bundles[@]}"; do
 if [[ $illumio_ven_bundle == $latest_illumio_ven_bundle ]]; then continue; fi
 sudo -u ilo-pce /opt/illumio-pce/illumio-pce-ctl ven-software-install $illumio_ven_bundle --compatibility-matrix /tmp/illumio-release-compatibility-* --no-prompt --orgs 1
done