#!/usr/bin/env python3
"""
Research Note Generator
=======================
Automatically detects project changes and generates dated research note entries.
Supports daily/weekly reports, email/Slack notifications, and auto-pause.

Usage:
    python generate_note.py                          # Daily run (all projects)
    python generate_note.py --project test_project   # Single project
    python generate_note.py --init test_project      # Initialize note
    python generate_note.py --dry-run                # Preview only
    python generate_note.py --send                   # Force send notification
    python generate_note.py --weekly                 # Generate weekly report
    python generate_note.py --date 2026-02-07        # Override date (testing)
"""

import argparse
import datetime
import email.mime.multipart
import email.mime.text
import fnmatch
import hashlib
import json
import os
import smtplib
import subprocess
import sys
import urllib.request
import urllib.error
from pathlib import Path
from typing import Optional

import yaml

# ============================================================================
# Configuration
# ============================================================================

DEFAULT_CONFIG_PATH = Path(__file__).parent / "config.yaml"


def load_config(config_path: str = None) -> dict:
    path = Path(config_path) if config_path else DEFAULT_CONFIG_PATH
    if not path.exists():
        print(f"[ERROR] Config not found: {path}")
        sys.exit(1)
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def get_date(config: dict) -> datetime.date:
    return config.get("_date_override", datetime.date.today())


# ============================================================================
# Change Detection
# ============================================================================

class ChangeDetector:
    def __init__(self, project_config: dict, state_dir: Path):
        self.name = project_config["name"]
        self.path = Path(project_config["path"]).resolve()
        self.detection = project_config.get("detection", "auto")
        self.include = project_config.get("include_patterns", ["**/*"])
        self.exclude = list(project_config.get("exclude_patterns", []))
        # Auto-exclude: generated files (note + daily files)
        self._exclude_basenames = {"RESEARCH_NOTE.md"}
        self._exclude_dirs = {"daily", "__pycache__"}
        self.state_dir = state_dir
        self.state_file = state_dir / f"{self.name}_state.json"

    def detect(self) -> dict:
        if self.detection == "git":
            return self._detect_git()
        elif self.detection == "mtime":
            return self._detect_mtime()
        else:
            return self._detect_git() if self._is_git_repo() else self._detect_mtime()

    def _is_git_repo(self) -> bool:
        try:
            r = subprocess.run(
                ["git", "rev-parse", "--is-inside-work-tree"],
                cwd=self.path, capture_output=True, text=True, timeout=5
            )
            return r.returncode == 0
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return False

    def _detect_git(self) -> dict:
        changes = {
            "method": "git", "project": self.name, "path": str(self.path),
            "date": datetime.date.today().isoformat(),
            "modified": [], "new": [], "deleted": [], "commits": [], "diffs": {}, "stats": {},
        }
        first_run = not self.state_file.exists()
        since = self._get_last_run_date() or "yesterday"
        try:
            # First run: get ALL commits; subsequent: only since last run
            if first_run:
                r = subprocess.run(
                    ["git", "log", "--oneline", "--no-merges"],
                    cwd=self.path, capture_output=True, text=True, timeout=30
                )
            else:
                r = subprocess.run(
                    ["git", "log", f"--since={since}", "--oneline", "--no-merges"],
                    cwd=self.path, capture_output=True, text=True, timeout=30
                )
            if r.returncode == 0 and r.stdout.strip():
                changes["commits"] = [l.strip() for l in r.stdout.strip().split("\n") if l.strip()]

            if first_run:
                # First run: list ALL tracked files as "new"
                r = subprocess.run(
                    ["git", "ls-files"],
                    cwd=self.path, capture_output=True, text=True, timeout=30
                )
                if r.returncode == 0 and r.stdout.strip():
                    for f in r.stdout.strip().split("\n"):
                        if f.strip() and self._match(f.strip()):
                            changes["new"].append(f.strip())
            else:
                r = subprocess.run(
                    ["git", "diff", "--name-status", "HEAD~1"],
                    cwd=self.path, capture_output=True, text=True, timeout=30
                )
                if r.returncode != 0 or not r.stdout.strip():
                    r = subprocess.run(
                        ["git", "diff", "--name-status"],
                        cwd=self.path, capture_output=True, text=True, timeout=30
                    )
                    u = subprocess.run(
                        ["git", "ls-files", "--others", "--exclude-standard"],
                        cwd=self.path, capture_output=True, text=True, timeout=30
                    )
                    if u.returncode == 0 and u.stdout.strip():
                        for f in u.stdout.strip().split("\n"):
                            if f.strip() and self._match(f.strip()):
                                changes["new"].append(f.strip())

                if r.returncode == 0 and r.stdout.strip():
                    for line in r.stdout.strip().split("\n"):
                        if not line.strip():
                            continue
                        parts = line.split("\t", 1)
                        if len(parts) < 2:
                            continue
                        status, fp = parts[0].strip(), parts[1].strip()
                        if not self._match(fp):
                            continue
                        if status.startswith("M"):
                            changes["modified"].append(fp)
                        elif status.startswith("A"):
                            changes["new"].append(fp)
                        elif status.startswith("D"):
                            changes["deleted"].append(fp)

                for fp in changes["modified"][:20]:
                    dr = subprocess.run(
                        ["git", "diff", "HEAD~1", "--", fp],
                        cwd=self.path, capture_output=True, text=True, timeout=10
                    )
                    if dr.returncode == 0 and dr.stdout.strip():
                        changes["diffs"][fp] = "\n".join(dr.stdout.strip().split("\n")[:50])

            changes["stats"] = self._get_file_stats()
        except (subprocess.TimeoutExpired, FileNotFoundError) as e:
            changes["error"] = str(e)
        return changes

    def _detect_mtime(self) -> dict:
        changes = {
            "method": "mtime", "project": self.name, "path": str(self.path),
            "date": datetime.date.today().isoformat(),
            "modified": [], "new": [], "deleted": [], "commits": [], "diffs": {}, "stats": {},
        }
        current = self._scan_files()
        previous = self._load_state()

        if previous:
            prev_set, curr_set = set(previous.keys()), set(current.keys())
            changes["new"] = sorted(curr_set - prev_set)
            changes["deleted"] = sorted(prev_set - curr_set)
            for f in curr_set & prev_set:
                if current[f]["hash"] != previous[f]["hash"]:
                    changes["modified"].append(f)
            changes["modified"].sort()
        else:
            changes["new"] = sorted(current.keys())

        self._save_state(current)
        changes["stats"] = self._get_file_stats()
        return changes

    def _scan_files(self) -> dict:
        files = {}
        for pattern in self.include:
            for fp in self.path.glob(pattern):
                if not fp.is_file():
                    continue
                rel = str(fp.relative_to(self.path))
                if self._should_exclude(rel):
                    continue
                try:
                    h = hashlib.md5(fp.read_bytes()).hexdigest()
                    files[rel] = {"hash": h, "mtime": fp.stat().st_mtime, "size": fp.stat().st_size}
                except (PermissionError, OSError):
                    continue
        return files

    def _match(self, fp: str) -> bool:
        if self._should_exclude(fp):
            return False
        for p in self.include:
            if fnmatch.fnmatch(fp, p):
                return True
            # **/ prefix: also match root-level files (e.g. **/*.py matches main.py)
            if p.startswith("**/") and fnmatch.fnmatch(fp, p[3:]):
                return True
        return False

    def _should_exclude(self, fp: str) -> bool:
        # Auto-exclude by basename
        if os.path.basename(fp) in self._exclude_basenames:
            return True
        # Auto-exclude by directory component
        parts = fp.replace("\\", "/").split("/")
        if any(d in self._exclude_dirs for d in parts[:-1]):
            return True
        # User-defined patterns (fnmatch + ** handling)
        for pattern in self.exclude:
            if fnmatch.fnmatch(fp, pattern):
                return True
            if "**" in pattern:
                simple = pattern.replace("**/", "").replace("/**", "").strip("/")
                if simple in parts:
                    return True
        return False

    def _get_file_stats(self) -> dict:
        stats = {"total_files": 0, "total_lines": 0, "by_extension": {}}
        for pattern in self.include:
            for fp in self.path.glob(pattern):
                if not fp.is_file() or self._should_exclude(str(fp.relative_to(self.path))):
                    continue
                ext = fp.suffix or "no_ext"
                if ext not in stats["by_extension"]:
                    stats["by_extension"][ext] = {"files": 0, "lines": 0}
                stats["total_files"] += 1
                stats["by_extension"][ext]["files"] += 1
                try:
                    lc = sum(1 for _ in open(fp, "r", errors="ignore"))
                    stats["total_lines"] += lc
                    stats["by_extension"][ext]["lines"] += lc
                except (PermissionError, OSError):
                    pass
        return stats

    def _load_state(self) -> Optional[dict]:
        if self.state_file.exists():
            with open(self.state_file, "r") as f:
                return json.load(f)
        return None

    def _save_state(self, state: dict):
        self.state_dir.mkdir(parents=True, exist_ok=True)
        with open(self.state_file, "w") as f:
            json.dump(state, f, indent=2)

    def _get_last_run_date(self) -> Optional[str]:
        if self.state_file.exists():
            mt = datetime.datetime.fromtimestamp(self.state_file.stat().st_mtime)
            return mt.strftime("%Y-%m-%d")
        return None


