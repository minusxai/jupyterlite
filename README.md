<img src="https://raw.githubusercontent.com/minusxai/.github/master/profile/logo.png" alt="logo" width="400"/>

# MinusX Research Preview

#### Links
- **Live Demo:** [minusxai.github.io/jupyterlite](https://minusxai.github.io/jupyterlite/lab/index.html)
- **Chrome Extension:** [chrome webstore](https://minusx.ai/chrome-extension)
- **Features, Demo, Roadmap:** [minusx.ai](https://minusx.ai)
- **Support/Discussion:** [Discord Invite](https://discord.com/invite/jtFeyPMDcH)

## Build environment

Use Python 3.11.17 and uv 0.13.4 or later for a reproducible Linux x86_64 build. From the repository root:

```bash
uv venv --python 3.11.17 .venv
uv pip sync --python .venv/bin/python requirements-linux-py311.lock.txt
uv pip check --python .venv/bin/python
.venv/bin/python tests/check_notebook_plotly.py
cp README.md content
.venv/bin/jupyter lite build --contents content --output-dir dist
```

`requirements.txt` remains the editable dependency input. The notebook's browser-side packages are installed by its Pyodide setup cell and are checked separately from the native JupyterLite build lock.
