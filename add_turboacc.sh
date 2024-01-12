#!/usr/bin/env bash

trap 'rm -rf "$TMPDIR"' EXIT
TMPDIR=$(mktemp -d) || exit 1

if ! [ -d "./package" ]; then
    echo "./package not found"
    exit 1
fi

kernel_versions="$(find "./include"|sed -n '/kernel-[0-9]/p'|sed -e "s@./include/kernel-@@" |sed ':a;N;$!ba;s/\n/ /g')"
if [ -z "$kernel_versions" ]; then
    echo "Error: Unable to get kernel version, script exited"
    exit 1
fi
echo "kernel version: $kernel_versions"

if [ -d "./package/turboacc" ]; then
    echo "./package/turboacc already exists,delete it?[Y/N]"
    read -r answer
    if [[ $answer =~ ^[Yy]$ ]]; then
        rm -rf "./package/turboacc"
    else
        echo "You selected 'No', script exited"
        exit 0
    fi
fi

git clone --depth=1 --single-branch --branch "package" https://github.com/zijieKwok/turboacc "$TMPDIR/package" || exit 1
git clone --depth=1 --single-branch https://github.com/fullcone-nat-nftables/nft-fullcone "$TMPDIR/turboacc/nft-fullcone" || exit 1
git clone --depth=1 --single-branch https://github.com/zijieKwok/turboacc "$TMPDIR/turboacc/turboacc" || exit 1
cp -r "$TMPDIR/turboacc/turboacc/luci-app-turboacc" "$TMPDIR/turboacc/luci-app-turboacc"
rm -rf "$TMPDIR/turboacc/turboacc"
cp -r "$TMPDIR/package/shortcut-fe" "$TMPDIR/turboacc/shortcut-fe"

for kernel_version in $kernel_versions ;do
    patch_953_path="./target/linux/generic/hack-$kernel_version/953-net-patch-linux-kernel-to-support-shortcut-fe.patch"
    patch_613_path="./target/linux/generic/pending-$kernel_version/613-netfilter_optional_tcp_window_check.patch"
    if  [ "$kernel_version" = "6.1" ] || [ "$kernel_version" = "5.15" ]; then
        patch_952_path="./target/linux/generic/hack-$kernel_version/952-add-net-conntrack-events-support-multiple-registrant.patch"
        patch_952="952-add-net-conntrack-events-support-multiple-registrant.patch"
    elif [ "$kernel_version" = "5.10" ]; then
        patch_952_path="./target/linux/generic/hack-$kernel_version/952-net-conntrack-events-support-multiple-registrant.patch"
        patch_952="952-net-conntrack-events-support-multiple-registrant.patch"
    else
        echo "Unsupported kernel version: $kernel_version"
        exit 1
    fi

    for file_path in "$patch_952_path" "$patch_953_path" "$patch_613_path" ;do
        if [ -a "$file_path" ]; then
            echo "$file_path already exists,delete."
            rm -rf "$file_path"
        fi
    done

    cp -f "$TMPDIR/package/hack-$kernel_version/$patch_952" "$patch_952_path"
    cp -f "$TMPDIR/package/hack-$kernel_version/953-net-patch-linux-kernel-to-support-shortcut-fe.patch" "$patch_953_path"
    cp -f "$TMPDIR/package/pending-$kernel_version/613-netfilter_optional_tcp_window_check.patch" "$patch_613_path"

    if ! grep -q "CONFIG_NF_CONNTRACK_CHAIN_EVENTS" "./target/linux/generic/config-$kernel_version" ; then
        echo "# CONFIG_NF_CONNTRACK_CHAIN_EVENTS is not set" >> "./target/linux/generic/config-$kernel_version"
    fi
    if ! grep -q "CONFIG_SHORTCUT_FE" "./target/linux/generic/config-$kernel_version" ; then
        echo "# CONFIG_SHORTCUT_FE is not set" >> "./target/linux/generic/config-$kernel_version"
    fi
done

cp -r "$TMPDIR/turboacc" "./package/turboacc"
rm -rf ./package/libs/libnftnl ./package/network/config/firewall4 ./package/network/utils/nftables
cp -RT "$TMPDIR/package/firewall4-$(grep -o 'FIREWALL4_VERSION=.*' "$TMPDIR/package/version" | cut -d '=' -f 2)/firewall4" ./package/network/config/firewall4
cp -RT "$TMPDIR/package/libnftnl-$(grep -o 'LIBNFTNL_VERSION=.*' "$TMPDIR/package/version" | cut -d '=' -f 2)/libnftnl" ./package/libs/libnftnl
cp -RT "$TMPDIR/package/nftables-$(grep -o 'NFTABLES_VERSION=.*' "$TMPDIR/package/version" | cut -d '=' -f 2)/nftables" ./package/network/utils/nftables

echo "Finish"
exit 0