# ============================================================================
# Idle Detector
# ============================================================================

class IdleDetector:
    def __init__(self, config: dict, state_dir: Path):
        self.enabled = config.get("idle", {}).get("enabled", False)
        self.pause_days = config.get("idle", {}).get("pause_after_days", 7)
        self.notify_on_pause = config.get("idle", {}).get("notify_on_pause", True)
        self.auto_resume = config.get("idle", {}).get("auto_resume", True)
        self.state_dir = state_dir

    def check(self, project_name: str, has_changes: bool) -> dict:
        """Returns {'should_run': bool, 'paused': bool, 'idle_days': int, 'just_resumed': bool}"""
        if not self.enabled:
            return {"should_run": True, "paused": False, "idle_days": 0, "just_resumed": False}

        idle_file = self.state_dir / f"{project_name}_idle.json"
        state = {}
        if idle_file.exists():
            with open(idle_file, "r") as f:
                state = json.load(f)

        today = datetime.date.today().isoformat()
        last_change = state.get("last_change_date", today)
        is_paused = state.get("paused", False)
        idle_days = (datetime.date.fromisoformat(today) - datetime.date.fromisoformat(last_change)).days

        result = {"should_run": True, "paused": False, "idle_days": idle_days, "just_resumed": False}

        if has_changes:
            state["last_change_date"] = today
            if is_paused:
                state["paused"] = False
                result["just_resumed"] = True
                print(f"  [RESUME] {project_name}: 변경 감지 → 자동 재개 ({idle_days}일 만)")
        else:
            if idle_days >= self.pause_days and not is_paused:
                state["paused"] = True
                result["should_run"] = False
                result["paused"] = True
                print(f"  [PAUSE] {project_name}: {idle_days}일간 변경 없음 → 자동 중단")
            elif is_paused:
                result["should_run"] = False
                result["paused"] = True

        with open(idle_file, "w") as f:
            json.dump(state, f)

        return result


# ============================================================================
# Note Generator
# ============================================================================

