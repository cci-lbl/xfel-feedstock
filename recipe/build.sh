#!/bin/bash
set -xe

# Get an updated config.sub and config.guess
cp $BUILD_PREFIX/share/gnuconfig/config.* ./modules/ccp4io/libccp4/build-aux
cp $BUILD_PREFIX/share/gnuconfig/config.* ./modules/cbflib/libtool
cp $BUILD_PREFIX/share/gnuconfig/config.* ./modules/cbflib

# clean up sources
if [[ "$CC" != *"arm64"* ]]; then
  futurize -f libfuturize.fixes.fix_print_with_import -wn ./modules/cbflib
  futurize -f lib2to3.fixes.fix_except -wn ./modules/cbflib
fi

# copy autogenerated header to avoid binary compiler check on osx-arm64
if [[ "$CC" == *"arm64"* ]]; then
  mkdir -p build/include/boost_adaptbx
  cp ${RECIPE_DIR}/type_id_eq.h build/include/boost_adaptbx/type_id_eq.h
fi

# link bootstrap.py
ln -s modules/cctbx_project/libtbx/auto_build/bootstrap.py

# remove extra source code
rm -fr ./modules/boost
rm -fr ./modules/eigen
rm -fr ./modules/scons

# remove some libtbx_refresh.py files
rm -fr ./modules/dials/libtbx_refresh.py
rm -fr ./modules/dxtbx/libtbx_refresh.py
rm -fr ./modules/iota/libtbx_refresh.py
rm -fr ./modules/xia2/libtbx_refresh.py

# build
export CCTBX_SKIP_CHEMDATA_CACHE_REBUILD=1
${PYTHON} bootstrap.py build --builder=xfel --use-conda ${PREFIX} --nproc ${CPU_COUNT} \
  --config-flags="--compiler=conda" \
  --config-flags="--use_environment_flags" \
  --config-flags="--enable_openmp_if_possible=True" \
  --config-flags="--no_bin_python" \
  --config-flags="--skip_phenix_dispatchers"
cd build
./bin/libtbx.configure lunus
./bin/libtbx.configure sim_erice
./bin/libtbx.configure serialtbx
# ./bin/libtbx.configure cma_es crys3d fable rstbx spotinder
./bin/libtbx.scons -j ${CPU_COUNT}
./bin/libtbx.scons -j ${CPU_COUNT}
cd ..

# remove intermediate objects in build directory
cd build
find . -name "*.o" -type f -delete
cd ..

# fix rpath on macOS because libraries and extensions will be in different locations
if [[ ! -z "$MACOSX_DEPLOYMENT_TARGET" ]]; then
  echo Fixing rpath
  ${PYTHON} ${RECIPE_DIR}/fix_macos_rpath.py
fi

# copy files in build
echo Copying build
EXTRA_CCTBX_DIR=${PREFIX}/share/cctbx
mkdir -p ${EXTRA_CCTBX_DIR}
CCTBX_CONDA_BUILD=./modules/cctbx_project/libtbx/auto_build/conda_build
./build/bin/libtbx.python ${CCTBX_CONDA_BUILD}/install_build.py --preserve-egg-dir

# SP_DIR is weird in osx-arm64 in this feedstock
# points to python3.10 instead of python3.9
if [[ "$CC" == *"arm64"* ]]; then
  SP_DIR=${PREFIX}/lib/python${PY_VER}/site-packages
fi

# copy gui_resources
cp -a ./modules/gui_resources ${SP_DIR}

# copy dxtbx_flumpy.so separately since it does not end it *_ext.so
cp ./build/lib/dxtbx_flumpy.so ${SP_DIR}/../lib-dynload/

# copy lunus separately
rm -fr ${SP_DIR}/lunus
cp -a ./modules/lunus/lunus ${SP_DIR}

# copy version and copyright files
${PYTHON} ./modules/cctbx_project/libtbx/version.py --version=${PKG_VERSION}
cp ./modules/cctbx_project/COPYRIGHT.txt ${EXTRA_CCTBX_DIR}
cp ./modules/cctbx_project/LICENSE.txt ${EXTRA_CCTBX_DIR}
cp ./modules/cctbx_project/cctbx_version.txt ${EXTRA_CCTBX_DIR}
cp ./modules/cctbx_project/cctbx_version.h ${PREFIX}/include/cctbx
cd ./modules/cctbx_project
${PYTHON} setup.py install
cd ../..

# copy libtbx_env and update dispatchers
echo Copying libtbx_env
./build/bin/libtbx.python ${CCTBX_CONDA_BUILD}/update_libtbx_env.py
if [[ -e "${PREFIX}/python.app/Contents/MacOS/python" ]]; then
  ${PREFIX}/python.app/Contents/MacOS/python ${CCTBX_CONDA_BUILD}/update_libtbx_env.py
else
  ${PYTHON} ${CCTBX_CONDA_BUILD}/update_libtbx_env.py
fi

# remove extra copies of dispatchers
echo Removing some duplicate dispatchers
find ${PREFIX}/bin -name "*show_dist_paths" -not -name "libtbx.show_dist_paths" -type f -delete
find ${PREFIX}/bin -name "*show_build_path" -not -name "libtbx.show_build_path" -type f -delete

# install dxtbx, dials, iota, and xia2
cd modules
for m in dxtbx dials iota xia2; do
  rm -fr ${SP_DIR}/${m}
  cd ./${m}
  ${PYTHON} -m pip install . -vv --no-deps
  cd ..
done
cd ..

# copy amber force field files
EXTRA_GROMACS_DIR=${PREFIX}/share/gromacs/top
mkdir -p ${EXTRA_GROMACS_DIR}
cp -a ${RECIPE_DIR}/extra/amber14sb.ff ${EXTRA_GROMACS_DIR}
