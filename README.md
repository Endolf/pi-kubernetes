# pi-kubernetes
Setup scripts for kubernetes running on a pi3 cluster

Flash script to download and burn an image.

Sets the hostname via the ```-n``` argument (mandatory).

If the ```-d``` argument is specified then no prompt for the device to burn to is made. This will also prepend ```/dev``` if needed and remove the partition number if specified.

If the ```-k``` argument is specified then SSH server is setup, this includes disabling login via password.

If the ```-s``` argument is specified then the ```-p``` argument is also needed. This will setup wifi.

e.g.
```
./flash.sh -n master -d mmcblk0 -k ~/.ssh/id_rsa.pub -s "MySSID" -p MyWifiPassword
```
