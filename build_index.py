import json
import re
from collections import defaultdict
from pathlib import Path
from packaging import version


def parse_version_files(directory="."):
    # Get the base directory as a Path object
    base_path = Path(directory)

    # Organize by package
    packages = defaultdict(lambda: {"stable": None, "preview": None})

    # Iterate through directories in the base path
    for package_dir in [d for d in base_path.iterdir() if d.is_dir()]:
        package_name = package_dir.name

        # Find all .txt files in this package directory
        for version_file in package_dir.glob("*.txt"):
            # Extract version string from filename
            version_str = version_file.stem

            # Use packaging.version to parse the version string
            parsed_version = version.parse(version_str)

            # Check if version is a preview (is a pre-release in packaging terminology)
            if parsed_version.is_prerelease:
                if (
                    packages[package_name]["preview"] is None
                    or version.parse(packages[package_name]["preview"]) < parsed_version
                ):
                    packages[package_name]["preview"] = version_str
            else:
                if (
                    packages[package_name]["stable"] is None
                    or version.parse(packages[package_name]["stable"]) < parsed_version
                ):
                    packages[package_name]["stable"] = version_str

    return dict(packages)


if __name__ == "__main__":
    print(json.dumps(parse_version_files(), indent=2))