class AIBackendDetector:
    """Auto-detect available AI backends: claude_cli → anthropic_api → ollama.
    AI is REQUIRED - the tool cannot function without an AI backend."""

    _cache = {}  # Class-level cache for detection results

    @classmethod
    def check_claude_cli(cls) -> bool:
        if "claude_cli" not in cls._cache:
            try:
                r = subprocess.run(
                    ["claude", "--version"],
                    capture_output=True, text=True, timeout=10
                )
                cls._cache["claude_cli"] = r.returncode == 0
            except (subprocess.TimeoutExpired, FileNotFoundError):
                cls._cache["claude_cli"] = False
            if cls._cache["claude_cli"]:
                print("[AI] Claude CLI detected ✓")
        return cls._cache["claude_cli"]

    @classmethod
    def check_anthropic_api(cls) -> bool:
        if "anthropic_api" not in cls._cache:
            api_key = os.environ.get("ANTHROPIC_API_KEY", "")
            cls._cache["anthropic_api"] = bool(api_key)
            if cls._cache["anthropic_api"]:
                print("[AI] Anthropic API Key detected ✓")
        return cls._cache["anthropic_api"]

    @classmethod
    def check_ollama(cls) -> bool:
        if "ollama" not in cls._cache:
            try:
                req = urllib.request.Request("http://localhost:11434/api/tags")
                with urllib.request.urlopen(req, timeout=5) as resp:
                    data = json.loads(resp.read().decode())
                    models = [m["name"] for m in data.get("models", [])]
                    cls._cache["ollama"] = len(models) > 0
                    cls._cache["ollama_models"] = models
            except Exception:
                cls._cache["ollama"] = False
                cls._cache["ollama_models"] = []
            if cls._cache["ollama"]:
                print(f"[AI] Ollama detected ✓ (models: {', '.join(cls._cache['ollama_models'][:3])})")
        return cls._cache["ollama"]

    @classmethod
    def get_ollama_models(cls) -> list:
        cls.check_ollama()
        return cls._cache.get("ollama_models", [])

    @classmethod
    def install_ollama_model(cls, model: str = "llama3.1:8b") -> bool:
        """Pull an ollama model if not already available."""
        models = cls.get_ollama_models()
        if any(model in m for m in models):
            return True
        print(f"[AI] Pulling ollama model '{model}'... (this may take a while)")
        try:
            data = json.dumps({"name": model, "stream": False}).encode("utf-8")
            req = urllib.request.Request(
                "http://localhost:11434/api/pull",
                data=data,
                headers={"Content-Type": "application/json"},
            )
            with urllib.request.urlopen(req, timeout=600) as resp:
                resp.read()
            print(f"[AI] Model '{model}' ready ✓")
            cls._cache.pop("ollama", None)
            cls._cache.pop("ollama_models", None)
            return True
        except Exception as e:
            print(f"[WARN] Failed to pull model '{model}': {e}")
            return False

    @classmethod
    def resolve(cls, configured: str, ollama_model: str = "llama3.1:8b") -> str:
        """Resolve 'auto' to the best available backend. Exits if none available."""
        if configured != "auto":
            return configured

        # 1순위: Claude Code CLI (구독 필요)
        if cls.check_claude_cli():
            return "claude_cli"

        # 2순위: Anthropic API Key
        if cls.check_anthropic_api():
            return "anthropic_api"

        # 3순위: Ollama (로컬 LLM)
        if cls.check_ollama():
            cls.install_ollama_model(ollama_model)
            return "ollama"

        # AI 없음 → 사용 불가
        cls._print_no_ai_error()
        sys.exit(1)

    @classmethod
    def _print_no_ai_error(cls):
        """Print detailed error message when no AI backend is available."""
        print("")
        print("=" * 60)
        print("[ERROR] AI 백엔드를 찾을 수 없습니다.")
        print("=" * 60)
        print("")
        print("이 도구는 AI 백엔드가 필수입니다.")
        print("아래 원인을 확인하고 하나 이상 설정해주세요:")
        print("")
        print("  ❌ Claude Code CLI")
        print("     → 'claude' 명령어가 설치되지 않았거나 PATH에 없음")
        print("     → Claude Code 구독이 필요합니다")
        print("     → 설치: https://docs.anthropic.com/en/docs/claude-code")
        print("")
        print("  ❌ Anthropic API Key")
        print("     → ANTHROPIC_API_KEY 환경변수가 설정되지 않음")
        print("     → .env 파일에 ANTHROPIC_API_KEY=sk-... 추가")
        print("     → API 키 발급: https://console.anthropic.com/")
        print("")
        print("  ❌ Ollama (로컬 LLM)")
        # Check specific Ollama failure reasons
        ollama_installed = False
        try:
            r = subprocess.run(["ollama", "--version"], capture_output=True, text=True, timeout=5)
            ollama_installed = r.returncode == 0
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

        if not ollama_installed:
            print("     → Ollama가 설치되지 않음")
            print("     → 설치: curl -fsSL https://ollama.com/install.sh | sh")
        else:
            # Ollama installed but no models or not running
            try:
                req = urllib.request.Request("http://localhost:11434/api/tags")
                with urllib.request.urlopen(req, timeout=3) as resp:
                    data = json.loads(resp.read().decode())
                    models = [m["name"] for m in data.get("models", [])]
                    if not models:
                        print("     → Ollama는 설치됐으나 모델이 없음")
                        print("     → 모델 다운로드: ollama pull llama3.1:8b")
                    else:
                        print(f"     → Ollama 모델 있음({', '.join(models[:3])}) 하지만 응답 오류")
            except urllib.error.URLError:
                print("     → Ollama가 설치됐으나 서비스가 실행 중이지 않음")
                print("     → 시작: ollama serve")
            except Exception as e:
                print(f"     → Ollama 연결 실패: {e}")

        # GPU check
        try:
            r = subprocess.run(["nvidia-smi"], capture_output=True, text=True, timeout=5)
            if r.returncode != 0:
                print("")
                print("  ⚠️  GPU (nvidia-smi) 감지 실패")
                print("     → GPU 없이도 Ollama CPU 모드로 동작 가능 (느림)")
                print("     → 또는 Claude CLI/API Key 사용을 권장합니다")
        except FileNotFoundError:
            print("")
            print("  ⚠️  GPU 없음 (nvidia-smi not found)")
            print("     → Ollama CPU 모드 가능하나 느릴 수 있음")
            print("     → Claude CLI 또는 API Key 사용을 권장합니다")
        except Exception:
            pass

        print("")
        print("해결 방법 (하나만 선택):")
        print("  1) Claude Code 설치 후 'claude' 명령어 사용 가능하게 설정")
        print("  2) export ANTHROPIC_API_KEY=sk-ant-... (.env 또는 shell)")
        print("  3) curl -fsSL https://ollama.com/install.sh | sh && ollama pull llama3.1:8b")
        print("=" * 60)


