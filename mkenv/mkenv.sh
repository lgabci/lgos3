#!/bin/bash
set -e

# git user name and git email address
GITUSER="lgabci"
GITEMAIL="gl12qw@gmail.com"
GITREPO="lgos3"

# set and check parameters
function set_and_check_params {
  ARCHIVE="$1"

  case "$ARCHIVE" in
    ""|a|arch)
      ARCHIVE=a
    ;;
    n|no)
      ARCHIVE=n
    ;;
    r|rm)
      ARCHIVE=r
    ;;
    *)
      ARCHIVE=h
    ;;
  esac

  # check parameters
  if [ $# -gt 1 ] || [ "$ARCHIVE" = "h" ]; then
    echo "$(basename $0) [archive]"
    echo "set up LGOS development environment on Debian systems"
    echo "arguments:"
    echo "	archive:	<empty>,a,arch	= copy modified config files to filename~"
    echo "			n,no		= don't create archive copy"
    echo "			r,rm		= remove archived config files (filename~)"
    echo "			h,help,--help	= print this help"
    exit
  fi

  # check root user
  if [ "$EUID" -ne 0 ]; then
    echo "Please run as root." >&2
    exit 1
  fi

  # check Debian distro
  if [ ! -e /etc/debian_version ]; then
    echo "This is not a Debian distro." >&2
    exit 1
  fi

  # get user name, home dir and install dir
  USERNAME=$SUDO_USER                             # caller of script
  USERNAME=${USERNAME:=$(logname)}
  USERNAME=${USERNAME:=$(who am i | awk '{print $1}')}
  if [ -z "$USERNAME" ]; then
    echo "Username not found." >&2
    exit 1
  fi

  HOMEDIR=$(awk -F : '($1 == "'"$USERNAME"'") {print $6}' /etc/passwd)
  if [ -z "$HOMEDIR" ]; then
    echo "Can not found user's home dir." >&2
    exit 1
  fi
  HOMEDIR="${HOMEDIR%/}"

  INSTALLDIR=$(readlink -m $(dirname $0)/..)
  INSTALLDIR="${INSTALLDIR#$HOMEDIR/}"
}

# install packages
function install_packages {
  # install packages
  pkgnames="sudo vim emacs-nox screen git gcc gdb make qemu dosfstools bochs"
  installedpkgs=$(dpkg -l $pkgnames 2>/dev/null | awk -F '[ :]+' '{if ($1 == "ii") {print($2)}}')
  pkgnames=$(echo "$pkgnames" | tr ' ' '\n' | grep -Fvx "$installedpkgs" | tr '\n' ' ')
  if [ -n "$pkgnames" ]; then
    echo "Installing packages: $pkgnames"
    apt-get -y install $pkgnames
  fi

  # set vi for default editor
  update-alternatives --set editor $(readlink -f $(which vi))
}

# set file contents
function set_files {
  FILES=$(get_text FILES)
  echo "$FILES" | while read fcmd ffile fowner dmode fmode; do
    fcnt=$(get_text $ffile)
    case $fcmd in
      cp)
        if ! diff -qbB <(echo "$fcnt") "$ffile" >/dev/null 2>&1; then
          echo "$ffile"
          if [ "$dmode" != - ]; then
            su -c "mkdir -m 755 -p $(dirname $ffile)" ${fowner%:*}
          fi
          if [ -e "$ffile" ] && [ "$ARCHIVE" = "a" ]; then
            mv "$ffile" "$ffile~"
          fi
          echo "$fcnt" >"$ffile"
          chown "$fowner" "$ffile"
          chmod "$fmode" "$ffile"
        fi
        ;;
      tail)
        if ! diff -qbB <(diff --unchanged-group-format='%=' --old-group-format='' --new-group-format='' --changed-group-format='' "$ffile" <(echo "$fcnt") 2>/dev/null) <(echo "$fcnt") >/dev/null 2>&1; then
          echo "$ffile"
          if [ "$dmode" != - ]; then
            su -c "mkdir -m 755 -p $(dirname $ffile)" ${fowner%:*}
          fi
          if [ -e "$ffile" ] && [ "$ARCHIVE" = "a" ]; then
            cp -p "$ffile" "$ffile~"
          fi
          echo "$fcnt" >>"$ffile"
          chown "$fowner" "$ffile"
          chmod "$fmode" "$ffile"
        fi
        ;;
      *)
        echo "Invalid command: $fcmd $ffile" >&2
        exit 1
        ;;
    esac
    if [ "$ARCHIVE" = "r" ]; then
      if [ -e "$ffile~" ]; then
        echo "rm $ffile~"
        rm -f "$ffile~"
      fi
    fi
  done
}

# set git options
function set_git {
  # Git directory
  cd $(dirname $0)/..

  # set git config variables
  while read var val; do
    gitvar=$(sudo -u $USERNAME git config --global --get "$var" || true)
    if [ "$gitvar" != "$val" ]; then
      echo "git config $var: \"$gitvar\" -> \"$val\""
      sudo -u "$USERNAME" git config --global "$var" "$val"
    fi
  done <<-EOF
	user.name $GITUSER
	user.email $GITEMAIL
	push.default simple
	EOF

  GITNAME=origin
  GITURL=git@github.com:$GITUSER/$GITREPO.git
  FETCHURL=$(git remote show -n "$GITNAME" | awk '{if (tolower($1 " " $2) == "fetch url:") {print $3}}')
  PUSHURL=$(git remote show -n "$GITNAME" | awk '{if (tolower($1 " " $2) == "push url:") {print $3}}')
  if [ "$GITURL" != "$FETCHURL" ] || [ "$GITURL" != "$PUSHURL" ]; then
    echo "Set Git URL to $GITURL"
    git remote set-url "$GITNAME" "$GITURL"
  fi
  cd - >/dev/null
}

