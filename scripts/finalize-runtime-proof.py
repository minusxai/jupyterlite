import hashlib,json,pathlib,sys
proof=pathlib.Path(sys.argv[1]);files={str(f.relative_to(proof)):hashlib.sha256(f.read_bytes()).hexdigest() for f in proof.rglob('*') if f.is_file() and f.name!='artifact-manifest.json'}
(proof/'artifact-manifest.json').write_text(json.dumps(files,sort_keys=True,indent=2))
