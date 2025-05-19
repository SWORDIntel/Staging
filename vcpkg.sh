cd ~/Documents/GitHub/MEGAcmd
git submodule add https://github.com/microsoft/vcpkg.git vcpkg
git submodule update --init --recursive

# now:
cd vcpkg
./bootstrap-vcpkg.sh
