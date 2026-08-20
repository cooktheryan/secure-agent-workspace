Feature: VM one persistent OpenClaw state
  The Cirrus cloud-init package can attach persistent disks to VM one so
  OpenShell and OpenClaw state survive VM recreation.

  Rule: While VM one is provisioned, Cirrus cloud-init shall attach state and asset PVCs without mounting them directly.

    Scenario: VM one receives persistent state and asset disks
      Given the committed Server one manifest references the VM one persistence PVCs
      When VM one starts from cloud-init
      Then VM one receives separate disks for service state and assets

  Rule: If a VM one persistent disk is blank, then the agent playbook shall format it exactly once.

    Scenario: Blank VM one persistent disks are initialized safely
      Given VM one receives unformatted persistent disks
      When agent provisioning prepares persistent storage
      Then VM one formats each blank disk before mounting it

  Rule: While agent provisioning runs, the agent playbook shall mount OpenShell and OpenClaw state before service setup.

    Scenario: OpenShell service state is written to persistent storage
      Given VM one receives the persistent state disk
      When agent provisioning prepares OpenShell configuration
      Then VM one stores OpenShell configuration and gateway state on the persistent disk

    Scenario: OpenClaw sandbox storage is written to persistent storage
      Given VM one receives the persistent asset disk
      When agent provisioning prepares OpenClaw sandbox storage
      Then VM one stores rootless container storage on the persistent disk

  Rule: While VM one uses persistent sandbox storage, the agent playbook shall preserve an existing OpenClaw sandbox.

    Scenario: Existing OpenClaw sandbox survives reprovisioning
      Given VM one already has an OpenClaw sandbox
      When agent provisioning runs again
      Then the existing sandbox is reused instead of deleted
