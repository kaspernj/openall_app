#!/bin/sh

rm -rf /home/kaspernj/Dev/rhodes-projects/OpenAllApp/app/Knj
cp -r /home/kaspernj/Dev/Ruby/knjrbfw/lib/knj /home/kaspernj/Dev/rhodes-projects/OpenAllApp/app/Knj
rm -rf /home/kaspernj/Dev/rhodes-projects/OpenAllApp/app/Knj/jruby
rm -rf /home/kaspernj/Dev/rhodes-projects/OpenAllApp/app/Knj/php_parser
rm -rf /home/kaspernj/Dev/rhodes-projects/OpenAllApp/app/Knj/scripts
rm -rf /home/kaspernj/Dev/rhodes-projects/OpenAllApp/app/Knj/sshrobot
rm -rf /home/kaspernj/Dev/rhodes-projects/OpenAllApp/app/Knj/tests
rm -rf /home/kaspernj/Dev/rhodes-projects/OpenAllApp/app/Knj/webscripts
rm -rf /home/kaspernj/Dev/rhodes-projects/OpenAllApp/app/Knj/erb
rm -rf /home/kaspernj/Dev/rhodes-projects/OpenAllApp/app/Knj/fs
rm -rf /home/kaspernj/Dev/rhodes-projects/OpenAllApp/app/Knj/includes
rm -rf /home/kaspernj/Dev/rhodes-projects/OpenAllApp/app/Knj/ironruby-gtk2
rm -rf /home/kaspernj/Dev/rhodes-projects/OpenAllApp/app/Knj/jruby-gtk2
rm -rf /home/kaspernj/Dev/rhodes-projects/OpenAllApp/app/Knj/maemo

rm -rf /home/kaspernj/Dev/rhodes-projects/OpenAllApp/app/openall_time_applet
cp -r /home/kaspernj/Dev/Ruby/openall_time_applet /home/kaspernj/Dev/rhodes-projects/OpenAllApp/app/openall_time_applet
rm -rf /home/kaspernj/Dev/rhodes-projects/OpenAllApp/app/openall_time_applet/.git
rm -rf /home/kaspernj/Dev/rhodes-projects/OpenAllApp/app/openall_time_applet/bin
rm -rf /home/kaspernj/Dev/rhodes-projects/OpenAllApp/app/openall_time_applet/gui
rm -rf /home/kaspernj/Dev/rhodes-projects/OpenAllApp/app/openall_time_applet/glade

rm -rf /home/kaspernj/Dev/rhodes-projects/OpenAllApp/app/wref
cp -r /home/kaspernj/Dev/Ruby/wref/lib /home/kaspernj/Dev/rhodes-projects/OpenAllApp/app/wref

rm -rf /home/kaspernj/Dev/rhodes-projects/OpenAllApp/app/tsafe
cp -r /home/kaspernj/Dev/Ruby/tsafe/lib /home/kaspernj/Dev/rhodes-projects/OpenAllApp/app/tsafe