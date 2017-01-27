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
  USERNAME=$(who am i | awk '{print $1}')
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
  pkgnames="sudo vim mc screen git gcc gcc-doc gdb gdb-doc logapp make make-doc qemu dosfstools bochs"
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
  echo "$FILES" | while read fcmd ffile fowner fmode; do
    fcnt=$(get_text $ffile)
    case $fcmd in
      cp)
        if ! diff -qbB <(echo "$fcnt") "$ffile" >/dev/null 2>&1; then
          echo "$ffile"
          if [ -e "$ffile" ] && [ "$ARCHIVE" = "a" ]; then
            mv "$ffile" "$ffile~"
          fi
          echo "$fcnt" >"$ffile"
          chown "$fowner" "$ffile"
          chmod "$fmode" "$ffile"
        fi
        ;;
      tail)
        if ! diff -qb <(diff --unchanged-group-format='%=' --old-group-format='' --new-group-format='' --changed-group-format='' "$ffile" <(echo "$fcnt") 2>/dev/null) <(echo "$fcnt") >/dev/null 2>&1; then
          echo "$ffile"
          if [ -e "$ffile" ] && [ "$ARCHIVE" = "a" ]; then
            cp -p "$ffile" "$ffile~"
          fi
          echo "$fcnt" >>"$ffile"
          chown "$fowner" "$ffile"
          chmod "$fmode" "$ffile"
        fi
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
      echo "tail /etc/sudoers.d/$USERNAME root:root 440
cp $HOMEDIR/.logapprc $USERNAME:$USERNAME 644
cp $HOMEDIR/.config/mc/ini $USERNAME:$USERNAME 644
cp /usr/local/bin/screen.sh root:staff 755
cp $HOMEDIR/.screenrc $USERNAME:$USERNAME 644
cp /etc/screenrc root:root 644
tail $HOMEDIR/.bashrc $USERNAME:$USERNAME 644
tail /etc/sudoers root:root 440"
      ;;
    /etc/sudoers.d/$USERNAME)
      echo "$USERNAME	$HOSTNAME = NOPASSWD: $HOMEDIR/$INSTALLDIR/arch/i386/emu/mkdisk.sh"
      ;;
    $HOMEDIR/.logapprc)
      echo "logfile="
      ;;
    $HOMEDIR/.config/mc/ini)
      echo '[Midnight-Commander]
verbose=1
pause_after_run=2
shell_patterns=1
auto_save_setup=1
preallocate_space=0
auto_menu=0
use_internal_view=1
use_internal_edit=1
clear_before_exec=1
confirm_delete=1
confirm_overwrite=1
confirm_execute=0
confirm_history_cleanup=1
confirm_exit=1
confirm_directory_hotlist_delete=1
safe_delete=0
mouse_repeat_rate=100
double_click_speed=250
use_8th_bit_as_meta=0
confirm_view_dir=0
mouse_move_pages_viewer=1
mouse_close_dialog=0
fast_refresh=0
drop_menus=0
wrap_mode=1
old_esc_mode=0
old_esc_mode_timeout=1000000
cd_symlinks=1
show_all_if_ambiguous=0
max_dirt_limit=10
use_file_to_guess_type=1
alternate_plus_minus=0
only_leading_plus_minus=1
show_output_starts_shell=0
xtree_mode=0
num_history_items_recorded=60
file_op_compute_totals=1
classic_progressbar=1
vfs_timeout=60
ftpfs_directory_timeout=900
use_netrc=1
ftpfs_retry_seconds=30
ftpfs_always_use_proxy=0
ftpfs_use_passive_connections=1
ftpfs_use_passive_connections_over_proxy=0
ftpfs_use_unix_list_options=1
ftpfs_first_cd_then_ls=1
fish_directory_timeout=900
editor_tab_spacing=8
editor_word_wrap_line_length=72
editor_fill_tabs_with_spaces=0
editor_return_does_auto_indent=1
editor_backspace_through_tabs=0
editor_fake_half_tabs=0
editor_option_save_mode=0
editor_option_save_position=1
editor_option_auto_para_formatting=0
editor_option_typewriter_wrap=0
editor_edit_confirm_save=1
editor_syntax_highlighting=1
editor_persistent_selections=1
editor_cursor_beyond_eol=0
editor_visible_tabs=1
editor_visible_spaces=1
editor_line_state=0
editor_simple_statusbar=0
editor_check_new_line=0
editor_show_right_margin=0
editor_group_undo=0
nice_rotating_dash=1
mcview_remember_file_position=0
auto_fill_mkdir_name=1
copymove_persistent_attr=1
select_flags=6
editor_backup_extension=~
mcview_eof=
ignore_ftp_chattr_errors=true
keymap=mc.keymap
skin=default

