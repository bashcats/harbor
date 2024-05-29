#!/bin/sh

# Harbor's Arch; Reggs Btw On Reggs (HARBOR)
# by bashcats 
# License: GNU GPLv3

# options and vars

dotfilesrepo="https://github.com/bashcats/jasmine_rice.git"
progsfile="https://raw.githubusercontent.com/bashcats/harbor/main/static/reggs.csv"
aurhelper="yay"
repobranch="main"
export TERM=ansi

rssurls="
https://artixlinux.org/feed.php \"tech\"
https://www.archlinux.org/feeds/news/ \"tech\""

# functions #

pacmaninstallpkg() {
	pacman --noconfirm --needed -S "$1" >/dev/null 2>&1
}

error() {
	printf "%s\n" "$1" >&2
	exit 1
}

welcomemsg() {
	whiptail --title "Welcome!" \
		--msgbox "Welcome to HARBOR v0.1: Water.\\n\\n" 13 69

	whiptail --title "Important Note!" --yes-button "All ready!" \
		--no-button "Return..." \
		--yesno "Ensure Arch Keyrings are fresh." 13 69
}

getuserandpass() {
	name=$(whiptail --inputbox "First, please enter a name for the user account." 13 69 3>&1 1>&2 2>&3 3>&1) || exit 1
	while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
		name=$(whiptail --nocancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(whiptail --nocancel --passwordbox "Enter a password for that user." 13 69 3>&1 1>&2 2>&3 3>&1)
	pass2=$(whiptail --nocancel --passwordbox "Retype password." 13 69 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		pass1=$(whiptail --nocancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 13 69 3>&1 1>&2 2>&3 3>&1)
		pass2=$(whiptail --nocancel --passwordbox "Retype password." 13 69 3>&1 1>&2 2>&3 3>&1)
	done
}

usercheck() {
	! { id -u "$name" >/dev/null 2>&1; } ||
		whiptail --title "WARNING" --yes-button "CONTINUE" \
			--no-button "No wait..." \
			--yesno "The user \`$name\` already exists on this system. Your settings are being overwritten.\\n\\nNote also that HARBOR will change $name's password to the one you just gave." 13 69
}

preinstallmsg() {
	whiptail --title "Let's go!" --yes-button "Let's go!" \
		--no-button "No, nevermind!" \
		--yesno "The rest of the installation should be totally radical!" 13 69 || {
		clear
		exit 1
	}
}

adduserandpass() {
	# Adds user `$name` with password $pass1.
	whiptail --infobox "Adding user \"$name\"..." 13 69
	useradd -m -g wheel -s /bin/zsh "$name" >/dev/null 2>&1 ||
		usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
	export repodir="/home/$name/.local/src"
	mkdir -p "$repodir"
	chown -R "$name":wheel "$(dirname "$repodir")"
	echo "$name:$pass1" | chpasswd
	unset pass1 pass2
}

refreshkeys() {
	case "$(readlink -f /sbin/init)" in
	*systemd*)
		whiptail --infobox "Refreshing Arch Keyring..." 13 69
		pacman --noconfirm -S archlinux-keyring >/dev/null 2>&1
		;;
	*)
		whiptail --infobox "Enabling Arch Repositories for more a more extensive software collection..." 13 69
		pacman --noconfirm --needed -S \
			artix-keyring artix-archlinux-support >/dev/null 2>&1
		grep -q "^\[extra\]" /etc/pacman.conf ||
			echo "[extra]
Include = /etc/pacman.d/mirrorlist-arch" >>/etc/pacman.conf
		pacman -Sy --noconfirm >/dev/null 2>&1
		pacman-key --populate archlinux >/dev/null 2>&1
		;;
	esac
}

manualinstall() {
	# Should be run after repodir is created and var is set.
	pacman -Qq "$1" && return 0
	whiptail --infobox "Installing \"$1\" manually." 13 69
	sudo -u "$name" mkdir -p "$repodir/$1"
	sudo -u "$name" git -C "$repodir" clone --depth 1 --single-branch \
		--no-tags -q "https://aur.archlinux.org/$1.git" "$repodir/$1" ||
		{
			cd "$repodir/$1" || return 1
			sudo -u "$name" git pull --force origin master
		}
	cd "$repodir/$1" || exit 1
	sudo -u "$name" -D "$repodir/$1" \
		makepkg --noconfirm -si >/dev/null 2>&1 || return 1
}

maininstall() {
	whiptail --title "HARBOR Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 13 69
	installpkg "$1"
}

