Scaffold Developer Checklist

1. Create a virtual environment (recommended name: .venv)
   - Windows PowerShell:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

2. Install dev dependencies:

```powershell
python -m pip install -r requirements-dev.txt
```

3. Run tests:

```powershell
python -m pytest
```

4. Format with black:

```powershell
python -m black src tests
```

5. Lint with flake8:

```powershell
python -m flake8 src tests
```

6. Install and enable pre-commit hooks (recommended):

```powershell
python -m pip install pre-commit
pre-commit install
# optional: run the hooks once against the repo
pre-commit run --all-files
```

7. Optional: initialize git and make initial commit

```powershell
git init
git add .
git commit -m "Initial scaffold"
```

8. (If you changed numbering) Adjust numbering for subsequent steps as needed.

6. Optional: initialize git and make initial commit

```powershell
git init
git add .
git commit -m "Initial scaffold"
```