class NoteGenerator:
    def __init__(self, config: dict):
        self.config = config
        ollama_cfg = config.get("general", {}).get("ollama", {})
        self.ollama_model = ollama_cfg.get("model", "llama3.1:8b")
        configured = config.get("general", {}).get("ai_backend", "auto")
        self.ai_backend = AIBackendDetector.resolve(configured, self.ollama_model)
        self.templates_dir = Path(__file__).parent / "templates"

    def generate_daily_entry(self, changes: dict) -> str:
        today = get_date(self.config)
        day_names = {0: "Mon", 1: "Tue", 2: "Wed", 3: "Thu", 4: "Fri", 5: "Sat", 6: "Sun"}
        day_name = day_names[today.weekday()]

        if self.ai_backend == "claude_cli":
            return self._generate_with_claude_cli(changes, today, day_name)
        elif self.ai_backend == "anthropic_api":
            return self._generate_with_api(changes, today, day_name)
        elif self.ai_backend == "ollama":
            return self._generate_with_ollama(changes, today, day_name)

    @staticmethod
    def _clean_ai_output(text: str) -> str:
        """Remove AI preamble/postamble, keep only the markdown note starting from # date."""
        import re
        lines = text.strip().split("\n")
        # Find first line starting with "# 20" (date heading)
        start_idx = 0
        for i, line in enumerate(lines):
            if re.match(r'^#\s+\d{4}-\d{2}-\d{2}', line.strip()):
                start_idx = i
                break
        # Find last meaningful line (trim trailing ---, empty lines)
        end_idx = len(lines)
        for i in range(len(lines) - 1, start_idx, -1):
            stripped = lines[i].strip()
            if stripped and stripped != "---":
                end_idx = i + 1
                break
        cleaned = "\n".join(lines[start_idx:end_idx]).strip()
        return cleaned if cleaned else text.strip()

    @staticmethod
    def _clean_init_output(text: str) -> str:
        """Remove AI preamble and wrapping code blocks from init output."""
        import re
        result = text.strip()

        # Remove wrapping ```markdown ... ``` (anywhere in text, not just at start)
        m = re.search(r'```(?:markdown)?\s*\n(.*?)```', result, re.DOTALL)
        if m:
            result = m.group(1).strip()

        # Remove any preamble before the first markdown heading
        lines = result.split('\n')
        first_heading_idx = None
        for i, line in enumerate(lines):
            if line.strip().startswith('#'):
                first_heading_idx = i
                break

        if first_heading_idx is not None and first_heading_idx > 0:
            result = '\n'.join(lines[first_heading_idx:])

        return result.strip()

    def _generate_with_claude_cli(self, changes: dict, today, day_name: str) -> str:
        context = self._build_ai_context(changes)
        prompt = (f"Generate a daily research note entry. "
                  f"Output ONLY the markdown content. "
                  f"Do NOT include any preamble, explanation, greeting, or commentary. "
                  f"Start directly with '# {today.isoformat()} ({day_name})'. "
                  f"Korean body, English headings.\n\n"
                  f"Project: {changes['project']}\n\n"
                  f"{context}\n\n"
                  f"Sections (in order):\n"
                  f"# {today.isoformat()} ({day_name})\n"
                  f"## Changes Summary\n"
                  f"## Key Changes Detail\n"
                  f"## Architecture Updates\n"
                  f"## Issues & Solutions (증상→원인→시도→해결)\n"
                  f"## Training / Experiment Status\n"
                  f"## Lessons Learned\n\n"
                  f"Be concise. NO preamble. Start with # heading immediately.")
        try:
            r = subprocess.run(
                ["claude", "--print", "-p", prompt],
                capture_output=True, text=True, timeout=120
            )
            if r.returncode == 0 and r.stdout.strip():
                cleaned = self._clean_ai_output(r.stdout)
                return f"\n---\n\n{cleaned}\n\n---\n"
        except (subprocess.TimeoutExpired, FileNotFoundError) as e:
            print(f"[ERROR] Claude CLI failed: {e}")
            sys.exit(1)

    def _generate_with_api(self, changes: dict, today, day_name: str) -> str:
        try:
            import anthropic
        except ImportError:
            print("[ERROR] anthropic 패키지가 설치되지 않았습니다: pip install anthropic")
            sys.exit(1)
        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            print("[ERROR] ANTHROPIC_API_KEY 환경변수가 설정되지 않았습니다")
            sys.exit(1)
        context = self._build_ai_context(changes)
        prompt = (f"Output ONLY markdown. No preamble, no explanation. "
                  f"Start directly with '# {today.isoformat()} ({day_name})'.\n"
                  f"Korean body, English headings.\n\n"
                  f"Project: {changes['project']}\n\n"
                  f"{context}\n\n"
                  f"Sections: # date, ## Changes Summary, ## Key Changes Detail, "
                  f"## Architecture Updates, ## Issues & Solutions, "
                  f"## Training / Experiment Status, ## Lessons Learned.")
        try:
            client = anthropic.Anthropic(api_key=api_key)
            msg = client.messages.create(
                model="claude-sonnet-4-5-20250929", max_tokens=4096,
                messages=[{"role": "user", "content": prompt}]
            )
            cleaned = self._clean_ai_output(msg.content[0].text)
            return f"\n---\n\n{cleaned}\n\n---\n"
        except Exception as e:
            print(f"[ERROR] Anthropic API 호출 실패: {e}")
            sys.exit(1)

    def _generate_with_ollama(self, changes: dict, today, day_name: str) -> str:
        context = self._build_ai_context(changes)
        prompt = (f"Output ONLY markdown. No preamble, no explanation, no greeting. "
                  f"Start directly with '# {today.isoformat()} ({day_name})'.\n"
                  f"Korean body, English headings.\n\n"
                  f"Project: {changes['project']}\n\n"
                  f"{context}\n\n"
                  f"Sections:\n"
                  f"# {today.isoformat()} ({day_name})\n"
                  f"## Changes Summary\n## Key Changes Detail\n"
                  f"## Architecture Updates\n## Issues & Solutions\n"
                  f"## Training / Experiment Status\n## Lessons Learned\n\n"
                  f"Be concise. Start with # heading immediately.")
        try:
            data = json.dumps({
                "model": self.ollama_model,
                "prompt": prompt,
                "stream": False,
                "options": {"temperature": 0.3, "num_predict": 2048},
            }).encode("utf-8")
            req = urllib.request.Request(
                "http://localhost:11434/api/generate",
                data=data,
                headers={"Content-Type": "application/json"},
            )
            with urllib.request.urlopen(req, timeout=180) as resp:
                result = json.loads(resp.read().decode())
            response_text = result.get("response", "").strip()
            if response_text:
                cleaned = self._clean_ai_output(response_text)
                return f"\n---\n\n{cleaned}\n\n---\n"
        except Exception as e:
            print(f"[ERROR] Ollama 호출 실패: {e}")
            print("  → ollama serve 실행 여부 확인")
            print("  → ollama list 로 모델 확인")
            sys.exit(1)

    def _build_ai_context(self, changes: dict) -> str:
        parts = [f"Detection: {changes['method']}", f"Path: {changes['path']}", ""]
        if changes["new"]:
            parts += [f"NEW ({len(changes['new'])}):" ] + [f"  + {f}" for f in changes["new"]] + [""]
        if changes["modified"]:
            parts += [f"MODIFIED ({len(changes['modified'])}):" ] + [f"  M {f}" for f in changes["modified"]] + [""]
        if changes["deleted"]:
            parts += [f"DELETED ({len(changes['deleted'])}):" ] + [f"  - {f}" for f in changes["deleted"]] + [""]
        if changes.get("commits"):
            parts += ["COMMITS:"] + [f"  {c}" for c in changes["commits"]] + [""]
        if changes.get("diffs"):
            parts.append("DIFFS:")
            for fp, diff in list(changes["diffs"].items())[:10]:
                parts += [f"--- {fp} ---", diff, ""]
        stats = changes.get("stats", {})
        if stats:
            parts.append(f"STATS: {stats.get('total_files', 0)} files, {stats.get('total_lines', 0)} lines")
        return "\n".join(parts)

    def generate_initial_note(self, project_config: dict) -> str:
        template_path = self.templates_dir / "initial_note.md"
        with open(template_path, "r", encoding="utf-8") as f:
            template = f.read()
        today = get_date(self.config).isoformat()
        base = template.format(
            project_name=project_config["name"], project_subtitle="Project Description",
            author=os.environ.get("USER", "Author"), start_date=today,
            last_updated=today, current_version="v1",
        )

        # AI is required - resolve() already ensures this

        project_path = Path(project_config["path"]).resolve()
        # Gather project context: file list + git log
        context_parts = [f"Project: {project_config['name']}", f"Path: {project_path}", ""]

        # File list with sizes
        try:
            r = subprocess.run(
                ["git", "ls-files"], cwd=project_path,
                capture_output=True, text=True, timeout=10
            )
            if r.returncode == 0 and r.stdout.strip():
                files = [f.strip() for f in r.stdout.strip().split("\n") if f.strip()]
                context_parts += ["FILES:"] + [f"  {f}" for f in files] + [""]
        except Exception:
            pass

        # Git log
        try:
            r = subprocess.run(
                ["git", "log", "--oneline", "--no-merges"],
                cwd=project_path, capture_output=True, text=True, timeout=10
            )
            if r.returncode == 0 and r.stdout.strip():
                context_parts += ["GIT COMMITS:"] + [f"  {l.strip()}" for l in r.stdout.strip().split("\n")] + [""]
        except Exception:
            pass

        # Read key source files (first 80 lines each)
        key_extensions = {".py", ".sh", ".yaml", ".yml"}
        try:
            for fp in sorted(project_path.iterdir()):
                if fp.is_file() and fp.suffix in key_extensions and fp.stat().st_size < 50000:
                    lines = fp.read_text(encoding="utf-8", errors="ignore").split("\n")[:80]
                    context_parts += [f"--- {fp.name} (first 80 lines) ---"] + lines + [""]
        except Exception:
            pass

        context = "\n".join(context_parts)

        prompt = (
            "아래 프로젝트 정보를 분석하여 연구노트 초기 템플릿의 빈 섹션을 채워주세요.\n"
            "기존 마크다운 구조(## 1. Project Overview, ## 2. Data Specification 등)를 그대로 유지하고,\n"
            "<!-- HTML 주석 --> 자리에 실제 내용을 채워넣으세요.\n"
            "**중요**: HTML 주석(<!-- -->)은 반드시 제거하고 실제 내용으로 대체하세요. 주석을 그대로 남기지 마세요.\n"
            "해당사항이 없는 섹션(예: Loss Function, Issues & Solutions)은 'N/A' 또는 '프로젝트 진행하며 업데이트 예정'으로 표시하세요.\n"
            "반드시 마크다운 형식으로만 출력하세요. 설명이나 인사말 없이 채워진 템플릿만 출력하세요.\n\n"
            f"=== 현재 템플릿 ===\n{base}\n\n"
            f"=== 프로젝트 정보 ===\n{context}"
        )

        if self.ai_backend == "claude_cli":
            try:
                r = subprocess.run(
                    ["claude", "-p", prompt], capture_output=True, text=True, timeout=None
                )
                if r.returncode == 0 and r.stdout.strip():
                    result = self._clean_init_output(r.stdout.strip())
                    # Ensure it has the Daily Log section
                    if "## Daily Log" not in result:
                        result += "\n\n---\n\n## Daily Log\n\n<!-- 날짜별 엔트리가 여기 아래에 최신순으로 쌓입니다 -->\n"
                    return result
            except Exception as e:
                print(f"[WARN] Claude CLI init failed ({e}), using empty template")
        elif self.ai_backend == "anthropic_api":
            try:
                import anthropic
                client = anthropic.Anthropic()
                msg = client.messages.create(
                    model="claude-sonnet-4-20250514", max_tokens=4096,
                    messages=[{"role": "user", "content": prompt}]
                )
                result = self._clean_init_output(msg.content[0].text.strip())
                if "## Daily Log" not in result:
                    result += "\n\n---\n\n## Daily Log\n\n<!-- 날짜별 엔트리가 여기 아래에 최신순으로 쌓입니다 -->\n"
                return result
            except Exception as e:
                print(f"[WARN] API init failed ({e}), using empty template")
        elif self.ai_backend == "ollama":
            try:
                ollama_model = self.config.get("general", {}).get("ollama", {}).get("model", "llama3.1:8b")
                payload = json.dumps({"model": ollama_model, "prompt": prompt, "stream": False})
                req = urllib.request.Request(
                    "http://localhost:11434/api/generate",
                    data=payload.encode(), headers={"Content-Type": "application/json"}
                )
                with urllib.request.urlopen(req, timeout=None) as resp:
                    result = self._clean_init_output(json.loads(resp.read().decode()).get("response", "").strip())
                    if result and "## Daily Log" not in result:
                        result += "\n\n---\n\n## Daily Log\n\n<!-- 날짜별 엔트리가 여기 아래에 최신순으로 쌓입니다 -->\n"
                    if result:
                        return result
            except Exception:
                pass

        return base