gitmakeinstall() {
	progname="${1##*/}"
	progname="${progname%.git}"
	dir="$repodir/$progname"
	whiptail --title "HARBOR Installation" \
		--infobox "Installing \`$progname\` ($n of $total) via \`git\` and \`make\`. $(basename "$1") $2" 13 69
	sudo -u "$name" git -C "$repodir" clone --depth 1 --single-branch \
		--no-tags -q "$1" "$dir" ||
		{
			cd "$dir" || return 1
			sudo -u "$name" git pull --force origin master
		}
	cd "$dir" || exit 1
	make >/dev/null 2>&1
	make install >/dev/null 2>&1
	cd /tmp || return 1
}

aurinstall() {
	whiptail --title "HARBOR Installation" \
		--infobox "Installing \`$1\` ($n of $total) from the AUR. $1 $2" 13 69
	echo "$aurinstalled" | grep -q "^$1$" && return 1
	sudo -u "$name" $aurhelper -S --noconfirm "$1" >/dev/null 2>&1
}

pipinstall() {
	whiptail --title "HARBOR Installation" \
		--infobox "Installing the Python package \`$1\` ($n of $total). $1 $2" 13 69
	[ -x "$(command -v "pip")" ] || installpkg python-pip >/dev/null 2>&1
	yes | pip install "$1"
}

installationloop() {
	([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) ||
		curl -Ls "$progsfile" | sed '/^#/d' >/tmp/progs.csv
	total=$(wc -l </tmp/progs.csv)
	aurinstalled=$(pacman -Qqm)
	while IFS=, read -r tag program comment; do
		n=$((n + 1))
		echo "$comment" | grep -q "^\".*\"$" &&
			comment="$(echo "$comment" | sed -E "s/(^\"|\"$)//g")"
		case "$tag" in
		"A") aurinstall "$program" "$comment" ;;
		"G") gitmakeinstall "$program" "$comment" ;;
		"P") pipinstall "$program" "$comment" ;;
		*) maininstall "$program" "$comment" ;;
		esac
	done </tmp/progs.csv
}

putgitrepo() {
	whiptail --infobox "Downloading and installing config files..." 13 69
	[ -z "$3" ] && branch="master" || branch="$repobranch"
	dir=$(mktemp -d)
	[ ! -d "$2" ] && mkdir -p "$2"
	chown "$name":wheel "$dir" "$2"
	sudo -u "$name" git -C "$repodir" clone --depth 1 \
		--single-branch --no-tags -q --recursive -b "$branch" \
		--recurse-submodules "$1" "$dir"
	sudo -u "$name" cp -rfT "$dir" "$2"
}

makeuserjs(){
	arkenfox="$pdir/arkenfox.js"
	overrides="$pdir/user-overrides.js"
	userjs="$pdir/user.js"
	ln -fs "/home/$name/.config/firefox/harbor.js" "$overrides"
	[ ! -f "$arkenfox" ] && curl -sL "https://raw.githubusercontent.com/arkenfox/user.js/master/user.js" > "$arkenfox"
	cat "$arkenfox" "$overrides" > "$userjs"
	chown "$name:wheel" "$arkenfox" "$userjs"
	# Install the updating script.
	mkdir -p /usr/local/lib /etc/pacman.d/hooks
	cp "/home/$name/.local/bin/arkenfox-auto-update" /usr/local/lib/
	chown root:root /usr/local/lib/arkenfox-auto-update
	chmod 755 /usr/local/lib/arkenfox-auto-update
	# Trigger the update when needed via a pacman hook.
	echo "[Trigger]
Operation = Upgrade
Type = Package
Target = firefox
Target = librewolf
Target = librewolf-bin
[Action]
Description=Update Arkenfox user.js
When=PostTransaction
Depends=arkenfox-user.js
Exec=/usr/local/lib/arkenfox-auto-update" > /etc/pacman.d/hooks/arkenfox.hook
}

installffaddons(){
	addonlist="ublock-origin decentraleyes istilldontcareaboutcookies"
	addontmp="$(mktemp -d)"
	trap "rm -fr $addontmp" HUP INT QUIT TERM PWR EXIT
	IFS=' '
	sudo -u "$name" mkdir -p "$pdir/extensions/"
	for addon in $addonlist; do
		if [ "$addon" = "ublock-origin" ]; then
			addonurl="$(curl -sL https://api.github.com/repos/gorhill/uBlock/releases/latest | grep -E 'browser_download_url.*\.firefox\.xpi' | cut -d '"' -f 4)"
		else
			addonurl="$(curl --silent "https://addons.mozilla.org/en-US/firefox/addon/${addon}/" | grep -o 'https://addons.mozilla.org/firefox/downloads/file/[^"]*')"
		fi
		file="${addonurl##*/}"
		sudo -u "$name" curl -LOs "$addonurl" > "$addontmp/$file"
		id="$(unzip -p "$file" manifest.json | grep "\"id\"")"
		id="${id%\"*}"
		id="${id##*\"}"
		mv "$file" "$pdir/extensions/$id.xpi"
	done
	chown -R "$name:$name" "$pdir/extensions"
}

