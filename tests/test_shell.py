"""Offline regression checks; every shell gets a disposable HOME."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ShellTests(unittest.TestCase):
    def run_shell(self, code, setup=None, shell='zsh'):
        with tempfile.TemporaryDirectory(prefix='my-zsh-test-') as directory:
            home = Path(directory)
            if setup:
                setup(home)
            env = os.environ.copy()
            env.update(HOME=directory, XDG_CONFIG_HOME=directory + '/.config',
                       XDG_STATE_HOME=directory + '/.state', MY_ZSH_AUTOUPDATE='0',
                       ZDOTDIR=directory, NVM_DIR=directory + '/.nvm')
            result = subprocess.run([shell, '-f', '-c', code], env=env,
                                    text=True, capture_output=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            return result.stdout

    def updater(self, extra):
        return self.run_shell(f'source "{ROOT}/.zshrc"\n' + '''
print 1.0.0 > "$my_zsh_local_version_file"
print '# old managed' > "$my_zsh_managed_file"
print '# personal' > "$HOME/.zshrc"
my_zsh_fetch_stdout() { print 2.0.0; }
my_zsh_fetch_to() { print '# valid download' > "$2"; }
''' + extra)

    def test_valid_update_preserves_entry(self):
        self.updater('''
my_zsh_do_update_check || exit 1
[[ $(cat "$HOME/.zshrc") == '# personal' ]] || exit 2
[[ $(cat "$my_zsh_local_version_file") == 2.0.0 ]] || exit 3
[[ -s "$my_zsh_config_dir/loader.managed.zsh" ]] || exit 4
''')

    def test_invalid_update_rejected(self):
        self.updater('''
my_zsh_fetch_to() { print 'if (' > "$2"; }
my_zsh_do_update_check && exit 1
[[ $(cat "$my_zsh_managed_file") == '# old managed' ]] || exit 2
[[ $(cat "$my_zsh_local_version_file") == 1.0.0 ]] || exit 3
''')

    def test_failed_second_move_rolls_back(self):
        self.updater('''
mv() { [[ "$2" == */loader.managed.zsh || "$3" == */loader.managed.zsh ]] && return 1; command mv "$@"; }
my_zsh_do_update_check && exit 1
[[ $(cat "$my_zsh_managed_file") == '# old managed' ]] || exit 2
[[ $(cat "$my_zsh_local_version_file") == 1.0.0 ]] || exit 3
[[ ! -e "$my_zsh_lock_dir" ]] || exit 4
''')

    def test_lock_returns_failure(self):
        self.run_shell(f'source "{ROOT}/.zshrc"\nmy_zsh_with_lock false; [[ $? == 1 ]]')

    def test_invalid_version_rejected(self):
        self.updater('my_zsh_fetch_stdout() { print bad; }; my_zsh_do_update_check && exit 1; [[ $(cat "$my_zsh_local_version_file") == 1.0.0 ]]')

    def test_npm_shortcut_survives_node(self):
        def setup(home):
            (home / '.nvm').mkdir()
            (home / 'bin').mkdir()
            (home / '.nvm/nvm.sh').write_text('export PATH="$HOME/bin:$PATH"\n')
            for name in ('node', 'npm'):
                path = home / 'bin' / name
                path.write_text('#!/bin/sh\nprintf "%s\\n" "$*"\n')
                path.chmod(0o700)
        managed = (ROOT / 'zshrc.managed').read_text()
        code = managed[managed.index('# Lazy-load NVM'):managed.index('# Custom aliases')]
        self.assertEqual(self.run_shell(code + '\nnode\nnpm s\nnpm s\n', setup).split(), ['start', 'start'])

    def test_gclone_real_local_repo_and_options(self):
        managed = (ROOT / 'zshrc.managed').read_text()
        code = managed[managed.index('gclone()'):managed.index("alias gclcd=")]
        self.run_shell(code + '''
cd "$HOME"
git init -q --bare source.git
gclone "$HOME/source.git" --depth 1 || exit 1
[[ "$PWD" == "$HOME/source" ]] || exit 2
cd "$HOME"
gclone "$HOME/source.git" 'target with spaces' --no-hardlinks || exit 3
[[ "$PWD" == "$HOME/target with spaces" ]]
''')

    def test_gclone_github_shorthand_and_local_precedence(self):
        def setup(home):
            (home / 'bin').mkdir()
            git = home / 'bin/git'
            git.write_text('''#!/bin/bash
printf '%s\\n' "$@" > "$HOME/git-args"
mkdir -p "${@: -1}"
''')
            git.chmod(0o700)
        managed = (ROOT / 'zshrc.managed').read_text()
        code = managed[managed.index('gclone()'):managed.index("alias gclcd=")]
        self.run_shell(code + '''
export PATH="$HOME/bin:$PATH"
cd "$HOME"
gclone author/repo-name --depth 1 || exit 1
[[ "$PWD" == "$HOME/repo-name" ]] || exit 2
grep -qx 'https://github.com/author/repo-name.git' "$HOME/git-args" || exit 3
cd "$HOME"
gclone author/other.git 'custom target' || exit 4
grep -qx 'https://github.com/author/other.git' "$HOME/git-args" || exit 5
cd "$HOME"
mkdir -p author/local
gclone author/local || exit 6
grep -qx 'author/local' "$HOME/git-args" || exit 7
cd "$HOME"
gclone ./author/missing || exit 8
grep -qx './author/missing' "$HOME/git-args"
''', setup)

    def test_loader_delegation(self):
        self.run_shell(f'''
mkdir -p "$XDG_CONFIG_HOME/my-zsh"
cp "{ROOT}/.zshrc" "$XDG_CONFIG_HOME/my-zsh/loader.managed.zsh"
source "{ROOT}/.zshrc"
[[ -z ${{_MY_ZSH_LOADER_ACTIVE:-}} ]] && (( $+functions[my_zsh_update_check] ))
''')

    def test_install_migrates_and_can_repeat(self):
        with tempfile.TemporaryDirectory(prefix='my-zsh-install-') as directory:
            home = Path(directory)
            bin_dir = home / 'bin'
            bin_dir.mkdir()
            omz = home / '.oh-my-zsh'
            omz.mkdir()
            (omz / 'oh-my-zsh.sh').write_text('# existing installation\n')
            for name in ('apt', 'sudo', 'chsh'):
                path = bin_dir / name
                path.write_text('#!/bin/sh\nexit 0\n')
                path.chmod(0o700)
            git = bin_dir / 'git'
            git.write_text('''#!/bin/bash
mkdir -p "${@: -1}"
name=$(basename "${@: -1}")
touch "${@: -1}/$name.zsh"
''')
            git.chmod(0o700)
            curl = bin_dir / 'curl'
            curl.write_text('''#!/bin/bash
while (( $# )); do
  case "$1" in
    https:*) url="$1"; shift ;;
    -o) out="$2"; shift 2 ;;
    *) shift ;;
  esac
done
cp "$TEST_REPO/${url##*/}" "$out"
''')
            curl.chmod(0o700)
            old = '# --- my-zsh loader + auto-updater\n# --- end my-zsh loader + auto-updater ---\nexport PERSONAL=preserved\n'
            (home / '.zshrc').write_text(old)
            env = os.environ.copy()
            env.update(HOME=directory, ZDOTDIR=directory, ZSH=str(omz),
                       ZSH_CUSTOM=str(omz / 'custom'),
                       XDG_CONFIG_HOME=directory + '/config',
                       XDG_STATE_HOME=directory + '/state',
                       PATH=str(bin_dir) + ':/usr/bin:/bin', TEST_REPO=str(ROOT),
                       MY_ZSH_INSTALL_MICRO='0', MY_ZSH_INSTALL_MSFCONSOLE='0',
                       TERMUX_VERSION='', PREFIX='')
            for _ in range(2):
                result = subprocess.run(['bash', str(ROOT / 'install.sh')],
                                        env=env, capture_output=True, text=True, timeout=15)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            # A failed subsequent download must not touch installed files.
            before = (home / '.zshrc').read_bytes()
            curl.write_text('#!/bin/sh\nexit 22\n')
            failed = subprocess.run(['bash', str(ROOT / 'install.sh')], env=env,
                                    capture_output=True, text=True, timeout=15)
            self.assertNotEqual(failed.returncode, 0)
            self.assertEqual((home / '.zshrc').read_bytes(), before)
            migrated = list((home / '.zshrc.d').glob('*.zsh'))
            self.assertEqual(len(migrated), 1)
            self.assertEqual(migrated[0].read_text(), 'export PERSONAL=preserved\n')
            self.assertEqual((home / '.zshrc').read_text(), (ROOT / '.zshrc').read_text())
            self.assertTrue((home / 'config/my-zsh/loader.managed.zsh').is_file())

    def test_ssh_override_after_theme(self):
        def setup(home):
            (home / '.oh-my-zsh').mkdir()
            (home / '.oh-my-zsh/oh-my-zsh.sh').write_text(
                'function _git_time_since_commit() { print expensive; }\n')
        self.assertEqual(self.run_shell(f'''unset ZSH
SSH_CONNECTION=test
source "{ROOT}/zshrc.managed"
_git_time_since_commit
''', setup), '')

    def test_termux_downloaded_wrapper(self):
        def setup(home):
            (home / 'bin').mkdir()
            curl = home / 'bin/curl'
            curl.write_text('''#!/bin/bash
while (( $# )); do
  if [[ "$1" == -o ]]; then out="$2"; break; fi
  shift
done
printf 'echo downloaded > "$HOME/result"\\n' > "$out"
''')
            curl.chmod(0o700)
        self.run_shell(f'''export PATH="$HOME/bin:$PATH"
cd "$HOME"
bash -c "$(cat '{ROOT}/termux_zsh.sh')" || exit 1
[[ $(cat "$HOME/result") == downloaded ]]
''', setup)

    def test_failed_version_move_rolls_back(self):
        self.updater('''
mv() { [[ "${@: -1}" == "$my_zsh_local_version_file" ]] && return 1; command mv "$@"; }
my_zsh_do_update_check && exit 1
[[ $(cat "$my_zsh_managed_file") == '# old managed' ]] || exit 2
[[ $(cat "$my_zsh_local_version_file") == 1.0.0 ]] || exit 3
[[ ! -f "$my_zsh_config_dir/loader.managed.zsh" ]]
''')

    def test_live_lock_not_stolen(self):
        self.run_shell(f'''source "{ROOT}/.zshrc"
mkdir "$my_zsh_lock_dir"
print $$ > "$my_zsh_lock_dir/pid"
my_zsh_with_lock true && exit 1
[[ -d "$my_zsh_lock_dir" ]]
''')

    def test_dead_lock_recovered(self):
        self.run_shell(f'''source "{ROOT}/.zshrc"
mkdir "$my_zsh_lock_dir"
print 99999999 > "$my_zsh_lock_dir/pid"
my_zsh_with_lock true || exit 1
[[ ! -d "$my_zsh_lock_dir" ]]
''')


if __name__ == '__main__':
    unittest.main()
