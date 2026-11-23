import json
import os
import re
import subprocess
from datetime import datetime


def actions_api(path, *filters):
    endpoint = f"repos/{os.environ['GITHUB_REPOSITORY']}/actions/{path}"
    return json.loads(subprocess.check_output(["gh", "api", "--method", "GET", endpoint, *filters]))


def commit_sha(value):
    if not re.fullmatch(r"[0-9a-f]{40}", value):
        raise ValueError("expected a full commit SHA")
    return value


def finished_build(run):
    jobs = actions_api(f"runs/{run['id']}/attempts/{run['run_attempt']}/jobs")["jobs"]
    if not isinstance(jobs, list):
        raise ValueError("expected a list of jobs for the prior run attempt")
    completed = {job["name"]: job for job in jobs if job["status"] == "completed"}
    build = completed.get("build")
    if build is None:
        return False

    # A successful preflight can skip the build only after proving coverage of this same SHA.
    if build["conclusion"] == "skipped":
        preflight = completed.get("nightly-preflight", {})
        return run["conclusion"] == "success" and preflight.get("conclusion") == "success"

    # Only the Xcode steps in build.yml count, not failures to set up the runner or SwiftLint.
    steps = {step["name"]: step["conclusion"] for step in build["steps"] if step["status"] == "completed"}
    outcomes = [steps.get(name) for name in (
        "Build the iOS app", "Build the tvOS app", "Compile the tvOS app for a device"
    )]
    return (build["conclusion"] == "success" and all(outcome == "success" for outcome in outcomes)
            or build["conclusion"] == "failure" and "failure" in outcomes)


def main():
    sha = commit_sha(os.environ["GITHUB_SHA"])
    run_id = int(os.environ["GITHUB_RUN_ID"])
    branch = os.environ["GITHUB_REF_NAME"]
    current = actions_api(f"runs/{run_id}")
    if (current["id"], current["event"], current["head_branch"], current["head_sha"]) != (
        run_id, "schedule", branch, sha
    ):
        raise ValueError("current run does not match the scheduled workflow context")

    workflow_id = int(current["workflow_id"])
    cutoff = datetime.fromisoformat(current["created_at"])
    history = actions_api(
        f"workflows/{workflow_id}/runs", "-f", f"branch={branch}", "-f", "event=schedule",
        "-f", "status=completed", "-f", f"created=<={current['created_at']}", "-F", "per_page=100",
    )["workflow_runs"]
    if not isinstance(history, list):
        raise ValueError("expected a list of prior runs for this workflow")
    run_build = True
    for prior in sorted(history, key=lambda run: run["run_number"], reverse=True):
        if (prior["id"] == run_id or prior["run_number"] >= current["run_number"]
                or prior["workflow_id"] != workflow_id or prior["head_branch"] != branch
                or prior["event"] != "schedule" or prior["status"] != "completed"
                or prior["conclusion"] not in ("success", "failure")
                or datetime.fromisoformat(prior["updated_at"]) >= cutoff):
            continue
        previous_sha = commit_sha(prior["head_sha"])
        if finished_build(prior):
            run_build = previous_sha != sha
            print(f"Prior completed nightly {prior['id']} checked {previous_sha}; current SHA is {sha}.")
            break
    else:
        print("No qualifying completed nightly in the latest scheduled history; building this commit.")

    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
        output.write(f"run={'true' if run_build else 'false'}\n")


if __name__ == "__main__":
    main()
