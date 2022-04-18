REM copy bootstrap.py
copy modules\cctbx_project\libtbx\auto_build\bootstrap.py .
if %errorlevel% neq 0 exit /b %errorlevel%

REM remove extra source code
rmdir /S /Q .\modules\boost
rmdir /S /Q .\modules\eigen
rmdir /S /Q .\modules\scons

REM build
%PYTHON% bootstrap.py build --builder=xfel --use-conda %PREFIX% --nproc %CPU_COUNT% --config-flags="--enable_cxx11" --config-flags="--no_bin_python" --config-flags="--skip_phenix_dispatchers"
if %errorlevel% neq 0 exit /b %errorlevel%
@REM cd build
@REM call .\bin\libtbx.configure cma_es crys3d fable rstbx spotinder
@REM if %errorlevel% neq 0 exit /b %errorlevel%
@REM call .\bin\libtbx.scons -j %CPU_COUNT%
@REM if %errorlevel% neq 0 exit /b %errorlevel%
@REM call .\bin\libtbx.scons -j %CPU_COUNT%
@REM if %errorlevel% neq 0 exit /b %errorlevel%
@REM cd ..

REM remove dxtbx and cbflib
@REM del /S /Q .\build\*cbflib*
@REM del /S /Q .\build\lib\cbflib*
@REM rmdir /S /Q .\modules\dxtbx
@REM rmdir /S /Q .\modules\cbflib
@REM rmdir /S /Q .\build\annlib
@REM rmdir /S /Q .\modules\annlib
@REM call .\build\bin\libtbx.python %RECIPE_DIR%\clean_env.py
@REM if %errorlevel% neq 0 exit /b %errorlevel%

REM remove extra source files (C, C++, Fortran, CUDA)
@REM cd build
@REM del /S /Q *.c
@REM del /S /Q *.cpp
@REM del /S /Q *.cu
@REM del /S /Q *.f
@REM cd ..\modules
@REM del /S /Q *.c
@REM del /S /Q *.cpp
@REM del /S /Q *.cu
@REM del /S /Q *.f
@REM cd ..

REM remove intermediate objects in build directory
cd build
del /S /Q *.obj
cd ..

REM copy files in build
SET EXTRA_CCTBX_DIR=%LIBRARY_PREFIX%\share\cctbx
mkdir  %EXTRA_CCTBX_DIR%
SET CCTBX_CONDA_BUILD=.\modules\cctbx_project\libtbx\auto_build\conda_build
call .\build\bin\libtbx.python %CCTBX_CONDA_BUILD%\install_build.py --prefix %LIBRARY_PREFIX% --sp-dir %SP_DIR% --ext-dir %PREFIX%\lib --preserve-egg-dir
if %errorlevel% neq 0 exit /b %errorlevel%

REM copy version and copyright files
%PYTHON% .\modules\cctbx_project\libtbx\version.py --version=%PKG_VERSION%
if %errorlevel% neq 0 exit /b %errorlevel%
copy .\modules\cctbx_project\COPYRIGHT.txt %EXTRA_CCTBX_DIR%
copy .\modules\cctbx_project\cctbx_version.txt %EXTRA_CCTBX_DIR%
copy .\modules\cctbx_project\cctbx_version.h %LIBRARY_INC%\cctbx
cd .\modules\cctbx_project
%PYTHON% setup.py install
if %errorlevel% neq 0 exit /b %errorlevel%
cd ..\..

REM copy libtbx_env and update dispatchers
echo Copying libtbx_env
call .\build\bin\libtbx.python %CCTBX_CONDA_BUILD%\update_libtbx_env.py
if %errorlevel% neq 0 exit /b %errorlevel%
%PYTHON% %CCTBX_CONDA_BUILD%\update_libtbx_env.py
if %errorlevel% neq 0 exit /b %errorlevel%

REM remove extra copies of dispatchers
attrib +H %LIBRARY_BIN%\libtbx.show_build_path.bat
attrib +H %LIBRARY_BIN%\libtbx.show_dist_paths.bat
del /Q %LIBRARY_BIN%\*show_build_path.bat
del /Q %LIBRARY_BIN%\*show_dist_paths.bat
attrib -H %LIBRARY_BIN%\libtbx.show_build_path.bat
attrib -H %LIBRARY_BIN%\libtbx.show_dist_paths.bat