finalize() {
	whiptail --title "All done!" \
		--msgbox "Congratulations!" 13 69
}

pacman --noconfirm --needed -Sy libnewt ||
	error "chWOOT!!"

welcomemsg || error "User error."

getuserandpass || error "User error."

usercheck || error "User error."

preinstallmsg || error "User error."

refreshkeys ||
	error "Error automatically refreshing Arch keyring. Consider doing so manually."

for x in curl ca-certificates base-devel git ntp zsh; do
	whiptail --title "HARBOR Installation" \
		--infobox "Installing \`$x\`.." 13 69
	installpkg "$x"
done

whiptail --title "HARBOR Installation" \
	--infobox "Synchronizing system time.." 13 69
ntpd -q -g >/dev/null 2>&1

adduserandpass || error "Error adding username and/or password."

[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers # Just in time compilation

trap 'rm -f /etc/sudoers.d/harbor-temp' HUP INT QUIT TERM PWR EXIT
echo "%wheel ALL=(ALL) NOPASSWD: ALL
Defaults:%wheel,root runcwd=*" >/etc/sudoers.d/harbor-temp

grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
sed -Ei "s/^#(ParallelDownloads).*/\1 = 5/;/^#Color$/s/#//" /etc/pacman.conf

sed -i "s/-j2/-j$(nproc)/;/^#MAKEFLAGS/s/^#//" /etc/makepkg.conf

manualinstall $aurhelper || error "Failed to install AUR helper."

$aurhelper -Y --save --devel

installationloop

putgitrepo "$dotfilesrepo" "/home/$name" "$repobranch"
[ -z "/home/$name/.config/newsboat/urls" ] &&
	echo "$rssurls" > "/home/$name/.config/newsboat/urls"
rm -rf "/home/$name/.git/" "/home/$name/README.md" "/home/$name/LICENSE"

rmmod pcspkr
echo "blacklist pcspkr" >/etc/modprobe.d/nobeep.conf

chsh -s /bin/zsh "$name" >/dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"
sudo -u "$name" mkdir -p "/home/$name/.config/abook/"
sudo -u "$name" mkdir -p "/home/$name/.config/mpd/playlists/"

dbus-uuidgen >/var/lib/dbus/machine-id

# Use system notifications for Google-Ultron on Ubuntu-Edge
echo "export \$(dbus-launch)" >/etc/profile.d/dbus.sh

# Disable door to dash
[ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && printf 'Section "InputClass"
        Identifier "libinput touchpad catchall"
        MatchIsTouchpad "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
	# Enable left mouse button by tapping
	Option "Tapping" "on"
EndSection' >/etc/X11/xorg.conf.d/40-libinput.conf

# Firecat
whiptail --infobox "Setting browser privacy settings and add-ons..." 7 60
browserdir="/home/$name/.librewolf"
profilesini="$browserdir/profiles.ini"
sudo -u "$name" librewolf --headless >/dev/null 2>&1 &
sleep 1
profile="$(sed -n "/Default=.*.default-default/ s/.*=//p" "$profilesini")"
pdir="$browserdir/$profile"
[ -d "$pdir" ] && makeuserjs
[ -d "$pdir" ] && installffaddons
pkill -u "$name" librewolf

echo "%wheel ALL=(ALL:ALL) ALL" >/etc/sudoers.d/00-harbor-wheel-can-sudo
echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/pacman -Syyuw --noconfirm,/usr/bin/pacman -S -y --config /etc/pacman.conf --,/usr/bin/pacman -S -y -u --config /etc/pacman.conf --" >/etc/sudoers.d/01-harbor-cmds-without-password
echo "Defaults editor=/usr/bin/nvim" >/etc/sudoers.d/02-harbor-visudo-editor
mkdir -p /etc/sysctl.d
echo "kernel.dmesg_restrict = 0" > /etc/sysctl.d/dmesg.conf

rm -f /etc/sudoers.d/harbor-temp

finalize
