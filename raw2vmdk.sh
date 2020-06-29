#!/bin/sh
# damuller@mol.hu

usage() { 
cat<<EOF >&2
Usage: `basename $0` [-g <geometry>] [-t <type>] <raw_image> [<vmdk>]

Options:
  -g <geometry>    Disk geometry in format Cylinders,Heads,Sectors
  -t <type>        Adapter type, default is 'lsilogic', can be also 'ide', 'buslogic', 'legacyESX'
  <raw_image>      Input raw image file
  <vmdk>           Output file, stdout if missing

Example: 
  `basename $0` -g 31130,255,63 -t ide image.raw image.vmdk

EOF
exit 1
}

usage_error() { 
echo "Error: $1\n" >&2
usage
}

error() { 
echo "Error: $1" >&2
exit 1
}

warning() { 
echo "Warning: $1" >&2
}

DDB_GEOMETRY_CYLINDERS=""
DDB_GEOMETRY_HEADS="255"
DDB_GEOMETRY_SECTORS="63"
DDB_ADAPTERTYPE="lsilogic"
OPT_IF=""
OPT_OF=""

while getopts ":g:t:" opt; do
  case $opt in
    g)
      CHS=$(printf "%s\n" "$OPTARG" | awk '/^[0-9]+,[0-9]+,[0-9]+$/')
      if [ -z "$CHS" ]; then
        usage_error "Invalid Disk geometry!"
      else
        OLDIFS=$IFS
        IFS=','
        read -r DDB_GEOMETRY_CYLINDERS DDB_GEOMETRY_HEADS DDB_GEOMETRY_SECTORS <<EOF
$CHS
EOF
        IFS=$OLDIFS
      fi
      ;;
    t)
      TYPE=$(printf "%s\n" "$OPTARG" | awk '/^ide|buslogic|lsilogic|legacyESX$/')
      if [ -z "$TYPE" ]; then
        usage_error "Invalid Adapter type!"
      else
        DDB_ADAPTERTYPE=$TYPE
      fi
      ;;
    \?)
      usage
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done
shift $(($OPTIND -1))
if [ -z "$1" ]; then usage_error "Missing input file parameter!"; fi
if [ ! -e "$1" ]; then error "Input file not found!"; fi
OPT_IF=$1
OPT_OF=$2


SIZEBYTES=""
if [ -f "$OPT_IF" ]; then
  SIZEBYTES=$(stat -c%s "$OPT_IF")
elif [ -b "$OPT_IF" ]; then
  SIZEBYTES=0
  SIZEBYTES=$(lsblk --noheadings -bido SIZE "$OPT_IF")
fi

if [ -z "$SIZEBYTES" ]; then error "Cannot determine file size!"; fi
SIZESECTORS=$( expr $SIZEBYTES / 512 ) # "a Sector is 512 bytes" - VMware Virtual Disk Format 1.1
CALC_GEOMETRY_CYLINDERS=$( expr $SIZESECTORS / $DDB_GEOMETRY_HEADS / $DDB_GEOMETRY_SECTORS )

if [ ! -z "$DDB_GEOMETRY_CYLINDERS" ]; then 
  if [ "$DDB_GEOMETRY_CYLINDERS" -ne "$CALC_GEOMETRY_CYLINDERS" ]; then 
    warning "Calculated cylinders mismatch! Using calculated: $CALC_GEOMETRY_CYLINDERS."
  fi
fi
DDB_GEOMETRY_CYLINDERS=$CALC_GEOMETRY_CYLINDERS

DDB_LONGCONTENTIDPRE=$( dd if=/dev/urandom bs=12 count=1 2> /dev/null | hexdump -ve '1/1 "%.2x"')
DDB_UUID=$( dd if=/dev/urandom bs=16 count=1 2> /dev/null | hexdump -ve '1/1 "%.2x "' | xargs)


VMDK_FILE=$(
cat<<EOF
# Disk DescriptorFile
version=1
encoding="UTF-8"
CID=fffffffe
parentCID=ffffffff
isNativeSnapshot="no"
createType="monolithicFlat"

# Extent description
RW $SIZESECTORS FLAT "$OPT_IF" 0

# The Disk Data Base 
#DDB

ddb.virtualHWVersion = "7"
ddb.adapterType = "$DDB_ADAPTERTYPE"
ddb.geometry.cylinders = "$DDB_GEOMETRY_CYLINDERS"
ddb.geometry.heads = "$DDB_GEOMETRY_HEADS"
ddb.geometry.sectors = "$DDB_GEOMETRY_SECTORS"
ddb.longContentID = "${DDB_LONGCONTENTIDPRE}fffffffe"
ddb.uuid = "$DDB_UUID"

EOF
)

if [ -z "$OPT_OF" ]; then
  echo "$VMDK_FILE"
else
  echo "$VMDK_FILE" > $OPT_OF 
fi
