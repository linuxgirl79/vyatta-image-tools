#
# Helper functions for unit tests
#

# Write to fake device file in /dev/
_setup_is_onie_boot ()
{
    function is_onie_boot ()
    {
        return $1
    }
    export -f is_onie_boot
}

_setup_partition () {
    local arr=( $@ )
    local device=$1
    local lsblk_args=( ${arr[@]:1} )
    
    mkdir -p "${SHUNIT_TMPDIR}/dev"
    echo ${lsblk_args[@]} >> "${SHUNIT_TMPDIR}/dev/$device"
}

_setup_basic_vrouter_hdd () {
    # Size in bytes
    _setup_partition sda "KNAME=sda" "SIZE=10550000000"
    _setup_partition sda "KNAME=sda1" "LABEL=BIOS_BOOT" "SIZE=300000000"
    _setup_partition sda "KNAME=sda2" "LABEL=vRouter" "SIZE=4096000000"
    _setup_partition sda "KNAME=sda3" "LABEL=LIBVIRT" "SIZE=2048000000"
    _setup_partition sda "KNAME=sda4" "LABEL=LOGS" "SIZE=4096000000"
}

_setup_lsblk ()
{
    function lsblk () {
    while test -n "$1"; do
     PARAM="$1"
     ARG="$2"
     case $PARAM in
       *-*=*)
     ARG=${PARAM#*=}
     PARAM=${PARAM%%=*}
     set -- "----noarg=$PARAM" "$@"
     ;;
     esac
     case ${PARAM/#--/-} in
       -o|-output)
            IFS=","
            OUT_REPLY=""
            for i in $ARG; do
            if [[ $i == KNAME ]]; then
                OUT_REPLY[${#OUT_REPLY[@]}]=KNAME
            fi
            if [[ $i == LABEL || $ARG == PARTLABEL ]]; then
                OUT_REPLY[${#OUT_REPLY[@]}]=LABEL
            fi
            if [[ $i == SIZE ]]; then
                OUT_REPLY[${#OUT_REPLY[@]}]=SIZE
            fi
            done
            unset IFS
            shift
            ;;
        /dev/*)
            DEV=${PARAM//\/dev\//}
            ROOT_DEV=$(echo $DEV | grep -o '[sv]d[a-z]')
            shift
            ;;
        -d|-*d|-*d*|-d*)
            NODEPS=true
            shift
            ;;

        *)
            shift
            ;;
    esac
    done
    # Build Reply
    while read -r device_line
    do
        resp=''
        for out_arg in ${OUT_REPLY[@]}; do
            resp="$resp$(echo $device_line | grep -o "${out_arg}=[A-Za-z0-9]*" | cut -d'=' -f2),"
        done
        [[ -n $resp ]] && resp=${resp::-1}
        echo $resp
        if [[ $NODEPS ]]; then
            return
        fi
    done < <(cat ${SHUNIT_TMPDIR}/dev/$ROOT_DEV | grep $DEV)

   }
    export -f lsblk

}

_setup_parted ()
{
  local arr=( $@ )

  cat > ${SHUNIT_TMPDIR}/parted <<EOF
Model: Virtio Block Device (virtblk)
Disk /dev/vda: 3221MB
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags: 

Number  Start   End     Size    File system  Name  Flags
EOF
  for i in `seq 1 ${arr[0]}`; do
    echo >> ${SHUNIT_TMPDIR}/parted " $i 1049kB  2000MB  ext4        ${arr[$i]}"
  done
  echo >> ${SHUNIT_TMPDIR}/parted ""

  function parted () {
    cat ${SHUNIT_TMPDIR}/parted
  }
}

_setup_parted_random ()
{ local arr=( $@ )

  cat > ${SHUNIT_TMPDIR}/parted <<EOF
Disk /dev/sda: 232.9 GiB, 250059350016 bytes, 488397168 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 4096 bytes
I/O size (minimum/optimal): 4096 bytes / 4096 bytes
Disklabel type: dos
Disk identifier: 0x75f2358b

Device     Boot  Start       End   Sectors   Size Id Type
EOF
  for i,j in `seq 1 ${arr[0]}` {1 2 3 5}; do
    echo >> ${SHUNIT_TMPDIR}/parted " $j  *      2048    499711    497664   243M 83 ${arr[$i]}"
  done
  echo >> ${SHUNIT_TMPDIR}/parted ""

  function parted () {
    cat ${SHUNIT_TMPDIR}/parted
  }
}
_setup_e2label ()
{
  local arr=( $@ )
  mkdir -p ${SHUNIT_TMPDIR}/dev
  for i in `seq 0 $(expr ${#arr[@]} - 1)`; do
    echo ${arr[$i]} > ${SHUNIT_TMPDIR}/dev/sda$(expr $i + 1)
  done

  function e2label () {
    cat ${SHUNIT_TMPDIR}$1
  }
}

_clean_up ()
{
  unset -f parted
  unset -f e2label
  unset -f lsblk
}
