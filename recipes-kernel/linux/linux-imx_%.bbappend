FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# CIP patch batches, in apply order. Each batch lives in files/cip/<batch>/
# (patches + SHA256SUMS, produced by cip-sync/3_export.sh).
CIP_BATCHES = ""
#CIP_BATCHES = "cip31"

# The batches are added as directories, not as individual patches: kernel-yocto's
# do_kernel_metadata passes every SRC_URI patch to scc on one command line, and
# 12,000+ patches exceed the argument length limit ("Argument list too long").
SRC_URI:append:imx8mq-ecu150a1 = " ${@' '.join('file://cip/%s/' % b for b in d.getVar('CIP_BATCHES').split())}"

SRC_URI:append:imx8mq-ecu150a1 = " \
    file://imx8mq_ecu150a1_defconfig \
    file://0001-Add-ECU150A1-board-support.patch \
"

DELTA_KERNEL_DEFCONFIG:imx8mq-ecu150a1 = "imx8mq_ecu150a1_defconfig"

# Kernel is 6.12.108 once the CIP patches are applied
LINUX_VERSION:imx8mq-ecu150a1 = "${@'6.12.108' if d.getVar('CIP_BATCHES').strip() else '6.12.49'}"

# Apply the CIP batches with git am before kernel-yocto applies the SRC_URI
# patches (the board support patch is made on top of CIP).
do_patch:prepend:imx8mq-ecu150a1() {
	cd ${S}
	check_git_config
	if [ "${KERNEL_DEBUG_TIMESTAMPS}" != "1" ]; then
		reproducible_git_committer_author
	fi
	for batch in ${CIP_BATCHES}; do
		dir=${UNPACKDIR}/cip/$batch
		bbnote "Applying CIP batch $batch"
		if ! (cd $dir && sha256sum -c --quiet SHA256SUMS); then
			bbfatal "CIP batch $batch: patches do not match SHA256SUMS"
		fi
		if ! ls $dir | grep '\.patch$' | sort -V | sed "s|^|$dir/|" \
			| xargs -d '\n' sh -c 'git -c gc.auto=0 am -q "$@" || exit 255' sh; then
			failed=$(git am --show-current-patch=raw 2>/dev/null | grep -m1 '^Subject:' || true)
			git am --abort || true
			bbfatal "CIP batch $batch: git am failed at: $failed"
		fi
	done
}
