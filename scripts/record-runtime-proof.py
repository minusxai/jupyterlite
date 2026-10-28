import datetime,hashlib,json,os,pathlib,subprocess,sys
root,proof=map(pathlib.Path,sys.argv[1:])
inputs={str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest() for f in root.rglob('*') if f.is_file() and '.git' not in f.parts and 'node_modules' not in f.parts}
(proof/'resolved-build-inputs.json').write_text(json.dumps(inputs,sort_keys=True,indent=2))
# Log remains open in the outer tee; final artifact manifest binds it after exit.
files={str(f.relative_to(proof)):hashlib.sha256(f.read_bytes()).hexdigest() for f in proof.rglob('*') if f.is_file() and f.name not in {'receipt.json','artifact-manifest.json','build.log'}}
(proof/'receipt.json').write_text(json.dumps({'checked_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'build_exit':os.environ.get('RUNTIME_BUILD_EXIT','pending'),'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'files':files,'scope':'Core build only. Package/browser/JSPI/security regression proof pending; no runtime all-clear.'},indent=2))
