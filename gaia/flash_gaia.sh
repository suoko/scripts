#! /usr/bin/env bash

# Reference Link: https://l10n.etherpad.mozilla.org/gaia-multilocale
# This script can be used to flash a version of Gaia greater than 1.2 on a device
# 1. Search for a folder called "gaia". If not available, clone Gaia
# repository.
# 2. If locales/XX exists, check the default repo and delete this
# folder if it doesn't match the requested version.
# 3. If locales/XX does not exist, clone the Hg locale repository.

# Syntax:
# parameter 1: version of Gaia to use (e.g. master, 1.2, 1.3)
# parameter 2: --no-update to use local information without update repos

# Change you locale code here
localecode="it"
# Folder used to store Gaia and locale repositories
repofolder="$HOME/moz/"


# You shouldn't need to modify the script after this line

function interrupt_code()
# This code runs if user hits control-c
{
  echored "\n*** Operation interrupted ***\n"
  exit $?
}

# Trap keyboard interrupt (control-c)
trap interrupt_code SIGINT

# Pretty printing functions
NORMAL=$(tput sgr0)
GREEN=$(tput setaf 2; tput bold)
RED=$(tput setaf 1)

function echored() {
    echo -e "$RED$*$NORMAL"
}

function echogreen() {
    echo -e "$GREEN$*$NORMAL"
}

function printUsage() {
	echo "Usage: flash_gaia.sh version [--no-update]"
	echo "Examples:"
	echo "flash_gaia.sh 1.4"
	echo "flash_gaia.sh 2.0 --no-update"
	echo "only 1.4 2.0, 2.1 and master (now version 2.2) are currently supported"
}

