# ansible_playbook_template

# Prerequisite
- [TargetServer] $ localedef -i ja_JP -c -f UTF-8 -A /usr/share/locale/locale.alias ja_JP.UTF-8
- [TargetServer] $ groupadd ansible
- [TargetServer] $ useradd -m ansible
- [TargetServer] $ passwd ansible
- [TargetServer] $ visudo
  - ansible ALL=(ALL) NOPASSWD: ALL
- [AnsibleServer]$ ssh-copy-id ansible@xxx.xxx.xxx.xxx
- [AnsibleServer]$ ssh ansible@xxx.xxx.xxx.xxx
- [TargetServer] $ sudo passwd -d ansible
