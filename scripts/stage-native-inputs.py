import pathlib,sys,json,urllib.request,hashlib
root=pathlib.Path(sys.argv[1]);items=json.load(open('/workspace/runtime-build/native-inputs.json'));mf=root/'cpython/Makefile';text=mf.read_text()
for item,var in zip(items,['LZMATARBALL','ZSTDTARBALL','SQLITE3TARBALL']):
    data=urllib.request.urlopen(item['url'],timeout=60).read()
    assert hashlib.sha256(data).hexdigest()==item['sha256']
    archive=root/'cpython/downloads'/(item['name']+'.tar.gz');archive.write_bytes(data)
    old='wget -q -O - $('+var+') | tar -xz --strip-components=1'
    assert text.count(old)==1
    text=text.replace(old,'tar -xzf '+str(archive)+' --strip-components=1')
old='CONFIG_SITE_FILE=./Tools/wasm/emscripten/config.site-wasm32-emscripten'
new='CONFIG_SITE_FILE=./Platforms/emscripten/config.site-wasm32-emscripten'
assert text.count(old)==1
assert (root/'cpython/build/Python-3.14.10/Platforms/emscripten/config.site-wasm32-emscripten').is_file()
text=text.replace(old,new)
mf.write_text(text)
