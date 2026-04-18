# SayIP-Shutdown-Reboot-2026
## New Sayip Shutdown Reboot script for 2026 ##
### Compatable with Debian Bookworn and Trixie ###

This a new and improved SayIP Script for Debain Bookworm and Debian Trixie for AllStarLink Version 3. This script set will tell you your local IP upon reboot. It will also tell you your Public IP address upon demand, as well as give you the ability to Reboot or Shutdown (a.k.a. Halt) your ASL3 Node. 

*A1 = Say Local IP Address<br>
*A3 = Say Public IP Address<br>
*B1 = Shutdown System (a.k.a. Halt)<br>
*B3 = Reboot System<br>

⚠️⚠️⚠️ Be aware that if your node is a Raspberry Pi then when you shutdown your system you will have to physically power cycle the power line to it to get it to start again.⚠️⚠️⚠️

Use this installer file
```
wget https://raw.githubusercontent.com/KD5FMU/Sayip-shutdown-reboot-2026/refs/heads/main/asl3_sayip_installer_new.sh
```
Once you get the installer download then you will need to make it executablwe
```
sudo chmod +x asl3_sayip_installer_new.sh
```
Then you can run the installer with your node number behind it
```
sudo ./asl3_sayip_installer_new.sh YOUR_NODE_NUMBER
```

Then the installer will get you going.

Have fun with it.

73 and "Ham On Y'all!"