filepos_max_saved_entries=1024

editor_wordcompletion_collect_entire_file=false

editor_drop_selection_on_copy=1
editor_cursor_after_inserted_block=0
editor_ask_filename_before_edit=0
editor_filesize_threshold=64M
editor_stop_format_chars=-+*\\,.;:&>

[Layout]
message_visible=0
keybar_visible=1
xterm_title=1
output_lines=0
command_prompt=1
menubar_visible=0
free_space=1
horizontal_split=0
vertical_equal=1
left_panel_size=56
horizontal_equal=1
top_panel_size=1

[Misc]
timeformat_recent=%b %e %H:%M
timeformat_old=%b %e  %Y
ftp_proxy_host=gate
ftpfs_password=anonymous@
display_codepage=UTF-8
source_codepage=Other_8_bit
autodetect_codeset=
clipboard_store=
clipboard_paste=

spell_language=en

[Colors]
#base_color=
#base_color=lightgray,green:normal=green,default:selected=white,gray:marked=yellow,default:markselect=yellow,gray:directory=blue,default:executable=brightgreen,default:link=cyan,default:device=brightmagenta,default:special=lightgray,default:errors=red,default:reverse=green,default:gauge=green,default:input=white,gray:dnormal=green,gray:dfocus=brightgreen,gray:dhotnormal=cyan,gray:dhotfocus=brightcyan,gray:menu=green,default:menuhot=cyan,default:menusel=green,gray:menuhotsel=cyan,default:helpnormal=cyan,default:editnormal=green,default:editbold=blue,default:editmarked=gray,blue:editwhitespace=gray,default:stalelink=red,default
base_color=lightgray,blue:normal=blue,default:selected=white,brightblue:marked=yellow,default:markselect=yellow,gray:directory=brightblue,default:executable=brightgreen,default:link=cyan,default:device=brightmagenta,default:special=lightgray,default:errors=red,default:reverse=green,default:gauge=green,default:input=white,gray:dnormal=green,gray:dfocus=brightgreen,gray:dhotnormal=cyan,gray:dhotfocus=brightcyan,gray:menu=green,default:menuhot=cyan,default:menusel=green,gray:menuhotsel=cyan,default:helpnormal=cyan,default:editnormal=green,default:editbold=blue,default:editmarked=gray,blue:editwhitespace=gray,default:stalelink=red,default
xterm=
color_terminals=

linux=

Eterm=

screen=

screen.linux=

[Panels]
show_mini_info=true
kilobyte_si=false
mix_all_files=false
show_backups=true
show_dot_files=true
fast_reload=false
fast_reload_msg_shown=false
mark_moves_down=true
reverse_files_only=true
auto_save_setup_panels=false
navigate_with_arrows=false
panel_scroll_pages=true
mouse_move_pages=true
filetype_mode=true
permission_mode=false
torben_fj_mode=false
quick_search_mode=2

simple_swap=false

select_flags=6

[HotlistConfig]
expanded_view_of_groups=0

[Panelize]
Find *.orig after patching=find . -name \\*.orig -print
Find SUID and SGID programs=find . \\( \\( -perm -04000 -a -perm +011 \\) -o \\( -perm -02000 -a -perm +01 \\) \\) -print
Find rejects after patching=find . -name \\*.rej -print
Modified git files=git ls-files --modified'
      ;;
    /usr/local/bin/screen.sh)
      echo '#!/bin/sh

SLEEP=10
BATTERIES="BAT0 MBAT"
BATTPATH=/sys/class/power_supply

while true; do
  TEMP=""

  if [ -e /sys/devices/system/cpu/cpu0/cpufreq/ ]; then
    TEMP="\005{g}$(echo "scale=2; $(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq | sort -nr | head -n 1) / 1000000" | /usr/bin/bc 2>&1) "
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
      echo "chdir \"$INSTALLDIR\"
screen mc \"$HOMEDIR/$INSTALLDIR\" \"$HOMEDIR/$INSTALLDIR/arch/i386/loader/\"
screen bash"
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
