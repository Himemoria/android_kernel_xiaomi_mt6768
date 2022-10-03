# Regenerate Defconfig
make O=out ARCH=arm64 merlin_defconfig
cp out/.config arch/arm64/configs/merlin_defconfig

make O=out ARCH=arm64 lancelot_defconfig
cp out/.config arch/arm64/configs/lancelot_defconfig

make O=out ARCH=arm64 shiva_defconfig
cp out/.config arch/arm64/configs/shiva_defconfig

rm -rf out
git add arch/arm64
git commit -asm "defconfig: regenerate"

