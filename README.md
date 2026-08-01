<img align="right" width="60" height="60" src="https://github.com/devicons/devicon/blob/master/icons/ansible/ansible-plain-wordmark.svg">

# Ansible Playbook: `ghes-ansible-operations`

A GHES Ansible Playbook Repository Consuming [ghes_upgrade](https://galaxy.ansible.com/ui/standalone/roles/Richard-Barrett/ghes_upgrade/) Ansible Galaxy Role

- [ghes_upgrade Ansible Galaxy Role Source Code](https://github.com/Richard-Barrett/ansible-role-ghes-maintenance)

## GHES Ansible Operations

A consumer playbook repository for the Ansible Galaxy role
`Richard-Barrett.ghes_upgrade`.

The repository is designed to run from a secured jump host or Ansible control
node. It supports two inventory patterns:

1. A standalone or primary-only GHES appliance.
2. A production HA inventory containing one primary and one or more replicas.

## Supported workflows

- Validate GHES administrative SSH connectivity on port 122.
- Run read-only configuration, disk, service, and health checks.
- Upgrade one standalone GHES appliance.
- Upgrade one HA primary while validating replication.
- Inventory and inspect production replicas.
- Display HA replication status from the primary.
- Guardedly reload core services with `ghe-config-apply -f`.

> The currently published Galaxy role upgrades `standalone` or `ha_primary`
> targets. It does not upgrade replica nodes. Production replica groups are
> included for health, connectivity, service visibility, and parent-level
> operational procedures.

## Repository layout

```text
.
├── ansible.cfg
├── requirements.yml
├── inventory/
│   ├── standalone/
│   ├── staging/
│   └── production/
├── playbooks/
│   ├── connectivity.yml
│   ├── health.yml
│   ├── replication-status.yml
│   ├── restart-core-services.yml
│   ├── service-status.yml
│   ├── upgrade-ha-primary.yml
│   └── upgrade-standalone.yml
├── vars/
│   └── upgrade.example.yml
├── packages/
├── artifacts/
└── Makefile
```

## Install on the jump host

```bash
make setup
export GHES_SSH_KEY="$HOME/.ssh/ghes_ansible"
```

The role is installed locally from `requirements.yml` into `.ansible/roles`.
Ansible is not installed on the GHES appliances.

## Standalone or primary-only inventory

Edit `inventory/standalone/hosts.yml`:

```yaml
---
all:
  children:
    ghes_standalone:
      hosts:
        ghes-standalone:
          ansible_host: github.example.com

    ghes:
      children:
        ghes_standalone:
```

Validate and upgrade:

```bash
make inventory ENV=standalone
make connectivity ENV=standalone LIMIT=ghes-standalone
make health ENV=standalone LIMIT=ghes-standalone
make upgrade-standalone ENV=standalone LIMIT=ghes-standalone
```

## Production HA inventory

Edit `inventory/production/hosts.yml`:

```yaml
---
all:
  children:
    ghes_primary:
      hosts:
        ghes-primary:
          ansible_host: github-primary.example.com

    ghes_replicas:
      hosts:
        ghes-replica-01:
          ansible_host: github-replica-01.example.com
        ghes-replica-02:
          ansible_host: github-replica-02.example.com

    ghes:
      children:
        ghes_primary:
        ghes_replicas:
```

Validate all nodes and inspect replication:

```bash
make inventory ENV=production
make connectivity ENV=production LIMIT=ghes
make health ENV=production LIMIT=ghes
make service-status ENV=production LIMIT=ghes
make replication-status ENV=production LIMIT=ghes-primary
```

Upgrade only the supported HA primary target:

```bash
make upgrade-ha-primary \
  ENV=production \
  LIMIT=ghes-primary
```

The playbook asserts that the selected host belongs to `ghes_primary` and is
not a member of `ghes_replicas`.

## Upgrade variables

Create the ignored local file:

```bash
cp vars/upgrade.example.yml vars/upgrade.yml
$EDITOR vars/upgrade.yml
```

At minimum, define:

```yaml
---
ghes_upgrade_confirm: true
ghes_upgrade_backup_confirmed: true
ghes_upgrade_snapshot_confirmed: true
ghes_upgrade_expected_current_version: "3.20.4"
ghes_upgrade_target_version: "3.21.1"
ghes_upgrade_package_local_path: /opt/ansible-ghes/packages/github-enterprise-3.21.1.pkg
ghes_upgrade_package_remote_path: /home/admin/github-enterprise-3.21.1.pkg
```

## Safety notes

- Always use `LIMIT` for upgrade and restart targets.
- Never target `ghes_replicas` with `upgrade-ha-primary`.
- Keep private keys, live approvals, packages, and evidence out of Git.
- Validate a release-specific HA procedure before changing replica state.
- GHES cluster topology is not supported by this role.
