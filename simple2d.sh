#!/bin/bash

# ------------------------------------------------------------------------------
# The Simple 2D Command-Line Utility
# 
# This script can:
#  - Install Simple 2D on OS X, Linux, and the Raspberry Pi (Raspbian)
#  - Update Simple 2D in place
#  - Provide Simple 2D libraries for compiling with applications
#  - Check for issues with Simple 2D and SDL
# 
# Run from the web using:
#   bash <(curl -fsSL http://script_url_here)
# or
#   bash <(wget -qO - http://script_url_here)
# ------------------------------------------------------------------------------

# Set Constants ################################################################

VERSION='0.1.0'
VERSION_URL='https://raw.githubusercontent.com/simple2d/simple2d/master/VERSION'

# Colors
BOLD='\033[1;39m'
BLUE='\033[1;34m'
RED='\033[1;31m'
INFO='\033[4;36m'    # cyan underline
WARN='\033[4;33m'    # yellow underline
ERROR='\033[4;31m'   # red underline
SUCCESS='\033[1;32m' # green bold
NORMAL='\033[0m'     # reset

# Set Variables ################################################################

platform='unknown'
platform_display='unknown'

install_edge=false

ret=''  # a return value used by some functions

# Helper Functions #############################################################

# Prompts to continue, or exits
# params:
#   $1  String  Message before y/n prompt
prompt_to_continue() {
  read -p "  $1 (y/n) " ans
  if [[ $ans != "y" ]]; then
    echo -e "\nQuitting...\n"
    exit
  fi
  echo
}

# Prints the task in progress
# params:
#   $1  String  Name of task
#   $2  String  Optional white space, e.g. "\n\n"
print_task() {
  printf "${BLUE}==>${BOLD} $1...${NORMAL}$2"
}

# Checks if a library is installed
# params:
#   $1  String  Name of the library, e.g. SDL2, without the "-l"
have_lib?() {
  print_task "Checking for $1"
  
  if $(ld -o /dev/null -l$1 2>&1 | grep -qE '(library not found|ld: cannot find)'); then
    echo " no"
    return 1
  else
    echo " yes"
    return 0
  fi
}

# Gets the text from a remote resource
# params:
#   $1  String  URL of the resource
get_remote_str() {
  # TODO: If no network, then exit(1)
  if which curl > /dev/null; then
    ret=$(curl -fsSL $1)
  else
    ret=$(wget -qO - $1)
  fi
}