# ============================================================================
# Note Writer (chronological - append to bottom)
# ============================================================================

class NoteWriter:
    @staticmethod
    def append_entry(note_path: Path, entry: str, date_override=None):
        """Append a daily entry at the bottom (chronological order)."""
        note_path = Path(note_path)
        if not note_path.exists():
            print(f"[WARN] Note file not found: {note_path}")
            return

        content = note_path.read_text(encoding="utf-8")
        content = content.rstrip() + "\n" + entry + "\n"

        today = (date_override or datetime.date.today()).isoformat()
        if "**Last Updated**:" in content:
            import re
            content = re.sub(
                r'\*\*Last Updated\*\*: \d{4}-\d{2}-\d{2}',
                f'**Last Updated**: {today}', content
            )

        note_path.write_text(content, encoding="utf-8")
        print(f"[OK] Updated: {note_path}")

    @staticmethod
    def create_initial(note_path: Path, content: str):
        note_path = Path(note_path)
        note_path.parent.mkdir(parents=True, exist_ok=True)
        note_path.write_text(content, encoding="utf-8")
        print(f"[OK] Created: {note_path}")


# ============================================================================
# Daily File Writer
# ============================================================================

class DailyFileWriter:
    @staticmethod
    def write(daily_dir: Path, project_name: str, date: datetime.date, entry: str) -> Path:
        """Write a standalone daily note file."""
        daily_dir = Path(daily_dir)
        daily_dir.mkdir(parents=True, exist_ok=True)

        filename = f"{date.isoformat()}-research-note.md"
        filepath = daily_dir / filename

        day_names = {0: "Mon", 1: "Tue", 2: "Wed", 3: "Thu", 4: "Fri", 5: "Sat", 6: "Sun"}
        header = (f"# {project_name} - Daily Research Note\n"
                  f"> **Date**: {date.isoformat()} ({day_names[date.weekday()]})\n"
                  f"> **Project**: {project_name}\n\n")

        filepath.write_text(header + entry, encoding="utf-8")
        print(f"[OK] Daily file: {filepath}")
        return filepath


