"""Check the browser-side Plotly pin and the notebook's plotting API."""

import json
import re
from importlib.resources import files
from pathlib import Path

import pandas as pd
import plotly
import plotly.express as px
from packaging.version import Version

notebook = json.loads(Path("content/minusx_demo.ipynb").read_text())
setup_source = next(
    "".join(cell["source"])
    for cell in notebook["cells"]
    if "piplite.install" in "".join(cell.get("source", []))
)
assert '"plotly==5.17.0"' in setup_source
assert Version(plotly.__version__) >= Version("5.17.0")

bundle = files("plotly").joinpath("package_data", "plotly.min.js").read_text()
match = re.search(r"plotly\.js v(\d+\.\d+\.\d+)", bundle)
assert match, "could not determine the embedded Plotly.js version"
assert Version(match.group(1)) >= Version("2.25.2")

figure = px.bar(pd.DataFrame({"batch": ["W23", "S24"], "count": [2, 3]}), x="batch", y="count")
assert len(figure.data) == 1
assert list(figure.data[0].y) == [2, 3]
assert figure.to_json()
print(f"Notebook Plotly pin and plotting smoke passed ({plotly.__version__}, Plotly.js {match.group(1)}).")
