# Ansible Playbook: `ghes-ansible-operations`

A GHES Ansible Playbook Repository Consuming [ghes_upgrade](https://galaxy.ansible.com/ui/standalone/roles/Richard-Barrett/ghes_upgrade/) Ansible Galaxy Role

- [ghes_upgrade Ansible Galaxy Role Source Code](https://github.com/Richard-Barrett/ansible-role-ghes-maintenance)

## GHES Ansible Operations

A consumer playbook repository for the Ansible Galaxy role
`Richard-Barrett.ghes_upgrade`.

The repository is intended to run from a secured jump host or Ansible control
node. It keeps inventories, operational playbooks, approved upgrade variables,
locally installed Galaxy roles, and controller-side evidence separate from the
role source repository.

## Supported workflows

- Validate administrative SSH connectivity on port 122.
- Run read-only GHES configuration, background-job, disk, service, and HA
  replication checks.
- Upgrade one standalone GHES appliance.
- Upgrade one HA primary while validating replication.
- Display GHES service status.
- Guardedly reload core services using `ghe-config-apply -f`.

> The current Galaxy role does not orchestrate a complete HA primary/replica
> upgrade. It does not sequence replica upgrades, perform promotion or failover,
> or support GHES cluster deployments.

## Repository layout

```text
.
├── ansible.cfg
├── requirements.yml
├── requirements-dev.txt
├── inventory/
│   ├── staging/
│   └── production/
├── playbooks/
│   ├── connectivity.yml
│   ├── health.yml
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

## Jump-host prerequisites

Install Python 3, Git, OpenSSH, and `make`. Ansible is installed into a local
virtual environment by the repository. Do not install Ansible or arbitrary
packages on the GHES appliance.

```bash
sudo dnf install -y python3 python3-pip git openssh-clients make
```

For Debian or Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv git openssh-client make
```

## Initial setup

```bash
git clone <this-repository-url>
cd ghes-ansible-operations
make setup
```

`make setup` creates `.venv`, installs the development dependencies, and runs:

```bash
ansible-galaxy role install \
  -r requirements.yml \
  -p .ansible/roles \
  --force
```

Ansible is configured to load roles from `.ansible/roles`.

## SSH configuration

Create an administrative SSH key and add its public key to GHES:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/ghes_ansible
export GHES_SSH_KEY="$HOME/.ssh/ghes_ansible"
```

Verify direct connectivity before using Ansible:

```bash
ssh -i "$GHES_SSH_KEY" -p 122 admin@github-staging.example.com ghe-version
```

## Configure inventory

Replace the example DNS names in:

- `inventory/staging/hosts.yml`
- `inventory/production/hosts.yml`
- the corresponding `host_vars` files

Inspect the resulting inventory:

```bash
.venv/bin/ansible-inventory -i inventory/staging/hosts.yml --graph
```

## Validate connectivity and health

```bash
make connectivity ENV=staging LIMIT=ghes-staging
make health ENV=staging LIMIT=ghes-staging
make service-status ENV=staging LIMIT=ghes-staging
```

## Prepare an upgrade

Create a local, ignored variables file:

```bash
cp vars/upgrade.example.yml vars/upgrade.yml
$EDITOR vars/upgrade.yml
```

For stronger protection, encrypt it:

```bash
.venv/bin/ansible-vault encrypt vars/upgrade.yml
```

Place the GHES upgrade package outside Git, such as under `/opt/ansible-ghes/packages`,
or export its path:

```bash
export GHES_UPGRADE_PACKAGE=/opt/ansible-ghes/packages/github-enterprise-3.21.1.pkg
```

## Upgrade standalone GHES

```bash
make upgrade-standalone \
  ENV=staging \
  LIMIT=ghes-staging
```

Production example:

```bash
make upgrade-standalone \
  ENV=production \
  LIMIT=ghes-production
```

## Upgrade an HA primary

```bash
make upgrade-ha-primary \
  ENV=production \
  LIMIT=ghes-primary
```

This command only runs the published role on the primary and validates
replication before and after the upgrade. Use a separately reviewed procedure
for replica sequencing and failover.

## Reload core services

```bash
make restart-core-services \
  ENV=production \
  LIMIT=ghes-primary
```

The playbook requires one targeted host, enables maintenance mode, runs
`ghe-config-apply -f`, validates configuration, and then disables maintenance
mode. On failure it leaves maintenance mode enabled by default.

## Safety controls

The upgrade role requires explicit values for:

- `ghes_upgrade_confirm`
- `ghes_upgrade_backup_confirmed`
- `ghes_upgrade_snapshot_confirmed`
- `ghes_upgrade_target_version`
- an upgrade package source

The consumer playbooks additionally require a single target through `--limit`.
Do not commit production secrets, private keys, upgrade packages, or live
approval variables.

## Helpful commands

```bash
make help
make requirements
make validate ENV=staging
make connectivity ENV=staging LIMIT=ghes-staging
make health ENV=production LIMIT=ghes-primary
make service-status ENV=production LIMIT=ghes-primary
```
