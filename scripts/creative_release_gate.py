#!/usr/bin/env python3
"""Local no-secrets release gate for the embedded OpenTU Creative artifact.

Default sibling layout:
  new2fly/   (this orchestration repo)
  opentu/    (frontend source + dist/apps/web)
  new-api/   (embedded web/creative/dist copies)

Generated artifact policy:
  - For source whitespace, run source-only git diff checks outside generated dist.
  - For generated Creative dist, the gate checks byte identity across the OpenTU
    dist and both new-api embedded copies. Do not hand-edit only one generated
    copy to appease whitespace tooling.
  - Sourcemaps are policy controlled. The default is to allow generated maps;
    pass --sourcemap-policy forbid if the release forbids production maps.

This script does not read secrets and does not call provider/payment/CDN or
production endpoints. Build/test commands are local process commands only.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from html.parser import HTMLParser
from pathlib import Path
from typing import Iterable

CREATIVE_BASE = "/creative/"
ENTRY_REF_PATTERN = re.compile(r"[\"'](?P<ref>/creative/assets/[^\"']+\.(?:js|css))(?:\?[^\"']*)?[\"']")
BAD_RELATIVE_ENTRY_PATTERN = re.compile(r"[\"']\.\/assets\/[^\"']+\.(?:js|css)(?:\?[^\"']*)?[\"']")
BAD_ROOT_ENTRY_PATTERN = re.compile(r"[\"']/assets/[^\"']+\.(?:js|css)(?:\?[^\"']*)?[\"']")
GIT_COMMIT_PATTERN = re.compile(r"^[0-9a-f]{7,64}$", re.IGNORECASE)
EMBEDDED_FORBIDDEN_TEXT_MARKERS = (
    "sourceMappingURL=",
    "node_modules/.pnpm",
    "packages/drawnix/src",
    "sw-debug.html",
    "cdn-debug.html",
    "menu.debugPanel",
)
EMBEDDED_FORBIDDEN_TEXT_PATTERNS = (
    re.compile(r"/mnt/[^\\s'\"<>]+"),
)
EMBEDDED_STANDALONE_HTML_FILES = (
    "home.html",
    "en/home.html",
    "versions.html",
    "iframe-test.html",
    "sw-debug.html",
    "cdn-debug.html",
)
EMBEDDED_STANDALONE_MARKERS = (
    "opentu.ai",
    "github.com/ljquan/aitu",
    "api.tu-zi.com",
    "wiki.tu-zi.com",
    "aitu-app",
    "product_showcase",
    "user-manual",
    "OpenTu.ai",
    "OpenTu",
    "OpenTU",
    "Opentu",
    "API Key",
    "GitHub Gist",
    "GitHub Token",
    "用户反馈群",
    "用户手册",
)
EMBEDDED_FORBIDDEN_STATIC_PATHS = (
    "stats.html",
    "product_showcase",
    "user-manual",
    "sw-debug",
    "logo-tuzi.png",
    "logo/group-qr.png",
    "logo/cardid.jpg",
)


class EmbeddedIndexStructureParser(HTMLParser):
    """Minimal generated-index structure guard.

    The embedded cleanup rewrites static HTML after Vite emits it. A malformed
    boot-card replacement can accidentally leave #root inside #app-boot-loading;
    the boot script then removes the React root together with the loading shell.
    This parser intentionally checks source nesting so the release gate fails
    before Docker/staging smoke gets a blank page.
    """

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.stack: list[tuple[str, str | None]] = []
        self.root_seen = False
        self.root_inside_boot = False
        self.boot_seen = False
        self.boot_title_seen = False
        self.boot_progress_seen = False
        self.new_api_boot_mark_seen = False

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attr_map = dict(attrs)
        node_id = attr_map.get("id")
        class_name = attr_map.get("class") or ""

        if node_id == "app-boot-loading":
            self.boot_seen = True
        if "data-app-boot-title" in attr_map:
            self.boot_title_seen = True
        if "data-app-boot-progress" in attr_map:
            self.boot_progress_seen = True
        if (
            tag == "span"
            and "app-boot-mark" in class_name.split()
            and "data-official-site-link" in attr_map
        ):
            self.new_api_boot_mark_seen = True

        if node_id == "root":
            self.root_seen = True
            if any(stacked_id == "app-boot-loading" for _, stacked_id in self.stack):
                self.root_inside_boot = True

        # Track regular elements closely enough for div/main/span/source nesting.
        if tag not in {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}:
            self.stack.append((tag, node_id))

    def handle_endtag(self, tag: str) -> None:
        for index in range(len(self.stack) - 1, -1, -1):
            if self.stack[index][0] == tag:
                del self.stack[index:]
                return


@dataclass(frozen=True)
class Layout:
    opentu: Path
    new_api: Path

    @property
    def source_dist(self) -> Path:
        return self.opentu / "dist" / "apps" / "web"

    @property
    def root_dist(self) -> Path:
        return self.new_api / "web" / "creative" / "dist"

    @property
    def router_dist(self) -> Path:
        return self.new_api / "router" / "web" / "creative" / "dist"

    @property
    def all_dists(self) -> list[tuple[str, Path]]:
        return [
            ("opentu", self.source_dist),
            ("new-api:web", self.root_dist),
            ("new-api:router", self.router_dist),
        ]


def repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def default_layout() -> Layout:
    parent = repo_root().parent
    return Layout(opentu=parent / "opentu", new_api=parent / "new-api")


def run(cmd: list[str], *, cwd: Path, env: dict[str, str] | None = None) -> None:
    printable = " ".join(cmd)
    print(f"[run] ({cwd}) {printable}", flush=True)
    subprocess.run(cmd, cwd=str(cwd), env=env, check=True)


def require_dir(path: Path, label: str) -> None:
    if not path.is_dir():
        raise SystemExit(f"{label} not found or not a directory: {path}")


def build_opentu(layout: Layout) -> None:
    require_dir(layout.opentu, "opentu repo")
    env = os.environ.copy()
    env["VITE_BASE_URL"] = CREATIVE_BASE
    run(["pnpm", "build:web"], cwd=layout.opentu, env=env)


def sync_dist(layout: Layout) -> None:
    require_dir(layout.source_dist, "opentu dist")
    for label, target in [("new-api:web", layout.root_dist), ("new-api:router", layout.router_dist)]:
        print(f"[sync] {layout.source_dist} -> {target} ({label})", flush=True)
        if target.exists():
            shutil.rmtree(target)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(layout.source_dist, target, symlinks=False)


def iter_files(root: Path) -> Iterable[Path]:
    for path in sorted(root.rglob("*")):
        if path.is_file():
            yield path


def tree_hashes(root: Path) -> dict[str, str]:
    require_dir(root, "dist tree")
    hashes: dict[str, str] = {}
    for path in iter_files(root):
        rel = path.relative_to(root).as_posix()
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        hashes[rel] = digest
    return hashes


def check_identity(layout: Layout) -> None:
    trees = [(label, path, tree_hashes(path)) for label, path in layout.all_dists]
    baseline_label, baseline_path, baseline = trees[0]
    print(f"[check] {baseline_label} file count: {len(baseline)} ({baseline_path})")
    for label, path, candidate in trees[1:]:
        if set(candidate) != set(baseline):
            missing = sorted(set(baseline) - set(candidate))[:20]
            extra = sorted(set(candidate) - set(baseline))[:20]
            raise SystemExit(
                f"dist file list mismatch for {label} ({path})\n"
                f"  missing(first20)={missing}\n  extra(first20)={extra}"
            )
        mismatched = sorted(rel for rel, digest in baseline.items() if candidate[rel] != digest)
        if mismatched:
            raise SystemExit(
                f"dist hash mismatch for {label} ({path}); first mismatches: {mismatched[:20]}"
            )
        print(f"[check] {label} matches {baseline_label}: {len(candidate)} files")


def check_version_provenance(layout: Layout) -> None:
    versions: list[tuple[str, dict[str, object]]] = []
    for label, dist in layout.all_dists:
        path = dist / "version.json"
        if not path.is_file():
            raise SystemExit(f"{label} version.json missing: {path}")
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            raise SystemExit(f"{label} version.json is not valid JSON: {exc}") from exc

        version = str(payload.get("version") or "").strip()
        build_time = str(payload.get("buildTime") or "").strip()
        git_commit = str(payload.get("gitCommit") or "").strip()
        if not version:
            raise SystemExit(f"{label} version.json has empty version")
        if not build_time:
            raise SystemExit(f"{label} version.json has empty buildTime")
        if git_commit.lower() == "unknown" or not GIT_COMMIT_PATTERN.match(git_commit):
            raise SystemExit(
                f"{label} version.json has invalid gitCommit {git_commit!r}; "
                "embedded provenance must be a concrete git commit"
            )
        versions.append((label, payload))

    baseline_label, baseline = versions[0]
    for label, payload in versions[1:]:
        if payload != baseline:
            raise SystemExit(
                f"{label} version.json differs from {baseline_label}; "
                "all embedded Creative dist trees must carry identical provenance"
            )
    print(
        f"[check] version provenance: version={baseline['version']} "
        f"gitCommit={baseline['gitCommit']}"
    )


def check_index_contract(layout: Layout) -> None:
    for label, dist in layout.all_dists:
        index = dist / "index.html"
        if not index.is_file():
            raise SystemExit(f"{label} index.html missing: {index}")
        body = index.read_text(encoding="utf-8")
        refs = [m.group("ref") for m in ENTRY_REF_PATTERN.finditer(body)]
        if not refs:
            raise SystemExit(f"{label} index.html does not reference /creative/assets/*.js|css entries")
        if BAD_RELATIVE_ENTRY_PATTERN.search(body):
            raise SystemExit(f"{label} index.html contains ./assets entry refs; rebuild with VITE_BASE_URL=/creative/")
        if BAD_ROOT_ENTRY_PATTERN.search(body):
            raise SystemExit(f"{label} index.html contains root /assets entry refs; rebuild with VITE_BASE_URL=/creative/")
        has_js = any(ref.split("?", 1)[0].endswith(".js") for ref in refs)
        has_css = any(ref.split("?", 1)[0].endswith(".css") for ref in refs)
        if not has_js or not has_css:
            raise SystemExit(f"{label} index.html must reference at least one JS and one CSS entry under /creative/assets/")
        parser = EmbeddedIndexStructureParser()
        parser.feed(body)
        if not parser.root_seen:
            raise SystemExit(f"{label} index.html is missing #root; embedded app would not mount")
        if parser.root_inside_boot:
            raise SystemExit(
                f"{label} index.html has #root nested inside #app-boot-loading; "
                "the boot loader would remove the React root and produce a blank page"
            )
        if not parser.boot_seen or not parser.boot_title_seen or not parser.boot_progress_seen:
            raise SystemExit(
                f"{label} index.html boot shell is malformed; expected app boot title and progress nodes"
            )
        if not parser.new_api_boot_mark_seen:
            raise SystemExit(
                f"{label} index.html boot mark was not rewritten to New API Creative safely"
            )
        print(f"[check] {label} embedded index refs: {len(refs)} /creative/assets entries")


def iter_json_strings(value: object) -> Iterable[str]:
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for item in value:
            yield from iter_json_strings(item)
    elif isinstance(value, dict):
        for item in value.values():
            yield from iter_json_strings(item)


def check_manifest_asset_contract(layout: Layout) -> None:
    manifest_names = ["precache-manifest.json", "idle-prefetch-manifest.json"]
    for label, dist in layout.all_dists:
        for manifest_name in manifest_names:
            manifest = dist / manifest_name
            if not manifest.is_file():
                continue
            body = manifest.read_text(encoding="utf-8")
            try:
                parsed = json.loads(body)
            except json.JSONDecodeError as exc:
                raise SystemExit(f"{label} {manifest_name} is not valid JSON: {exc}") from exc
            root_asset_refs = sorted(
                {ref for ref in iter_json_strings(parsed) if ref.startswith("/assets/")}
            )
            if root_asset_refs:
                raise SystemExit(
                    f"{label} {manifest_name} contains root /assets refs; "
                    f"embedded manifests must use /creative/assets. first refs: {root_asset_refs[:20]}"
                )
            creative_asset_refs = sum(
                1 for ref in iter_json_strings(parsed) if ref.startswith("/creative/assets/")
            )
            if creative_asset_refs == 0:
                raise SystemExit(
                    f"{label} {manifest_name} contains no /creative/assets refs; "
                    "embedded manifests must keep Creative asset URLs."
                )
            print(
                f"[check] {label} {manifest_name}: {creative_asset_refs} /creative/assets refs"
            )


def check_embedded_static_brand_contract(layout: Layout) -> None:
    for label, dist in layout.all_dists:
        manifest_path = dist / "manifest.json"
        if manifest_path.is_file():
            try:
                manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            except json.JSONDecodeError as exc:
                raise SystemExit(f"{label} manifest.json is not valid JSON: {exc}") from exc
            if manifest.get("name") != "New API Creative" or manifest.get("short_name") != "Creative":
                raise SystemExit(
                    f"{label} manifest.json still exposes standalone app identity; "
                    "embedded builds must use New API Creative metadata."
                )

        for relative in EMBEDDED_FORBIDDEN_STATIC_PATHS:
            if (dist / relative).exists():
                raise SystemExit(
                    f"{label} contains standalone static path {relative!r}; "
                    "embedded artifacts must not ship standalone docs/showcase/feedback assets."
                )

        text_files = [
            "index.html",
            "manifest.json",
            "_headers",
            "_redirects",
            "robots.txt",
            "sitemap.xml",
            "cdn-config.js",
            "changelog.json",
            "sw.js",
            *EMBEDDED_STANDALONE_HTML_FILES,
        ]
        for relative in text_files:
            path = dist / relative
            if not path.is_file():
                continue
            body = path.read_text(encoding="utf-8", errors="ignore")
            lower_body = body.lower()
            for marker in EMBEDDED_STANDALONE_MARKERS:
                haystack = lower_body if marker.islower() else body
                needle = marker if marker.islower() else marker
                if needle in haystack:
                    raise SystemExit(
                        f"{label} {relative} contains standalone marker {marker!r}; "
                        "embedded artifacts must not expose OpenTU/GitHub standalone surfaces."
                    )
        print(f"[check] {label} embedded static brand contract holds")


def check_sourcemaps(layout: Layout, policy: str) -> None:
    maps: list[str] = []
    for label, dist in layout.all_dists:
        maps.extend(f"{label}:{path.relative_to(dist).as_posix()}" for path in dist.rglob("*.map"))
    if maps and policy == "forbid":
        raise SystemExit(f"sourcemap policy forbids generated maps; found first entries: {maps[:20]}")
    if maps:
        print(f"[policy] sourcemap-policy=allow; generated maps present: {len(maps)}")
    else:
        print("[policy] no generated sourcemaps found")


def check_dist_text_hygiene(layout: Layout) -> None:
    findings: list[str] = []
    for label, dist in layout.all_dists:
        for path in iter_files(dist):
            relative = path.relative_to(dist).as_posix()
            if relative in {"stats.html", "sw-debug.html", "cdn-debug.html"}:
                findings.append(f"{label}:{relative}: forbidden debug analysis artifact")
                continue
            try:
                body = path.read_text(encoding="utf-8", errors="ignore")
            except OSError as exc:
                raise SystemExit(f"{label}:{relative}: failed to read for hygiene scan: {exc}") from exc
            if not body:
                continue
            for marker in EMBEDDED_FORBIDDEN_TEXT_MARKERS:
                if marker in body:
                    findings.append(f"{label}:{relative}: contains {marker!r}")
            for pattern in EMBEDDED_FORBIDDEN_TEXT_PATTERNS:
                match = pattern.search(body)
                if match:
                    findings.append(f"{label}:{relative}: contains build path marker {match.group(0)!r}")
    if findings:
        raise SystemExit(
            "embedded dist hygiene check failed; first findings:\n  "
            + "\n  ".join(findings[:20])
        )
    print("[check] embedded dist text hygiene holds")


def run_new_api_tests(layout: Layout) -> None:
    require_dir(layout.new_api, "new-api repo")
    run(["go", "test", "-count=1", "."], cwd=layout.new_api)
    run(
        ["go", "test", "-count=1", "./router", "./middleware", "./controller", "./model", "./service", "./relay/..."],
        cwd=layout.new_api,
    )
    run(["go", "build", "./..."], cwd=layout.new_api)


def run_embedded_smoke(layout: Layout, base_url: str, timeout_ms: int | None) -> None:
    require_dir(layout.opentu, "opentu repo")
    env = os.environ.copy()
    env["CREATIVE_EMBEDDED_BASE_URL"] = base_url
    # The embedded smoke depends on its target URL; do not let Nx replay a
    # previous skipped/no-env result.
    env["NX_SKIP_NX_CACHE"] = "true"
    if timeout_ms is not None:
        env["DRAWNIX_READY_TIMEOUT_MS"] = str(timeout_ms)
    run(["pnpm", "e2e:creative-embedded"], cwd=layout.opentu, env=env)


def source_diff_check(layout: Layout) -> None:
    # Git pathspec exclusions intentionally omit generated dist trees. This keeps
    # whitespace policy focused on source while artifact policy is enforced by
    # check_identity(). Include this orchestration repo too because it owns the
    # release-gate script and Trellis policy docs.
    root = repo_root()
    if (root / ".git").is_dir():
        run(["git", "diff", "--check", "--", ":!.codex-flow/**", ":!.cache/**"], cwd=root)
    if (layout.opentu / ".git").is_dir():
        run(["git", "diff", "--check", "--", ":!dist/**"], cwd=layout.opentu)
    if (layout.new_api / ".git").is_dir():
        run(
            [
                "git",
                "diff",
                "--check",
                "--",
                ":!web/creative/dist/**",
                ":!router/web/creative/dist/**",
            ],
            cwd=layout.new_api,
        )


def check_all(layout: Layout, sourcemap_policy: str) -> None:
    for label, path in layout.all_dists:
        require_dir(path, f"{label} dist")
    check_index_contract(layout)
    check_manifest_asset_contract(layout)
    check_embedded_static_brand_contract(layout)
    check_identity(layout)
    check_version_provenance(layout)
    check_sourcemaps(layout, sourcemap_policy)
    check_dist_text_hygiene(layout)
    print("[ok] Creative embedded artifact contract holds")


def parse_args(argv: list[str]) -> argparse.Namespace:
    defaults = default_layout()
    parser = argparse.ArgumentParser(
        description="Build/sync/check the local OpenTU -> new-api embedded Creative artifact contract.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "action",
        nargs="?",
        choices=["check", "sync", "build-sync-check"],
        default="check",
        help="Action to perform. check is read-only; sync copies current dist; build-sync-check builds then syncs then checks.",
    )
    parser.add_argument("--opentu", type=Path, default=defaults.opentu, help="Path to the opentu repository")
    parser.add_argument("--new-api", type=Path, default=defaults.new_api, help="Path to the new-api repository")
    parser.add_argument(
        "--sourcemap-policy",
        choices=["allow", "forbid"],
        default="allow",
        help="Whether generated *.map files are allowed in the embedded artifact.",
    )
    parser.add_argument("--run-new-api-tests", action="store_true", help="Run selected new-api Go tests/build after artifact checks")
    parser.add_argument("--source-diff-check", action="store_true", help="Run source-only git diff --check in opentu and new-api")
    parser.add_argument(
        "--embedded-smoke-url",
        help="Optional local new-api Creative base URL (for example http://localhost:3000/creative/) for pnpm e2e:creative-embedded",
    )
    parser.add_argument(
        "--drawnix-ready-timeout-ms",
        type=int,
        help="Optional DRAWNIX_READY_TIMEOUT_MS override passed to Playwright smoke commands",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    layout = Layout(opentu=args.opentu.resolve(), new_api=args.new_api.resolve())

    if args.action == "build-sync-check":
        build_opentu(layout)
        sync_dist(layout)
    elif args.action == "sync":
        sync_dist(layout)

    check_all(layout, args.sourcemap_policy)

    if args.source_diff_check:
        source_diff_check(layout)
    if args.run_new_api_tests:
        run_new_api_tests(layout)
    if args.embedded_smoke_url:
        run_embedded_smoke(layout, args.embedded_smoke_url, args.drawnix_ready_timeout_ms)

    print("[done] no-secrets Creative release gate completed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
