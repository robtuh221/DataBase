#настройка разрешения на astra

xrandr
cvt 1920 1080 60
# 1920x1080 59.96 Hz (CVT 2.07M9) hsync: 67.50 kHz; pclk: 173.00 MHz
# Modeline "1920x1080_60.00"  173.00  1920 2048 2248 2576  1080 1083 1088 1120 -hsync +vsync

# HDMI-1 выбрать устройство из списка команды xrandr
xrandr --newmode "1920x1080_60.00"  173.00  1920 2048 2248 2576  1080 1083 1088 1120 -hsync +vsync
xrandr --addmode HDMI-1 "1920x1080_60.00"
xrandr --output HDMI-1 --mode "1920x1080_60.00"
#############################################################################################################
visudo
astra ALL=(ALL) NOPASSWD: /usr/local/bin/razreshenie.sh

nano /etc/systemd/system/razreshenie.service
[Unit]
Description=Configure razreshenie ekrana
After=network.target

[Service]
User=astra
ExecStart=/usr/bin/sudo -u astra /usr/local/bin/razreshenie.sh
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target


nano /usr/local/bin/razreshenie.sh
#!/bin/bash
export DISPLAY=:0
xrandr
cvt 1920 1080 60
xrandr --newmode "1920x1080_60.00"  173.00  1920 2048 2248 2576  1080 1083 1088 1120 -hsync +vsync
xrandr --addmode DP-1 "1920x1080_60.00"
xrandr --output DP-1 --mode "1920x1080_60.00"

chmod 755 /usr/local/bin/razreshenie.sh
systemctl enable razreshenie.service
systemctl daemon-reload
systemctl restart razreshenie.service