# Compares version numbers in the form `#.#.#`
# Adapted from:
#  stackoverflow.com/questions/4023830/bash-how-compare-two-strings-in-version-format
# params:
#   $1  String  First version number to compare
#   $2  String  Second version number to compare
# returns:
#   0  If $1 is equal to $2
#   1  If $1 is newer than $2
#   2  If $1 is older than $2
compare_versions() {
  if [[ $1 == $2 ]]
    then
    return 0
  fi
  local IFS=.
  local i ver1=($1) ver2=($2)
  # fill empty fields in ver1 with zeros
  for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
  do
    ver1[i]=0
  done
  for ((i=0; i<${#ver1[@]}; i++))
  do
    if [[ -z ${ver2[i]} ]]
      then
      # fill empty fields in ver2 with zeros
      ver2[i]=0
    fi
    if ((10#${ver1[i]} > 10#${ver2[i]}))
      then
      return 1
    fi
    if ((10#${ver1[i]} < 10#${ver2[i]}))
      then
      return 2
    fi
  done
  return 0
}

# Starts the timer
start_timer() {
  START_TIME=$SECONDS
}

# Ends the timer and prints the time elapsed since `start_timer()`
end_timer() {
  ELAPSED_TIME=$(($SECONDS - $START_TIME))
  echo -e "${BOLD}Finished in $(($ELAPSED_TIME/60/60)) hr,"\
          "$(($ELAPSED_TIME/60%60)) min, and $(($ELAPSED_TIME%60)) sec${NORMAL}\n"
}

# Prints an information message
# params:
#   $1  String  Message text
info_msg() {
  echo -e "${INFO}Info:${NORMAL} $1\n"
}

# Prints a warning message
# params:
#   $1  String  Message text
warning_msg() {
  echo -e "${WARN}Warning:${NORMAL} $1\n"
}

# Prints an error message
# params:
#   $1  String  Message text
error_msg() {
  echo -e "${ERROR}Error:${NORMAL} $1\n"
}

# Prints a success message
# params:
#   $1  String  Message text
success_msg() {
  echo -e "${SUCCESS}$1${NORMAL}\n"
}

# Installation #################################################################

# Checks if SDL2 libraries are installed
have_sdl2_libs?() {
  
  have_all_libs=true
  have_sdl2_lib=true
  have_image_lib=true
  have_mixer_lib=true
  have_ttf_lib=true
  
  if ! have_lib? 'SDL2'; then
    have_all_libs=false
    have_sdl2_lib=false
  fi
  
  if ! have_lib? 'SDL2_image'; then
    have_all_libs=false
    have_image_lib=false
  fi
  
  if ! have_lib? 'SDL2_mixer'; then
    have_all_libs=false
    have_mixer_lib=false
  fi
  
  if ! have_lib? 'SDL2_ttf'; then
    have_all_libs=false
    have_ttf_lib=false
  fi
  
  if $have_all_libs; then
    return 0
  else
    echo; error_msg "Missing SDL libraries."
    return 1
  fi
}

# Installs SDL on Linux
install_sdl_linux() {
  
  prompt_to_continue "Install SDL now?"
  
  print_task "Updating packages" "\n\n"
  sudo apt-get update
  echo; print_task "Installing SDL2" "\n\n"
  sudo apt-get install -y libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev
  echo
  
  if ! have_sdl2_libs?; then
    error_msg "SDL libraries did not install correctly."
    exit
  else
    echo; info_msg "SDL was installed successfully."
  fi
}

# Installs SDL on Raspberry Pi
# params:
#   $1  String  Install options, e.g. 'reinstall'
install_sdl_rpi() {
  
  # TODO: Installing SDL2 on RPI 2 takes about 25 min; update this message.
  warning_msg "Installing SDL can take up to an hour on the Raspberry Pi."
  prompt_to_continue "Continue?"
  
  # Install library dependencies
  print_task "Installing SDL2 dependencies" "\n\n"
  sudo apt-get update
  
  libs=(
    # SDL2
    libudev-dev
    libasound2-dev
    libdbus-1-dev
    
    # SDL2_image
    libjpeg8-dev
    libpng12-dev
    libtiff5-dev
    libwebp-dev
    
    # SDL2_mixer
    libvorbis-dev
    libflac-dev
    
    # SDL2_ttf
    libfreetype6-dev
  )
  
  sudo apt-get install -y ${libs[*]}
  
  # Setting up variables
  url="http://www.libsdl.org"
  
  sdl="SDL2-2.0.3"
  sdl_url="${url}/release/${sdl}.tar.gz"
  
  image="SDL2_image-2.0.0"
  image_url="${url}/projects/SDL_image/release/${image}.tar.gz"
  
  smpeg="smpeg2-2.0.0"  # An SDL_mixer dependency, no package available
  smpeg_url="${url}/projects/smpeg/release/${smpeg}.tar.gz"
  
  mixer="SDL2_mixer-2.0.0"
  mixer_url="${url}/projects/SDL_mixer/release/${mixer}.tar.gz"
  
  ttf="SDL2_ttf-2.0.12"
  ttf_url="${url}/projects/SDL_ttf/release/${ttf}.tar.gz"
  
  # Downloads, compiles, and installs an SDL library from source
  # params:
  #   $1  String  URL of the tar archive
  #   $2  String  Name of the tar file
  #   $3  String  ./configure flags
  install_sdl_lib () {
    cd /tmp
    wget -N $1
    tar -xzf $2.tar.gz
    cd $2
    print_task "Configuring" "\n\n"
    ./configure $3
    echo; print_task "Compiling"
    make > /dev/null 2>&1
    echo -e " done"
    print_task "Installing" "\n\n"
    sudo make install
    rm /tmp/$2.tar.gz
    rm -rf /tmp/$2
  }
  
  # Note: `$have_*_lib` variables set by `have_sdl2_libs?()`
  
  if [[ $have_sdl2_lib == 'false' || $1 == 'reinstall' ]]; then
    echo; print_task "Installing SDL2" "\n\n"
    
    # May need to also add flags:
    #   --disable-pulseaudio --disable-esd
    #   --disable-video-mir --disable-video-wayland"
    
    sdl_config_flags="--disable-video-opengl --disable-video-x11"
    
    if [[ $rpi_version == 2 ]]; then
      sdl_config_flags="--host=armv7l-raspberry-linux-gnueabihf $sdl_config_flags"
    fi
    
    install_sdl_lib $sdl_url $sdl $sdl_config_flags
  fi
  
  if [[ $have_image_lib == 'false' || $1 == 'reinstall' ]]; then
    echo; print_task "Installing SDL2_image" "\n\n"
    install_sdl_lib $image_url $image
  fi
  
  if [[ $have_mixer_lib == 'false' || $1 == 'reinstall' ]]; then
    echo; print_task "Installing SDL2_mixer" "\n\n"
    install_sdl_lib $smpeg_url $smpeg
    install_sdl_lib $mixer_url $mixer
  fi
  
  if [[ $have_ttf_lib == 'false' || $1 == 'reinstall' ]]; then
    echo; print_task "Installing SDL2_ttf" "\n\n"
    install_sdl_lib $ttf_url $ttf
  fi
  
  echo
  if ! have_sdl2_libs?; then
    error_msg "SDL libraries did not install correctly."
    exit
  else
    echo; info_msg "SDL was installed successfully."
  fi
}

# Installs SDL
# params:
#   $1  String  'flag' means `simple2d install --sdl` used
install_sdl() {
  
  sdl_install_options=''
  
  if have_sdl2_libs?; then
    
    echo; info_msg "SDL already installed."
    
    if [[ $1 == 'flag' ]]; then
      prompt_to_continue "Reinstall SDL?"
      sdl_install_options='reinstall'
    else
      return
    fi
  fi
  
  print_task "Installing SDL" "\n\n"
  
  if [[ $platform == 'linux' ]]; then
    install_sdl_linux
  elif [[ $platform == 'rpi' ]]; then
    
    if [[ $1 == 'flag' ]]; then
      start_timer
    fi
    
    install_sdl_rpi $sdl_install_options
    
    if [[ $1 == 'flag' ]]; then
      end_timer
    fi
    
  fi
}

# Installs Simple 2D
# params:
#   $1  String  ...
# TODO: Figure out what these params are
install_s2d() {
  
  mkdir /tmp/simple2d
  
  if [[ $1 == 'master' ]]; then
    f_name=$1
  else
    f_name="v$1"
  fi
  
  print_task "Downloading Simple 2D" "\n\n"
  # Linux and Raspberry Pi may not have curl installed by default
  if which curl > /dev/null; then
    curl -L https://github.com/simple2d/simple2d/archive/$f_name.zip -o /tmp/simple2d/$f_name.zip
  else
    wget -NP /tmp/simple2d https://github.com/simple2d/simple2d/archive/$f_name.zip
  fi
  
  # Check if archive was downloaded properly
  if [ ! -f "/tmp/simple2d/$f_name.zip" ]; then
    echo; error_msg "Simple 2D could not be downloaded."
    exit
  fi
  
  echo; print_task "Unpacking"
  unzip -q /tmp/simple2d/$f_name.zip -d /tmp/simple2d
  
  # Check if archive was unpacked properly
  if [[ $? != 0 ]]; then
    echo; error_msg "The downloaded Simple 2D package is damaged. Could not unpack."
    exit
  fi
  
  printf " done"
  cd /tmp/simple2d/simple2d-$1
  
  echo; print_task "Compiling" "\n\n"
  make
  
  echo; print_task "Installing" "\n\n"
  sudo make install
  
  echo; print_task "Cleaning up"
  cd
  rm -rf /tmp/simple2d
  echo -e " done"
  
  # Check if S2D installed correctly
  if ! have_lib? 'simple2d'; then
    echo; error_msg "Simple 2D did not install correctly."
    exit
  fi
  echo
}

# Main entry point to install Simple 2D
install() {
  
  if [[ $platform == 'osx' ]]; then
    osx_homebrew_message
  fi
  
  # Welcome message
  echo -e "\n${BOLD}Welcome to Simple 2D!${NORMAL}"
  echo -e "${BLUE}---------------------${NORMAL}\n"
  
  echo -e "Platform detected: ${BOLD}${platform_display}${NORMAL}\n"
  
  if have_lib? 'simple2d' > /dev/null; then
    warning_msg "Simple 2D is already installed. Proceeding will reinstall."
  fi
  
  echo -e "Simple 2D will be installed to the following locations:
    /usr/local/include/simple2d.h
    /usr/local/lib/libsimple2d.a
    /usr/local/bin/simple2d"
  echo
  
  if $install_edge; then
    echo -e "This will install to the bleeding edge (latest commit).\n"
  fi
  
  prompt_to_continue "Continue?"
  
  start_timer
  
  install_sdl
  
  if $install_edge; then
    install_s2d 'master'
  else
    install_s2d $VERSION
  fi
  
  end_timer
  
  success_msg "Simple 2D installed successfully!"
}

# Uninstall ####################################################################

# Uninstalls SDL
uninstall_sdl() {
  
  echo; print_task "Uninstalling SDL" "\n\n"
  
  if [[ $platform == 'linux' ]]; then
    apt-get --purge remove libsdl2*
  elif [[ $platform == 'rpi' ]]; then
    # TODO: Implement this
    echo "Not yet implemented, sorry!"; echo
  fi
}

# Uninstalls Simple 2D
uninstall() {
  
  if [[ $platform == 'osx' ]]; then
    osx_homebrew_message
  fi
  
  echo; prompt_to_continue "Uninstall Simple 2D?"
  
  # Use hard-coded, absolute paths for safety
  rm -f /usr/local/include/simple2d.h
  rm -f /usr/local/lib/libsimple2d.a
  rm -f /usr/local/bin/simple2d
  
  # Check if files were actually deleted
  files=(/usr/local/include/simple2d.h
         /usr/local/lib/libsimple2d.a
         /usr/local/bin/simple2d)
  
  if [ -f ${files[0]} -o -f ${files[1]} -o -f ${files[2]} ]; then
    echo; error_msg "Simple 2D files could not be removed. Try using \`sudo\`?"
  else
    success_msg "Simple 2D uninstalled."
  fi
}

# Update #######################################################################

# Updates Simple 2D to latest version or commit
update() {
  
  if [[ $platform == 'osx' ]]; then
    osx_homebrew_message
  fi
  
  # Is Simple 2D installed?
  echo
  if ! have_lib? 'simple2d' > /dev/null; then
    error_msg "Simple 2D isn't currently installed."
    echo -e "Use the \`install\` command to install it.\n"
    exit
  fi
  
  # Checks if SDL is installed
  update_check_sdl() {
    if have_sdl2_libs?; then
      echo; info_msg "SDL already installed."
    else
      echo -e "Run \`simple2d doctor\` for more information, or..."
      echo -e "Run \`simple2d install --sdl\` to install missing libraries.\n"
      exit
    fi
  }
  
  if $install_edge; then
    echo -e "This will update Simple 2D to the bleeding edge (latest commit)."
    prompt_to_continue "Continue?"
    update_check_sdl
    install_s2d 'master'
    success_msg "Updated Simple 2D to latest commit!"
    echo "  Go to:"
    echo "    http://github.com/simple2d/simple2d/commits/master"
    echo "  to see the revision history."; echo
  else
    get_remote_str $VERSION_URL
    NEW_VERSION=$ret
    compare_versions $NEW_VERSION $VERSION
    
    if [[ $? == 1 ]]; then
      echo -e "A new version of Simple 2D is available."
      prompt_to_continue "Install now?"
      update_check_sdl
      print_task "Updating Simple 2D" "\n"
      install_s2d $NEW_VERSION
      success_msg "Simple 2D has been updated to $NEW_VERSION!"
    else
      success_msg "Simple 2D is up to date."
    fi
  fi
}

# Doctor #######################################################################

# Runs the diagnostics
doctor() {
  
  echo; print_task "Running diagnostics" "\n\n"
  
  errors=false
  
  if ! have_sdl2_libs?; then
    errors=true
  fi
  
  if have_lib? 'simple2d'; then
    echo
  else
    errors=true
    echo; error_msg "Simple 2D library missing."
  fi
  
  if $errors; then
    echo -e "Issues found.\n"
  else
    success_msg "No issues found!"
  fi
}

# Platform Specific ############################################################

# Prints homebrew message and quit
osx_homebrew_message() {
  echo "
Use Homebrew to install, update, and uninstall Simple 2D on OS X.

  First, use \`brew tap\` to get Simple 2D formulas:
    brew tap simple2d/tap
  
  Then, \`brew\` commands will be available:
    brew install simple2d
    brew upgrade simple2d
    brew uninstall simple2d

Learn more at http://brew.sh
"
  exit
}

# Detect Platform ##############################################################

unamestr=$(uname)
if [[ $unamestr == 'Darwin' ]]; then
  platform_display='Mac OS X'
  platform='osx'
elif [[ $(uname -m) =~ 'arm' && $unamestr == 'Linux' ]]; then
  platform_display='Raspberry Pi'
  platform='rpi'
  
  if [[ $(uname -m) == 'armv7l' ]]; then
    rpi_version=2
  fi
  
elif [[ $unamestr == 'Linux' ]]; then
  platform_display='Linux'
  platform='linux'
fi

# Look for supported platform
if [[ $platform == 'unknown' ]]; then
  echo; error_msg "Not a supported system (OS X, Linux, Raspberry Pi)."
  exit
fi

# Check Command-line Arguments #################################################

print_usage() {
echo "
Usage: simple2d [-l|--libs] [-v|--version]
                <command> <args>

Summary of commands and options:
  install       Installs the latest stable version.
    --edge      Installs latest build (possibly unstable).
    --sdl       Installs SDL only.
  uninstall     Removes Simple 2D files only.
    --sdl       Removes SDL only.
  update        Updates to latest stable version.
    --edge      Updates to latest build (possibly unstable).
  doctor        Checks the installation status, reports issues.
  -l|--libs     Outputs libraries needed to compile Simple 2D apps.
  -v|--version  Prints the installed version.
"
}

case $1 in
  install)
    case $2 in
      '')
        install;;
      --edge)
        install_edge=true
        install;;
      --sdl)
        echo; install_sdl 'flag';;
      *)
        print_usage;;
    esac;;
  uninstall)
    case $2 in
      '')
        uninstall;;
      --sdl)
        uninstall_sdl;;
      *)
        print_usage;;
    esac;;
  update)
    case $2 in
      '')
        update;;
      --edge)
        install_edge=true
        update;;
      *)
        print_usage;;
    esac;;
  doctor)
    doctor;;
  -l|--libs)
    if [[ $platform == 'osx' ]]; then
      LDFLAGS='-Wl,-framework,OpenGL'
    elif [[ $platform == 'linux' ]]; then
      LDFLAGS='-lGL'
    elif [[ $platform == 'rpi' ]]; then
      LDFLAGS='-I/opt/vc/include/ -L/opt/vc/lib -lGLESv2'
    fi
    echo "-lsimple2d `sdl2-config --cflags --libs`"\
         "${LDFLAGS} -lSDL2_image -lSDL2_mixer -lSDL2_ttf";;
  -v|--version)
    echo $VERSION;;
  *)
    print_usage;;
esac