# ============================================================================
# Weekly Merger
# ============================================================================

class WeeklyMerger:
    def __init__(self, config: dict):
        self.config = config
        ollama_cfg = config.get("general", {}).get("ollama", {})
        configured = config.get("general", {}).get("ai_backend", "auto")
        self.ai_backend = AIBackendDetector.resolve(configured, ollama_cfg.get("model", "llama3.1:8b"))

    def merge(self, daily_dir: Path, project_name: str, date: datetime.date) -> Optional[Path]:
        """Merge last 7 daily files into a weekly report."""
        daily_dir = Path(daily_dir)
        if not daily_dir.exists():
            print(f"[WARN] Daily dir not found: {daily_dir}")
            return None

        daily_files = []
        for i in range(7):
            d = date - datetime.timedelta(days=i)
            fp = daily_dir / f"{d.isoformat()}-research-note.md"
            if fp.exists():
                daily_files.append((d, fp))

        if not daily_files:
            print(f"[SKIP] No daily files found for weekly merge")
            return None

        daily_files.sort(key=lambda x: x[0])  # Chronological

        week_start = daily_files[0][0]
        week_end = daily_files[-1][0]

        parts = []
        parts.append(f"# Weekly Research Report: {project_name}")
        parts.append(f"> **Period**: {week_start.isoformat()} ~ {week_end.isoformat()}")
        parts.append(f"> **Daily Notes**: {len(daily_files)} days")
        parts.append(f"> **Generated**: {date.isoformat()}\n")

        # AI Summary
        use_ai = self.config.get("notification", {}).get("weekly", {}).get("ai_summary", False)
        if use_ai:
            all_content = "\n".join(fp.read_text(encoding="utf-8") for _, fp in daily_files)
            summary = self._generate_summary(all_content, project_name, week_start, week_end)
            if summary:
                parts.append("---\n")
                parts.append("## Weekly Summary (AI Generated)\n")
                parts.append(summary)
                parts.append("")

        parts.append("---\n")
        parts.append("## Daily Notes\n")

        for d, fp in daily_files:
            content = fp.read_text(encoding="utf-8")
            parts.append(content)
            parts.append("")

        weekly_filename = f"{week_start.isoformat()}_to_{week_end.isoformat()}-weekly-report.md"
        weekly_path = daily_dir / weekly_filename
        weekly_path.write_text("\n".join(parts), encoding="utf-8")
        print(f"[OK] Weekly report: {weekly_path}")
        return weekly_path

    def _generate_summary(self, content: str, project: str, start, end) -> Optional[str]:
        prompt = (f"Summarize this week's research progress for project '{project}' "
                  f"({start} ~ {end}). Write in Korean, bullet points, concise.\n\n"
                  f"Focus on: key changes, issues resolved, metrics improvements, "
                  f"lessons learned.\n\n{content[:8000]}")

        if self.ai_backend == "claude_cli":
            try:
                r = subprocess.run(
                    ["claude", "--print", "-p", prompt],
                    capture_output=True, text=True, timeout=120
                )
                if r.returncode == 0:
                    return r.stdout.strip()
            except (subprocess.TimeoutExpired, FileNotFoundError):
                pass
        elif self.ai_backend == "anthropic_api":
            try:
                import anthropic
                api_key = os.environ.get("ANTHROPIC_API_KEY")
                if api_key:
                    client = anthropic.Anthropic(api_key=api_key)
                    msg = client.messages.create(
                        model="claude-sonnet-4-5-20250929", max_tokens=2048,
                        messages=[{"role": "user", "content": prompt}]
                    )
                    return msg.content[0].text
            except Exception:
                pass
        elif self.ai_backend == "ollama":
            try:
                ollama_model = self.config.get("general", {}).get("ollama", {}).get("model", "llama3.1:8b")
                data = json.dumps({
                    "model": ollama_model,
                    "prompt": prompt,
                    "stream": False,
                    "options": {"temperature": 0.3, "num_predict": 2048},
                }).encode("utf-8")
                req = urllib.request.Request(
                    "http://localhost:11434/api/generate",
                    data=data,
                    headers={"Content-Type": "application/json"},
                )
                with urllib.request.urlopen(req, timeout=180) as resp:
                    result = json.loads(resp.read().decode())
                text = result.get("response", "").strip()
                if text:
                    return text
            except Exception:
                pass
        return None


