#!/usr/bin/env bash
#
# Copyright (C) 2021 a xyzprjkt property
# Copyright (C) 2021 a Panchajanya1999 <rsk52959@gmail.com>
# Copyright (C) 2022 a Himemorii <himemori@mail.com>
#

msg() {
	echo
	echo -e "\e[1;32m$*\e[0m"
	echo
}

# Main Dir Info
KERNEL_ROOTDIR=$(pwd)
GCC64_DIR=$(pwd)/GCC64
GCC32_DIR=$(pwd)/GCC32

# Main Declaration
MODEL=Redmi Note 9
DEVICE_CODENAME=merlin
DEVICE_DEFCONFIG=merlin_defconfig
AK3_BRANCH=merlin
KERNEL_NAME=$(cat "arch/arm64/configs/$DEVICE_DEFCONFIG" | grep "CONFIG_LOCALVERSION=" | sed 's/CONFIG_LOCALVERSION="-*//g' | sed 's/"*//g' )
export KBUILD_BUILD_USER=Himemori
export KBUILD_BUILD_HOST=XZI-TEAM
IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
DATE=$(TZ=Asia/Jakarta date +"%Y%m%d-%T")
DATE2=$(date +"%m%d")
START=$(date +"%s")
DTB=$(pwd)/out/arch/arm64/boot/dts/mediatek/mt6768.dtb
DTBO=$(pwd)/out/arch/arm64/boot/dtbo.img
DISTRO=$(source /etc/os-release && echo "${NAME}")

msg "|| Cloning GCC  ||"
git clone --depth=1 https://github.com/cyberknight777/gcc-arm64 -b master $GCC64_DIR
git clone --depth=1 https://github.com/cyberknight777/gcc-arm -b master $GCC32_DIR
KBUILD_COMPILER_STRING=$("$GCC64_DIR"/bin/aarch64-elf-gcc --version | head -n 1)
PATH=$GCC64_DIR/bin/:$GCC32_DIR/bin/:/usr/bin:$PATH

#Check Kernel Version
KERVER=$(make kernelversion)

# Set a commit head
COMMIT_HEAD=$(git log --oneline -1)
HEADCOMMITID="$(git log --pretty=format:'%h' -n1)"
HEADCOMMITMSG="$(git log --pretty=format:'%s' -n1)"
CI_BRANCH=$(git rev-parse --abbrev-ref HEAD)
TERM=xterm
PROCS=$(nproc --all)
export CI_BRANCH TERM

## Check for CI
if [ "$CI" ]
then
	if [ "$CIRCLECI" ]
	then
		export KBUILD_BUILD_VERSION=$CIRCLE_BUILD_NUM
		export CI_BRANCH=$CIRCLE_BRANCH
	fi
	if [ "$DRONE" ]
	then
		export KBUILD_BUILD_VERSION=$DRONE_BUILD_NUMBER
		export CI_BRANCH=$DRONE_BRANCH
		export BASEDIR=$DRONE_REPO_NAME # overriding
		export SERVER_URL="${DRONE_SYSTEM_PROTO}://${DRONE_SYSTEM_HOSTNAME}/${AUTHOR}/${BASEDIR}/${KBUILD_BUILD_VERSION}"
	else
		echo "Not presetting Build Version"
	fi
fi

# Telegram
export BOT_MSG_URL="https://api.telegram.org/bot$TG_TOKEN/sendMessage"

tg_post_msg() {
  curl -s -X POST "$BOT_MSG_URL" -d chat_id="$TG_CHAT_ID" \
  -d "disable_web_page_preview=true" \
  -d "parse_mode=html" \
  -d text="$1"

}

# Post Main Information
tg_post_msg "
<b>========= Roulette-Kernel =========</b>
<b>• Date</b> : <code>$(TZ=Asia/Jakarta date)</code>
<b>• Docker OS</b> : <code>$DISTRO</code>
<b>• Kernel Name</b> : <code>${KERNEL_NAME}</code>
<b>• Kernel Version</b> : <code>${KERVER}</code>
<b>• Builder Name</b> : <code>${KBUILD_BUILD_USER}</code>
<b>• Builder Host</b> : <code>${KBUILD_BUILD_HOST}</code>
<b>• Pipeline Host</b> : <code>$DRONE_SYSTEM_HOSTNAME</code>
<b>• Host Core Count</b> : <code>$PROCS</code>
<b>• Compiler</b> : <code>${KBUILD_COMPILER_STRING}</code>
<b>• Top Commit</b> : <code>${COMMIT_HEAD}</code>
<b>=================================</b>
"

  MAKE+=(
    CC=aarch64-elf-gcc
    LD=aarch64-elf-ld.lld
    CROSS_COMPILE=aarch64-elf-
    CROSS_COMPILE_ARM32=arm-eabi-
    AR=llvm-ar
    NM=llvm-nm
    OBJDUMP=llvm-objdump
    OBJCOPY=llvm-objcopy
    OBJSIZE=llvm-objsize
    STRIP=llvm-strip
    HOSTAR=llvm-ar
    HOSTCC=gcc
    HOSTCXX=aarch64-elf-g++
    CONFIG_DEBUG_SECTION_MISMATCH=y
)

# Compile
compile(){
msg "|| Started Compilation ||"
make -j$(nproc) O=out ARCH=arm64 ${DEVICE_DEFCONFIG}
make -j$(nproc) ARCH=arm64 O=out \
         "${MAKE[@]}" 2>&1 | tee error.log

   if ! [ -a "$IMAGE" ]; then
	finerr
	exit 1
   fi

  git clone --depth=1 https://github.com/Himemoria/AnyKernel3 -b ${AK3_BRANCH} AnyKernel
    cp $IMAGE AnyKernel
    cp $DTBO AnyKernel
    mv $DTB AnyKernel/dtb
}

# Push kernel to channel
function push() {
    msg "|| Started Uploading ||"
    cd AnyKernel
    ZIP_NAME=$KERNEL_NAME-$DEVICE_CODENAME-R-OSS-$DATE.zip
    ZIP=$(echo *.zip)
    MD5CHECK=$(md5sum "${ZIP}" | cut -d' ' -f1)
    SHA1CHECK=$(sha1sum "${ZIP}" | cut -d' ' -f1)
tg_post_msg "
<b>=================================</b>
✅ <b>Build Success</b>
- <code>$((DIFF / 60)) minute(s) $((DIFF % 60)) second(s) </code>
<b>• MD5 Checksum</b>
- <code>${MD5CHECK}</code>
<b>• SHA1 Checksum</b>
- <code>${SHA1CHECK}</code>
<b>• Zip Name</b>
- <code>${ZIP_NAME}</code>
<b>=================================</b>
"

    curl -F document=@$ZIP "https://api.telegram.org/bot$TG_TOKEN/sendDocument" \
        -F chat_id="$TG_CHAT_ID" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="$KBUILD_COMPILER_STRING"
}
# Fin Error
function finerr() {
    LOG=$(echo error.log)
    curl -F document=@$LOG "https://api.telegram.org/bot$TG_TOKEN/sendDocument" \
        -F chat_id="$TG_CHAT_ID" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="❌ Compilation Failed. | For <b>${DEVICE_CODENAME}</b> | <b>${KBUILD_COMPILER_STRING}</b>"
    exit 1
}

# Zipping
function zipping() {
    msg "|| Started Zipping ||"
    cd AnyKernel || exit 1
    zip -r9 $KERNEL_NAME-$DEVICE_CODENAME-R-OSS-$DATE.zip *
    cd ..
}
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push
