@rem Copyright 2016, Google Inc.
@rem All rights reserved.
@rem
@rem Redistribution and use in source and binary forms, with or without
@rem modification, are permitted provided that the following conditions are
@rem met:
@rem
@rem     * Redistributions of source code must retain the above copyright
@rem notice, this list of conditions and the following disclaimer.
@rem     * Redistributions in binary form must reproduce the above
@rem copyright notice, this list of conditions and the following disclaimer
@rem in the documentation and/or other materials provided with the
@rem distribution.
@rem     * Neither the name of Google Inc. nor the names of its
@rem contributors may be used to endorse or promote products derived from
@rem this software without specific prior written permission.
@rem
@rem THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
@rem "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
@rem LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
@rem A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
@rem OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
@rem SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
@rem LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
@rem DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
@rem THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
@rem (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
@rem OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


set PATH=C:\%1;C:\%1\scripts;C:\msys64\mingw%2\bin;%PATH%

pip install --upgrade six
pip install --upgrade setuptools
pip install -rrequirements.txt

@rem Because this is windows and *everything seems to hate Windows* we have to
@rem set all of these flags ourselves because Python won't help us (see the
@rem setup.py of the grpcio_tools project).
set GRPC_PYTHON_CFLAGS=-fno-wrapv -frtti -std=c++11

@rem See https://sourceforge.net/p/mingw-w64/bugs/363/
if %2 == 32 (
  set GRPC_PYTHON_CFLAGS=%GRPC_PYTHON_CFLAGS% -D_ftime=_ftime32 -D_timeb=__timeb32 -D_ftime_s=_ftime32_s
) else (
  set GRPC_PYTHON_CFLAGS=%GRPC_PYTHON_CFLAGS% -D_ftime=_ftime64 -D_timeb=__timeb64
)

@rem Further confusing things, MSYS2's mingw64 tries to dynamically link
@rem libgcc, libstdc++, and winpthreads. We have to override this or our
@rem extensions end up linking to MSYS2 DLLs, which the normal Python on
@rem Windows user won't have... and ON TOP OF THIS, there's MinGW's GCC default
@rem behavior of linking msvcrt.dll as the C runtime library, which we need to
@rem override so that Python's distutils doesn't link us against multiple C
@rem runtimes.
python -c "from distutils.cygwinccompiler import get_msvcr; print(get_msvcr()[0])" > temp.txt
set /p PYTHON_MSVCR=<temp.txt
set GRPC_PYTHON_LDFLAGS=-static-libgcc -static-libstdc++ -mcrtdll=%PYTHON_MSVCR% -static -lpthread

set GRPC_PYTHON_BUILD_WITH_CYTHON=1


@rem Set up gRPC Python tools
python tools\distrib\python\make_grpcio_tools.py

@rem Build gRPC Python extensions
python setup.py build_ext -c mingw32
python tools\distrib\python\grpcio_tools\setup.py build_ext -c mingw32

@rem Build gRPC Python distributions
python setup.py bdist_wheel
python tools\distrib\python\grpcio_tools\setup.py bdist_wheel

mkdir artifacts
xcopy /Y /I /S dist\* artifacts\ || goto :error
xcopy /Y /I /S tools\distrib\python\grpcio_tools\dist\* artifacts\ || goto :error

goto :EOF

:error
exit /b 1