# ============================================================================
# Notification Manager
# ============================================================================

class NotificationManager:
    def __init__(self, config: dict):
        self.config = config
        self.notif = config.get("notification", {})
        self.enabled = self.notif.get("enabled", False)

    def send(self, subject: str, body: str, attachment_path: Path = None):
        """Send notification via all enabled channels."""
        if not self.enabled:
            print("[SKIP] Notifications disabled")
            return

        if self.notif.get("email", {}).get("enabled", False):
            self._send_email(subject, body, attachment_path)

        if self.notif.get("slack", {}).get("enabled", False):
            self._send_slack(subject, body, attachment_path)

    def _send_email(self, subject: str, body: str, attachment_path: Path = None):
        email_cfg = self.notif["email"]
        sender = os.environ.get(email_cfg.get("sender_env", ""), "")
        password = os.environ.get(email_cfg.get("password_env", ""), "")
        recipients = email_cfg.get("recipients", [])

        if not sender or not password:
            print(f"[WARN] Email credentials not set "
                  f"({email_cfg.get('sender_env')}, {email_cfg.get('password_env')})")
            return
        if not recipients:
            print("[WARN] No email recipients configured")
            return

        try:
            msg = email.mime.multipart.MIMEMultipart()
            msg["From"] = sender
            msg["To"] = ", ".join(recipients)
            msg["Subject"] = subject

            msg.attach(email.mime.text.MIMEText(body, "plain", "utf-8"))

            if attachment_path and Path(attachment_path).exists():
                with open(attachment_path, "r", encoding="utf-8") as f:
                    att = email.mime.text.MIMEText(f.read(), "plain", "utf-8")
                att.add_header(
                    "Content-Disposition", "attachment",
                    filename=Path(attachment_path).name
                )
                msg.attach(att)

            smtp_host = email_cfg.get("smtp_host", "smtp.gmail.com")
            smtp_port = email_cfg.get("smtp_port", 587)

            with smtplib.SMTP(smtp_host, smtp_port) as server:
                if email_cfg.get("use_tls", True):
                    server.starttls()
                server.login(sender, password)
                server.sendmail(sender, recipients, msg.as_string())

            print(f"[OK] Email sent to: {', '.join(recipients)}")
        except Exception as e:
            print(f"[ERROR] Email failed: {e}")

    def _send_slack(self, subject: str, body: str, attachment_path: Path = None):
        slack_cfg = self.notif["slack"]
        token = os.environ.get(slack_cfg.get("bot_token_env", ""), "")
        recipients = slack_cfg.get("recipients", [])

        if not token:
            print(f"[WARN] Slack token not set ({slack_cfg.get('bot_token_env')})")
            return
        if not recipients:
            print("[WARN] No Slack recipients configured")
            return

        message = f"*{subject}*\n\n```\n{body[:35000]}\n```"

        for user_id in recipients:
            try:
                # Open DM channel
                dm_data = json.dumps({"users": user_id}).encode("utf-8")
                req = urllib.request.Request(
                    "https://slack.com/api/conversations.open",
                    data=dm_data,
                    headers={
                        "Authorization": f"Bearer {token}",
                        "Content-Type": "application/json",
                    },
                )
                with urllib.request.urlopen(req, timeout=10) as resp:
                    dm_resp = json.loads(resp.read().decode())

                if not dm_resp.get("ok"):
                    print(f"[ERROR] Slack DM open failed for {user_id}: {dm_resp.get('error')}")
                    continue

                channel_id = dm_resp["channel"]["id"]

                # Send message
                msg_data = json.dumps({
                    "channel": channel_id,
                    "text": message,
                }).encode("utf-8")
                req = urllib.request.Request(
                    "https://slack.com/api/chat.postMessage",
                    data=msg_data,
                    headers={
                        "Authorization": f"Bearer {token}",
                        "Content-Type": "application/json",
                    },
                )
                with urllib.request.urlopen(req, timeout=10) as resp:
                    msg_resp = json.loads(resp.read().decode())

                if msg_resp.get("ok"):
                    print(f"[OK] Slack DM sent to: {user_id}")
                else:
                    print(f"[ERROR] Slack send failed: {msg_resp.get('error')}")

                # Upload file if attachment
                if attachment_path and Path(attachment_path).exists():
                    self._slack_upload_file(token, channel_id, attachment_path)

            except (urllib.error.URLError, Exception) as e:
                print(f"[ERROR] Slack failed for {user_id}: {e}")

    def _slack_upload_file(self, token: str, channel_id: str, filepath: Path):
        try:
            content = Path(filepath).read_text(encoding="utf-8")
            data = json.dumps({
                "channels": channel_id,
                "content": content,
                "filename": Path(filepath).name,
                "title": f"Research Note - {Path(filepath).stem}",
            }).encode("utf-8")
            req = urllib.request.Request(
                "https://slack.com/api/files.upload",
                data=data,
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json",
                },
            )
            with urllib.request.urlopen(req, timeout=30) as resp:
                r = json.loads(resp.read().decode())
            if r.get("ok"):
                print(f"[OK] Slack file uploaded: {Path(filepath).name}")
            else:
                print(f"[WARN] Slack upload failed: {r.get('error')}")
        except Exception as e:
            print(f"[WARN] Slack upload error: {e}")