# get text to write into files
# parameters:
#	file name
function get_text {
  case "$1" in
    FILES)
      echo "tail /etc/sudoers.d/$USERNAME root:root - 440
cp $HOMEDIR/.emacs.d/init.el $USERNAME:$USERNAME 755 644
cp /usr/local/bin/screen.sh root:staff - 755
cp $HOMEDIR/.screenrc $USERNAME:$USERNAME - 644
cp /etc/screenrc root:root - 644
tail $HOMEDIR/.bashrc $USERNAME:$USERNAME - 644
tail /etc/sudoers root:root - 440
cp $HOMEDIR/.vimrc $USERNAME:$USERNAME - 644"
      ;;
    /etc/sudoers.d/$USERNAME)
      echo "$USERNAME	$HOSTNAME = NOPASSWD: $HOMEDIR/$INSTALLDIR/arch/i386/emu/mkdisk.sh"
      ;;
    $HOMEDIR/.emacs.d/init.el)
      echo "(require 'saveplace)
(setq-default save-place t)

(setq column-number-mode t)"
      ;;
    /usr/local/bin/screen.sh)
      echo '#!/bin/sh

SLEEP=10
BATTERIES="BAT0 MBAT"
BATTPATH=/sys/class/power_supply

while true; do
  TEMP=""

  if [ -e /sys/devices/system/cpu/cpu0/cpufreq/ ]; then
    TEMP="\005{g}$(($(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq | sort -nr | head -n 1) / 1000)) "
  fi

  if [ -e /sys/class/thermal/thermal_zone0/ ]; then
    TEMP="$TEMP\005{B}$(($(cat /sys/class/thermal/thermal_zone*/temp | sort -nr | head -n 1) / 1000))\xc2\xb0C "
  fi

  for bat in $BATTERIES; do
    bp=$BATTPATH/$bat
    if [ -d $bp ]; then
      CHARGE_FULL=$({ [ -e $bp/energy_full ] && cat $bp/energy_full; } || { [ -e $bp/charge_full ] && cat $bp/charge_full; })
      CHARGE_NOW=$({ [ -e $bp/energy_now ] && cat $bp/energy_now; } || { [ -e $bp/charge_now ] && cat $bp/charge_now; })
      STATUS=$(cat /sys/class/power_supply/$bat/status)
      ALARM=$(cat /sys/class/power_supply/$bat/alarm)

      if [ -n "$CHARGE_NOW" ] && [ -n CHARGE_FULL ] && [ $CHARGE_FULL -gt 0 ]; then
        CAPACITY=$((CHARGE_NOW * 100 / CHARGE_FULL))
      else
        CAPACITY="?"
      fi

      case "$STATUS" in
        Discharging)
          if [ -n "$ALARM" ] && [ -n "$CHARGE_NOW" ] && [ $CHARGE_NOW -le $ALARM ]; then
            COLOR="\005{+b r}"
          else
            COLOR="\005{+b g}"
          fi
          ;;
        Charging)
          COLOR="\005{+b m}"
          ;;
        Full)
          COLOR="\005{+b G}"
          ;;
        *)
          COLOR="\005{+b y}"
          ;;
      esac

      TEMP="$TEMP$COLOR$CAPACITY% "
    fi
  done

  TEMP="$TEMP\005{-}"
  /bin/echo -e $TEMP || exit
  sleep $SLEEP
done'
      ;;
    $HOMEDIR/.screenrc)
      echo "chdir \"$INSTALLDIR\""
      ;;
    /etc/screenrc)
      echo "startup_message off
vbell off
altscreen on

backtick 1 0 0 /usr/local/bin/screen.sh

hardstatus alwayslastline
hardstatus string '%{= G}%{G}%H%= %{B}%-Lw%{+br}%n%f* %t%{-}%+LW %=%{c}%1\`%{g}%c'"
      ;;
    $HOMEDIR/.bashrc)
      echo '
# execute screen when connecting via SSH
if [ -n "$SSH_TTY" ] && [ "$SHLVL" = 1 ]; then
  SHLVL=$(($SHLVL + 1))
  export SHLVL
  exec screen -d -RR
fi'
      ;;
    /etc/sudoers)
      echo '#includedir /etc/sudoers.d'
      ;;
    $HOMEDIR/.vimrc)
      echo 'syntax on
if has("autocmd")
  autocmd BufReadPost *
    \ if line("'\''\"") > 1 && line("'\''\"") <= line("$") |
    \   exe "normal! g`\"" |
    \ endif
endif'
      ;;
    *)
      echo "File content not found: \"$1\"" >&2
      exit 1
  esac
}

# main function
function main {
  set_and_check_params $@
  install_packages
  set_files
  set_git
}

# call main function
main $@

