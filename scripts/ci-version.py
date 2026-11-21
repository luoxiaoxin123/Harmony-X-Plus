import os
import re
from pathlib import Path


def main():
    path = Path("AppScope/app.json5")
    manifest = path.read_text(encoding="utf-8")
    base_version = re.search(r'"versionName"\s*:\s*"([^"]+)"', manifest)
    base_code = re.search(r'"versionCode"\s*:\s*(\d+)', manifest)
    if base_version is None or base_code is None:
        raise SystemExit("Missing app version in AppScope/app.json5")
    run = int(os.environ["GITHUB_RUN_NUMBER"])
    attempt = int(os.environ["GITHUB_RUN_ATTEMPT"])
    commit = os.environ["GITHUB_SHA"][:7]
    if not 0 < attempt < 100 or run < 1 or not re.fullmatch(r"[a-f0-9]{7}", commit):
        raise SystemExit("Invalid CI build identity")

    if os.environ["GITHUB_EVENT_NAME"] == "release":
        version = os.environ["GITHUB_REF_NAME"].removeprefix("v")
    else:
        version = f"{base_version[1]}-beta.{run}.{attempt}.g{commit}"
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?", version):
        raise SystemExit("Use a semantic release tag such as v4.0.0 or v4.0.0-rc.1")
    code = int(base_code[1]) + run * 100 + attempt
    if code > 2_147_483_647:
        raise SystemExit("Computed versionCode exceeds the supported range")
    manifest = manifest[:base_version.start(1)] + version + manifest[base_version.end(1):]
    manifest = re.sub(r'("versionCode"\s*:\s*)\d+', lambda match: f"{match[1]}{code}", manifest, count=1)
    path.write_text(manifest, encoding="utf-8")
    print(f"App version {version} ({code})")


if __name__ == "__main__":
    main()
