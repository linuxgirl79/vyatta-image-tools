#!/bin/bash

testConfigure ()
{
    # save stdin in fd 3 to be able to restore it later
    exec 4<&0
    # automatically hit return when prompted
    exec < <( yes "" )

    TEXT=( $(70-vyatta-xen configure) )
    assertEquals "2" "${#TEXT[*]}"
    assertEquals "false" "${TEXT[0]##VII_POSTINSTALL_VYATTA_XEN=}"
    # we don't care about the second entry

    # restore stdin from fd 4
    exec 0<&4 4<&-
}

testConfigureOnXen ()
{
    # mock dmidecode binary
    _create_dmidecode
    if [ "Xen" != "$(dmidecode -s system-manufacturer)" -o \
	"HVM domU" != "$(dmidecode -s system-product-name)" ]; then
	fail "ERROR: Failed to mock dmidecode binary"
	return
    fi

    # save stdin in fd 3 to be able to restore it later
    exec 4<&0
    # automatically hit return when prompted
    exec < <( yes "" )

    TEXT=( $(VII_POSTINSTALL_VYATTA_XEN=true 70-vyatta-xen configure) )
    assertEquals "2" "${#TEXT[*]}"
    assertEquals "true" "${TEXT[0]##VII_POSTINSTALL_VYATTA_XEN=}"
    assertEquals "xvda1" "${TEXT[1]##VII_POSTINSTALL_VYATTA_XEN_ROOTDEV=}"

    # restore stdin from fd 4
    exec 0<&4 4<&-
}

testRun ()
{
    # succeed (don't run) if unconfigured
    TEXT=$(70-vyatta-xen run)
    assertTrue "Returns true" $?
    assertEquals "" "${TEXT}"

    # fail if missing arguments
    TEXT=$(VII_POSTINSTALL_VYATTA_XEN='true' 70-vyatta-xen run 2>&1)
    assertFalse "Returns false" $?
    #assertEquals "" "${TEXT}"

    # fail is required directories don't exist
    TEXT=$(VII_POSTINSTALL_VYATTA_XEN='true' \
	VII_POSTINSTALL_VYATTA_XEN_ROOTDEV='xvda1' \
	70-vyatta-xen run \
	"${SHUNIT_TMPDIR}" "test" 2>&1)
    assertFalse "Returns false" $?

    # succeed
    mkdir -p "${SHUNIT_TMPDIR}"/boot/grub
    mkdir -p "${SHUNIT_TMPDIR}"/lib/live/mount/persistence/xvda2/boot
    mkdir -p "${SHUNIT_TMPDIR}"/config
    cat > "${SHUNIT_TMPDIR}"/config/config.boot <<EOF
console {
}
EOF
    TEXT=$(VII_POSTINSTALL_VYATTA_XEN='true' \
	VII_POSTINSTALL_VYATTA_XEN_ROOTDEV='xvda2' \
	70-vyatta-xen run \
	"${SHUNIT_TMPDIR}" "test" 2>&1)
    assertTrue "Returns true" $?
    assertEquals "" "${TEXT}"

    # default image symlink created
    assertTrue "default_image symlink" \
	$(test -L "${SHUNIT_TMPDIR}"/lib/live/mount/persistence/xvda2/boot/%%default_image; echo $?)
    # /boot/grub/menu.lst checks
    assertTrue "menu.lst root entry" \
	$(grep -q '^kernel\s.*\sroot=/dev/xvda2' \
	"${SHUNIT_TMPDIR}"/boot/grub/menu.lst; echo $?)
    assertTrue "menu.lst console entry" \
	$(grep -q '^kernel\s.*\sconsole=hvc0' \
	"${SHUNIT_TMPDIR}"/boot/grub/menu.lst; echo $?)
    # console entry added
    TEXT="$(cat "${SHUNIT_TMPDIR}"/config/config.boot)"
    assertTrue "contains hvc0: ${TEXT}" \
	"$(echo ${TEXT} | grep -q 'device hvc0'; echo $?)"
}

_create_dmidecode ()
{
    mkdir -p ${SHUNIT_TMPDIR}/bin
    cat > ${SHUNIT_TMPDIR}/bin/dmidecode << 'EOF'
#!/bin/sh

case "$2" in
    system-manufacturer)
	echo "Xen"
	;;
    system-product-name)
	echo "HVM domU"
	;;
    *)
	echo "moo: \"$2\""
	;;
esac
EOF
    chmod +x ${SHUNIT_TMPDIR}/bin/dmidecode
}

oneTimeSetUp ()
{
    local THIS_DIR=$(cd $(dirname ${0}); pwd -P)

    vyatta_sbindir="${THIS_DIR}/../scripts"
    export vyatta_sbindir

    # make SUT visible
    PATH="${THIS_DIR}/../postinstall.d:${SHUNIT_TMPDIR}/bin:${PATH}"
    export PATH

    # the implementation knows about unittest implementation
    if [ -z "${SHUNIT_TMPDIR}" ] ; then
	SHUNIT_TMPDIR=`mktemp -d`
	trap "rm -rf ${SHUNIT_TMPDIR}" EXIT
    fi
    export SHUNIT_TMPDIR
}

tearDown ()
{
    # clean-up after every test
    if [ -n "${SHUNIT_TMPDIR}" ] ; then
	rm -fr "${SHUNIT_TMPDIR}/*"
    fi
}

# load and run shUnit2
[ -n "${ZSH_VERSION:-}" ] && SHUNIT_PARENT=$0
. shunit2