# No parameters
if [ $# -lt 1 ]
then
	echored "Script requires at least one parameter (Gaia version)."
	printUsage
	exit
fi

# Too many parameters
if [ $# -gt 2 ]
then
	echored "Too many parameters."
	printUsage
	exit
fi

if [ $# -eq 1 ]
then
	# One parameter
	if [ $1 == "--no-update" ]
	then
		echored "Missing Gaia version."
		printUsage
		exit
	else
		version="$1"
		echogreen "Flashing Gaia $version with updates"
		updatelocal=true
	fi
else
	# Two parameters
	if [ $1 == "--no-update" ]
	then
		version="$2"
		echogreen "Flashing Gaia $version without updates"
		updatelocal=false
	else
		if [ $2 == "--no-update" ]
		then
			version="$1"
			echogreen "Flashing Gaia $version without updates"
			updatelocal=false
		else
			echored "Wrong parameters"
			printUsage
		fi
	fi
fi

# Check if the provided version makes sense
if [ $version != 'master' ] && [ ${version:0:3} != '1.4' ] && [ ${version:0:3} != '2.0' ] && [ ${version:0:3} != '2.1' ]
then
	echored "Unsupported Gaia version, aborting."
	exit
fi

if [ $version == '2.1' ]
then
	hggaiaversion="master"
	gitversion="master"

elif [ $version == "master"]
then
	hggaiaversion="master"
	gitversion="master"
else
	# Replace . with _ (e.g. 1.3=>1_3) for Hg URL
	hggaiaversion=$(echo $version | tr '.' '_')
	gitversion="v$version"
fi

mkdir -p "$repofolder/$hggaiaversion"
cd "$repofolder/$hggaiaversion"

# Check if mercurial and git are available
if ! hash git 2>/dev/null
then
    echored "git not found: please make sure that git is installed on your system"
    exit
fi

if ! hash hg 2>/dev/null
then
    echored "hg not found: please make sure that mercurial is installed on your system"
    exit
fi

# Check Gaia repository
if [ ! -d "gaia" ]
then
	echogreen "Gaia folder not found. Cloning Gaia"
	echogreen "Cloning https://github.com/mozilla-b2g/gaia"
	git clone https://github.com/mozilla-b2g/gaia
	echogreen "Checkout $gitversion"
	git checkout $gitversion
else
	if $updatelocal
	then
		echogreen "Update Gaia repository"
		cd gaia
		echogreen "Running reset --hard"
		git reset --hard
        echogreen "Removing extra files and folders"
        git clean -fd
		echogreen "Running git pull"
		echogreen "Checkout $gitversion"
		git checkout $gitversion
		git pull
	fi
fi


cd "$repofolder/$hggaiaversion/gaia/locales"

# Does the locale folder exist?
if [ -d "$localecode" ]
then
	# Check which repo is cloned in the folder
	l10nrepo=$(awk -F "=" '/default/ {print $2}' $localecode/.hg/hgrc | tr -d ' ')
	echogreen "Checking if the l10n repo is correct for $gitversion"
	# If default path doesn't contain releases it's master
	if [[ $l10nrepo != *releases* ]] && [ $version != "2.1" ]
	then
		echored "Wrong locale version (master). Deleting folder"
		rm -r $localecode
	fi

	# If default path contains /releases/ it's a version branch
	if [[ $l10nrepo == *releases* ]] && [ $version == "2.1" ]
	then
		echored "Wrong locale version (not master). Deleting folder"
		rm -r $localecode
	fi
fi

# Clone if locale folder is missing
if [ ! -d "$localecode" ]
then
	# Clone locale repo
	if [ $version == '2.1' ]
	then
		echogreen "Cloning https://hg.mozilla.org/gaia-l10n/$localecode/"
		hg clone https://hg.mozilla.org/gaia-l10n/$localecode/
	elif [ $version == "master"]
	then
		echogreen "Cloning https://bitbucket.org/flod/gaia-master-$localecode/"
		hg clone https://bitbucket.org/flod/gaia-master-$localecode/ $localecode 
	else
		echogreen "Cloning https://hg.mozilla.org/releases/gaia-l10n/v$hggaiaversion/$localecode/"
		hg clone https://hg.mozilla.org/releases/gaia-l10n/v$hggaiaversion/$localecode/
	fi
else
	if $updatelocal
	then
		cd $localecode
		echogreen "Update locales/$localecode repository"
		hg pull -r default
		hg up -C
	fi
fi


cd "$repofolder/$hggaiaversion"



if [ $hggaiaversion == "2_0" ]
then
b2g_version=32.0
url=http://ftp.mozilla.org/pub/mozilla.org/b2g/nightly/latest-mozilla-b2g${b2g_version:0:2}_v$hggaiaversion-flame-kk/

elif [ $hggaiaversion == "1_4" ]
then
b2g_version=30.0
url=http://ftp.mozilla.org/pub/mozilla.org/b2g/nightly/latest-mozilla-b2g${b2g_version:0:2}_v$hggaiaversion-flame/

elif [ $hggaiaversion == "2_1" ]
then
b2g_version=34.0a2
url=http://ftp.mozilla.org/pub/mozilla.org/b2g/nightly/latest-mozilla-aurora-flame-kk/

elif [ $hggaiaversion == "master" ]
then
b2g_version=35.0a1
url=http://ftp.mozilla.org/pub/mozilla.org/b2g/nightly/latest-mozilla-central-flame-kk/

fi


 
#clean
for dir in system gaia.zip b2g-$b2g_version.en-US.android-arm.tar.gz; do
if [ -d $dir ] || [ -f $dir ]; then
rm -r $dir;
fi
done
 
#download update files
#wget $url/gaia.zip
wget $url/b2g-$b2g_version.en-US.android-arm.tar.gz
 
#prepare update
#unzip gecko
 
tar -zxvf b2g-$b2g_version.en-US.android-arm.tar.gz

#compile gaia
cd $repofolder/$hggaiaversion/gaia
make clean 
PRODUCTION=1 make MAKECMDGOALS=production MOZILLA_OFFICIAL=1 GAIA_KEYBOARD_LAYOUTS=en,$localecode LOCALES_FILE=locales/languages_all.json LOCALE_BASEDIR=locales/ DEVICE_DEBUG=1

cd "$repofolder/$hggaiaversion"
 
mkdir system
 
mv b2g system/
mv gaia/profile/* system/b2g/
 
#update the phone
adb remount
adb shell rm -r /system/b2g
adb reboot
adb wait-for-device
adb remount
adb shell stop b2g
adb push system/b2g /system/b2g


adb shell start b2g
rm -fr gaia b2g-$b2g_version.en-US.android-arm.tar.gz
echo "you've been left with system directory only"
