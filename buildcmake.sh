# 1) Remove any leftover CMake bits in /usr/local
sudo rm -f /usr/local/bin/{cmake,ccmake,ctest,cpack}
sudo rm -rf /usr/local/share/cmake-3.*

# 2) Go back to your 3.30.1 source dir
cd ~/Documents/GitHub/cmake-3.30.1

# 3) Clean any previous build outputs (just in case)
make clean || true

# 4) Bootstrap with /usr/local prefix
./bootstrap --prefix=/usr/local -- -DCMAKE_USE_OPENSSL=ON

# 5) Build using all 20 cores & native flags
make -j20 CFLAGS="-march=native -O2" CXXFLAGS="-march=native -O2"

# 6) Install into /usr/local
sudo make install

# 7) Refresh your shell’s command cache
hash -r

# 8) Verify the new CMake is in place
which cmake       # should print /usr/local/bin/cmake
cmake --version   # should now show 3.30.1