# ============================================================================
# CLI
# ============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Research Note Generator - Auto-generate daily research notes"
    )
    parser.add_argument("--config", "-c", default=str(DEFAULT_CONFIG_PATH))
    parser.add_argument("--project", "-p", help="Specific project only")
    parser.add_argument("--init", metavar="PROJECT", help="Initialize note for project")
    parser.add_argument("--dry-run", "-n", action="store_true", help="Preview only")
    parser.add_argument("--verbose", "-v", action="store_true")
    parser.add_argument("--date", help="Override date (YYYY-MM-DD) for testing")
    parser.add_argument("--send", action="store_true", help="Force send notification")
    parser.add_argument("--weekly", action="store_true", help="Generate weekly report")

    args = parser.parse_args()
    config = load_config(args.config)

    if args.date:
        config["_date_override"] = datetime.date.fromisoformat(args.date)
        print(f"[TEST] Date override: {args.date}")

    config_dir = Path(args.config).parent.resolve()
    state_dir = (config_dir / config.get("state", {}).get("state_dir", ".state")).resolve()
    state_dir.mkdir(parents=True, exist_ok=True)

    # --init
    if args.init:
        pc = next((p for p in config.get("projects", []) if p["name"] == args.init), None)
        if not pc:
            print(f"[ERROR] Project '{args.init}' not found"); sys.exit(1)
        gen = NoteGenerator(config)
        content = gen.generate_initial_note(pc)
        note_path = (config_dir / pc["note_output"]).resolve()
        if args.dry_run:
            print(f"[DRY-RUN] Would create: {note_path}\n{content}")
        else:
            NoteWriter.create_initial(note_path, content)
        return

    # --weekly
    if args.weekly:
        merger = WeeklyMerger(config)
        notifier = NotificationManager(config)
        today = get_date(config)
        for pc in config.get("projects", []):
            if args.project and pc["name"] != args.project:
                continue
            daily_dir = (config_dir / pc.get("daily_dir", f"./{pc['name']}/daily")).resolve()
            report_path = merger.merge(daily_dir, pc["name"], today)
            if report_path and (args.send or config.get("notification", {}).get("enabled")):
                body = report_path.read_text(encoding="utf-8")
                notifier.send(
                    subject=f"[Weekly] {pc['name']} Research Report ({today.isoformat()})",
                    body=body, attachment_path=report_path
                )
        return

    # Normal: detect → generate → write → notify
    projects = config.get("projects", [])
    if args.project:
        projects = [p for p in projects if p["name"] == args.project]
        if not projects:
            print(f"[ERROR] Project '{args.project}' not found"); sys.exit(1)

    generator = NoteGenerator(config)
    idle_detector = IdleDetector(config, state_dir)
    notifier = NotificationManager(config)
    today = get_date(config)

    for pc in projects:
        print(f"\n{'='*60}")
        print(f"Processing: {pc['name']}")
        print(f"{'='*60}")

        # Resolve paths
        project_path = Path(pc["path"])
        if not project_path.is_absolute():
            pc["path"] = str((config_dir / project_path).resolve())
        if not Path(pc["path"]).exists():
            print(f"[ERROR] Path not found: {pc['path']}"); continue

        # Detect changes
        detector = ChangeDetector(pc, state_dir)
        changes = detector.detect()
        total = len(changes["modified"]) + len(changes["new"]) + len(changes["deleted"])

        if args.verbose:
            print(f"  Changes: {total} (New:{len(changes['new'])} "
                  f"Mod:{len(changes['modified'])} Del:{len(changes['deleted'])})")

        # Idle detection
        idle_result = idle_detector.check(pc["name"], total > 0)
        if not idle_result["should_run"]:
            if idle_result["paused"] and idle_detector.notify_on_pause:
                notifier.send(
                    subject=f"[Paused] {pc['name']} - {idle_result['idle_days']}일간 변경 없음",
                    body=f"프로젝트 '{pc['name']}'가 {idle_result['idle_days']}일간 "
                         f"변경이 없어 연구노트 자동 생성을 중단합니다.\n"
                         f"변경이 감지되면 자동으로 재개됩니다."
                )
            continue

        if total == 0:
            print(f"[SKIP] No changes for {pc['name']}")
            continue

        # Generate entry
        entry = generator.generate_daily_entry(changes)

        if args.dry_run:
            print(f"\n[DRY-RUN] Would write:\n{'─'*40}\n{entry}\n{'─'*40}")
            continue

        # 1. Ensure full note exists
        note_path = (config_dir / pc.get("note_output", "")).resolve()
        if not note_path.exists():
            print(f"[INFO] Creating initial note...")
            NoteWriter.create_initial(note_path, generator.generate_initial_note(pc))

        # 2. Append to full RESEARCH_NOTE.md (chronological - newest at bottom)
        NoteWriter.append_entry(note_path, entry, date_override=today)

        # 3. Write separate daily file
        daily_dir = (config_dir / pc.get("daily_dir", f"./{pc['name']}/daily")).resolve()
        daily_path = DailyFileWriter.write(daily_dir, pc["name"], today, entry)

        # 4. Notify (if daily schedule)
        schedule = config.get("notification", {}).get("schedule", "daily")
        if args.send or (notifier.enabled and schedule == "daily"):
            body = daily_path.read_text(encoding="utf-8")
            notifier.send(
                subject=f"[Daily] {pc['name']} Research Note ({today.isoformat()})",
                body=body, attachment_path=daily_path
            )

    print(f"\nDone! ({datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')})")


if __name__ == "__main__":
    main()
