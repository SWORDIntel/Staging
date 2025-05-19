# 1. Download & unpack
wget https://github.com/Kitware/CMake/releases/download/v3.30.1/cmake-3.30.1.tar.gz
tar -xzf cmake-3.30.1.tar.gz
cd cmake-3.30.1

# 2. Bootstrap & build with 20 jobs and -march=native
./bootstrap -- -DCMAKE_USE_OPENSSL=ON
make -j20 \
     CFLAGS="-O3 -march=native" \
     CXXFLAGS="-O3 -march=native"

# 3. Install
sudo make install

# 4. Verify
cmake --version   # should show 3.30.1
