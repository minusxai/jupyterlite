#!/usr/bin/env bash
set -euo pipefail
export PYODIDE_JOBS=4 EMSDK_NUM_CORE=4 EMCC_CORES=4 CCACHE_DISABLE=1
python -c 'import sys; assert sys.version_info[:3] == (3,14,10)'
proof=/workspace/runtime-proof
mkdir -p "$proof"
work=$(mktemp -d)
finish() {
  result=$?
  trap - EXIT
  if [ -d "$work/pyodide/.git" ]; then
    RUNTIME_BUILD_EXIT="$result" python /workspace/scripts/record-runtime-proof.py "$work/pyodide" "$proof" || true
  fi
  rm -rf "$work"
  exit "$result"
}
trap finish EXIT
git clone --no-checkout https://github.com/pyodide/pyodide "$work/pyodide"
cd "$work/pyodide"
git checkout --detach b1e4fcc2488962f6360a97f19b9982d6fdb5d16f
git submodule update --init --recursive
test "$(git -C pyodide-build rev-parse HEAD)" = 79fb82b2a576a833a12f3889061ca976de2f4167
python -m pip install --require-hashes --only-binary=:all: -r /workspace/runtime-build/host-build-requirements.lock
python -m pip install --no-deps --no-build-isolation ./pyodide-build
ln -s pyodide-build/pyodide_build pyodide_build
touch .pyodide_build_installed
python -m pip check
python -m pip freeze --all > "$proof/host-python-packages.txt"
python - <<'INNER'
from pathlib import Path
p=Path('Makefile.envs');s=p.read_text();assert '3.14.2' in s;s=s.replace('3.14.2','3.14.10').replace('c609e078adab90e2c6bacb6afafacd5eaf60cd94cf670f1e159565725fcd448d','9e4996c19ae5a3df31f10c37723661f71d3455d73bd005f79df7098e5cc13192');p.write_text(s)
p=Path('Makefile');s=p.read_text();assert 'pip install -e ./pyodide-build' in s;p.write_text(s.replace('pip install -e ./pyodide-build','python -m pip check'))
p=Path('pyodide_env.sh');s=p.read_text();assert 'export _EMCC_CCACHE=1' in s;p.write_text(s.replace('export _EMCC_CCACHE=1','unset _EMCC_CCACHE'))
INNER
# Reconciled source supplied directly so Make never reapplies obsolete patches.
mkdir -p cpython/downloads cpython/build
curl -fsSL https://www.python.org/ftp/python/3.14.10/Python-3.14.10.tgz -o cpython/downloads/Python-3.14.10.tgz
echo '9e4996c19ae5a3df31f10c37723661f71d3455d73bd005f79df7098e5cc13192  cpython/downloads/Python-3.14.10.tgz' | sha256sum -c -
tar -xzf cpython/downloads/Python-3.14.10.tgz -C cpython/build
for patchfile in /workspace/runtime-build/patches/*.patch; do
  (cd cpython/build/Python-3.14.10 && patch --batch --fuzz=0 -p1 -i "$patchfile")
done
python /workspace/scripts/verify-runtime-source.py cpython/build/Python-3.14.10 /workspace/runtime-build/patched-source-manifest.json
touch cpython/build/Python-3.14.10/.patched
python /workspace/scripts/stage-native-inputs.py "$PWD"
# Exact official release bytes measured before review; no mutable SDK installer.
mkdir -p emsdk/emsdk
curl -fsSL https://storage.googleapis.com/webassembly/emscripten-releases-builds/linux/065bfade0ee2c02138b83cb10049d8be95e146b6/wasm-binaries.tar.xz -o "$work/toolchain.tar.xz"
echo "7ae996db24911edc535cccf069fb8a3ed63e8dac7abe58e758431abfe3255165  $work/toolchain.tar.xz" | sha256sum -c -
tar -xJf "$work/toolchain.tar.xz" -C "$work"
mv "$work/install" emsdk/emsdk/upstream
(cd emsdk/emsdk/upstream/emscripten && cat ../../../patches/*.patch | patch --batch --fuzz=0 -p1)
curl -fsSL https://nodejs.org/dist/v24.19.0/node-v24.19.0-linux-x64.tar.xz -o "$work/node.tar.xz"
echo "14b342e71204f811bde6153be8e04b62aef63c236fef92b55f9c83154b409647  $work/node.tar.xz" | sha256sum -c -
tar -xJf "$work/node.tar.xz" -C "$work"
export PATH="$work/node-v24.19.0-linux-x64/bin:$PWD/emsdk/emsdk/upstream/emscripten:$PATH"
export EM_CONFIG="$PWD/emsdk/emsdk/.emscripten"
printf "LLVM_ROOT = '%s/emsdk/emsdk/upstream/bin'\nBINARYEN_ROOT = '%s/emsdk/emsdk/upstream'\nNODE_JS = '%s/node-v24.19.0-linux-x64/bin/node'\n" "$PWD" "$PWD" "$work" > "$EM_CONFIG"
python - <<'INNER'
from pathlib import Path
import os,shlex
p=Path('emsdk/emsdk/emsdk_env.sh')
p.write_text('export EM_CONFIG='+shlex.quote(os.environ['EM_CONFIG'])+'\nexport PATH='+shlex.quote(os.environ['PATH'])+'\nunset _EMCC_CCACHE\n')
INNER
bash -n emsdk/emsdk/emsdk_env.sh
bash -c '. emsdk/emsdk/emsdk_env.sh; command -v emcc; emcc --version'
git diff --no-index --ignore-all-space emsdk/emsdk/upstream/emscripten/src/struct_info_generated.json src/js/struct_info_generated.json
touch emsdk/emsdk/.complete
emcc --version | tee "$proof/emcc-version.txt"
node --version | tee "$proof/node-version.txt"
emcc --version | head -1 | grep -F '5.0.3'
# Core only; no scientific wheel rebuild, browser or deployment in this job.
make -n all-but-packages > "$proof/make-core-plan.txt"
! grep -E 'pip install|wget|emsdk install|git clone --depth 1 https://github.com/emscripten-core/emsdk' "$proof/make-core-plan.txt"
make -j4 all-but-packages
mkdir -p "$proof/dist"
cp -a dist/. "$proof/dist/"
git diff --binary > "$proof/source-changes.diff"
git submodule status --recursive > "$proof/submodule-status.txt"
cp /workspace/runtime-build/*.json "$proof/"
