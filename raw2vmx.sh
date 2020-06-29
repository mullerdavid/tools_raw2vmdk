#!/bin/sh
# damuller@mol.hu

usage() { 
cat<<EOF >&2
Usage: `basename $0` [-g <geometry>] [-t <type>] [-d] <raw_image> [<vmdk>] [<vmx>]

Options:
  -g <geometry>    Disk geometry in format Cylinders,Heads,Sectors
  -t <type>        Adapter type, default is 'lsilogic', can be also 'ide', 'buslogic', 'legacyESX'
  -d               Don't generate snapshots
  <raw_image>      Input raw image file
  <vmdk>           Output vmdk file, stdout if missing
  <vmx>            Output vmx file, stderr if missing

Example: 
  `basename $0` -g 31130,255,63 -t ide image.raw image.vmdk

EOF
exit 1
}




https://www.vmware.com/support/ws5/doc/ws_learning_files_in_a_vm.html
http://cri.ch/linux/docs/sk0020.html
    
snapshot with vmware
https://www.vmware.com/support/developer/vix-api/vix112_vmrun_command.pdf
